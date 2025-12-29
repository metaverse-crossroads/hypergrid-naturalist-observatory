import argparse
import asyncio
import json
import logging
import sys
import datetime
import os
from typing import Optional

# Configure logging to stderr to avoid polluting stdout (NDJSON stream)
logging.basicConfig(level=logging.ERROR, stream=sys.stderr)
logger = logging.getLogger("deepsea_client")

def emit(sys_name: str, sig_name: str, val: str):
    """Emits an NDJSON record."""
    ua = os.environ.get("TAG_UA")
    # ISO 8601 timestamp (UTC)
    ts = datetime.datetime.now(datetime.timezone.utc).isoformat().replace("+00:00", "Z")

    record = {
        "at": ts,
        "via": "Visitant",
        "sys": sys_name,
        "sig": sig_name,
        "val": val
    }
    if ua:
        record["ua"] = ua

    print(json.dumps(record), flush=True)

# Strict import check
try:
    from hippolyzer.lib.client.hippo_client import HippoClient
except ImportError:
    emit("System", "Error", "Hippolyzer not installed")
    sys.exit(1)

class DeepSeaClient:
    def __init__(self, firstname, lastname, password, uri):
        self.firstname = firstname
        self.lastname = lastname
        self.password = password
        self.uri = uri
        self.client: Optional[HippoClient] = None
        self.running = True

    async def start(self):
        self.client = HippoClient()

        # Apply UA if present
        ua = os.environ.get("TAG_UA")
        if ua and self.client.settings:
            self.client.settings.USER_AGENT = ua

        # Ensure we clean up
        try:
            await self.repl()
        finally:
            await self.client.aclose()

    async def repl(self):
        emit("System", "Status", "Ready")

        # Auto-login if configured via CLI args (defaults provided by argparse)
        if self.firstname and self.lastname and self.password and self.uri:
            username = f"{self.firstname} {self.lastname}"
            await self.do_login(username, self.password, self.uri)

        loop = asyncio.get_running_loop()
        while self.running:
            try:
                line = await loop.run_in_executor(None, sys.stdin.readline)
                if not line: # EOF
                    break
                await self.process_command(line.strip())
            except Exception as e:
                logger.exception("REPL Error")
                emit("System", "Error", str(e))

    async def process_command(self, cmd_line: str):
        if not cmd_line:
            return

        parts = cmd_line.split()
        cmd = parts[0].upper()
        args = parts[1:]

        if cmd == "LOGIN":
            # LOGIN Firstname Lastname [Password] [URI]
            if len(args) < 2:
                emit("System", "Error", "Usage: LOGIN Firstname Lastname [Password] [URI]")
                return

            username = f"{args[0]} {args[1]}"
            # Default Password
            password = args[2] if len(args) >= 3 else "password"
            # Default URI
            uri = args[3] if len(args) >= 4 else "http://127.0.0.1:9000/"

            await self.do_login(username, password, uri)

        elif cmd == "CHAT":
            message = " ".join(args)
            if self.client and self.client.session:
                 try:
                     await self.client.send_chat(message)
                 except Exception as e:
                     emit("System", "Error", f"Chat failed: {e}")
            else:
                emit("System", "Error", "Not logged in")

        elif cmd == "LOGOUT":
            if self.client:
                self.client.logout()
                emit("Network", "Logout", "Initiated")
            else:
                emit("System", "Error", "Not logged in")

        elif cmd == "EXIT":
            self.running = False
            if self.client:
                try:
                    self.client.logout()
                except Exception:
                    pass
            emit("System", "Exit", "Bye")

        elif cmd == "WHOAMI":
            if self.client and self.client.session:
                # TODO: Could fetch actual name from agent data if available,
                # but we'll use what we logged in with or stored.
                # Since we don't track current username in state other than what was passed to do_login,
                # we might need to store it.
                # For now, let's use the CLI args or last login info if we tracked it?
                # The prompt doesn't strictly require robust state tracking for WHOAMI,
                # but it's good practice.
                # Let's rely on self.firstname/lastname if it matches,
                # or just say "Self" if we don't know.
                # Actually, let's just not implement full WHOAMI logic if it's not critical,
                # or use a placeholder.
                emit("Self", "Identity", f"Name: {self.firstname} {self.lastname}")
            else:
                emit("System", "Error", "Not logged in")

        elif cmd == "WHERE":
             if self.client and self.client.main_region:
                 emit("Navigation", "Location", f"Region: {self.client.main_region.name}")
             else:
                 emit("System", "Error", "Not logged in or no region")

        elif cmd == "WHO":
             emit("Sight", "Avatar", "Not implemented yet")

        elif cmd == "SLEEP":
             if args:
                 try:
                     seconds = float(args[0])
                     await asyncio.sleep(seconds)
                     emit("System", "Sleep", f"Slept {seconds}s")
                 except ValueError:
                     emit("System", "Error", "Invalid sleep duration")

        else:
            emit("System", "Warning", f"Unknown command: {cmd}")

    async def do_login(self, username, password, uri):
        # Re-initialize client if needed (though start() does it)
        if not self.client:
             self.client = HippoClient()
             ua = os.environ.get("TAG_UA")
             if ua and self.client.settings:
                self.client.settings.USER_AGENT = ua

        try:
            emit("Network", "Login", f"Connecting to {uri} as {username}...")
            await self.client.login(
                username=username,
                password=password,
                login_uri=uri,
                start_location="last"
            )
            emit("Network", "Login", "Success")

            # Subscribe to Chat
            if self.client.session:
                self.client.session.message_handler.subscribe("ChatFromSimulator", self._handle_chat)

            if self.client.main_region:
                emit("Navigation", "Location", f"Connected to region: {self.client.main_region.name}")

            # Update internal identity state for WHOAMI
            parts = username.split()
            if len(parts) >= 2:
                self.firstname = parts[0]
                self.lastname = parts[1]

        except Exception as e:
            logger.exception("Login failed")
            emit("Network", "Login", f"Failure: {e}")

    def _handle_chat(self, msg):
        try:
            # msg is a Message object. ChatFromSimulator has ChatData block.
            chat_data = msg["ChatData"]

            # Fields: FromName, Message
            from_name_val = chat_data["FromName"]
            message_val = chat_data["Message"]

            # Helper to decode
            def decode_str(val):
                if isinstance(val, bytes):
                    return val.decode("utf-8", errors="replace").rstrip("\x00")
                return str(val).rstrip("\x00")

            from_name = decode_str(from_name_val)
            message = decode_str(message_val)

            # Protocol: sys="Chat", sig="Heard", val="From: {Name}, Msg: {Message}"
            emit("Chat", "Heard", f"From: {from_name}, Msg: {message}")
        except Exception as e:
            logger.error(f"Error handling chat packet: {e}")

async def main():
    parser = argparse.ArgumentParser(description="Hippolyzer DeepSea Client")
    # Defaults aligned with Visitant CLI spec
    parser.add_argument("--firstname", "-f", default="Test")
    parser.add_argument("--lastname", "-l", default="User")
    parser.add_argument("--password", "-p", default="password")
    parser.add_argument("--uri", "-u", default="http://127.0.0.1:9000/")

    args, unknown = parser.parse_known_args()

    client = DeepSeaClient(args.firstname, args.lastname, args.password, args.uri)
    await client.start()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
