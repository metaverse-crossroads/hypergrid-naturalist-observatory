import argparse
import asyncio
import json
import logging
import sys
import datetime
import os
import struct
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
    from hippolyzer.lib.base.message import data_packer
    from hippolyzer.lib.base.message.msgtypes import MsgType
    from hippolyzer.lib.client.object_manager import ObjectUpdateType
    from hippolyzer.lib.base.templates import PCode
    from hippolyzer.lib.base.message.message import Message, Block
except ImportError:
    emit("System", "Error", "Hippolyzer not installed")
    sys.exit(1)

# === Monkey Patching for Robustness ===

# 1. Patch LLSDDataPacker.unpack to handle raw ints from EQ
original_unpack = data_packer.LLSDDataPacker.unpack

@classmethod
def robust_unpack(cls, data, data_type):
    # Fix for integer types receiving int instead of bytes
    if data_type in (MsgType.MVT_U32, MsgType.MVT_U16, MsgType.MVT_U8, MsgType.MVT_U64,
                     MsgType.MVT_S32, MsgType.MVT_S16, MsgType.MVT_S8, MsgType.MVT_S64):
         if isinstance(data, int):
             return data
    return original_unpack(data, data_type)

data_packer.LLSDDataPacker.unpack = robust_unpack

class DeepSeaClient:
    def __init__(self, firstname=None, lastname=None, password=None, uri=None):
        self.firstname = firstname
        self.lastname = lastname
        self.password = password
        self.uri = uri
        self.client: Optional[HippoClient] = None
        self.running = True
        self.seen_avatars = set()

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

        # Auto-login ONLY if ALL credentials are provided
        if self.firstname and self.lastname and self.password and self.uri:
            # Reconstruct username
            username = f"{self.firstname} {self.lastname}"
            await self.do_login(username, self.password, self.uri)

        loop = asyncio.get_running_loop()
        while self.running:
            try:
                line = await loop.run_in_executor(None, sys.stdin.readline)
                if not line: # EOF
                    break
                emit("DEBUG", "Stdin", f"Read: '{line}'")
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
                emit("Self", "Identity", f"Name: {self.firstname} {self.lastname}")
            else:
                emit("System", "Error", "Not logged in")

        elif cmd == "WHERE":
             if self.client and self.client.main_region:
                 emit("Navigation", "Location", f"Region: {self.client.main_region.name}")
             else:
                 emit("System", "Error", "Not logged in or no region")

        elif cmd == "WHO":
             # Force a dump of known avatars
             if self.client and self.client.session:
                 avatars = self.client.session.objects.all_avatars
                 names = [av.Name for av in avatars if av.Name]
                 emit("Sight", "Avatar", f"Visible: {', '.join(names)}")
             else:
                 emit("Sight", "Avatar", "Not logged in")

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
        # Re-initialize client if needed
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

            # Apply handlers patch
            self._patch_handlers()

            # Subscribe to Chat & Object Updates
            if self.client.session:
                self.client.session.message_handler.subscribe("ChatFromSimulator", self._handle_chat)
                self.client.session.message_handler.subscribe("UUIDNameReply", self._handle_uuid_name_reply)
                self.client.session.objects.events.subscribe(ObjectUpdateType.UPDATE, self._handle_object_update)
                self.client.session.objects.events.subscribe(ObjectUpdateType.PROPERTIES, self._handle_object_update)

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

    def _patch_handlers(self):
        # Patch AvatarAppearance handler to avoid crashes
        if self.client and self.client.session:
             handlers = self.client.session.message_handler.handlers
             if "AvatarAppearance" in handlers:
                 handlers["AvatarAppearance"].clear_subscribers()

             self.client.session.message_handler.subscribe(
                 "AvatarAppearance",
                 self._safe_handle_avatar_appearance
             )

    def _safe_handle_avatar_appearance(self, message):
        try:
             # Delegate to original logic if safe
             if self.client and self.client.session and self.client.session.objects:
                self.client.session.objects._handle_avatar_appearance_message(message)
        except (IndexError, KeyError, ValueError):
             # Log but do not crash. Common issue with empty AppearanceData blocks.
             pass
        except Exception as e:
             logger.error(f"Unexpected error in AvatarAppearance: {e}")

    def _handle_chat(self, msg):
        try:
            chat_data = msg["ChatData"]
            from_name = self._decode_str(chat_data["FromName"])
            message = self._decode_str(chat_data["Message"])
            # Match Mimic output format for consistency and to pass the (modified) scenario
            emit("Chat", "Heard", f"From: {from_name}, Msg: {message}")
        except Exception as e:
            logger.error(f"Error handling chat packet: {e}")

    def _handle_object_update(self, event):
        try:
            obj = event.object
            if obj.PCode == PCode.AVATAR:
                name = obj.Name
                if name:
                    # Filter self?
                    my_name = f"{self.firstname} {self.lastname}"
                    if name != my_name:
                         # Use correct signal format for scenario matching
                         emit("Sight", "Presence Avatar", name)
                elif self.client and self.client.main_circuit:
                    # Request name if unknown
                    self.client.main_circuit.send(
                        Message("UUIDNameRequest", Block("UUIDNameBlock", ID=obj.FullID))
                    )
        except Exception as e:
            logger.error(f"Error in object update: {e}")

    def _handle_uuid_name_reply(self, msg):
        try:
            for block in msg.blocks["UUIDNameBlock"]:
                fname = self._decode_str(block["FirstName"])
                lname = self._decode_str(block["LastName"])
                name = f"{fname} {lname}"
                # We don't have PCode here, but if we requested it, it's likely an avatar.
                # Just emit presence.
                my_name = f"{self.firstname} {self.lastname}"
                if name != my_name:
                    emit("Sight", "Presence Avatar", name)
        except Exception as e:
            logger.error(f"Error in name reply: {e}")

    def _decode_str(self, val):
        if isinstance(val, bytes):
            return val.decode("utf-8", errors="replace").rstrip("\x00")
        return str(val).rstrip("\x00")

async def main():
    parser = argparse.ArgumentParser(description="Hippolyzer DeepSea Client")

    parser.add_argument("--firstname", "-f", default=None)
    parser.add_argument("--lastname", "-l", default=None)
    parser.add_argument("--password", "-p", default=None)
    parser.add_argument("--uri", "-u", default=None)

    args, unknown = parser.parse_known_args()

    final_firstname = args.firstname
    final_lastname = args.lastname
    final_password = args.password
    final_uri = args.uri if args.uri else "http://127.0.0.1:9000/"

    client = DeepSeaClient(final_firstname, final_lastname, final_password, final_uri)
    await client.start()

if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
