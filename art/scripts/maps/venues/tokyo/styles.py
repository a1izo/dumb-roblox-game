"""How each of Tokyo's buildings looks (maps/buildings.py builds them): its cladding, windows,
ground floor, signs and roof. The landmarks and every building a player looks at from the scramble
are styled one by one below; the rest take their kind's look, picked from a small palette by the
building's name (so it never changes between builds), and no two neighbours match.

Signs use made-up Japanese names (the game draws the words); the places a player looks for also
say what they are in English."""

import math
import random

from maps import geo2d as g2
from maps.venues.tokyo import plan as P

# Words for signs.
BARS = ["やきとり 鳥八", "居酒屋 まる", "酒処 灯", "スナック 月", "BAR 夜鷹", "おでん 花", "立ち飲み 金", "焼肉 牛若",
        "串カツ 大吉", "餃子 一番", "バー ルナ", "酒場 暁", "もつ焼 たか", "小料理 雪", "喫茶 ミモザ", "ホルモン 鉄",
        "天ぷら 松", "寿司 辰", "BAR 黒猫", "酒場 よる", "焼鳥 ほし", "居酒屋 風", "蕎麦 源", "バー 霧"]
FLOOR_SIGNS = ["カラオケ", "居酒屋", "英会話", "ネイル", "麻雀", "整体", "漫画喫茶", "占い", "歯科", "美容室", "焼肉",
               "ダーツ", "質屋", "学習塾", "ゲーム", "エステ", "バー", "中華", "写真館", "不動産"]
SHOPS = ["ドラッグ まつや", "書店 文林", "眼鏡 ミライ", "靴 アルク", "古着 ルル", "携帯 スマイル", "花屋 はな", "パン 麦",
         "カフェ 珈", "時計 秒", "百円 ショップ", "帽子 ボウ", "文具 ペン", "薬局 あおば", "果物 みかん", "化粧品 ハル"]
HOTELS = ["ホテル 月光", "ビジネスホテル 旭", "ホテル 銀河", "ホテル サクラ"]
OFFICES = ["影ヶ丘ビル", "第二 明星ビル", "東雲ビル", "朝日ビル", "丸山ビル", "新光ビル", "北斗ビル", "若葉ビル"]
COLOURS = ["white", "yellow", "red", "pink", "blue", "green", "orange", "purple", "cyan"]

CLADS = {
    "zakkyo": ["FacadeTile", "FacadeTileGrey", "PlasterLight", "PlasterGrey", "BrickDark"],
    "office": ["ConcreteDark", "FacadeTileGrey", "PlasterGrey", "Concrete", "Stone"],
    "apartment": ["PlasterLight", "BrickRed", "FacadeTile", "PlasterGrey", "Concrete"],
    "hotel": ["BrickDark", "FacadeTileGrey", "PlasterLight", "FacadeTile"],
    "shop": ["FacadeTile", "PlasterLight", "BrickRed", "FacadeTileGrey", "PlasterGrey"],
    "bar": ["Shutter", "WoodPanel", "PlasterDark", "BrickDark", "PlasterGrey"],
    "edge": ["ConcreteDark", "FacadeTileGrey", "PlasterGrey", "BrickDark"],
    "pencil": ["FacadeTileGrey", "PlasterLight"],
}
TRIMS = ["DarkMetal", "WhiteTrim", "BlackMetal", "Steel", "CreamTrim"]

