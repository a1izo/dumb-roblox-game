---
name: browser-frame-sheets-to-disk
description: How to save YouTube frame sheets as image files (not just look at them) from the built-in browser pane: Trusted Types policy, a local receiver on 127.0.0.1, 1080p, crops; learned in V0.4 (2026-11-16)
metadata:
  type: reference
---

[[youtube-reference-hunting]] says how to *look at* a frame sheet in the pane. To keep sheets as files (so they can be
opened with Read, committed, or compared later) this worked on 2026-11-16 (ticket V0.4, `art/refs/vfx/`):

- **Run a receiver on the machine**: a 20-line `http.server` (Blender's Python; `python` is only the Store stub) that
  accepts `POST /<name>` with a `data:image/jpeg;base64,...` body, answers with `Access-Control-Allow-Origin: *`, and
  writes `<name>.jpg`. From a youtube.com page, `fetch('http://127.0.0.1:8765/<name>', {method:'POST', body: canvas.toDataURL('image/jpeg', 0.78)})`
  goes through (no CSP block on localhost). A second tiny server (or the same one) can serve the helper script as text.
- **YouTube's Trusted Types blocks `eval`/script tags**, but `trustedTypes.createPolicy('anything', {createScript: s => s})`
  succeeds once per name per page; then `(0,eval)(policy.createScript(text))` defines the helper (seek, draw, label, post).
  The page's globals vanish on every navigation, so define the helper again on each watch page, in the same call as the
  first use (a call right after the policy call can find `window.__tp` gone if the page reloaded).
- **Ask for 1080p**: `document.getElementById('movie_player').setPlaybackQualityRange('hd1080','hd1080')`, wait 3 s; the video
  element then reports 1920x1080 and small effects read. Without it the pane often plays 360p and the effect is mush.
- **Crop** with the nine-argument `drawImage(video, sx, sy, sw, sh, dx, dy, dw, dh)` to the actor; 4 columns of 400 px (up to
  16 frames, 1600x900) is about 100 to 280 KB as JPEG and is easy to read with Read.
- **Seek, don't play**: pause, set `currentTime`, wait for `seeked` plus about 550 ms, draw. Short effects (a hit) fall
  between samples 0.25 s apart: sample 0.1 to 0.25 s around the moment, and say in the notes what could not be caught.
- Traps: some watch pages bounce to the "up next" video during a script (a 10-minute clip did, three times: the call
  returns "the page navigated"); check `location.href` and the title in the result and skip the clip. Search with
  `/results?search_query=` fetch as in the sibling note; fan one `javascript_tool` call over a list of queries.
