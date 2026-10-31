#!/usr/bin/env python3
"""Play a quiet generated signal and verify the packaged process-audio route."""
import math
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import time
import wave

app = Path(sys.argv[1] if len(sys.argv) > 1 else "dist/Cadence.app")
binary = app / "Contents/MacOS/Cadence"
if not binary.is_file():
    sys.exit("Build Cadence first with bash scripts/build.sh")

with tempfile.TemporaryDirectory(prefix="cadence-check-") as directory:
    tone = Path(directory) / "signal.wav"
    rate, duration = 48000, 12
    frames = bytearray()
    for i in range(rate * duration):
        envelope = min(1, i / (rate * 0.05), (rate * duration - i) / (rate * 0.05))
        sample = int(math.sin(2 * math.pi * 440 * i / rate) * 1000 * envelope)
        frames.extend(struct.pack("<hh", sample, sample))
    with wave.open(str(tone), "wb") as output:
        output.setparams((2, 2, rate, 0, "NONE", "not compressed"))
        output.writeframes(frames)
    player = subprocess.Popen(["/usr/bin/afplay", str(tone)])
    try:
        time.sleep(0.6)
        result = subprocess.run([str(binary), "--verify-pid", str(player.pid)], timeout=35)
    finally:
        player.terminate()
        player.wait()
    sys.exit(result.returncode)
