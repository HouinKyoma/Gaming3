"""Synthesizes the game's placeholder sound effects and music (all original, made from maths).

Run from the project folder:   python tools/make_sounds.py      (needs: pip install numpy)

Like make_placeholders.py it NEVER overwrites an existing file, so replacing a sound with your
own is just: save your .wav (or .ogg, then update the extension in autoload/audio.gd) at the same path.
"""
import os
import wave
import numpy as np

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")
RATE = 22050
rng = np.random.default_rng(7)


def t_axis(dur):
    return np.arange(int(RATE * dur)) / RATE


def env(n, attack=0.005, release=None):
    """Linear attack, exponential-ish decay to zero."""
    e = np.ones(n)
    a = max(1, int(RATE * attack))
    e[:a] = np.linspace(0, 1, a)
    tail = np.linspace(1, 0, n - a) ** 2 if release is None else np.exp(-np.arange(n - a) / (RATE * release))
    e[a:] = tail
    return e


def square(freq, t):
    return np.sign(np.sin(2 * np.pi * np.cumsum(np.broadcast_to(freq, t.shape)) / RATE))


def tri(freq, t):
    phase = np.cumsum(np.broadcast_to(freq, t.shape)) / RATE
    return 2 * np.abs(2 * (phase % 1) - 1) - 1


def noise(n):
    return rng.uniform(-1, 1, n)


def lowpass(x, k=0.2):
    y = np.zeros_like(x)
    acc = 0.0
    for i, v in enumerate(x):
        acc += k * (v - acc)
        y[i] = acc
    return y


def save(rel, x, vol=0.6):
    path = os.path.join(ROOT, rel)
    if os.path.exists(path):
        print("keep   ", rel)
        return
    os.makedirs(os.path.dirname(path), exist_ok=True)
    x = np.clip(x * vol, -1, 1)
    data = (x * 32767).astype("<i2").tobytes()
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data)
    print("create ", rel)


def sweep(f0, f1, dur, shape=square):
    t = t_axis(dur)
    f = np.geomspace(f0, f1, t.size)
    return shape(f, t)


def sfx():
    n = lambda d: int(RATE * d)
    save("sfx/shoot.wav", sweep(900, 300, 0.08) * env(n(0.08)) * 0.5)
    save("sfx/hit.wav", (noise(n(0.06)) * 0.6 + sweep(400, 150, 0.06) * 0.4) * env(n(0.06)))
    d = 0.3
    save("sfx/enemy_die.wav", (lowpass(noise(n(d)), 0.3) * 1.2 + sweep(300, 60, d) * 0.3) * env(n(d)))
    save("sfx/player_hurt.wav", (sweep(500, 120, 0.25) * 0.6 + noise(n(0.25)) * 0.3) * env(n(0.25)))
    save("sfx/dash.wav", lowpass(noise(n(0.15)), 0.5) * np.linspace(0.2, 1, n(0.15)) * env(n(0.15), 0.08))
    t = t_axis(0.12)
    blip = np.concatenate([square(np.full(n(0.05), 880.0), t[:n(0.05)]), square(np.full(n(0.07), 1320.0), t[:n(0.07)])])
    save("sfx/pickup.wav", blip * env(blip.size) * 0.35)
    save("sfx/door.wav", (lowpass(noise(n(0.35)), 0.08) * 2 + sweep(110, 70, 0.35, tri) * 0.5) * env(n(0.35), 0.02))
    chord = sum(square(np.full(n(0.3), f), t_axis(0.3)) for f in (523.25, 659.25, 783.99)) / 3
    save("sfx/buy.wav", chord * env(n(0.3)) * 0.5)
    save("sfx/ui_click.wav", square(np.full(n(0.03), 660.0), t_axis(0.03)) * env(n(0.03)) * 0.3)
    d = 1.2
    t = t_axis(d)
    roar = (sweep(90, 45, d, square) * 0.5 + lowpass(noise(t.size), 0.15) * 1.5) * (1 + 0.3 * np.sin(2 * np.pi * 7 * t))
    save("sfx/boss_roar.wav", roar * env(t.size, 0.1) * 0.8)
    arp = np.concatenate([tri(np.full(n(0.09), f), t_axis(0.09)) * env(n(0.09)) for f in (392, 523.25, 659.25, 783.99)])
    save("sfx/stairs.wav", arp * 0.7)
    save("sfx/death.wav", sweep(440, 55, 1.0, tri) * env(n(1.0)) * 0.8)


def note(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def music_loop(name, bpm, bass_line, lead_line, lead_shape=square, drums=True, vol=0.45):
    """bass_line / lead_line: lists of MIDI notes (0 = rest), one per 8th note."""
    step = 60 / bpm / 2
    steps = max(len(bass_line), len(lead_line))
    out = np.zeros(int(RATE * step * steps))
    ns = int(RATE * step)
    t = t_axis(step)
    for i in range(steps):
        seg = slice(i * ns, (i + 1) * ns)
        b = bass_line[i % len(bass_line)]
        if b:
            out[seg] += tri(np.full(ns, note(b)), t) * env(ns, 0.005, 0.12) * 0.6
        l = lead_line[i % len(lead_line)]
        if l:
            out[seg] += lead_shape(np.full(ns, note(l)), t) * env(ns, 0.01, 0.08) * 0.18
        if drums:
            if i % 4 == 0:
                out[seg] += sweep(150, 40, step, tri)[:ns] * env(ns, 0.002, 0.05) * 0.7
            if i % 4 == 2:
                out[seg] += lowpass(noise(ns), 0.6) * env(ns, 0.001, 0.03) * 0.35
            out[seg] += noise(ns) * env(ns, 0.001, 0.008) * 0.08
    save(f"music/{name}.wav", out, vol)


def music():
    # A minor, slow and moody for menus
    bass = [45, 0, 45, 0, 41, 0, 41, 0, 43, 0, 43, 0, 40, 0, 40, 0] * 2
    lead = [69, 0, 72, 0, 76, 0, 74, 72, 65, 0, 69, 0, 72, 0, 71, 0,
            67, 0, 71, 0, 74, 0, 72, 71, 64, 0, 68, 0, 71, 0, 0, 0]
    music_loop("menu_loop", 84, bass, lead, tri, drums=False)
    # Driving loop for runs
    bass = [45, 45, 57, 45, 45, 45, 55, 45, 41, 41, 53, 41, 43, 43, 55, 43] * 2
    lead = [76, 0, 74, 76, 0, 72, 74, 0, 72, 0, 69, 0, 71, 72, 74, 0,
            76, 0, 79, 76, 0, 74, 72, 0, 71, 0, 67, 0, 69, 0, 0, 0]
    music_loop("run_loop", 132, bass, lead)
    # Boss: faster, lower, chromatic
    bass = [40, 40, 52, 40, 41, 41, 53, 41, 40, 40, 52, 40, 39, 39, 51, 39] * 2
    lead = [64, 65, 64, 0, 71, 70, 71, 0, 64, 65, 67, 68, 71, 0, 70, 0,
            76, 75, 76, 0, 71, 0, 70, 71, 68, 0, 67, 0, 64, 0, 63, 0]
    music_loop("boss_loop", 150, bass, lead)


if __name__ == "__main__":
    sfx()
    music()