# Hand-styled buildings: the landmarks and the frames round the scramble and the station.
HAND = {
    "station": dict(clad="Concrete", trim="WhiteTrim", windows="band", bay=5.0, lit=0.55, ground="interior",
                    roof=("ac", "hut", ("billboard", "影ヶ丘駅  KAGEGAOKA STATION", "white"))),
    "station_tower": dict(clad="GlassDark", trim="Steel", windows="curtain", bay=4.0, lit=0.4, ground="lobby",
                          roof=("antenna",)),
    "station_annex": dict(clad="Concrete", trim="WhiteTrim", windows="band", bay=5.0, lit=0.3, ground="shutters"),
    "station_north": dict(clad="ConcreteDark", trim="Steel", windows="punched", bay=6.0, lit=0.3, ground="shutters",
                          fascia=("駅北口 NORTH EXIT", "white")),
    "glass_tower": dict(clad="GlassDark", trim="Steel", windows="curtain", bay=4.0, lit=0.5, ground="display",
                        screen=(30.0, 18.0), roof=("antenna",)),
    "dept_store": dict(clad="Stone", trim="Gold", windows="punched", bay=8.0, win=5.0, lit=0.6, ground="interior",
                       rooms=2,
                       screen=(16.0, 10.0), roof=(("billboard", "影屋  KAGEYA", "red"), "ac")),
    "zakkyo_se": dict(clad="FacadeTileGrey", trim="DarkMetal", windows="punched", bay=5.6, lit=0.55,
                      ground="display", fascia=("眼鏡 ミライ", "blue"),
                      vsign=[("カラオケ", "pink"), ("焼肉", "red"), ("英会話", "yellow"), ("ネイル", "white"),
                             ("麻雀", "green"), ("占い", "purple"), ("バー", "cyan"), ("整体", "orange")],
                      roof=(("billboard", "ONE PIECE OF NIGHT", "yellow"),)),
    "zakkyo_sw": dict(clad="PlasterLight", trim="BlackMetal", windows="punched", bay=6.0, lit=0.5, ground="display",
                      fascia=("カフェ 珈", "orange"),
                      vsign=[("漫画喫茶", "yellow"), ("ダーツ", "blue"), ("歯科", "white"), ("学習塾", "green"),
                             ("バー", "pink"), ("中華", "red")], roof=("tank", "ac")),
    "koban": dict(clad="BrickDark", trim="WhiteTrim", windows="punched", ground="interior"),
    "karaoke": dict(clad="PlasterDark", trim="NeonPink", windows="punched", bay=5.0, lit=0.65, ground="interior",
                    rooms=2,
                    vsign=[("カラオケ", "pink"), ("KARAOKE", "pink"), ("ホテル", "purple"), ("HOTEL", "purple"),
                           ("月光", "cyan"), ("24H", "yellow"), ("フリータイム", "orange"), ("個室", "pink")],
                    roof=(("billboard", "カラオケ 月光  KARAOKE HOTEL", "pink"),)),
    "konbini_block": dict(clad="FacadeTile", trim="WhiteTrim", windows="balcony", bay=9.0, lit=0.45,
                          ground="interior", roof=("tank",)),
    "arcade_n2": dict(clad="PlasterDark", trim="NeonBlue", windows="punched", bay=6.0, lit=0.6, ground="interior",
                      vsign=[("ゲーム", "blue"), ("GAME", "cyan"), ("UFO", "pink"), ("メダル", "yellow"),
                             ("プリクラ", "pink")]),
    "arcade_s1": dict(clad="FacadeTileGrey", trim="WhiteTrim", windows="punched", bay=6.5, lit=0.5,
                      ground="interior", rooms=2, roof=("ac",),
                      vsign=[("クリニック", "white"), ("CLINIC", "green"), ("内科", "white"), ("薬", "green")]),
    "arcade_s2": dict(clad="BrickRed", trim="CreamTrim", windows="punched", bay=6.0, lit=0.55, ground="interior",
                      vsign=[("ラーメン", "red"), ("麺屋", "yellow"), ("餃子", "white")]),
    "laundromat": dict(clad="PlasterLight", trim="DarkMetal", windows="balcony", bay=8.0, lit=0.5,
                       ground="interior", roof=("tank",)),
    "ya_s2": dict(clad="WoodPanel", trim="Wood", windows="tin", lit=0.6, ground="interior"),
}


def _rng(name):
    return random.Random("style:" + name)


