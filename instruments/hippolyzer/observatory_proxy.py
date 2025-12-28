import asyncio
import logging
import socket
import struct
import sys
import re

# --- CONFIGURATION ---
# The port your test clients will connect to
# Client thinks Sim is here.
WRAPPER_LISTEN_PORT = 9050
WRAPPER_LISTEN_HOST = '0.0.0.0'

# Hippolyzer details
HIPPO_HOST = '127.0.0.1'
HIPPO_SOCKS_PORT = 9061  # For UDP
HIPPO_HTTP_PORT = 9062   # For TCP (Login)

# The REAL destination (Your OpenSim.dll instance)
DEST_SIM_HOST = '127.0.0.1'
DEST_SIM_PORT = 9000
DEST_SIM_HTTP_URL = f"http://{DEST_SIM_HOST}:{DEST_SIM_PORT}"

# SOCKS5 Constants
SOCKS_VER = b'\x05'
SOCKS_AUTH_NONE = b'\x00'
CMD_UDP_ASSOC = b'\x03'
ATYP_IPV4 = b'\x01'
RSV = b'\x00'

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s | %(levelname)s | %(message)s',
    datefmt='%H:%M:%S'
)
logger = logging.getLogger("ObservatoryProxy")

class Socks5Client:
    """Helper to handle the SOCKS5 handshake with Hippolyzer (UDP ONLY)."""
    @staticmethod
    async def connect_and_handshake(reader, writer):
        writer.write(SOCKS_VER + b'\x01' + SOCKS_AUTH_NONE)
        await writer.drain()
        ver, method = struct.unpack("!BB", await reader.readexactly(2))
        if ver != 5 or method != 0:
            raise ConnectionError(f"SOCKS5 handshake failed: Ver={ver}, Method={method}")

    @staticmethod
    async def udp_associate(reader, writer):
        # Request UDP Associate on 0.0.0.0:0
        req = SOCKS_VER + CMD_UDP_ASSOC + RSV + ATYP_IPV4 + socket.inet_aton('0.0.0.0') + struct.pack("!H", 0)
        writer.write(req)
        await writer.drain()
        
        data = await reader.readexactly(10)
        ver, rep, rsv, atyp = struct.unpack("!BBBB", data[:4])
        if rep != 0:
            raise ConnectionError(f"SOCKS5 UDP ASSOC failed with code: {rep}")
            
        bind_ip = socket.inet_ntoa(data[4:8])
        bind_port = struct.unpack("!H", data[8:10])[0]
        return bind_ip, bind_port

async def handle_tcp_client(client_reader, client_writer):
    """
    Bridges a TCP connection (HTTP Login).
    1. REQUEST: Rewrites standard HTTP requests to Proxy requests for Hippolyzer.
    2. RESPONSE: Rewrites '9000' to '9050' in the body to trick client into using our UDP port.
    """
    peer = client_writer.get_extra_info('peername')
    logger.info(f"[TCP] Login connection from {peer}")

    try:
        # Connect to Hippolyzer's HTTP Proxy
        hippo_reader, hippo_writer = await asyncio.open_connection(HIPPO_HOST, HIPPO_HTTP_PORT)
        
        # --- HANDLE REQUEST (Client -> Hippo) ---
        initial_data = await client_reader.read(4096)
        if not initial_data: return

        # Rewrite "POST /uri HTTP/1.1" -> "POST http://dest:port/uri HTTP/1.1"
        try:
            text_data = initial_data.decode('latin-1')

            # 1. Rewrite Request Line
            first_line_end = text_data.find('\r\n')
            if first_line_end != -1:
                first_line = text_data[:first_line_end]
                match = re.match(r'^([A-Z]+)\s+(/[^\s]*)\s+(HTTP/\d\.\d)$', first_line)
                if match:
                    method, path, version = match.groups()
                    new_uri = f"{DEST_SIM_HTTP_URL}{path}"
                    new_first_line = f"{method} {new_uri} {version}"
                    # Swap the line
                    text_data = text_data.replace(first_line, new_first_line, 1)
                    logger.info(f"[TCP] Rewrote Request: {first_line} -> {new_first_line}")

            # 2. Rewrite Host Header (Catch 127.0.0.1, localhost, and 0.0.0.0)
            text_data = re.sub(r'Host: .*?\r\n', f'Host: {DEST_SIM_HOST}:{DEST_SIM_PORT}\r\n', text_data, count=1, flags=re.IGNORECASE)

            # 3. Disable Gzip (Force plain text for safe port rewriting)
            text_data = re.sub(r'Accept-Encoding: .*?\r\n', '', text_data, flags=re.IGNORECASE)

            initial_data = text_data.encode('latin-1')

        except Exception as e:
            logger.error(f"[TCP] Request Rewrite Error: {e}")

        hippo_writer.write(initial_data)
        await hippo_writer.drain()

        # Start background task to pipe remaining request body (if any)
        async def pipe_request():
            try:
                while True:
                    data = await client_reader.read(4096)
                    if not data: break
                    hippo_writer.write(data)
                    await hippo_writer.drain()
            except: pass
            
        req_task = asyncio.create_task(pipe_request())

        # --- HANDLE RESPONSE (Hippo -> Client) ---
        # We perform the "Trivial String Replace" here.
        # We replace the Real Port (9000) with the Proxy Port (9050)
        # Since string lengths are identical, Content-Length headers remain valid.
        
        target_bytes = str(DEST_SIM_PORT).encode('ascii')       # b'9000'
        replacement_bytes = str(WRAPPER_LISTEN_PORT).encode('ascii') # b'9050'

        while True:
            data = await hippo_reader.read(4096)
            if not data: break
            
            # The "Duh" Logic: Blind replace.
            # Warning: This replaces ALL occurrences of '9000'. 
            # In a login response, this is almost certainly just the port.
            if target_bytes in data:
                logger.info("[TCP] Patched Login Response (Port Rewrite)")
                data = data.replace(target_bytes, replacement_bytes)
            
            client_writer.write(data)
            await client_writer.drain()

        req_task.cancel()

    except Exception as e:
        logger.error(f"[TCP] Bridge error: {e}")
    finally:
        client_writer.close()
        logger.info(f"[TCP] Closed connection {peer}")

