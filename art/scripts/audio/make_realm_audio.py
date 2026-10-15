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
    """(Retired with the bone dice: the file is no longer written, but its random draws are still made so
    every sound after it in main() comes out as before.)"""
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
    fade(reverb(x, 0.8, 0.2), 0.001, 0.2)


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


def game_bell_toll():
    """Death's mark: one stroke of a great cracked bell, low, a sour partial in it, a long dying ring."""
    seconds = 6.0
    t = t_axis(seconds)
    x = bell(98, seconds, 0.55, partials=((1.0, 1.0), (2.0, 0.55), (2.41, 0.5), (3.0, 0.3), (4.07, 0.22), (5.6, 0.12)))
    strike = shaped_noise(len(t), lambda f: bandpass(f, 300, 2500, 2)) * np.exp(-40 * t) * 0.6
    save("game_bell_toll.wav", fade(reverb(x + strike, 3.5, 0.3, 2600), 0.001, 1.5), 0.75)


def game_dive_wind():
    """The dive into the rift: air rushing past a falling body, rising over six seconds."""
    seconds = 6.5
    t = t_axis(seconds)
    n = len(t)
    u = t / seconds
    low = shaped_noise(n, lambda f: lowpass(f, 500, 2) / np.sqrt(np.maximum(f, 30) / 30))
    high = shaped_noise(n, lambda f: bandpass(f, 900, 4200, 2))
    flutter = slow_envelope(n, 2.0, 9.0)
    x = low / np.abs(low).max() * (0.25 + 0.75 * u) + high / np.abs(high).max() * u ** 2 * (0.5 + 0.5 * flutter) * 0.6
    save("game_dive_wind.wav", fade(x, 0.4, 0.6), 0.6)


def game_dive_crash():
    """The dive, braked too late: a body landing hard on a flat roof, a dull heavy thud and a short rattle."""
    t = t_axis(1.2)
    n = len(t)
    thud = np.sin(2 * np.pi * (52 + 30 * np.exp(-t * 30)) * t) * np.exp(-7 * t)
    slap = shaped_noise(n, lambda f: lowpass(f, 900, 2))
    slap = slap / np.abs(slap).max() * np.exp(-28 * t) * 0.7
    rattle = shaped_noise(n, lambda f: bandpass(f, 1200, 3800, 2))
    rattle = rattle / np.abs(rattle).max() * np.exp(-10 * np.clip(t - 0.08, 0, None)) * (t > 0.08) * 0.12
    save("game_dive_crash.wav", fade(reverb(thud + slap + rattle, 1.2, 0.25, 1800), 0.001, 0.3), 0.8)


def trial_chime():
    """The Trial's wisp setting off: two soft glassy notes a fifth apart, warm, with a short shimmer after."""
    soft = ((1.0, 1.0), (2.0, 0.18), (3.01, 0.07))
    a = bell(659.3, 1.6, 4.2, soft)
    b = np.zeros_like(a)
    shift = int(SR * 0.16)
    b[shift:] = bell(987.8, 1.6, 4.6, soft)[: len(a) - shift]
    save("trial_chime.wav", fade(reverb(a + 0.8 * b, 1.6, 0.3, 5000), 0.001, 0.35), 0.5)


def style_typewriter():
    """A typewriter key striking: a sharp metallic clack with a short wooden knock under it."""
    t = t_axis(0.25)
    n = len(t)
    clack = shaped_noise(n, lambda f: bandpass(f, 2500, 7000, 2))
    clack = clack / np.abs(clack).max() * np.exp(-90 * t)
    knock = np.sin(2 * np.pi * 220 * t) * np.exp(-40 * t) * 0.4
    save("style_typewriter.wav", fade(clack + knock, 0.0005, 0.05), 0.7)


def style_knife():
    """A blade cut into paper: a dry scrape, rising, a little gritty."""
    t = t_axis(0.9)
    n = len(t)
    scrape = shaped_noise(n, lambda f: bandpass(f, 1800, 6500, 2))
    env = np.sin(np.pi * np.clip(t / 0.85, 0, 1)) ** 0.6
    grit = 1 + 0.35 * np.sign(np.sin(2 * np.pi * 38 * t))
    save("style_knife.wav", fade(scrape / np.abs(scrape).max() * env * grit, 0.01, 0.1), 0.6)


def style_crows():
    """A burst of crows taking off: wings beating and three rough caws."""
    t = t_axis(2.2)
    n = len(t)
    wings = shaped_noise(n, lambda f: bandpass(f, 300, 2400, 2))
    wings = wings / np.abs(wings).max() * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * t) ** 2) * np.exp(-1.2 * t)
    caws = np.zeros(n)
    for start, pitch in ((0.15, 620), (0.6, 560), (1.1, 680)):
        k = (t >= start) & (t < start + 0.35)
        u = t[k] - start
        tone = np.sign(np.sin(2 * np.pi * (pitch - 260 * u) * u)) * 0.5 + np.sin(2 * np.pi * pitch * 2.1 * u) * 0.3
        caws[k] += tone * np.sin(np.pi * u / 0.35) * 0.5
    save("style_crows.wav", fade(reverb(wings + caws, 1.5, 0.25, 4000), 0.005, 0.3), 0.7)


