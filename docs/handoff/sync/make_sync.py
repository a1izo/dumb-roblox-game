"""Writes a one-shot Studio plugin (Plugins/DGPass.lua) that brings every script changed since the place's last sync
(e5b191a7, 2026-11-06) up to main, and creates the new ones. A script is only overwritten when the place holds a
version from the repo's history (by hash): anything else is someone's live work and is skipped. Shared.Assets (the
user's sound ids, never committed) is never touched."""
import json
import os
import subprocess
import sys

ROOT = r"C:\Users\negru\Documents\Lgame"
SINCE_COMMIT = "90a60109"
HISTORY_SINCE = "2026-10-20"
OUT = os.path.join(os.environ["LOCALAPPDATA"], "Roblox", "Plugins", "DGPass.lua")
REPORT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "jobs.json")

MOUNTS = [
    ("src/shared/", ["ReplicatedStorage", "Shared"]),
    ("src/server/", ["ServerScriptService", "Server"]),
    ("src/client/", ["StarterPlayer", "StarterPlayerScripts", "Client"]),
]
SINGLES = {
    "src/first/Cover.client.luau": (["ReplicatedFirst", "DGCover"], "LocalScript"),
    "src/character/Animate.client.luau": (["StarterPlayer", "StarterCharacterScripts", "Animate"], "LocalScript"),
}
NEVER = {"src/shared/Assets.luau"}


def git(*args, data=None):
    return subprocess.run(["git", *args], cwd=ROOT, capture_output=True, check=True, input=data).stdout


def h(b: bytes) -> str:
    a, s = 1, 0
    for c in b:
        a = (a + c) % 65521
        s = (s + a) % 65521
    return f"{len(b)}:{s * 65536 + a}"


def place_of(rel):
    """(instance path, class) Rojo gives a repo file, or None."""
    if rel in SINGLES:
        return SINGLES[rel]
    for prefix, base in MOUNTS:
        if rel.startswith(prefix):
            parts = rel[len(prefix):].split("/")
            name = parts[-1]
            for ext in (".luau", ".lua"):
                if name.endswith(ext):
                    name = name[: -len(ext)]
                    break
            else:
                return None
            cls = "ModuleScript"
            if name.endswith(".server"):
                cls, name = "Script", name[: -len(".server")]
            elif name.endswith(".client"):
                cls, name = "LocalScript", name[: -len(".client")]
            if name == "init":
                if len(parts) == 1:
                    return None
                return base + parts[:-1], cls
            return base + parts[:-1] + [name], cls
    return None


changed = [p for p in git("diff", "--name-only", SINCE_COMMIT, "HEAD", "--", "src").decode().split()
           if p not in NEVER]
# every version each changed file has had lately: blob ids from the log, read in one batch
blobs = {}
log = git("log", f"--since={HISTORY_SINCE}", "--format=", "--raw", "--no-abbrev", "--", *changed).decode()
for line in log.splitlines():
    if not line.startswith(":"):
        continue
    meta, path = line.split("\t", 1)
    fields = meta.split()
    for blob in (fields[2], fields[3]):
        if set(blob) != {"0"}:
            blobs.setdefault(path, set()).add(blob)
for path in changed:  # (and the version at the last sync)
    try:
        blobs.setdefault(path, set()).add(git("rev-parse", f"{SINCE_COMMIT}:{path}").decode().strip())
    except subprocess.CalledProcessError:
        pass
wanted = sorted({b for s in blobs.values() for b in s})
batch = git("cat-file", "--batch", data=("\n".join(wanted) + "\n").encode())
contents, i = {}, 0
while i < len(batch):
    nl = batch.index(b"\n", i)
    sha, _, size = batch[i:nl].decode().split()
    size = int(size)
    body = batch[nl + 1: nl + 1 + size]
    contents[sha] = body
    i = nl + 1 + size + 1

jobs = []
for path in changed:
    full = os.path.join(ROOT, path)
    if not os.path.exists(full):
        continue  # (deleted since: reported by the plugin as place-only, left alone)
    where = place_of(path)
    if not where:
        continue
    inst, cls = where
    new = open(full, "rb").read()
    if b"]=====]" in new:
        sys.exit("delimiter clash in " + path)
    olds = set()
    for blob in blobs.get(path, ()):
        body = contents.get(blob)
        if body is not None:
            olds.add(h(body))
            olds.add(h(body.replace(b"\r\n", b"\n")))
            olds.add(h(body.replace(b"\n", b"\r\n").replace(b"\r\r\n", b"\r\n")))
    olds.discard(h(new))
    jobs.append({"file": path, "path": inst, "class": cls, "new": h(new), "old": sorted(olds), "text": new})

deleted = [p for p in git("diff", "--name-only", "--diff-filter=D", SINCE_COMMIT, "HEAD", "--", "src").decode().split()]


