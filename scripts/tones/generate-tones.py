#!/usr/bin/env python3
"""Synthesizes the app's six alarm tones from scratch (#225). Python 3 standard library only.

    python3 scripts/tones/generate-tones.py [output-folder]

Writes chime.caf, bell.caf, pulse.caf, beacon.caf, rise.caf and siren.caf, each 25 seconds of mono
16-bit linear PCM, into App/Resources/Tones (or the folder given). No samples, no third-party audio:
every sound is sine waves shaped by the maths below, and nothing is random, so a second run writes
the same bytes. See scripts/tones/README.md for the licensing note and how to replace a tone.
"""
import math
import struct
import sys
from pathlib import Path

SAMPLE_RATE = 22050
SECONDS = 25  # Apple: a notification sound over 30 seconds falls back to the default.
PEAK = 0.8  # Headroom below full scale.
TAU = 2 * math.pi


def blank():
    return [0.0] * (SAMPLE_RATE * SECONDS)


def add(buf, start, samples):
    """Mixes `samples` into `buf` from `start` seconds in; anything past the end is dropped."""
    offset = int(start * SAMPLE_RATE)
    for i, value in enumerate(samples):
        if offset + i >= len(buf):
            break
        buf[offset + i] += value


def tone(freq, duration, attack=0.005, release=0.02, partials=((1, 1.0),)):
    """A sine tone (with optional harmonic partials) with a linear attack and release."""
    count = int(duration * SAMPLE_RATE)
    out = []
    for i in range(count):
        t = i / SAMPLE_RATE
        envelope = min(1.0, t / attack, (duration - t) / release)
        out.append(envelope * sum(amp * math.sin(TAU * freq * mult * t) for mult, amp in partials))
    return out


def struck(freq, duration, partials, decay):
    """A struck, ringing sound: partials (frequency multiple, amplitude, decay multiple) that fade out."""
    count = int(duration * SAMPLE_RATE)
    out = []
    for i in range(count):
        t = i / SAMPLE_RATE
        attack = min(1.0, t / 0.003)
        value = sum(amp * math.exp(-t * decay * d) * math.sin(TAU * freq * mult * t) for mult, amp, d in partials)
        out.append(attack * value)
    return out


def sweep(duration, frequency_at, partials=((1, 1.0),), fade=0.02):
    """A tone whose pitch follows frequency_at(fraction of the duration); phase is integrated, so no clicks."""
    count = int(duration * SAMPLE_RATE)
    out = []
    phase = 0.0
    for i in range(count):
        t = i / SAMPLE_RATE
        phase += TAU * frequency_at(i / count) / SAMPLE_RATE
        envelope = min(1.0, t / fade, (duration - t) / fade)
        out.append(envelope * sum(amp * math.sin(phase * mult) for mult, amp in partials))
    return out


def chime():
    """Gentle: a soft three-note rising chime (C6, E6, G6), then a rest."""
    buf = blank()
    for start in range(0, SECONDS, 5):
        for n, freq in enumerate((1046.5, 1318.5, 1568.0)):
            add(buf, start + n * 0.45, struck(freq, 2.4, ((1, 1.0, 1.0), (2, 0.25, 1.6), (3, 0.08, 2.4)), 1.6))
    return buf


def bell():
    """A struck bell: inharmonic partials ringing out, one strike every 3.125 seconds."""
    buf = blank()
    partials = ((0.5, 0.5, 0.7), (1.0, 1.0, 1.0), (1.19, 0.6, 1.3), (1.56, 0.4, 1.6), (2.0, 0.5, 2.0), (2.74, 0.3, 2.6), (3.76, 0.15, 3.4))
    for n in range(8):
        add(buf, n * 3.125, struck(660.0, 3.1, partials, 1.1))
    return buf


def pulse():
    """Steady: three short 880 Hz beeps, then a rest; repeated."""
    buf = blank()
    for start in range(0, SECONDS, 2):
        for n in range(3):
            add(buf, start + n * 0.28, tone(880.0, 0.16, partials=((1, 1.0), (2, 0.2))))
    return buf


def beacon():
    """Urgent: a two-tone call (660 Hz, 880 Hz), twice, then a short rest; repeated."""
    buf = blank()
    for start in range(0, SECONDS * 10, 18):  # every 1.8 seconds
        for n, freq in enumerate((660.0, 880.0, 660.0, 880.0)):
            add(buf, start / 10 + n * 0.3, tone(freq, 0.26, attack=0.01, release=0.04, partials=((1, 1.0), (3, 0.2))))
    return buf


def rise():
    """Insistent: a swell that climbs from 400 Hz to 1600 Hz in two seconds; repeated every 2.5."""
    buf = blank()
    for start in range(0, SECONDS * 2, 5):  # every 2.5 seconds
        add(buf, start / 2, sweep(2.0, lambda f: 400.0 * (4.0 ** f), partials=((1, 1.0), (2, 0.3)), fade=0.05))
    return buf


def siren():
    """The most insistent: a continuous wail between 600 Hz and 1300 Hz, one cycle every 1.25 seconds."""
    buf = blank()
    cycles = int(SECONDS / 1.25)
    for n in range(cycles):
        add(buf, n * 1.25, sweep(1.25, lambda f: 950.0 - 350.0 * math.cos(TAU * f), partials=((1, 1.0), (2, 0.35), (3, 0.15)), fade=0.0001))
    return buf


TONES = {"chime": chime, "bell": bell, "pulse": pulse, "beacon": beacon, "rise": rise, "siren": siren}


def pcm(buf):
    """Scales the tone to PEAK, fades the last 50 ms, and returns little-endian 16-bit samples."""
    top = max(abs(v) for v in buf) or 1.0
    fade = int(0.05 * SAMPLE_RATE)
    out = bytearray()
    for i, v in enumerate(buf):
        v = v / top * PEAK
        left = len(buf) - 1 - i
        if left < fade:
            v *= left / fade
        out += struct.pack("<h", int(round(v * 32767)))
    return bytes(out)


def caf(data):
    """A Core Audio Format file holding mono, little-endian 16-bit linear PCM."""
    description = struct.pack(">dIIIIII", float(SAMPLE_RATE), int.from_bytes(b"lpcm", "big"), 2, 2, 1, 1, 16)
    return (
        b"caff" + struct.pack(">HH", 1, 0)
        + b"desc" + struct.pack(">q", len(description)) + description
        + b"data" + struct.pack(">q", 4 + len(data)) + struct.pack(">I", 0) + data
    )


def main():
    folder = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[2] / "App/Resources/Tones"
    folder.mkdir(parents=True, exist_ok=True)
    for name, make in TONES.items():
        (folder / f"{name}.caf").write_bytes(caf(pcm(make())))
        print(f"wrote {folder / (name + '.caf')}")


if __name__ == "__main__":
    main()
