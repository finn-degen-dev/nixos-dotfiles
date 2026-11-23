import os
import select
import signal
import subprocess
import sys
import termios
import time

out_file = sys.argv[1]
raw_wav = out_file + ".wav"
os.makedirs(os.path.dirname(out_file), exist_ok=True)

# Open /dev/tty directly so ncurses/background subshell stdin does not trigger ioctl error
try:
    tty_fd = os.open("/dev/tty", os.O_RDWR)
    tty_in = os.fdopen(tty_fd, "rb", buffering=0)
    tty_out = os.fdopen(tty_fd, "wb", buffering=0)
except Exception:
    tty_in = sys.stdin.buffer
    tty_out = sys.stdout.buffer

# Capture uncompressed PCM first so live PulseAudio timestamps never leak into Ogg Opus
rec = subprocess.Popen(
    [
        "ffmpeg", "-y", "-v", "error",
        "-f", "pulse", "-i", "default",
        "-ac", "1", "-ar", "16000",
        "-f", "wav", raw_wav,
    ],
    stdin=subprocess.PIPE,
    stdout=subprocess.DEVNULL,
    stderr=subprocess.DEVNULL,
)

send_audio = False
start_ts = time.monotonic()
old_term = None

try:
    import tty

    try:
        old_term = termios.tcgetattr(tty_in.fileno())
        tty.setcbreak(tty_in.fileno())
    except Exception:
        old_term = None

    tty_out.write(b"\n")
    while True:
        if rec.poll() is not None:
            break
        elapsed = int(time.monotonic() - start_ts)
        mins, secs = divmod(elapsed, 60)
        status_line = (
            f"\r  \033[1;31m●\033[0m Recording voice message  {mins:02d}:{secs:02d}   "
            "[Enter/Space] Send   [q/Esc] Cancel   "
        )
        tty_out.write(status_line.encode("utf-8", "ignore"))

        rlist, _, _ = select.select([tty_in.fileno()], [], [], 0.1)
        if rlist:
            ch = tty_in.read(1)
            if ch in (b"\r", b"\n", b" "):
                send_audio = True
                break
            if ch in (b"q", b"Q", b"\x1b", b"\x03"):
                send_audio = False
                break
except KeyboardInterrupt:
    send_audio = False
finally:
    if old_term is not None:
        try:
            termios.tcsetattr(tty_in.fileno(), termios.TCSADRAIN, old_term)
        except Exception:
            pass
    tty_out.write(b"\n\033[0m")

# Ask ffmpeg to quit gracefully via 'q' so the WAV header and samples flush cleanly
if rec.poll() is None:
    try:
        if rec.stdin is not None:
            rec.stdin.write(b"q\n")
            rec.stdin.flush()
            rec.stdin.close()
        rec.wait(timeout=3)
    except Exception:
        if rec.poll() is None:
            rec.send_signal(signal.SIGINT)
            try:
                rec.wait(timeout=2)
            except subprocess.TimeoutExpired:
                rec.kill()
                rec.wait()

encoded_ok = False
try:
    if send_audio and os.path.isfile(raw_wav) and os.path.getsize(raw_wav) > 44:
        flt = subprocess.Popen(
            [
                "ffmpeg", "-y", "-v", "error",
                "-i", raw_wav,
                "-af", "highpass=f=80",
                "-ac", "1", "-ar", "16000",
                "-f", "wav", "-",
            ],
            stdout=subprocess.PIPE,
            stderr=subprocess.DEVNULL,
        )
        enc = subprocess.Popen(
            [
                "opusenc", "--quiet",
                "--vbr", "--bitrate", "16",
                "--comp", "10", "--framesize", "20",
                "--speech", "--discard-comments",
                "-", out_file,
            ],
            stdin=flt.stdout,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        if flt.stdout is not None:
            flt.stdout.close()
        enc_rc = enc.wait()
        flt_rc = flt.wait()
        encoded_ok = (enc_rc == 0) and (flt_rc == 0) and os.path.isfile(out_file) and os.path.getsize(out_file) > 512
finally:
    if os.path.exists(raw_wav):
        try:
            os.unlink(raw_wav)
        except OSError:
            pass

if encoded_ok:
    sys.exit(0)

if os.path.exists(out_file):
    try:
        os.unlink(out_file)
    except OSError:
        pass
sys.exit(1)
