---
name: station-props-2026-11
description: The 17 case-file station props were rebuilt 2026-11-01 from stationkit.py inside their old boxes; how to change one without breaking map layouts
metadata:
  type: project
---

On 2026-11-01 every station look (Station, StationCCTV, StationPhoneBooth, StationReception, StationPrintKit,
StationLabBench, StationCRTBank, StationPhoneDesk, StationReelToReel, StationCameraPost, StationPublicPhone,
StationNewsDesk, StationBookReturn, StationVault, StationAutopsy) and the metro's StationClock and StationSignHanging
were rebuilt to the semi-real standard after the owner said the stations looked very low quality next to the rest.

- Shared parts live in `art/scripts/stationkit.py`: `lcd` / `crt` / `bezel` round a screen slot (never cover the
  face), `keyboard`, `desk_phone`, `mug`, `papers`, `folder`, `open_book`, `desk_lamp`, `steel_desk`, `wood_desk`,
  `tilt_about` / `turn_about`. The old `props_stations.desk` / `monitor` and the local `crt`s are gone.
- Each prop keeps the box (in station coordinates) the maps were laid out round, and every `screen` slot is
  unchanged, so no venue needed re-exporting. StationCCTV and StationClock came off `build_props.KEPT`, rebuilt inside
  their kept boxes; StationCCTV now has anchor (0, 0) and a screen slot equal to the console default (0, 0.8, 5.4,
  4.4 x 2.6).
- The plain `Station` has no anchor and no slot (Builder:station places it by its footprint's middle and puts the
  screen at (0, 5.4, 0.8)), so it must stay symmetric in depth: its foot rail and cable tray both reach 1.625.
- A prop's `anchor` in Props.blend / ModelCatalog is the design origin minus the footprint centre with x mirrored
  (Roblox x): footprint centre in Blender = (anchor[0], -anchor[1]).

**Why:** the maps (check_v2) were laid out round the old boxes; a bigger box means re-exporting and re-checking venues.
**How to apply:** when changing a station look, compare its new box in station coordinates with the old one before
exporting. Glows only on real lights (LEDs, lit screens, lamp bulbs, lit signs). Related: [[map-remake-project]],
[[parallel-agent-merges]].
