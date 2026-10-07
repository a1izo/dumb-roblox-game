"""Tokyo's karaoke box and konbini extras (set "Tokyo"): the karaoke console with its cordless mics
and song-search tablet, a mic stand, a floor speaker, a mirror ball, a song book, a tambourine, a
drinks tray, and for the konbini a magazine rack and a bank ATM.

Built to the semi-real standard (propkit). They face -Y and stand on z = 0 (the mirror ball hangs:
its pivot is its centre)."""

import math
import random

import modelkit as mk
import propkit as pk
from common import srgb
from props import prop


@prop("KaraokeConsole", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024, set="Tokyo")
def karaoke_console():
    """The machine under a karaoke room's screen, 5 wide: a black cabinet with the amp's lit level
    meters, two cordless mics in their charging cradle, the song-search tablet in its dock, a
    remote and a spare battery tray."""
    black = pk.plastic("KC_Black", (22, 22, 26))
    panel = pk.metal("KC_Panel", (40, 40, 46), (60, 60, 66), rough=0.4, metallic=0.4)
    chrome = pk.chrome("KC_Chrome")
    mic = pk.plastic("KC_Mic", (226, 226, 230))
    grille = pk.metal("KC_Grille", (60, 60, 64), (90, 90, 96), rough=0.5, metallic=0.7)
    parts = [pk.rounded("Cabinet", (5.0, 1.8, 2.4), (0, 0, 1.2), black, r=0.06),
             mk.box("Amp", (4.4, 0.06, 0.9), (0, -0.92, 1.85), mat=panel),
             mk.box("Kick", (4.8, 1.6, 0.15), (0, 0, 0.08), mat=panel),
             pk.rounded("Cradle", (1.6, 0.8, 0.3), (-1.4, -0.2, 2.55), black, r=0.05),
             pk.rounded("Dock", (1.4, 0.9, 0.25), (1.3, -0.1, 2.53), black, r=0.05),
             mk.box("Tablet", (1.2, 0.08, 0.85), (1.3, 0.1, 2.95), rot=(-20, 0, 0), mat=black, bevel=0.03),
             pk.rounded("Remote", (0.25, 0.7, 0.08), (0.2, -0.4, 2.44), black, r=0.03)]
    parts += pk.louvres("Vent", 0, 0.92, 0.7, 4.0, 0.5, grille, count=8)
    for k, x in enumerate((-1.8, -1.0)):
        parts += [mk.cylinder("MicBody", 0.13, 0.9, (x, -0.2, 3.0), mat=mic, verts=12, radius2=0.1),
                  mk.lathe("MicHead", [(0.0, 0.0), (0.2, 0.05), (0.24, 0.2), (0.2, 0.36), (0.0, 0.42)],
                           (x, -0.2, 3.42), mat=grille, segments=12),
                  mk.torus("MicRing", 0.17, 0.02, (x, -0.2, 3.44), mat=chrome, major_segments=12,
                           minor_segments=4)]
    glows = [mk.box(f"Meter{k}", (0.5, 0.03, 0.12), (-1.4 + k * 0.6, -0.96, 1.95), mat=pk.glow("KC_Meter", (80, 220, 140), 3))
             for k in range(5)]
    glows += [mk.box("Screen", (1.05, 0.03, 0.7), (1.3, 0.05, 2.97), rot=(-20, 0, 0),
                     mat=pk.glow("KC_Tablet", (120, 170, 255), 2.5))]
    return parts, glows


@prop("MicStand", pivot="bottom", material="Metal", collide=False, texture=512, set="Tokyo")
def mic_stand():
    """A boom mic stand: a weighted round base, a telescopic column, the boom tilted toward -Y and a
    wired mic in its clip."""
    chrome = pk.chrome("MS_Chrome")
    black = pk.plastic("MS_Black", (24, 24, 28))
    grille = pk.metal("MS_Grille", (70, 70, 74), (100, 100, 106), rough=0.5, metallic=0.7)
    top = (0, -1.3, 5.6)
    parts = [mk.cylinder("Base", 0.7, 0.12, (0, 0, 0.06), mat=black, verts=24, bevel=0.03),
             mk.cylinder("Column", 0.07, 3.6, (0, 0, 1.9), mat=chrome, verts=10),
             mk.cylinder("Sleeve", 0.05, 1.2, (0, 0, 4.2), mat=chrome, verts=10),
             mk.cylinder("Clutch", 0.12, 0.25, (0, 0, 3.7), mat=black, verts=12),
             mk.tube("Boom", (0, 0.5, 4.6), top, 0.04, mat=chrome, verts=8),
             mk.cylinder("Counter", 0.14, 0.4, (0, 0.6, 4.55), rot=(70, 0, 0), mat=black, verts=10),
             mk.tube("Clip", top, (0, -1.42, 5.52), 0.06, mat=black, verts=8),
             mk.tube("MicBody", (0, -1.42, 5.52), (0, -1.95, 5.22), 0.1, radius_end=0.12, mat=black, verts=12),
             mk.sphere("MicHead", 0.19, (0, -2.08, 5.15), mat=grille, segments=12, rings=8),
             mk.tube("Cable", (0, -1.42, 5.48), (0.08, -0.15, 0.15), 0.025, mat=black, verts=4)]
    return parts, []