def style_stone():
    """A body turning to stone: a deep grinding crack, then grit settling."""
    t = t_axis(1.6)
    n = len(t)
    crack = shaped_noise(n, lambda f: lowpass(f, 1400, 2))
    crack = crack / np.abs(crack).max() * np.exp(-6 * t)
    grind = np.sin(2 * np.pi * (70 + 20 * np.sin(2 * np.pi * 3 * t)) * t) * np.exp(-2.5 * t) * 0.5
    grit = shaped_noise(n, lambda f: bandpass(f, 2000, 6000, 2))
    grit = grit / np.abs(grit).max() * np.exp(-3 * np.clip(t - 0.3, 0, None)) * (t > 0.3) * 0.15
    save("style_stone.wav", fade(reverb(crack + grind + grit, 1.4, 0.3, 2500), 0.002, 0.3), 0.8)


def style_strings():
    """Strings cut: a taut twang, snapping, with a short whip of the loose ends."""
    t = t_axis(1.0)
    n = len(t)
    twang = np.zeros(n)
    for start, hz in ((0.0, 330), (0.07, 392), (0.13, 294)):
        k = t >= start
        u = t[k] - start
        twang[k] += np.sin(2 * np.pi * hz * u) * np.exp(-9 * u) * (1 + 0.3 * np.sin(2 * np.pi * hz * 2 * u))
    snap = shaped_noise(n, lambda f: bandpass(f, 3000, 9000, 2))
    snap = snap / np.abs(snap).max() * np.exp(-70 * t)
    save("style_strings.wav", fade(reverb(twang * 0.6 + snap, 1.0, 0.2, 6000), 0.0005, 0.2), 0.7)


def game_dive_fall():
    """The dive as it is now (2026-10-15: about eleven seconds down): air tearing past a tumbling body, from
    a hush to a roar, a slow beat in it as the body turns over."""
    seconds = 11.8
    t = t_axis(seconds)
    n = len(t)
    u = np.clip(t / 10.6, 0, 1)
    low = shaped_noise(n, lambda f: lowpass(f, 420, 2) / np.sqrt(np.maximum(f, 30) / 30))
    high = shaped_noise(n, lambda f: bandpass(f, 800, 4800, 2))
    tumble = 0.75 + 0.25 * np.sin(2 * np.pi * 0.35 * t + 0.6)
    flutter = slow_envelope(n, 2.5, 11.0)
    x = low / np.abs(low).max() * (0.2 + 0.8 * u) * tumble
    x = x + high / np.abs(high).max() * u ** 1.6 * (0.45 + 0.55 * flutter) * 0.65
    save("game_dive_fall.wav", fade(x, 0.5, 0.25), 0.62)


def game_dive_string():
    """The catch: a taut string snapping tight, a dry twang that dies quickly, with a soft whip of air."""
    t = t_axis(0.9)
    n = len(t)
    twang = np.zeros(n)
    for hz, amp in ((196.0, 1.0), (392.6, 0.45), (589.4, 0.22), (786.0, 0.12)):
        twang += amp * np.sin(2 * np.pi * hz * t * (1 + 0.012 * np.exp(-t * 18))) * np.exp(-t * 7.5)
    snap = shaped_noise(n, lambda f: bandpass(f, 2500, 9000, 2))
    snap = snap / np.abs(snap).max() * np.exp(-t * 90) * 0.9
    whip = shaped_noise(n, lambda f: bandpass(f, 400, 2400, 2))
    whip = whip / np.abs(whip).max() * np.exp(-((t - 0.05) / 0.06) ** 2) * 0.35
    save("game_dive_string.wav", fade(reverb(twang * 0.5 + snap + whip, 0.9, 0.18, 5000), 0.0005, 0.2), 0.7)


def game_dive_impact():
    """Braked too late: a body slamming into a flat roof: a heavy low thud, a dry crack on it, a short slap
    and a little rattle of grit. No blood, no scream."""
    t = t_axis(1.4)
    n = len(t)
    thud = np.sin(2 * np.pi * (46 + 38 * np.exp(-t * 26)) * t) * np.exp(-6 * t)
    crack = shaped_noise(n, lambda f: bandpass(f, 1800, 7000, 2))
    crack = crack / np.abs(crack).max() * np.exp(-((t - 0.012) / 0.008) ** 2) * 0.8
    crack2 = shaped_noise(n, lambda f: bandpass(f, 1200, 5000, 2))
    crack2 = crack2 / np.abs(crack2).max() * np.exp(-((t - 0.05) / 0.01) ** 2) * 0.35
    slap = shaped_noise(n, lambda f: lowpass(f, 1100, 2))
    slap = slap / np.abs(slap).max() * np.exp(-30 * t) * 0.6
    grit = shaped_noise(n, lambda f: bandpass(f, 2000, 6000, 2))
    grit = grit / np.abs(grit).max() * np.exp(-9 * np.clip(t - 0.1, 0, None)) * (t > 0.1) * 0.08
    save("game_dive_impact.wav", fade(reverb(thud + crack + crack2 + slap + grit, 1.1, 0.22, 2200), 0.0005, 0.3), 0.85)


def main():
    # (New sounds go at the end: the random stream is shared, so the earlier files stay as they were.)
    for make in (wind, drone, rumble, rocks, stone1, stone2, metal1, metal2, far1, far2, game_rune, game_wrong,
                 game_checkpoint, game_finish, game_dice, game_throw, game_fall, game_bell_toll, game_dive_wind,
                 game_dive_crash, trial_chime, style_typewriter, style_knife, style_crows, style_stone,
                 style_strings, game_dive_fall, game_dive_string, game_dive_impact):
        make()


if __name__ == "__main__":
    main()
