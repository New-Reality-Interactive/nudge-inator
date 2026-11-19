#!/usr/bin/env python3
"""Synthesizes the app's six alarm tones from scratch (#225). Python 3 standard library only.

    python3 scripts/tones/generate-tones.py [output-folder]

Writes chime.caf, bell.caf, pulse.caf, beacon.caf, rise.caf and siren.caf, each 25 seconds of mono
16-bit linear PCM, into App/Resources/Tones (or the folder given). No samples, no third-party audio:
every sound is sine waves shaped by the maths below, and nothing is random, so a second run writes
the same bytes. See scripts/tones/README.md for the licensing note and how to replace a tone.

The six, from gentle to insistent: Chime (a music box tune), Bell (a struck bell), Pulse (a retro
digital chirp), Beacon (a sonar ping), Rise (a climbing run) and Siren (an escalating wail).
"""
import math
import struct
import sys
from pathlib import Path

SR = 22050
SECONDS = 25  # Apple: a notification sound over 30 seconds falls back to the default.
PEAK = 0.8  # Headroom below full scale.
TAU = 2 * math.pi
N = SR * SECONDS


def blank():
    return [0.0] * N


def mix(buf, start, samples, gain=1.0):
    off = int(start * SR)
    for i, v in enumerate(samples):
        if off + i >= N:
            break
        buf[off + i] += v * gain


def echo(buf, delay, feedback, mixlevel=1.0, taps=4):
    """Adds `taps` decaying repeats of the buffer, `delay` seconds apart."""
    out = buf[:]
    d = int(delay * SR)
    for k in range(1, taps + 1):
        g = (feedback ** k) * mixlevel
        for i in range(d * k, N):
            out[i] += buf[i - d * k] * g
    return out


def saw_partials(count=12):
    return [(k, 1.0 / k) for k in range(1, count + 1)]


def square_partials(count=9):
    return [(k, 1.0 / k) for k in range(1, 2 * count, 2)]


def note(freq, dur, partials, decay, attack=0.004, vibrato=(0.0, 0.0), release=0.02):
    """A plucked/struck note: partials ((multiple, amplitude, decay multiple), ...) fading from the start."""
    count = int(dur * SR)
    out = []
    for i in range(count):
        t = i / SR
        env = min(1.0, t / attack, (dur - t) / release)
        f = freq * (1 + vibrato[0] * math.sin(TAU * vibrato[1] * t))
        v = sum(a * math.exp(-t * decay * d) * math.sin(TAU * f * m * t) for m, a, d in partials)
        out.append(env * v)
    return out


def held(freq, dur, partials, attack=0.01, release=0.04, vibrato=(0.0, 0.0), sustain=1.0):
    """A held (non-decaying) note with a shaped envelope; `partials` are (multiple, amplitude)."""
    count = int(dur * SR)
    out = []
    phase = 0.0
    for i in range(count):
        t = i / SR
        env = min(1.0, t / attack, (dur - t) / release) * (sustain + (1 - sustain) * math.exp(-t * 6))
        f = freq * (1 + vibrato[0] * math.sin(TAU * vibrato[1] * t))
        phase += TAU * f / SR
        out.append(env * sum(a * math.sin(phase * m) for m, a in partials if f * m < SR / 2 * 0.9))
    return out


def glide(dur, freq_at, partials, fade=0.02, tremolo=(0.0, 0.0)):
    count = int(dur * SR)
    out = []
    phase = 0.0
    for i in range(count):
        t = i / SR
        phase += TAU * freq_at(i / count) / SR
        env = min(1.0, t / fade, (dur - t) / fade)
        trem = 1 - tremolo[0] + tremolo[0] * math.sin(TAU * tremolo[1] * t)
        out.append(env * trem * sum(a * math.sin(phase * m) for m, a in partials))
    return out


def struck(freq, duration, partials, decay):
    """A struck, ringing sound: partials (frequency multiple, amplitude, decay multiple) that fade out."""
    count = int(duration * SR)
    out = []
    for i in range(count):
        t = i / SR
        attack = min(1.0, t / 0.003)
        value = sum(amp * math.exp(-t * decay * d) * math.sin(TAU * freq * mult * t) for mult, amp, d in partials)
        out.append(attack * value)
    return out


# --- the six tones ---------------------------------------------------------------------------

def chime():
    """A music box: a little tune (up, up, down, resolve) in glassy bell notes with a soft echo."""
    buf = blank()
    # C major pentatonic: C6 D6 E6 G6 A6 C7
    f = {"C": 1046.5, "D": 1174.7, "E": 1318.5, "G": 1568.0, "A": 1760.0, "C2": 2093.0}
    tune = [("E", 0.0), ("G", 0.28), ("C2", 0.56), ("A", 0.98), ("G", 1.26), ("E", 1.54), ("G", 2.1)]
    box = ((1, 1.0, 1.0), (2, 0.0, 1.0), (3.01, 0.35, 2.2), (5.04, 0.18, 3.5), (7.1, 0.07, 5.0))
    for start in (0.0, 5.0, 10.0, 15.0, 20.0):
        for name, at in tune:
            mix(buf, start + at, note(f[name], 2.0, box, 2.6), 1.0 if name != "G" or at > 2 else 0.85)
    return echo(buf, 0.33, 0.45, 0.6, 3)


def bell():
    """A struck bell: inharmonic partials ringing out, one strike every 3.125 seconds."""
    buf = blank()
    partials = ((0.5, 0.5, 0.7), (1.0, 1.0, 1.0), (1.19, 0.6, 1.3), (1.56, 0.4, 1.6), (2.0, 0.5, 2.0), (2.74, 0.3, 2.6), (3.76, 0.15, 3.4))
    for n in range(8):
        mix(buf, n * 3.125, struck(660.0, 3.1, partials, 1.1))
    return buf