@prop("KaraokeSpeaker", pivot="bottom", material="SmoothPlastic", collide=True, texture=512, set="Tokyo")
def karaoke_speaker():
    """A floor speaker on a low riser, 1.8 wide: a black cabinet, two woofers and a horn behind a
    cloth grille's frame, a small lit power ring."""
    black = pk.plastic("KS_Black", (20, 20, 24))
    cone = pk.metal("KS_Cone", (40, 40, 44), (64, 64, 70), rough=0.6, metallic=0.2)
    frame = pk.metal("KS_Frame", (70, 70, 76), (100, 100, 106), rough=0.4, metallic=0.6)
    parts = [mk.box("Riser", (1.9, 1.6, 0.4), (0, 0, 0.2), mat=frame, bevel=0.04),
             pk.rounded("Cabinet", (1.8, 1.5, 3.4), (0, 0, 2.1), black, r=0.06)]
    for z in (1.3, 2.4):
        parts += [mk.cylinder("Woofer", 0.55, 0.1, (0, -0.76, z), rot=(90, 0, 0), mat=cone, verts=24),
                  mk.torus("Surround", 0.56, 0.04, (0, -0.78, z), rot=(90, 0, 0), mat=frame, major_segments=24,
                           minor_segments=4)]
    parts.append(mk.box("Horn", (0.9, 0.2, 0.45), (0, -0.78, 3.4), mat=cone, bevel=0.06))
    parts += pk.frame("Grille", 1.6, 3.1, 0.06, 0.05, (0, -0.8, 2.15), frame)
    glows = [mk.torus("Power", 0.08, 0.02, (0.65, -0.77, 0.75), rot=(90, 0, 0), mat=pk.glow("KS_Power", (90, 160, 255), 3),
                      major_segments=10, minor_segments=4)]
    return parts, glows


@prop("MirrorBall", pivot="centre", material="Metal", collide=False, texture=512, set="Tokyo")
def mirror_ball():
    """A mirror ball 1.6 across on its chain and motor, hung from the ceiling."""
    mirror = pk.metal("MB_Mirror", (190, 196, 206), (230, 234, 240), rough=0.05, metallic=1.0, scale=40)
    chrome = pk.chrome("MB_Chrome")
    parts = [mk.sphere("Ball", 0.8, (0, 0, 0), mat=mirror, segments=14, rings=10),
             mk.cylinder("Motor", 0.18, 0.3, (0, 0, 1.0), mat=chrome, verts=10),
             mk.cylinder("Chain", 0.03, 1.4, (0, 0, 1.85), mat=chrome, verts=4),
             mk.cylinder("Mount", 0.25, 0.08, (0, 0, 2.55), mat=chrome, verts=10)]
    return parts, []


@prop("SongBook", pivot="bottom", material="SmoothPlastic", collide=False, texture=512, set="Tokyo")
def song_book():
    """The fat song catalogue a room keeps on its table, open on its ring binder."""
    cover = pk.plastic("SB_Cover", (150, 26, 70))
    paper = pk.plastic("SB_Paper", (236, 232, 222))
    parts = [mk.box("CoverL", (1.0, 1.4, 0.06), (-0.52, 0, 0.03), mat=cover, bevel=0.02),
             mk.box("CoverR", (1.0, 1.4, 0.06), (0.52, 0, 0.03), mat=cover, bevel=0.02),
             mk.box("PagesL", (0.92, 1.3, 0.18), (-0.5, 0, 0.15), mat=paper),
             mk.box("PagesR", (0.92, 1.3, 0.12), (0.5, 0, 0.12), mat=paper)]
    parts += pk.label("Title", "曲目", 0.16, (0.5, -0.1, 0.22), pk.plastic("SB_Ink", (30, 30, 34)), rot=(0, 0, 0))
    return parts, []


@prop("Tambourine", pivot="bottom", material="SmoothPlastic", collide=False, texture=512, set="Tokyo")
def tambourine():
    """A karaoke room's tambourine lying on its side: a red plastic ring with its jingles."""
    ring = pk.plastic("TB_Ring", (200, 30, 40))
    jingle = pk.chrome("TB_Jingle")
    parts = [mk.torus("Ring", 0.45, 0.07, (0, 0, 0.07), mat=ring, major_segments=24, minor_segments=6)]
    for k in range(6):
        a = 2 * math.pi * k / 6
        parts.append(mk.cylinder("Jingle", 0.08, 0.04, (math.cos(a) * 0.45, math.sin(a) * 0.45, 0.14), mat=jingle,
                                 verts=8))
    return parts, []


