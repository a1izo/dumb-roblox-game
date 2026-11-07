---
name: dive-probe-hover
description: A harness probe that drops a body into the lobby's rift must hover it there a moment first (CFrame each Heartbeat): a teleport, or an anchored body, leaves the server seeing it at the spawn and the dive is refused into a plain fall
metadata:
  type: reference
---

2026-11-07, testing the rift's dive in the throwaway harness place: a probe that set the root's CFrame over the rift
and let it fall got the dive refused two runs in three. LobbyRift.enter judges where the server last heard the body
was (ENTER_REACH of the rift's ellipse, at most ENTER_ABOVE over the rim), and the client asks the moment the root is 2
studs under the rim: an instant teleport is ahead of the server's view, and anchoring a client-owned root sends nothing
at all. Hovering it (root.CFrame and a zero velocity every Heartbeat for 1.5 s) lets the server catch up; then every
run dives.

Refused dives are plain falls: DiveController lets go and LobbyGamesController darkens the screen. Such a fall showed
the camera's one way out of the throat (the body under the cloud, the camera behind it up in the dark beside the
throat), now shut: when what the camera looks at is under the cloud, the camera stays under it too.

**How to apply:** probe the dive by hovering first; read `DiveController.diving()` each frame to tell a dive from a
fall. Results to expect: the camera's reach of the throat's clear ellipse 1.00 with the zoom forced to 35, the body's
about 1.1, nothing in the rock. Related: [[lobby-remake-v2]], [[studio-no-screen]].
