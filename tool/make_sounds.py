"""Synthesises Cairn's sound effects into assets/sounds/ as 16-bit mono WAV.

Every sound is generated here from sine partials and filtered noise, so the
set is original and needs no licence. The palette is "stones and mallets":
pieces settle with a short stone clack, line clears ring like a soft marimba
on a pentatonic scale, so any combination stays consonant.

Run:  python3 tool/make_sounds.py
"""

import math
import pathlib
import random
import struct
import wave

RATE = 44100
OUT = pathlib.Path(__file__).resolve().parent.parent / "assets" / "sounds"
random.seed(7)  # deterministic output


def silence(seconds):
    return [0.0] * int(RATE * seconds)


def mix(into, sound, at=0.0, gain=1.0):
    start = int(at * RATE)
    if len(into) < start + len(sound):
        into.extend([0.0] * (start + len(sound) - len(into)))
    for i, s in enumerate(sound):
        into[start + i] += s * gain
    return into


def partials(freqs, seconds, decays, gains, attack=0.002):
    """Sum of exponentially decaying sines: a struck object's modes."""
    out = []
    for i in range(int(RATE * seconds)):
        t = i / RATE
        env_a = min(1.0, t / attack)
        out.append(
            env_a
            * sum(g * math.exp(-t / d) * math.sin(2 * math.pi * f * t) for f, d, g in zip(freqs, decays, gains))
        )
    return out


def noise_burst(seconds, decay, smooth):
    """Low-passed noise with a fast decay: the grit of stone on stone."""
    out, y = [], 0.0
    for i in range(int(RATE * seconds)):
        y += smooth * (random.uniform(-1, 1) - y)
        out.append(y * math.exp(-(i / RATE) / decay))
    return out


def mallet(freq, seconds=0.7):
    """Soft marimba-like note: fundamental plus the bar's 4x overtone."""
    return partials([freq, freq * 3.93, freq * 9.2], seconds, [0.32, 0.06, 0.02], [1.0, 0.28, 0.06], attack=0.003)


def note(name):
    names = {"C": -9, "D": -7, "E": -5, "G": -2, "A": 0}
    return 440.0 * 2 ** ((names[name[0]] + 12 * (int(name[1:]) - 4)) / 12)


def stone(pitch=1.0, weight=1.0):
    body = partials(
        [380 * pitch, 1010 * pitch, 2150 * pitch],
        0.16,
        [0.035, 0.018, 0.009],
        [1.0, 0.55, 0.25],
        attack=0.0008,
    )
    return mix(body, noise_burst(0.05, 0.008, 0.35), gain=0.5 * weight)


def write(name, samples, peak=0.7):
    top = max(abs(s) for s in samples) or 1.0
    fade = int(RATE * 0.01)  # avoid a click at the cut
    data = bytearray()
    for i, s in enumerate(samples):
        if i > len(samples) - fade:
            s *= (len(samples) - i) / fade
        data += struct.pack("<h", int(max(-1, min(1, s / top * peak)) * 32767))
    OUT.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT / f"{name}.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(data))


# Rotate: a light wooden tick, quieter than everything else.
write("rotate", partials([1750, 3900], 0.05, [0.012, 0.005], [1.0, 0.3], attack=0.0005), peak=0.32)

# Lock: a piece settles with a small stone clack.
write("lock", stone(), peak=0.5)

# Hard drop: a lower, heavier stone with a short thud under it.
thud = [math.exp(-(i / RATE) / 0.05) * math.sin(2 * math.pi * (150 - 60 * i / RATE / 0.2) * i / RATE) for i in range(int(RATE * 0.2))]
write("hard_drop", mix(stone(pitch=0.8, weight=1.4), thud, gain=0.9), peak=0.68)

# Line clear: a rising three-note mallet figure.
clear = silence(0.0)
for k, n in enumerate(["C6", "E6", "G6"]):
    mix(clear, mallet(note(n)), at=0.055 * k)
write("clear", clear, peak=0.6)

# Four lines: a longer five-note run that lands on a held chord.
big = silence(0.0)
for k, n in enumerate(["C6", "D6", "E6", "G6", "A6"]):
    mix(big, mallet(note(n)), at=0.05 * k)
for n in ["C6", "E6", "G6", "C7"]:
    mix(big, mallet(note(n), 1.1), at=0.3, gain=0.7)
write("clear_four", big, peak=0.72)

# Level up: an upward fifth, bright but short.
up = mix(mallet(note("G5"), 0.6), mallet(note("D6"), 0.6), at=0.09)
write("level_up", up, peak=0.55)

# Game over: a slow descending figure that settles low.
down = silence(0.0)
for k, n in enumerate(["G5", "E5", "D5", "C5"]):
    mix(down, mallet(note(n), 1.0), at=0.16 * k, gain=1.0 - 0.12 * k)
write("game_over", down, peak=0.6)

print("Wrote", ", ".join(sorted(p.name for p in OUT.glob("*.wav"))), "to", OUT)