def kind_style(b):
    """A building's look from its kind, picked by its name."""
    rng = _rng(b["name"])
    kind = b["kind"]
    clad = rng.choice(CLADS.get(kind, CLADS["office"]))
    trim = rng.choice(TRIMS)
    if kind == "zakkyo" or kind == "pencil":
        count = min(8, b["floors"] - 1)
        return dict(clad=clad, trim=trim, windows="punched", bay=rng.choice((5.0, 5.6, 6.0)), lit=0.5,
                    ground=rng.choice(("display", "shutters")),
                    fascia=(rng.choice(SHOPS), rng.choice(COLOURS)),
                    vsign=[(w, rng.choice(COLOURS)) for w in rng.sample(FLOOR_SIGNS, count)],
                    roof=rng.sample(("tank", "ac", "antenna"), 2))
    if kind == "office":
        return dict(clad=clad, trim=trim, windows=rng.choice(("band", "punched")), bay=rng.choice((4.0, 6.0, 7.0)),
                    lit=rng.uniform(0.3, 0.55), ground="lobby", roof=("hut", "ac"),
                    fascia=(rng.choice(OFFICES), "white") if rng.random() < 0.4 else None)
    if kind == "apartment":
        return dict(clad=clad, trim=trim, windows="balcony", bay=rng.choice((8.0, 9.0, 10.0)), lit=0.5,
                    ground=rng.choice(("shutters", "lobby")), panel=rng.choice((clad, "WhiteTrim", "ConcreteDark")),
                    roof=("tank",))
    if kind == "hotel":
        return dict(clad=clad, trim=trim, windows="punched", bay=5.4, win=3.6, lit=0.55, ground="lobby",
                    roof=(("billboard", rng.choice(HOTELS) + "  HOTEL", "white"), "ac"))
    if kind == "shop":
        return dict(clad=clad, trim=trim, windows="punched", bay=rng.choice((6.0, 7.0)), lit=0.5,
                    ground=rng.choice(("display", "shutters")), fascia=(rng.choice(SHOPS), rng.choice(COLOURS)),
                    roof=("ac",))
    if kind == "bar":
        return dict(clad=clad, trim=rng.choice(("Wood", "DarkMetal")), windows="tin", lit=0.6, ground="tin",
                    fascia=(rng.choice(BARS), rng.choice(("red", "white", "yellow", "orange"))))
    if kind == "glass":
        return dict(clad="GlassDark", trim="Steel", windows="curtain", bay=4.0, lit=0.45, ground="lobby")
    if kind == "karaoke":
        return HAND["karaoke"]
    return dict(clad=clad, trim=trim, windows="punched", bay=7.0, lit=0.4, ground="shutters", roof=("ac",))


def style(b):
    """The finished style of building b (a dict for maps.buildings.build)."""
    s = dict(kind_style(b))
    s.update(HAND.get(b["name"], {}))
    if b.get("use") and "ground" not in HAND.get(b["name"], {}):
        s["ground"] = "interior"
    if not s.get("fascia"):
        s.pop("fascia", None)
    return s


# Which walls face a street -------------------------------------------------------------------------------

_CHANNEL = None


def _walkable(p):
    """Open ground: in the map, and not in the river's channel (buildings are left to fronts)."""
    global _CHANNEL
    if _CHANNEL is None:
        _CHANNEL = g2.strip_quads(P.RIVER, P.CHANNEL[1], P.CHANNEL[0])
    if not (P.X0 < p[0] < P.X1 and P.Z0 < p[1] < P.Z1):
        return False
    return not any(g2.contains(q, p) for q in _CHANNEL)


def fronts(b, buildings):
    """The indices (counter-clockwise edge order, as maps.buildings.edges_of) of the walls of b
    that look onto open ground people walk on (a street, plaza, lane, yard or the river's
    promenade), three studs of it at least."""
    from maps.buildings import edges_of

    out = []
    edges = edges_of(b["poly"])
    for i, e in enumerate(edges):
        if e.length < 3.0:
            continue
        probes = [e.at(e.length / 2, out) for out in (1.5, 3.0)]
        if all(_walkable(p) and not any(o is not b and g2.contains(o["poly"], p) for o in buildings) for p in probes):
            out.append(i)
    # The side on the street the building is named for first (its signs go there).
    return sorted(out, key=lambda i: _to_front(b, edges[i].at(edges[i].length / 2, 3.0)))


def _to_front(b, p):
    """How far p lies from the place building b fronts (plan: front=...)."""
    name = b.get("front")
    if name in P.STREETS:
        line = P.STREETS[name]["points"]
    elif name == "river":
        line = P.RIVER
    elif name == "scramble":
        return g2.dist_to_poly_edge(P.SCRAMBLE, p) * (0 if g2.contains(P.SCRAMBLE, p) else 1)
    elif name == "plaza":
        line = [(-108.0, -68.0), (-40.0, -68.0)]
    else:
        return 0.0
    return min(g2.dist_point_segment(p, line[k], line[k + 1]) for k in range(len(line) - 1))


def repeats(buildings):
    """Neighbouring buildings that ended up looking the same (for the plan's self-check)."""
    looks = [(b, style(b)) for b in buildings]
    found = []
    for i, (a, sa) in enumerate(looks):
        ca = g2.centroid(a["poly"])
        for b, sb in looks[i + 1:]:
            if math.dist(ca, g2.centroid(b["poly"])) < 40 and all(
                    sa.get(k) == sb.get(k) for k in ("clad", "windows", "ground", "trim")):
                found.append((a["name"], b["name"]))
    return found
