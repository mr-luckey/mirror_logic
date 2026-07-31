"""Render the game's music and sound effects to WAV.

Everything here is synthesised from scratch so the project carries no
third-party audio licences. The techniques are chosen for realism rather than
convenience: Karplus-Strong for the plucked harp, inharmonic additive partials
for glass and bell strikes, and noise burst plus resonant modes for wood and
iron impacts.

Run:  python tool/make_audio.py
"""

import math
import os
import struct
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SFX_DIR = os.path.join(ROOT, 'assets', 'audio', 'sfx')
MUSIC_DIR = os.path.join(ROOT, 'assets', 'audio', 'music')

SFX_RATE = 44100
# Music is pads and plucks with little content above 14 kHz, so a lower rate
# halves the bundle size with no audible loss.
MUSIC_RATE = 32000

rng = np.random.default_rng(0xB0A7)


# --------------------------------------------------------------------------
# helpers
# --------------------------------------------------------------------------

def seconds(n, sr):
    return int(round(n * sr))


def silence(dur, sr):
    return np.zeros(seconds(dur, sr))


def add_at(track, part, at, sr, gain=1.0):
    """Mix `part` into `track` starting at `at` seconds, wrapping the tail."""
    start = seconds(at, sr)
    n = len(track)
    if start >= n:
        start %= n
    end = start + len(part)
    if end <= n:
        track[start:end] += part * gain
    else:
        head = n - start
        track[start:] += part[:head] * gain
        # Wrapping the overhang back to the top is what makes the loop seamless.
        rest = part[head:]
        if len(rest) > n:
            rest = rest[:n]
        track[:len(rest)] += rest * gain


def delayed(part, at, total, sr):
    """`part` placed `at` seconds into a buffer of `total` samples."""
    out = np.zeros(total)
    start = seconds(at, sr)
    end = min(total, start + len(part))
    if end > start:
        out[start:end] = part[:end - start]
    return out


def fft_filter(x, sr, response):
    """Zero-phase filtering via the spectrum. Fine for offline rendering."""
    n = len(x)
    if n == 0:
        return x
    spec = np.fft.rfft(x)
    freqs = np.fft.rfftfreq(n, 1.0 / sr)
    return np.fft.irfft(spec * response(freqs), n)


def lowpass(x, sr, cut, order=2):
    return fft_filter(
        x, sr,
        lambda f: 1.0 / np.sqrt(1.0 + (f / max(cut, 1.0)) ** (2 * order)),
    )


def highpass(x, sr, cut, order=2):
    def resp(f):
        r = np.maximum(f, 1e-6) / max(cut, 1.0)
        return r ** order / np.sqrt(1.0 + r ** (2 * order))
    return fft_filter(x, sr, resp)


def bandpass(x, sr, centre, q=2.0):
    def resp(f):
        f = np.maximum(f, 1e-6)
        # Magnitude of a classic resonant band-pass.
        return 1.0 / np.sqrt(1.0 + (q * (f / centre - centre / f)) ** 2)
    return fft_filter(x, sr, resp)


def env_exp(n, sr, attack, decay):
    """Fast attack, exponential tail: how struck objects actually behave."""
    t = np.arange(n) / sr
    a = np.clip(t / max(attack, 1e-5), 0.0, 1.0)
    return a * np.exp(-t / max(decay, 1e-5))


def env_adsr(n, sr, attack, decay, sustain, release):
    t = np.arange(n) / sr
    total = t[-1] if n else 0.0
    out = np.ones(n)
    a = np.clip(t / max(attack, 1e-5), 0.0, 1.0)
    d = sustain + (1.0 - sustain) * np.exp(-np.maximum(t - attack, 0) / max(decay, 1e-5))
    r = np.clip((total - t) / max(release, 1e-5), 0.0, 1.0)
    return out * a * d * r


def normalise(x, peak=0.85):
    m = float(np.max(np.abs(x))) if len(x) else 0.0
    return x if m < 1e-9 else x * (peak / m)


def soft_clip(x):
    return np.tanh(x * 1.2) / math.tanh(1.2)