def lua_str(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


entries = []
for j in jobs:
    entries.append(
        "\t{ path = { %s }, class = %s, new = %s, old = { %s }, text = [=====[\n%s]=====] },"
        % (", ".join(lua_str(p) for p in j["path"]), lua_str(j["class"]), lua_str(j["new"]),
           ", ".join(lua_str(o) for o in j["old"]), j["text"].decode("utf-8"))
    )
gone = ", ".join("{ %s }" % ", ".join(lua_str(p) for p in place_of(d)[0]) for d in deleted if place_of(d))

lua = """-- One-shot (DGPass, sync): brings the scripts changed since the place's last sync up to main and creates the new
-- ones; a script holding a version that is not in the repo's history is someone's live work and is left alone.
if game.GameId ~= 10767766818 then
\treturn
end
local RunService = game:GetService("RunService")
if RunService:IsRunning() then
\treturn
end
local ScriptEditorService = game:GetService("ScriptEditorService")

local function h(s)
\tlocal b = buffer.fromstring(s)
\tlocal a, t = 1, 0
\tfor i = 0, buffer.len(b) - 1 do
\t\ta = (a + buffer.readu8(b, i)) % 65521
\t\tt = (t + a) % 65521
\tend
\treturn buffer.len(b) .. ":" .. string.format("%d", t * 65536 + a)
end

local JOBS = {
""" + "\n".join(entries) + """
}
local GONE = { """ + gone + """ }

local function at(path, wait)
\tlocal inst = game:GetService(path[1])
\tfor i = 2, #path do
\t\tif not inst then
\t\t\treturn nil
\t\tend
\t\tinst = if wait then inst:WaitForChild(path[i], 90) else inst:FindFirstChild(path[i])
\tend
\treturn inst
end

task.spawn(function()
\ttask.wait(10)
\tfor _, root in ipairs({ { "ReplicatedStorage", "Shared" }, { "ServerScriptService", "Server" },
\t\t{ "StarterPlayer", "StarterPlayerScripts", "Client" } }) do
\t\tif not at(root, true) then
\t\t\tprint("[DGPASS] MISSING ROOT " .. table.concat(root, "."))
\t\tend
\tend
\tlocal counts = { updated = 0, already = 0, created = 0, skipped = 0, failed = 0 }
\tfor k, job in ipairs(JOBS) do
\t\tlocal name = table.concat(job.path, ".")
\t\tlocal ok, err = pcall(function()
\t\t\tlocal inst = at(job.path, false)
\t\t\tif not inst then
\t\t\t\tlocal parentPath = table.clone(job.path)
\t\t\t\tlocal leaf = table.remove(parentPath)
\t\t\t\tlocal parent = at(parentPath, false)
\t\t\t\tif not parent then
\t\t\t\t\tprint("[DGPASS] NOPARENT " .. name)
\t\t\t\t\tcounts.failed += 1
\t\t\t\t\treturn
\t\t\t\tend
\t\t\t\tlocal made = Instance.new(job.class)
\t\t\t\tmade.Name = leaf
\t\t\t\tmade.Parent = parent
\t\t\t\tScriptEditorService:UpdateSourceAsync(made, function()
\t\t\t\t\treturn job.text
\t\t\t\tend)
\t\t\t\tprint("[DGPASS] CREATED " .. name .. " " .. h(made.Source))
\t\t\t\tcounts.created += 1
\t\t\t\treturn
\t\t\tend
\t\t\tif inst.ClassName ~= job.class then
\t\t\t\tprint("[DGPASS] SKIP class " .. inst.ClassName .. " ~= " .. job.class .. " " .. name)
\t\t\t\tcounts.skipped += 1
\t\t\t\treturn
\t\t\tend
\t\t\tlocal cur = h(inst.Source)
\t\t\tif cur == job.new then
\t\t\t\tcounts.already += 1
\t\t\t\treturn
\t\t\tend
\t\t\tif table.find(job.old, cur) then
\t\t\t\tScriptEditorService:UpdateSourceAsync(inst, function()
\t\t\t\t\treturn job.text
\t\t\t\tend)
\t\t\t\tlocal now = h(inst.Source)
\t\t\t\tif now == job.new then
\t\t\t\t\tprint("[DGPASS] UPDATED " .. name)
\t\t\t\t\tcounts.updated += 1
\t\t\t\telse
\t\t\t\t\tprint("[DGPASS] FAILED " .. name .. " now " .. now .. " want " .. job.new)
\t\t\t\t\tcounts.failed += 1
\t\t\t\tend
\t\t\telse
\t\t\t\tprint("[DGPASS] SKIP live " .. name .. " " .. cur)
\t\t\t\tcounts.skipped += 1
\t\t\tend
\t\tend)
\t\tif not ok then
\t\t\tprint("[DGPASS] ERROR " .. name .. ": " .. tostring(err))
\t\t\tcounts.failed += 1
\t\tend
\t\tif k % 5 == 0 then
\t\t\ttask.wait()
\t\tend
\tend
\tfor _, path in ipairs(GONE) do
\t\tif at(path, false) then
\t\t\tprint("[DGPASS] PLACE-ONLY (deleted in the repo, left alone) " .. table.concat(path, "."))
\t\tend
\tend
\tprint(string.format("[DGPASS] totals updated %d, already %d, created %d, skipped %d, failed %d", counts.updated,
\t\tcounts.already, counts.created, counts.skipped, counts.failed))
\tprint("[DGPASS] sync done")
end)
"""
open(OUT, "w", encoding="utf-8", newline="\n").write(lua)
json.dump([{k: v for k, v in j.items() if k != "text"} for j in jobs] + [{"deleted": deleted}], open(REPORT, "w"),
          indent=1)
print(f"{len(jobs)} scripts, {len(deleted)} deleted files, plugin {len(lua) / 1e6:.2f} MB -> {OUT}")