class UDPBridgeProtocol(asyncio.DatagramProtocol):
    """
    The UDP Bridge. 
    Wraps Client UDP -> SOCKS5 -> Hippolyzer -> OpenSim
    """
    def __init__(self):
        self.transport = None
        self.hippo_udp_addr = None
        self.hippo_transport = None
        self.last_client_addr = None
        self.packet_queue = []

    def connection_made(self, transport):
        self.transport = transport
        asyncio.create_task(self.setup_socks_association())

    async def setup_socks_association(self):
        try:
            # 1. TCP Control Connection to Hippolyzer (SOCKS Port)
            reader, writer = await asyncio.open_connection(HIPPO_HOST, HIPPO_SOCKS_PORT)
            
            await Socks5Client.connect_and_handshake(reader, writer)
            
            # 2. Request UDP Associate
            bind_ip, bind_port = await Socks5Client.udp_associate(reader, writer)
            
            self.hippo_udp_addr = (bind_ip, bind_port)
            logger.info(f"[UDP] SOCKS5 UDP Associated. Relay Endpoint: {bind_ip}:{bind_port}")

            # 3. Create a socket to talk to Hippolyzer's UDP endpoint
            loop = asyncio.get_running_loop()
            self.hippo_transport, _ = await loop.create_datagram_endpoint(
                lambda: HippoRelayProtocol(self),
                remote_addr=self.hippo_udp_addr
            )
            
            # Flush queued packets
            while self.packet_queue:
                data = self.packet_queue.pop(0)
                self.forward_data(data)

            # 4. Keep TCP alive
            while True:
                if not await reader.read(1): break
                
        except Exception as e:
            logger.error(f"[UDP] SOCKS Setup Failed: {e}")
            sys.exit(1)

    def datagram_received(self, data, addr):
        # Traffic FROM Client (Raw LLUDP)
        self.last_client_addr = addr 
        
        if self.hippo_transport:
            self.forward_data(data)
        else:
            self.packet_queue.append(data)

    def forward_data(self, data):
        if self.hippo_transport and not self.hippo_transport.is_closing():
            # Wrap in SOCKS5 UDP Header: RSVP | FRAG | ATYP | DST.ADDR | DST.PORT | DATA
            # We hardcode the destination to 127.0.0.1:9000 (OpenSim)
            header = b'\x00\x00\x00\x01' + socket.inet_aton(DEST_SIM_HOST) + struct.pack("!H", DEST_SIM_PORT)
            self.hippo_transport.sendto(header + data)

    def send_to_client(self, raw_data):
        if self.last_client_addr:
            self.transport.sendto(raw_data, self.last_client_addr)

class HippoRelayProtocol(asyncio.DatagramProtocol):
    def __init__(self, bridge):
        self.bridge = bridge

    def datagram_received(self, data, addr):
        # Traffic FROM Hippolyzer (SOCKS5 Wrapped)
        # Unwrap (Skip 10 byte header) and send to client
        if len(data) > 10:
            self.bridge.send_to_client(data[10:])

async def main():
    logger.info(f"--- Observatory Dumb Proxy v3 ---")
    logger.info(f"1. Client Login URI: http://{WRAPPER_LISTEN_HOST}:{WRAPPER_LISTEN_PORT}/")
    logger.info(f"2. Hippolyzer:       127.0.0.1 (UDP: {HIPPO_SOCKS_PORT}, TCP: {HIPPO_HTTP_PORT})")
    logger.info(f"3. Target OpenSim:   {DEST_SIM_HTTP_URL}")

    tcp_server = await asyncio.start_server(
        handle_tcp_client, WRAPPER_LISTEN_HOST, WRAPPER_LISTEN_PORT
    )

    loop = asyncio.get_running_loop()
    await loop.create_datagram_endpoint(
        lambda: UDPBridgeProtocol(),
        local_addr=(WRAPPER_LISTEN_HOST, WRAPPER_LISTEN_PORT)
    )

    async with tcp_server:
        await tcp_server.serve_forever()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass

