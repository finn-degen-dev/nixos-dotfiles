import os
import sys
import tempfile
import urllib.parse

secret_path = sys.argv[1]
conf_path = sys.argv[2]
addr_path = sys.argv[3]
name_path = sys.argv[4]

with open(secret_path, "r", encoding="utf-8") as f:
    pw = f.read().rstrip("\r\n")

with open(addr_path, "r", encoding="utf-8") as f:
    email = f.read().strip()

with open(name_path, "r", encoding="utf-8") as f:
    display_name = f.read().strip()

# Strip whitespace (e.g. grouped 4-char blocks or trailing space from Google App Passwords)
pw = "".join(urllib.parse.unquote(pw).split())
encoded_pw = urllib.parse.quote(pw, safe="")
encoded_user = urllib.parse.quote(email, safe="")
content = (
    "[Personal]\n"
    f"source        = imaps://{encoded_user}:{encoded_pw}@imap.gmail.com:993\n"
    f"outgoing      = smtp://{encoded_user}:{encoded_pw}@smtp.gmail.com:587\n"
    "default       = INBOX\n"
    f"from          = {display_name} <{email}>\n"
    "cache-headers = true\n"
)

conf_dir = os.path.dirname(conf_path)
os.makedirs(conf_dir, exist_ok=True)
fd, tmp_path = tempfile.mkstemp(dir=conf_dir, prefix=".accounts.conf.")
try:
    os.fchmod(fd, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as out:
        out.write(content)
    os.replace(tmp_path, conf_path)
except Exception:
    if os.path.exists(tmp_path):
        os.unlink(tmp_path)
    raise
