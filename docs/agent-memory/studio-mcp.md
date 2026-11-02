---
name: studio-mcp
description: "Roblox Studio's built-in MCP server is registered with Claude Code (user scope, 2026-11-02): what it gives, what to watch out for"
metadata:
  type: reference
---

Studio has a built-in MCP server (create.roblox.com/docs/studio/mcp). Registered 2026-11-02 at user scope as
`Roblox_Studio`: `cmd.exe /c %LOCALAPPDATA%\Roblox\mcp.bat` (stdio; the .bat is installed with Studio and points at
the current version's StudioMCP.exe). In Studio it must be switched on: Assistant > ... > Manage MCP Servers >
Enable Studio as MCP server (a green dot shows connected clients). A new session picks the tools up after a restart.

Tools: script_read / multi_edit / script_search / script_grep, search_game_tree / inspect_instance, execute_luau,
get_studio_state / start_stop_play / get_console_output / screen_capture, character_navigation and keyboard/mouse
input, list_roblox_studios (every call takes a studio_id; several Studios can be open at once).

**Why it matters:** it replaces the old ways of seeing the real place (screen control, or the temporary plugin in a
second Studio, see [[studio-no-screen]]): play-test, read the console and capture the screen without taking the
person's mouse. **How to apply:** the place is Team Create and shared with other people: edits through multi_edit or
execute_luau land in their live session, and Rojo-managed scripts are overwritten by the next sync, so change code in
the repo, not in Studio; use the MCP to look, play-test and capture (cutscene checks: the debug cues in
[[studio-cutscene-testing]]).
