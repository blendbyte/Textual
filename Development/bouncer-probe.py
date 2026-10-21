#!/usr/bin/env python3
#
# A raw IRC probe for the test bouncers in the VM (vm-dev bouncer start):
# prints every line sent and received. Run there with the bundled Python:
#   TextualTest/python/bin/python3 TextualTest/Development/bouncer-probe.py [soju|znc]

import base64, socket, sys, time

def session(port, lines, wait=3.0, label=""):
    print(f"===== {label} (port {port})")
    s = socket.create_connection(("127.0.0.1", port), timeout=5)
    s.settimeout(0.3)
    buf = b""
    def send(line):
        print(">>", line)
        s.sendall((line + "\r\n").encode())
    def drain(seconds):
        nonlocal buf
        end = time.time() + seconds
        while time.time() < end:
            try:
                chunk = s.recv(65536)
                if not chunk:
                    return
                buf += chunk
            except socket.timeout:
                pass
            while b"\r\n" in buf:
                line, buf = buf.split(b"\r\n", 1)
                text = line.decode("utf-8", "replace")
                print("<<", text)
                if text.startswith("PING"):
                    send("PONG" + text[4:])
    for line in lines:
        if isinstance(line, float):
            drain(line)
        else:
            send(line)
    drain(wait)
    s.close()

plain = base64.b64encode(b"dan\0dan\0textual").decode()

which = sys.argv[1] if len(sys.argv) > 1 else "all"

if which in ("soju", "all"):
    session(6670, ["CAP LS 302", 0.5, "CAP REQ :soju.im/bouncer-networks soju.im/bouncer-networks-notify sasl batch message-tags server-time", 0.5,
                   "AUTHENTICATE PLAIN", 0.5, "AUTHENTICATE " + plain, 0.5, "NICK probe", "USER probe 0 * :probe", "CAP END", 1.5,
                   "BOUNCER LISTNETWORKS"], wait=2.0, label="soju: unbound, list networks")

if which in ("znc", "all"):
    session(6672, ["CAP LS 302", 0.5, "CAP END", "PASS dan:textual", "NICK probe", "USER dan 0 * :probe", 2.0,
                   "PRIVMSG *status :ListNetworks", 2.0], wait=1.0, label="znc: login without a network")
    session(6672, ["CAP LS 302", 0.5, "CAP END", "PASS dan/ergo:textual", "NICK probe", "USER dan 0 * :probe"], wait=3.0,
            label="znc: login to network ergo")
    session(6672, ["CAP LS 302", 0.5, "CAP REQ :sasl", 0.5, "AUTHENTICATE PLAIN", 0.5,
                   "AUTHENTICATE " + base64.b64encode(b"dan/ergotwo\0dan/ergotwo\0textual").decode(), 0.5, "CAP END", "NICK probe", "USER dan 0 * :probe"],
            wait=3.0, label="znc: SASL PLAIN as dan/ergotwo")
