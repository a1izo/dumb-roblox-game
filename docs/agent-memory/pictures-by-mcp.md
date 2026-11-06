---
name: pictures-by-mcp
description: "Upload Assets.images pictures without screen control: serve the PNGs on localhost and call the Studio MCP's upload_image"
metadata:
  type: reference
---

Pictures that travel on their own (Assets.images: the intro's eye, the apple screen, the pointers) no longer need
Studio's Asset Manager and the person's screen. With Studio's MCP switched on ([[studio-mcp]]):

1. Copy the PNGs into a scratch folder and serve it: `python -m http.server 8765 --bind 127.0.0.1 --directory <dir>`
   (Blender's Python will do), in the background.
2. Call `upload_image` with `imagePaths` = `http://localhost:8765/<name>.png` (a batch of eight went through in one
   call) and the Studio's `studio_id` (list_roblox_studios). It answers `{url: "rbxassetid://<id>"}` for each.
3. Put the ids in `Assets.images` (check `git diff --stat src/shared/Assets.luau` first: the user keeps hand edits
   there, see [[protect-user-assets-edits]]; edit only the picture lines, never stylua the whole file).

They upload as whoever is signed in to that Studio (Kenshi_89 on 2026-11-03) and work at once in an ImageLabel. It
works while the Studio is in Play mode and touches nothing in the place. Keep the ids in a scratch file as they come
back: an answer lost to a crash means uploading again.

**Why:** the Asset Manager route took the person's screen and their Studio for minutes, and its Copy Info menu did
not always copy. **How to apply:** draw, check the previews, upload, then commit the ids with the code that uses
them in one push.