@prop("DrinksTray", pivot="bottom", material="SmoothPlastic", collide=False, texture=512, set="Tokyo")
def drinks_tray():
    """A tray of the night's drinks: highballs, an oolong tea, a beer mug, coasters and a menu card."""
    rng = random.Random(9)
    tray = pk.plastic("DT_Tray", (30, 30, 34))
    glass = pk.metal("DT_Glass", (170, 190, 200), (210, 220, 228), rough=0.05, metallic=0.1)
    drinks = [pk.plastic("DT_Highball", (220, 200, 120)), pk.plastic("DT_Oolong", (120, 70, 30)),
              pk.plastic("DT_Beer", (230, 170, 40)), pk.plastic("DT_Melon", (90, 200, 90))]
    foam = pk.plastic("DT_Foam", (244, 240, 230))
    parts = [mk.box("Tray", (2.0, 1.3, 0.06), (0, 0, 0.03), mat=tray, bevel=0.02)]
    for k, (x, y) in enumerate(((-0.6, -0.3), (-0.1, 0.3), (0.45, -0.25), (0.7, 0.35))):
        h = rng.uniform(0.5, 0.75)
        parts += [mk.cylinder("Glass", 0.17, h, (x, y, 0.06 + h / 2), mat=glass, verts=12),
                  mk.cylinder("Drink", 0.15, h * 0.75, (x, y, 0.06 + h * 0.38), mat=drinks[k], verts=12)]
        if k == 2:
            parts.append(mk.cylinder("Foam", 0.16, 0.08, (x, y, 0.06 + h * 0.78), mat=foam, verts=12))
    parts.append(mk.box("Menu", (0.5, 0.05, 0.7), (-0.75, 0.45, 0.4), rot=(-12, 0, 0), mat=pk.plastic("DT_Menu", (240, 70, 120))))
    return parts, []


@prop("MagazineRack", pivot="bottom", material="SmoothPlastic", collide=True, texture=1024, set="Tokyo")
def magazine_rack():
    """A konbini's magazine shelf under its front window, 8 long: three sloped tiers of magazines and
    manga, their covers loud, the comics shrink-wrapped."""
    rng = random.Random(4)
    white = pk.plastic("MR_White", (232, 232, 228))
    steel = pk.metal("MR_Steel", (150, 154, 160), (190, 194, 200))
    covers = [pk.plastic(f"MR_Cover{k}", c) for k, c in enumerate(
        [(220, 40, 60), (240, 200, 40), (40, 120, 200), (250, 250, 246), (30, 30, 34), (240, 120, 160), (60, 170, 90)])]
    parts = [mk.box("Base", (8.0, 1.6, 0.8), (0, 0, 0.4), mat=white, bevel=0.03),
             mk.box("Back", (8.0, 0.1, 3.0), (0, 0.75, 1.5), mat=white)]
    for tier in range(3):
        z = 0.85 + tier * 0.75
        y = 0.4 - tier * 0.25
        parts.append(mk.box("Tier", (8.0, 0.6, 0.06), (0, y, z), rot=(-15, 0, 0), mat=steel))
        x = -3.8
        while x < 3.5:
            w = rng.uniform(0.6, 0.85)
            parts.append(mk.box("Mag", (w - 0.05, 0.04, 0.95), (x + w / 2, y - 0.12, z + 0.42), rot=(-15, 0, 0),
                                mat=covers[rng.randrange(len(covers))]))
            x += w
    return parts, []


@prop("ATM", pivot="bottom", material="Metal", collide=True, texture=1024, set="Tokyo")
def atm():
    """A bank ATM in a konbini corner: a grey cabinet with its lit touch screen under a privacy hood,
    the card and cash slots, a keypad, the bank's band on top."""
    body = pk.metal("ATM_Body", (150, 154, 160), (180, 184, 190), rough=0.35, metallic=0.5)
    dark = pk.plastic("ATM_Dark", (30, 30, 34))
    band = pk.plastic("ATM_Band", (40, 90, 170))
    parts = [pk.rounded("Body", (2.4, 2.2, 5.6), (0, 0, 2.8), body, r=0.08),
             mk.box("Band", (2.42, 2.22, 0.7), (0, 0, 5.3), mat=band),
             mk.box("Shelf", (2.2, 0.8, 0.12), (0, -1.4, 3.0), mat=body, bevel=0.03),
             mk.box("Hood", (1.9, 0.6, 0.12), (0, -1.35, 4.65), rot=(12, 0, 0), mat=dark),
             mk.box("HoodSideL", (0.08, 0.6, 1.4), (-0.95, -1.35, 4.0), mat=dark),
             mk.box("HoodSideR", (0.08, 0.6, 1.4), (0.95, -1.35, 4.0), mat=dark),
             mk.box("CardSlot", (0.5, 0.06, 0.06), (-0.6, -1.11, 3.25), mat=dark),
             mk.box("CashSlot", (1.2, 0.06, 0.1), (0.3, -1.11, 2.6), mat=dark),
             mk.box("Keypad", (0.7, 0.5, 0.06), (0.65, -1.5, 3.08), rot=(-10, 0, 0), mat=dark)]
    parts += pk.label("Bank", "ATM", 0.3, (0, -1.12, 5.3), pk.plastic("ATM_Ink", (240, 240, 240)))
    glows = [mk.box("Screen", (1.3, 0.04, 0.9), (0, -1.12, 4.0), rot=(-8, 0, 0), mat=pk.glow("ATM_Screen", (150, 200, 255), 3))]
    return parts, glows