def fade_edges(x, sr, ms=4.0):
    n = seconds(ms / 1000.0, sr)
    if n * 2 >= len(x) or n == 0:
        return x
    ramp = np.linspace(0.0, 1.0, n)
    x[:n] *= ramp
    x[-n:] *= ramp[::-1]
    return x


def write_wav(path, samples, sr):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    data = np.clip(samples, -1.0, 1.0)
    pcm = (data * 32767.0).astype('<i2')
    with wave.open(path, 'wb') as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(sr)
        f.writeframes(pcm.tobytes())
    kb = os.path.getsize(path) / 1024
    print(f'  {os.path.relpath(path, ROOT):<44} {len(samples)/sr:5.2f}s  {kb:7.1f} KB')


# --------------------------------------------------------------------------
# instruments
# --------------------------------------------------------------------------

def note_hz(semitones_from_a4):
    return 440.0 * 2.0 ** (semitones_from_a4 / 12.0)


NOTES = {n: i for i, n in enumerate(
    ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'])}


def pitch(name):
    """'D3' -> Hz."""
    octave = int(name[-1])
    step = NOTES[name[:-1]]
    return note_hz(step - 9 + (octave - 4) * 12)


def pluck(freq, dur, sr, damping=0.9965, brightness=0.5, level=1.0):
    """Karplus-Strong string. Gives a convincing harp / lute attack."""
    n = seconds(dur, sr)
    delay = max(int(sr / freq), 2)
    buf = rng.uniform(-1.0, 1.0, delay)
    # Rolling off the excitation burst controls how bright the pluck reads.
    smooth = int((1.0 - brightness) * 8) + 1
    if smooth > 1:
        kernel = np.ones(smooth) / smooth
        buf = np.convolve(buf, kernel, mode='same')

    out = np.empty(n)
    idx = 0
    prev = 0.0
    for i in range(n):
        cur = buf[idx]
        out[i] = cur
        # One-pole average is the string's frequency-dependent loss.
        buf[idx] = damping * 0.5 * (cur + prev)
        prev = cur
        idx = (idx + 1) % delay

    out *= np.minimum(1.0, np.exp(-np.arange(n) / sr / (dur * 0.9)) * 1.2)
    return out * level


def bell(freq, dur, sr, partials=None, level=1.0, attack=0.001):
    """Inharmonic additive strike: glass, chimes, struck metal."""
    if partials is None:
        # Ratios measured off real tubular bells.
        partials = [(1.0, 1.0, 1.0), (2.00, 0.55, 0.8), (2.76, 0.45, 0.6),
                    (4.07, 0.30, 0.42), (5.43, 0.20, 0.3), (8.10, 0.12, 0.2)]
    n = seconds(dur, sr)
    t = np.arange(n) / sr
    out = np.zeros(n)
    for ratio, amp, decay_scale in partials:
        f = freq * ratio
        if f > sr * 0.45:
            continue
        phase = rng.uniform(0, 2 * math.pi)
        out += amp * np.sin(2 * math.pi * f * t + phase) * \
            env_exp(n, sr, attack, dur * 0.42 * decay_scale)
    return out * level


def wood_knock(freq, dur, sr, level=1.0, noise=0.55):
    """Short noise transient plus two decaying modes: a knuckle on oak."""
    n = seconds(dur, sr)
    burst = rng.normal(0, 1, n) * env_exp(n, sr, 0.0004, dur * 0.09)
    burst = bandpass(burst, sr, freq * 3.2, q=1.1) * noise
    body = bell(freq, dur, sr, partials=[
        (1.0, 1.0, 1.0), (1.61, 0.42, 0.55), (2.43, 0.22, 0.32),
    ])
    return (burst + body * 0.9) * level


def iron_clunk(dur, sr, level=1.0):
    """Latch dropping into a keep door."""
    n = seconds(dur, sr)
    thud = bell(74, dur, sr, partials=[(1.0, 1.0, 1.0), (1.9, 0.4, 0.5)])
    ring = bell(910, dur * 0.8, sr, partials=[
        (1.0, 0.5, 1.0), (2.41, 0.34, 0.7), (3.83, 0.22, 0.5), (6.12, 0.12, 0.3),
    ])
    scrape = rng.normal(0, 1, n) * env_exp(n, sr, 0.0005, dur * 0.06)
    scrape = bandpass(scrape, sr, 2400, q=0.8) * 0.5
    return (thud + np.pad(ring, (0, n - len(ring))) * 0.55 + scrape) * level


def air_shimmer(dur, sr, lo=900, hi=8000, level=1.0):
    """Noise sweeping upward through a resonance: a spell settling."""
    n = seconds(dur, sr)
    noise = rng.normal(0, 1, n)
    chunks = 24
    out = np.zeros(n)
    step = n // chunks
    for c in range(chunks):
        s, e = c * step, min((c + 1) * step, n)
        centre = lo * (hi / lo) ** (c / (chunks - 1))
        seg = bandpass(noise[s:e] * np.hanning(e - s), sr, centre, q=1.6)
        out[s:e] += seg
    return out * env_exp(n, sr, dur * 0.12, dur * 0.35) * level


# --------------------------------------------------------------------------
# sound effects
# --------------------------------------------------------------------------

def sfx_mirror_grab():
    """Fingertip settling on a glass pane in a bronze frame."""
    sr, dur = SFX_RATE, 0.16
    n = seconds(dur, sr)
    tick = rng.normal(0, 1, n) * env_exp(n, sr, 0.0005, 0.018)
    tick = bandpass(tick, sr, 3200, q=1.0)
    body = bell(520, dur, sr, partials=[(1.0, 0.6, 0.6), (2.7, 0.25, 0.35)])
    return normalise(fade_edges(tick * 0.8 + body * 0.5, sr), 0.5)


def sfx_mirror_detent():
    """The notch a rotating mirror clicks into. Must be tiny: it repeats a lot."""
    sr, dur = SFX_RATE, 0.09
    n = seconds(dur, sr)
    click = rng.normal(0, 1, n) * env_exp(n, sr, 0.0003, 0.008)
    click = bandpass(click, sr, 5200, q=1.4)
    ping = bell(1760, dur, sr, partials=[(1.0, 0.7, 0.5), (2.4, 0.3, 0.3)])
    return normalise(fade_edges(click * 0.7 + ping * 0.55, sr), 0.42)


def sfx_mirror_lock():
    """Beam snaps onto a target: bright glass chime, unmistakable."""
    sr, dur = SFX_RATE, 0.55
    n = seconds(dur, sr)
    out = bell(1318.5, dur, sr)                                    # E6
    out += delayed(bell(1975.5, dur * 0.8, sr, level=0.55), 0.012, n, sr)  # B6
    out += air_shimmer(dur, sr, 3000, 11000, level=0.16)
    return normalise(fade_edges(out, sr), 0.72)


def sfx_beam_hit():
    """Light grazing a mirror face: a short, high, glassy tick."""
    sr, dur = SFX_RATE, 0.24
    out = bell(2093, dur, sr, partials=[
        (1.0, 1.0, 0.55), (2.76, 0.4, 0.35), (5.4, 0.18, 0.2),
    ])
    out += air_shimmer(dur, sr, 4000, 12000, level=0.1)
    return normalise(fade_edges(out, sr), 0.5)


def sfx_crystal_lit():
    """A target crystal takes the beam and rings."""
    sr, dur = SFX_RATE, 1.1
    n = seconds(dur, sr)
    out = bell(880, dur, sr, level=0.9)
    out += delayed(bell(1318.5, dur * 0.75, sr, level=0.5), 0.05, n, sr)
    out += air_shimmer(dur, sr, 2200, 9000, level=0.14)
    return normalise(fade_edges(out, sr), 0.8)


def sfx_reject():
    """Beam reaches a crystal the wrong way: dull, sour, no sparkle."""
    sr, dur = SFX_RATE, 0.42
    n = seconds(dur, sr)
    t = np.arange(n) / sr
    # A minor second beating against itself reads as "wrong" instantly.
    tone = (np.sin(2 * math.pi * 146.8 * t) + 0.8 * np.sin(2 * math.pi * 155.6 * t))
    tone *= env_exp(n, sr, 0.004, 0.14)
    thud = wood_knock(96, dur, sr, level=0.7, noise=0.3)
    out = lowpass(tone * 0.6 + thud, sr, 1400)
    return normalise(fade_edges(out, sr), 0.62)


def sfx_win():
    """Level cleared: a rising bell figure over a warm swell."""
    sr, dur = SFX_RATE, 2.6
    track = silence(dur, sr)
    # D major triad climbing into the octave; bright but not saccharine.
    figure = [('D5', 0.00, 1.0), ('F#5', 0.11, 0.9), ('A5', 0.22, 0.95),
              ('D6', 0.34, 1.0), ('F#6', 0.50, 0.7)]
    for name, at, lvl in figure:
        add_at(track, bell(pitch(name), 1.9, sr, level=lvl * 0.6), at, sr)

    n = seconds(dur, sr)
    t = np.arange(n) / sr
    swell = sum(
        np.sin(2 * math.pi * pitch(p) * t + rng.uniform(0, 6))
        for p in ('D3', 'A3', 'D4')
    ) / 3.0
    swell *= env_adsr(n, sr, 0.18, 0.9, 0.45, 0.9) * 0.28
    track += lowpass(swell, sr, 2600)
    track += air_shimmer(dur, sr, 2500, 12000, level=0.12)
    return normalise(fade_edges(soft_clip(track), sr, 8), 0.9)


def sfx_star():
    """One star landing on the results plaque."""
    sr, dur = SFX_RATE, 0.7
    out = bell(1567.98, dur, sr, level=0.8)          # G6
    out += air_shimmer(dur, sr, 4000, 13000, level=0.12)
    return normalise(fade_edges(out, sr), 0.62)


def sfx_coin():
    """Two coins settling against each other."""
    sr, dur = SFX_RATE, 0.42
    n = seconds(dur, sr)
    p = [(1.0, 1.0, 0.5), (2.41, 0.6, 0.35), (4.19, 0.35, 0.22), (6.7, 0.2, 0.15)]
    out = bell(2200, dur, sr, partials=p, level=0.7)
    out += delayed(bell(2960, dur * 0.7, sr, partials=p, level=0.45), 0.045, n, sr)
    return normalise(fade_edges(out, sr), 0.55)


def sfx_tap():
    """Pressing a wooden button in a bronze bezel."""
    sr, dur = SFX_RATE, 0.17
    n = seconds(dur, sr)
    out = wood_knock(210, dur, sr)
    out += delayed(
        bell(1400, dur * 0.5, sr, partials=[(1.0, 0.3, 0.4)], level=0.25),
        0.0, n, sr,
    )
    return normalise(fade_edges(out, sr), 0.5)


def sfx_back():
    """Same knock, lower and softer: leaving a room."""
    sr, dur = SFX_RATE, 0.2
    return normalise(fade_edges(wood_knock(132, dur, sr, noise=0.4), sr), 0.42)


def sfx_unlock():
    sr, dur = SFX_RATE, 0.9
    n = seconds(dur, sr)
    out = iron_clunk(dur, sr)
    out += delayed(bell(1046.5, 0.6, sr, level=0.35), 0.14, n, sr)
    return normalise(fade_edges(out, sr), 0.75)


def sfx_hint():
    """Arcane guidance appearing on the board."""
    sr, dur = SFX_RATE, 1.0
    n = seconds(dur, sr)
    out = air_shimmer(dur, sr, 700, 9000, level=0.7)
    out += delayed(bell(1318.5, dur * 0.8, sr, level=0.32), 0.0, n, sr)
    out += delayed(bell(1760, dur * 0.6, sr, level=0.22), 0.1, n, sr)
    return normalise(fade_edges(out, sr), 0.55)


def sfx_undo():
    sr, dur = SFX_RATE, 0.3
    n = seconds(dur, sr)
    t = np.arange(n) / sr
    # Falling pitch: the universal "put it back" gesture.
    f = 900 * (0.45 ** (t / dur))
    sweep = np.sin(2 * math.pi * np.cumsum(f) / sr) * env_exp(n, sr, 0.004, 0.09)
    return normalise(fade_edges(lowpass(sweep, sr, 3000) + wood_knock(170, dur, sr, 0.4), sr), 0.45)


# --------------------------------------------------------------------------
# music
# --------------------------------------------------------------------------

def loop_lock(freq, dur):
    """Nearest frequency that completes a whole number of cycles in the loop.

    A sustained tone whose phase does not line up at the seam clicks on every
    repeat; the shift needed is far under a cent at these lengths.
    """
    return max(round(freq * dur), 1) / dur


def drone(track, sr, roots, dur, level=0.16):
    """Slow bowed pad under everything, in the key of the piece."""
    n = len(track)
    t = np.arange(n) / sr
    pad = np.zeros(n)
    for name in roots:
        f = pitch(name)
        # Three slightly detuned voices per note make the pad breathe.
        for cents in (-6, 0, 7):
            ff = loop_lock(f * 2 ** (cents / 1200.0), dur)
            pad += np.sin(2 * math.pi * ff * t)
        pad += 0.25 * np.sin(2 * math.pi * loop_lock(f * 2, dur) * t)
    pad /= (len(roots) * 3.25)
    # A slow swell keeps a looped drone from sounding like a held organ key.
    pad *= 0.72 + 0.28 * np.sin(2 * math.pi * t / dur - math.pi / 2)
    track += lowpass(pad, sr, 900) * level


def flute(freq, dur, sr, level=1.0):
    """Wooden recorder: near-sine with breath noise and a slow vibrato."""
    n = seconds(dur, sr)
    t = np.arange(n) / sr
    vib = 1.0 + 0.006 * np.sin(2 * math.pi * 4.6 * t) * np.clip(t / 0.35, 0, 1)
    phase = 2 * math.pi * np.cumsum(freq * vib) / sr
    tone = np.sin(phase) + 0.22 * np.sin(2 * phase) + 0.06 * np.sin(3 * phase)
    breath = bandpass(rng.normal(0, 1, n), sr, freq * 2.2, q=0.7) * 0.05
    env = env_adsr(n, sr, 0.07, 0.5, 0.8, 0.18)
    return (tone * 0.5 + breath) * env * level


def music_menu():
    """Warm, hopeful harp over a low drone. Loops at 76 BPM in D Aeolian."""
    sr = MUSIC_RATE
    bpm = 76.0
    beat = 60.0 / bpm
    bars = 8
    dur = bars * 4 * beat
    track = silence(dur, sr)

    drone(track, sr, ['D2', 'A2'], dur, level=0.19)

    # i - VI - III - VII, the backbone of just about every hall-of-heroes cue.
    chords = [
        ['D3', 'F3', 'A3', 'D4', 'F4', 'A4'],
        ['A#2', 'D3', 'F3', 'A#3', 'D4', 'F4'],
        ['F3', 'A3', 'C4', 'F4', 'A4', 'C5'],
        ['C3', 'E3', 'G3', 'C4', 'E4', 'G4'],
    ]
    pattern = [0, 2, 4, 3, 5, 4, 2, 3]  # rolling arpeggio, not a straight run

    for bar in range(bars):
        chord = chords[bar % len(chords)]
        base = bar * 4 * beat
        for step, degree in enumerate(pattern):
            at = base + step * beat * 0.5
            f = pitch(chord[degree])
            level = 0.5 if step % 2 == 0 else 0.34
            add_at(track, pluck(f, 2.4, sr, damping=0.9968, brightness=0.55),
                   at, sr, gain=level * 0.5)

    melody = [
        ('D5', 0, 2.0), ('F5', 2.0, 1.0), ('E5', 3.0, 1.0),
        ('D5', 4.0, 2.0), ('C5', 6.0, 2.0),
        ('D5', 8.0, 1.5), ('F5', 9.5, 0.5), ('G5', 10.0, 2.0),
        ('F5', 12.0, 1.0), ('E5', 13.0, 1.0), ('D5', 14.0, 2.0),
        ('A4', 16.0, 2.0), ('C5', 18.0, 2.0),
        ('D5', 20.0, 1.0), ('E5', 21.0, 1.0), ('F5', 22.0, 2.0),
        ('E5', 24.0, 2.0), ('D5', 26.0, 1.0), ('C5', 27.0, 1.0),
        ('D5', 28.0, 4.0),
    ]
    for name, at_beats, len_beats in melody:
        add_at(track, flute(pitch(name), len_beats * beat * 0.95, sr, 0.3),
               at_beats * beat, sr)

    return normalise(soft_clip(track * 1.1), 0.62), sr


def music_gameplay():
    """Sparse and unhurried so it never competes with the puzzle."""
    sr = MUSIC_RATE
    bpm = 60.0
    beat = 60.0 / bpm
    bars = 8
    dur = bars * 4 * beat
    track = silence(dur, sr)

    drone(track, sr, ['A2', 'E3'], dur, level=0.17)

    scale = ['A3', 'C4', 'D4', 'E4', 'G4', 'A4', 'C5', 'D5', 'E5']
    # Hand-placed rather than random so the loop has a shape you can learn.
    figure = [
        (0.0, 0), (1.5, 2), (3.0, 4), (5.0, 3),
        (8.0, 5), (9.5, 4), (11.0, 2), (13.0, 1),
        (16.0, 0), (17.5, 3), (19.0, 5), (21.0, 6),
        (24.0, 7), (25.5, 5), (27.0, 4), (29.0, 2), (30.5, 0),
    ]
    for at_beats, degree in figure:
        add_at(track, pluck(pitch(scale[degree]), 3.2, sr,
                            damping=0.9972, brightness=0.42),
               at_beats * beat, sr, gain=0.34)

    # A distant bell every other bar marks time without nagging.
    for bar in range(0, bars, 4):
        add_at(track, bell(pitch('A4'), 3.0, sr, level=0.1), bar * 4 * beat, sr)

    return normalise(soft_clip(track), 0.62), sr


# --------------------------------------------------------------------------

SFX = {
    'mirror_grab': sfx_mirror_grab,
    'mirror_detent': sfx_mirror_detent,
    'mirror_lock': sfx_mirror_lock,
    'beam_hit': sfx_beam_hit,
    'crystal_lit': sfx_crystal_lit,
    'reject': sfx_reject,
    'win': sfx_win,
    'star': sfx_star,
    'coin': sfx_coin,
    'tap': sfx_tap,
    'back': sfx_back,
    'unlock': sfx_unlock,
    'hint': sfx_hint,
    'undo': sfx_undo,
}

MUSIC = {
    'menu': music_menu,
    'gameplay': music_gameplay,
}


def report_loop_seam(name, samples, sr):
    """A loop is only usable if the last sample flows into the first."""
    window = seconds(0.005, sr)
    seam = abs(float(samples[0]) - float(samples[-1]))
    inner = float(np.max(np.abs(np.diff(samples[window:-window]))))
    verdict = 'seamless' if seam <= inner * 3 else 'CLICKS'
    print(f'  {name}: seam step {seam:.5f} vs typical {inner:.5f} -> {verdict}')


def main():
    print('sound effects')
    for name, fn in SFX.items():
        write_wav(os.path.join(SFX_DIR, f'{name}.wav'), fn(), SFX_RATE)

    print('music')
    for name, fn in MUSIC.items():
        samples, sr = fn()
        write_wav(os.path.join(MUSIC_DIR, f'{name}.wav'), samples, sr)
        report_loop_seam(name, samples, sr)

    total = 0
    for d in (SFX_DIR, MUSIC_DIR):
        for f in os.listdir(d):
            total += os.path.getsize(os.path.join(d, f))
    print(f'\ntotal audio payload: {total / 1024 / 1024:.2f} MB')


if __name__ == '__main__':
    main()
