# Booth fx.play failed on first call from the command bar

Playing any booth entry from execute_luau (a command-bar require of DebugPanel) built a second, never-init()ed copy of
LightingController. FxBooth.applyLook called its scene(), whose apply() did TweenService:Create on a nil Atmosphere
("Instance is null"; Recipes.impact was never the cause), and sceneKey stayed set so every later call passed silently.
Fixed 2026-11-17: applyLook skips when LightingController.atmosphere() is nil. In the real client (init ran) nothing
changed. To test the booth by MCP, expect the booth's lighting look to be off.
