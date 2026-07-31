"""Print level and brightness stats for the rendered audio.

Cheap stand-in for listening: catches silent, clipped or muddy renders.
"""

import glob
import os
import wave

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def read(path):
    with wave.open(path) as f:
        sr = f.getframerate()
        raw = f.readframes(f.getnframes())
    return np.frombuffer(raw, '<i2').astype(float) / 32768.0, sr


def main():
    files = sorted(glob.glob(os.path.join(ROOT, 'assets', 'audio', 'sfx', '*.wav')))
    files += sorted(glob.glob(os.path.join(ROOT, 'assets', 'audio', 'music', '*.wav')))
    header = f"{'file':<18}{'dur':>6}{'peak':>7}{'rms':>8}{'centroid':>10}  note"
    print(header)
    print('-' * len(header))
    for path in files:
        data, sr = read(path)
        spec = np.abs(np.fft.rfft(data))
        freqs = np.fft.rfftfreq(len(data), 1.0 / sr)
        centroid = float((spec * freqs).sum() / max(spec.sum(), 1e-9))
        rms = float(np.sqrt((data ** 2).mean()))
        peak = float(np.max(np.abs(data)))
        notes = []
        if rms < 0.005:
            notes.append('SILENT')
        if peak > 0.999:
            notes.append('CLIPPED')
        print(f'{os.path.basename(path):<18}{len(data)/sr:>6.2f}{peak:>7.2f}'
              f'{rms:>8.3f}{centroid:>9.0f}Hz  {" ".join(notes)}')


if __name__ == '__main__':
    main()
