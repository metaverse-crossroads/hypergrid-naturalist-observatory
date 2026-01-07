#!/usr/bin/env python3
import urllib.request
import urllib.parse
import urllib.error
import argparse
import sys
import time
import xml.etree.ElementTree as ET
import json
import threading

class ConsoleSession:
    def __init__(self, base_url, user, password):
        self.base_url = base_url
        self.user = user
        self.password = password
        self.session_id = None
        self.last_line_seen = 0 # Not strictly used by us, but concept is there

    def _make_request(self, url, params=None):
        try:
            if params:
                data = urllib.parse.urlencode(params).encode('utf-8')
                req = urllib.request.Request(url, data=data)
            else:
                req = urllib.request.Request(url)

            with urllib.request.urlopen(req, timeout=0.25) as response:
                return response.read().decode('utf-8')
        except Exception as e:
            # sys.stderr.write(f"Request Error: {e}\n")
            return None

    def connect(self):
        url = f"{self.base_url}/StartSession/"
        response = self._make_request(url, {'USER': self.user, 'PASS': self.password})
        if not response:
            return False

        try:
            root = ET.fromstring(response.strip())
            sid = root.find('SessionID')
            if sid is not None and sid.text:
                self.session_id = sid.text.strip()
                return True
        except:
            pass
        return False

    def send(self, command):
        if not self.session_id: return False
        url = f"{self.base_url}/SessionCommand/"
        response = self._make_request(url, {'ID': self.session_id, 'COMMAND': command})
        return response and "Result>OK" in response

    def poll(self):
        if not self.session_id: return None
        url = f"{self.base_url}/ReadResponses/{self.session_id}"
        return self._make_request(url)

def parse_lines(xml_content):
    if not xml_content: return []
    try:
        root = ET.fromstring(xml_content)
        parsed = []
        for line in root.findall('Line'):
            entry = {
                'text': line.text or "",
                'input': line.get('Input') == 'true',
                'prompt': line.get('Prompt') == 'true',
                'command': line.get('Command') == 'true'
            }
            parsed.append(entry)
        return parsed
    except:
        return []

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--url", required=True)
    parser.add_argument("--user", required=True)
    parser.add_argument("--password", required=True)
    parser.add_argument("--timeout", type=float, default=1.0)
    args = parser.parse_args()

    session = ConsoleSession(args.url, args.user, args.password)
    import time
    st = time.time()
    connected = False
    while (time.time()-st) < args.timeout and not connected:
        # print("session.connect...", file=sys.stderr)
        connected = session.connect()
        time.sleep(0.25)
    if not connected:
        print("NOT CONNECTED", file=sys.stderr)
        print(json.dumps({"error": f"Failed to connect (TIMEOUT={args.timeout}s; dt={(time.time()-st)})"}))
        sys.exit(1)

    print(json.dumps({"event": "connected", "session_id": session.session_id}), flush=True)

    # REPL Loop
    for line in sys.stdin:
        command = line.strip()
        if not command: continue

        # 1. Send Command
        if not session.send(command):
            print(json.dumps({"error": "Send failed", "command": command}), flush=True)
            continue

        # 2. Poll for Output
        # We need to find the ECHO of our command (Input=true, text=command)
        # Then capture until Prompt=true

        captured_output = []
        seen_echo = False
        start_time = time.time()
        timeout = 10.0 # seconds

        while time.time() - start_time < timeout:
            xml_resp = session.poll()
            lines = parse_lines(xml_resp)

            complete = False
            for l in lines:
                # sys.stderr.write(f"DEBUG LINE: {l}\n")

                # Check for Echo
                if not seen_echo:
                    # Note: OpenSim echoes inputs.
                    # Strict matching: l['input'] and l['text'].strip() == command
                    # Relaxed matching: just l['input']? No, might see previous inputs if race?
                    if l['input'] and (l['text'].strip() == command or command in l['text']):
                        seen_echo = True
                        continue # Don't include the echo in output

                if seen_echo:
                    if l['prompt']:
                        complete = True
                        break # Done
                    if not l['input'] and not l['command']: # Normal output
                        captured_output.append(l['text'])

            if complete:
                break

            time.sleep(0.2)

        # 3. Emit Result
        result = {
            "command": command,
            "response": "\n".join(captured_output).split('#---')[-1].removeprefix('# \n'),
            "status": "OK" if seen_echo else "TIMEOUT"
        }
        print(json.dumps(result), flush=True)

if __name__ == "__main__":
    main()
