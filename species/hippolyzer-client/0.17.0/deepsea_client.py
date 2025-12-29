import argparse
import asyncio
import json
import logging
import sys
import datetime
from typing import Optional

# Attempt to import HippoClient.
# This script runs in an environment where hippolyzer is installed.
try:
    from hippolyzer.lib.client.hippo_client import HippoClient
except ImportError:
    # Fallback for when running in an environment without hippolyzer (e.g. during simple syntax check)
    # But strictly this should fail if run for real.
    HippoClient = None

# Configure logging to stderr to avoid polluting stdout (REPL output)
logging.basicConfig(level=logging.ERROR, stream=sys.stderr)
logger = logging.getLogger("deepsea_client")

def emit(sys_name: str, sig_name: str, val: str):
    """Emits an NDJSON record."""
    record = {
        "at": datetime.datetime.now(datetime.timezone.utc).isoformat(),
        "via": "Visitant",
        "sys": sys_name,
        "sig": sig_name,
        "val": val
    }
    print(json.dumps(record), flush=True)

class DeepSeaClient:
    def __init__(self, firstname, lastname, password, uri):
        self.firstname = firstname
        self.lastname = lastname
        self.password = password
        self.uri = uri
        self.client: Optional[HippoClient] = None
        self.running = True

    async def start(self):
        if HippoClient is None:
            emit("System", "Error", "Hippolyzer not installed")
            return

        self.client = HippoClient()
        # Ensure we clean up
        try:
            await self.repl()
        finally:
            await self.client.aclose()

    async def repl(self):
        emit("System", "Status", "Ready")

        # Auto-login if configured via CLI args (standard Visitant behavior)
        if self.firstname and self.lastname and self.password and self.uri:
            # We construct the username. If firstname/lastname are provided, we use them.
            # Note: "Test User" is default.
            await self.do_login(f"{self.firstname} {self.lastname}", self.password, self.uri)

        loop = asyncio.get_running_loop()
        while self.running:
            try:
                # Read stdin in a thread to avoid blocking the async loop
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
            # LOGIN [First] [Last] [Pass] [URI]
            if len(args) >= 4:
                username = f"{args[0]} {args[1]}"
                password = args[2]
                uri = args[3]
                await self.do_login(username, password, uri)
            else:
                emit("System", "Error", "Usage: LOGIN First Last Pass URI")

        elif cmd == "CHAT":
            message = " ".join(args)
            if self.client and self.client.session:
                 try:
                     # Attempt to send chat. Defaulting type if possible.
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
                # We assume client.logout() is safe to call even if not fully logged in or already logged out
                try:
                    self.client.logout()
                except:
                    pass
            emit("System", "Exit", "Bye")

        elif cmd == "WHOAMI":
            if self.client and self.client.session:
                # TODO: Retrieve actual UUID/Name from session if available
                val = f"Name: {self.firstname} {self.lastname}"
                emit("Self", "Identity", val)
            else:
                emit("System", "Error", "Not logged in")

        elif cmd == "WHERE":
             if self.client and self.client.main_region:
                 emit("Navigation", "Location", f"Region: {self.client.main_region.name}")
             else:
                 emit("System", "Error", "Not logged in or no region")

        elif cmd == "WHO":
             # TODO: Implement avatar listing
             emit("Sight", "Avatar", "Not implemented yet (TODO)")

        elif cmd == "SLEEP":
             # SLEEP <seconds>
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
        if not self.client:
             self.client = HippoClient()

        try:
            emit("Network", "Login", f"Connecting to {uri} as {username}...")
            await self.client.login(
                username=username,
                password=password,
                login_uri=uri,
                start_location="last"
            )
            emit("Network", "Login", "Success")
            if self.client.main_region:
                emit("Navigation", "Location", f"Connected to region: {self.client.main_region.name}")
        except Exception as e:
            logger.exception("Login failed")
            emit("Network", "Login", f"Failure: {e}")

async def main():
    parser = argparse.ArgumentParser(description="Hippolyzer DeepSea Client")
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