def pulse():
    """A retro digital blip: square-wave chirps in a 'da-da-da-DAA' rhythm that steps up each time."""
    buf = blank()
    sq = [(m, a) for m, a in square_partials(7)]
    steps = [(784.0, 0.0, 0.09), (784.0, 0.16, 0.09), (784.0, 0.32, 0.09), (1046.5, 0.5, 0.32)]
    for start in range(0, SECONDS * 4, 8):  # every 2 seconds
        s = start / 4
        for freq, at, dur in steps:
            mix(buf, s + at, held(freq, dur, sq, attack=0.003, release=0.02, vibrato=(0.0, 0.0)), 0.7)
        mix(buf, s + 0.5, held(1046.5, 0.32, [(2, 0.25)], attack=0.003, release=0.05, vibrato=(0.012, 9.0)), 0.5)
    return echo(buf, 0.12, 0.3, 0.4, 2)


def beacon():
    """A sonar ping: a clear ping with pinging echoes sweeping away, answered by a lower ping."""
    buf = blank()
    ping = ((1, 1.0, 1.0), (2, 0.2, 1.5), (3.0, 0.08, 2.5))
    for start in range(0, SECONDS * 10, 40):  # every 4 seconds
        s = start / 10
        mix(buf, s, note(1318.5, 1.2, ping, 5.0, attack=0.006))
        mix(buf, s + 0.55, note(987.8, 1.2, ping, 5.0, attack=0.006), 0.8)
    return echo(buf, 0.45, 0.55, 0.8, 5)


def rise():
    """A sparkling climb: a pentatonic run that quickens as it goes, ending on a bright chord."""
    buf = blank()
    bright = ((1, 1.0, 1.0), (2, 0.3, 1.8), (3, 0.12, 2.8))
    scale = [523.25, 587.33, 659.25, 783.99, 880.0, 1046.5, 1174.7, 1318.5, 1568.0]
    for start in (0.0, 5.0, 10.0, 15.0, 20.0):
        t = start
        gap = 0.22
        for freq in scale:
            mix(buf, t, note(freq, 1.1, bright, 3.0), 0.7)
            t += gap
            gap *= 0.86
        for freq in (1046.5, 1318.5, 1568.0, 2093.0):  # the bright chord
            mix(buf, t + 0.05, note(freq, 2.4, bright, 1.8), 0.75)
    return echo(buf, 0.25, 0.4, 0.45, 3)


def smooth(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


def siren():
    """One continuous escalating wail: five phrases with a break after each. Speed, pitch range, brightness,
    warble and loudness all rise gradually over the 25 seconds (no jumps), wails join with no dip between
    them, and a break fades out and in softly."""
    buf = blank()
    edge = 0.15                                           # fade at each break's edges
    period_at = lambda u: 1.4 - 0.8 * u                   # seconds per up-and-down sweep, falling smoothly
    phase = 0.0
    wobble = 0.0
    for block in range(5):
        gap = 0.7 - 0.1 * block
        wail_length = 5.0 - gap
        start = block * 5.0
        first, last = int(start * SR), int((start + wail_length) * SR)
        # Whole sweeps only, so each phrase ends at its lowest pitch, just before the break.
        total = sum(1.0 / period_at((i / SR + start) / SECONDS) for i in range(0, last - first, 50)) * 50 / SR
        sweeps = max(1, round(total))
        rate = sweeps / total
        cycle = 0.0
        for i in range(first, last):
            t = i / SR
            u = t / SECONDS
            cycle += rate / period_at(u) / SR
            low, high = 500.0 + 300.0 * u, 900.0 + 800.0 * u
            freq = low + (high - low) * (0.5 - 0.5 * math.cos(TAU * cycle))
            phase += TAU * freq / SR
            wobble += TAU * (12.0 + 10.0 * u) / SR
            brightness = 3.0 + 9.0 * u                    # how many harmonics are fully in
            tone = 0.0
            for k in range(1, 13):
                weight = min(1.0, max(0.0, brightness - k + 1))
                if weight > 0 and freq * k < SR / 2 * 0.9:
                    tone += weight * math.sin(phase * k) / k
            depth = 0.05 + 0.2 * u
            env = smooth((t - start) / edge) * smooth((start + wail_length - t) / edge)
            buf[i] = tone * (1 - depth + depth * math.sin(wobble)) * (0.5 + 0.5 * u) * env
    return buf


TONES = {"chime": chime, "bell": bell, "pulse": pulse, "beacon": beacon, "rise": rise, "siren": siren}


def pcm(buf):
    top = max(abs(v) for v in buf) or 1.0
    fade = int(0.05 * SR)
    out = bytearray()
    for i, v in enumerate(buf):
        v = v / top * PEAK
        left = len(buf) - 1 - i
        if left < fade:
            v *= left / fade
        out += struct.pack("<h", int(round(v * 32767)))
    return bytes(out)


def caf(data):
    desc = struct.pack(">dIIIIII", float(SR), int.from_bytes(b"lpcm", "big"), 2, 2, 1, 1, 16)
    return (b"caff" + struct.pack(">HH", 1, 0) + b"desc" + struct.pack(">q", len(desc)) + desc
            + b"data" + struct.pack(">q", 4 + len(data)) + struct.pack(">I", 0) + data)



def main():
    folder = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[2] / "App/Resources/Tones"
    folder.mkdir(parents=True, exist_ok=True)
    for name, make in TONES.items():
        (folder / f"{name}.caf").write_bytes(caf(pcm(make())))
        print(f"wrote {folder / (name + '.caf')}")


if __name__ == "__main__":
    main()
