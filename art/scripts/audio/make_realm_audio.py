"""Synthesises the Grey Realm's soundscape and the lobby mini-games' sounds as 16-bit mono WAV files
in art/audio/ (44.1 kHz). Run it with Blender's Python (it needs numpy):

    "C:/Program Files/Blender Foundation/Blender 5.2/5.2/python/bin/python.exe" art/scripts/audio/make_realm_audio.py

Upload each file to Roblox (Studio: Asset Manager > Audio > Bulk Import, or the Creator Hub), then put
the asset ids in src/shared/Assets.luau (Assets.sfx, the slot named in art/audio/README.md). While a
slot's id is empty the game plays nothing for it.

The beds are made to loop without a click: every wave in them has a whole number of cycles in the
file, and the filtered noise is built in the frequency domain (so it wraps round by construction)."""

import os
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "audio")
rng = np.random.default_rng(1507)


def t_axis(seconds):
    return np.arange(int(SR * seconds)) / SR


def save(name, x, peak=0.8):
    x = np.asarray(x, dtype=np.float64)
    x = x - x.mean()
    m = np.abs(x).max()
    if m > 0:
        x = x / m * peak
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("wrote", name, f"{len(x) / SR:.1f}s")


def shaped_noise(n, gain):
    """Noise whose spectrum is gain(frequency in Hz): periodic over n samples (it loops)."""
    spec = rng.normal(size=n // 2 + 1) + 1j * rng.normal(size=n // 2 + 1)
    f = np.fft.rfftfreq(n, 1 / SR)
    spec *= gain(f)
    spec[0] = 0
    return np.fft.irfft(spec, n)


def slow_envelope(n, lowest, highest):
    """A positive, periodic envelope wandering at rates between `lowest` and `highest` Hz."""
    env = shaped_noise(n, lambda f: ((f >= lowest) & (f <= highest)).astype(float) + 0.0)
    env = env / (np.abs(env).max() + 1e-9)
    return 0.5 + 0.5 * env


def lowpass(f, fc, order=2):
    return 1.0 / (1.0 + (f / fc) ** (2 * order))


def bandpass(f, lo, hi, order=2):
    return lowpass(f, hi, order) * (1 - lowpass(f, lo, order))


def reverb(x, t60=2.5, wet=0.35, lp=3500):
    """A synthetic room: decaying noise as the impulse response."""
    n = int(SR * t60)
    ir = rng.normal(size=n) * np.exp(-6.9 * np.arange(n) / n)
    spec = np.fft.rfft(ir)
    ir = np.fft.irfft(spec * lowpass(np.fft.rfftfreq(n, 1 / SR), lp, 1), n)
    ir /= np.abs(ir).max()
    out = np.convolve(x, ir)[: len(x) + n // 2] * wet * 0.05
    y = np.zeros(len(out))
    y[: len(x)] += x * (1 - wet)
    return y + out


def fade(x, a=0.01, b=0.05):
    n = len(x)
    ia, ib = int(SR * a), int(SR * b)
    x = x.copy()
    x[:ia] *= np.linspace(0, 1, ia)
    x[-ib:] *= np.linspace(1, 0, ib)
    return x


# Beds (loops) -------------------------------------------------------------------------------------


def wind():
    seconds = 32
    n = int(SR * seconds)
    body = shaped_noise(n, lambda f: lowpass(f, 380, 3) / np.sqrt(np.maximum(f, 20) / 20))
    breath = shaped_noise(n, lambda f: bandpass(f, 700, 1800, 2) * 0.08)
    gust = slow_envelope(n, 1 / seconds, 0.12)
    gust2 = slow_envelope(n, 1 / seconds, 0.3)
    x = body * (0.35 + 0.65 * gust) + breath * gust2
    save("realm_wind.wav", x, 0.6)


def drone():
    seconds = 24
    t = t_axis(seconds)
    x = np.zeros_like(t)
    for hz, amp in ((55.0, 0.5), (55.125, 0.4), (82.5, 0.28), (110.0, 0.16), (164.96, 0.06)):
        hz = round(hz * seconds) / seconds
        x += amp * np.sin(2 * np.pi * hz * t + rng.uniform(0, 6.28))
    x *= 0.8 + 0.2 * np.sin(2 * np.pi * (3 / seconds) * t)
    x += 0.05 * shaped_noise(len(t), lambda f: bandpass(f, 60, 400, 2))
    save("realm_drone.wav", x, 0.5)


def rumble():
    seconds = 20
    n = int(SR * seconds)
    x = shaped_noise(n, lambda f: lowpass(f, 55, 3) * (f > 8))
    x *= 0.3 + 0.7 * slow_envelope(n, 1 / seconds, 0.18)
    save("realm_rumble.wav", x, 0.5)


def rocks():
    seconds = 20
    t = t_axis(seconds)
    n = len(t)
    x = np.zeros(n)
    for centre, width in ((900, 90), (1330, 120), (2100, 160)):
        drift = 1 + 0.18 * np.sin(2 * np.pi * (rng.integers(1, 4) / seconds) * t + rng.uniform(0, 6.28))
        band = shaped_noise(n, lambda f, c=centre, w=width: np.exp(-((f - c) / w) ** 2))
        x += band * slow_envelope(n, 1 / seconds, 0.2) ** 2
    x *= 0.7 + 0.3 * slow_envelope(n, 1 / seconds, 0.1)
    save("realm_rocks.wav", x, 0.45)


# One-shots ----------------------------------------------------------------------------------------


def stone1():
    t = t_axis(1.2)
    x = np.zeros_like(t)
    for hz, amp, decay in ((88, 1.0, 11), (141, 0.6, 15), (213, 0.35, 22)):
        x += amp * np.sin(2 * np.pi * hz * t) * np.exp(-decay * t)
    burst = shaped_noise(len(t), lambda f: bandpass(f, 200, 1200, 2)) * np.exp(-60 * t)
    save("realm_stone1.wav", fade(reverb(x + 0.5 * burst, 1.6, 0.4), 0.002, 0.2), 0.8)


def stone2():
    t = t_axis(3.2)
    n = len(t)
    x = shaped_noise(n, lambda f: bandpass(f, 250, 3000, 2)) * np.exp(-1.1 * t) * (0.4 + 0.6 * slow_envelope(n, 4, 18))
    for _ in range(90):
        i = rng.integers(0, n - 4000)
        x[i: i + 800] += rng.normal(size=800) * np.exp(-np.arange(800) / 90) * rng.uniform(0.2, 1.0) * np.exp(-i / n * 2)
    save("realm_stone2.wav", fade(reverb(x, 2.0, 0.4), 0.05, 0.4), 0.7)


def metal1():
    seconds = 2.8
    t = t_axis(seconds)
    glide = 430 - 45 * (t / seconds)
    phase = 2 * np.pi * np.cumsum(glide + 6 * np.sin(2 * np.pi * 5.5 * t)) / SR
    x = np.sin(phase) + 0.5 * np.sin(2 * phase) + 0.3 * np.sin(3 * phase)
    x *= np.sin(np.pi * t / seconds) ** 1.5
    x += 0.15 * shaped_noise(len(t), lambda f: bandpass(f, 800, 3000, 2)) * np.sin(np.pi * t / seconds) ** 2
    save("realm_metal1.wav", fade(reverb(x, 2.2, 0.35), 0.05, 0.5), 0.55)


def metal2():
    t = t_axis(4.5)
    x = np.zeros_like(t)
    for hz, amp, decay in ((179, 1.0, 0.9), (421, 0.7, 1.3), (693, 0.45, 1.8), (1041, 0.2, 2.6)):
        x += amp * np.sin(2 * np.pi * hz * t) * np.exp(-decay * t)
    x *= 1 - np.exp(-t * 30)
    save("realm_metal2.wav", fade(reverb(x, 3.0, 0.5, 2500), 0.01, 0.8), 0.5)


def far1():
    t = t_axis(3.8)
    n = len(t)
    syll = np.clip(np.sin(2 * np.pi * 5.2 * t) + 0.6 * np.sin(2 * np.pi * 3.1 * t + 1), 0, None)
    x = shaped_noise(n, lambda f: bandpass(f, 1500, 5200, 2)) * syll * np.sin(np.pi * t / 3.8) ** 2
    save("realm_far1.wav", fade(reverb(x, 2.4, 0.5, 3000), 0.1, 0.6), 0.4)


def far2():
    t = t_axis(4.2)
    n = len(t)
    x = shaped_noise(n, lambda f: np.exp(-((f - 520) / 140) ** 2) + 0.7 * np.exp(-((f - 1500) / 300) ** 2))
    x *= np.sin(np.pi * t / 4.2) ** 3 * (0.6 + 0.4 * np.sin(2 * np.pi * 0.7 * t))
    save("realm_far2.wav", fade(reverb(x, 2.6, 0.5, 2800), 0.2, 0.8), 0.4)


# The mini-games ------------------------------------------------------------------------------------


def bell(hz, seconds, decay=3.5, partials=((1.0, 1.0), (2.76, 0.5), (5.4, 0.25))):
    t = t_axis(seconds)
    x = np.zeros_like(t)
    for ratio, amp in partials:
        x += amp * np.sin(2 * np.pi * hz * ratio * t) * np.exp(-decay * ratio ** 0.7 * t)
    return x * (1 - np.exp(-t * 400))


def game_rune():
    t = t_axis(0.6)
    x = np.sin(2 * np.pi * 660 * t) * np.exp(-6 * t) + 0.35 * np.sin(2 * np.pi * 1320 * t) * np.exp(-9 * t)
    save("game_rune.wav", fade(x * (1 - np.exp(-t * 300)), 0.001, 0.05), 0.6)


def game_wrong():
    t = t_axis(0.7)
    x = np.sin(2 * np.pi * 70 * t) * np.exp(-9 * t) + 0.4 * shaped_noise(len(t), lambda f: lowpass(f, 500, 2)) * np.exp(-30 * t)
    save("game_wrong.wav", fade(x, 0.001, 0.1), 0.7)


def game_checkpoint():
    save("game_checkpoint.wav", fade(bell(880, 1.4, 4.0), 0.001, 0.3), 0.55)


def game_finish():
    a = bell(660, 1.8, 3.2)
    b = np.zeros_like(a)
    shift = int(SR * 0.28)
    b[shift:] = bell(990, 1.8, 3.2)[: len(a) - shift]
    save("game_finish.wav", fade(a + 0.9 * b, 0.001, 0.4), 0.6)


def game_dice():
    n = int(SR * 1.3)
    x = np.zeros(n)
    t0 = 0.0
    for k in range(18):
        t0 += rng.uniform(0.02, 0.09) * (1 + k * 0.08)
        i = int(t0 * SR)
        if i + 2000 >= n:
            break
        click = rng.normal(size=1600) * np.exp(-np.arange(1600) / rng.uniform(50, 160))
        x[i: i + 1600] += click * rng.uniform(0.3, 1.0) * np.exp(-t0 * 1.6)
    x = np.convolve(x, np.sin(2 * np.pi * 900 * np.arange(60) / SR) * np.hanning(60), "same") + 0.4 * x
    save("game_dice.wav", fade(reverb(x, 0.8, 0.2), 0.001, 0.2), 0.7)


def game_throw():
    t = t_axis(0.5)
    n = len(t)
    x = shaped_noise(n, lambda f: bandpass(f, 600, 3500, 2)) * np.sin(np.pi * np.clip(t / 0.5, 0, 1)) ** 2
    save("game_throw.wav", fade(x, 0.01, 0.1), 0.45)


def game_fall():
    seconds = 6.5
    t = t_axis(seconds)
    n = len(t)
    x = np.zeros(n)
    gap = 0.12
    hit = 0.4
    amp = 1.0
    while hit < seconds - 0.7:
        i = int(hit * SR)
        k = np.arange(5000)
        knock = np.sin(2 * np.pi * rng.uniform(300, 700) * k / SR) * np.exp(-k / 700) + 0.4 * rng.normal(size=5000) * np.exp(-k / 300)
        x[i: i + 5000] += knock * amp
        gap *= 1.28
        hit += gap
        amp *= 0.78
    save("game_fall.wav", fade(reverb(x, 4.5, 0.6, 2200), 0.001, 1.2), 0.6)


def main():
    for make in (wind, drone, rumble, rocks, stone1, stone2, metal1, metal2, far1, far2, game_rune, game_wrong,
                 game_checkpoint, game_finish, game_dice, game_throw, game_fall):
        make()


if __name__ == "__main__":
    main()
