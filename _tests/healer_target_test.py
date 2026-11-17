"""Exercise the addon's healer target selection with a small WoW API stub."""

from pathlib import Path
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "LH_AuraBars.lua").read_text(encoding="utf-8")
start = source.index("local function IsHealingFriendlyTarget()")
end = source.index("local function RenderGroup(", start)
functions = source[start:end]
event_start = source.index("local events = CreateFrame(")
event_end = source.index("local elapsedSinceWidth", event_start)
events = source[event_start:event_end]
render_start = source.index("    local healing = IsHealingFriendlyTarget()", source.index("local function Render()"))
render_end = source.index("\nend\nlocal function Initialize()", render_start)
render_native = "local function RenderNativeTarget(targetDisplay)\n" + source[render_start:render_end] + "\nend\n"

setup = r'''
local secret = {}
local grouped, assigned, talent, specRole, friendly = true, "HEALER", nil, nil, true
IsSecret = function(value) return value == secret end
IsInGroup = function() return grouped end
UnitGroupRolesAssigned = function() return assigned end
GetActiveTalentGroup = function() return 1 end
GetTalentGroupRole = function() return talent end
GetSpecialization = function() return 1 end
GetSpecializationRole = function() return specRole end
UnitCanAssist = function() return friendly end
UnitExists = function() return true end
GetTime = function() return 1 end
targetGroup = {}
targetAuras, untimedTargetAuras, seenUntimedTargetAuras = {}, {}, {}
nativeTarget, nativeHealerTarget = {}, nil
local scanned = {}
BuildSnapshot = function(_, filter)
    scanned[#scanned + 1] = filter
    return {{name = filter, expires = 20, key = 1}}, false
end
'''

checks = r'''
local function check(name, condition)
    if not condition then error(name) end
    print("PASS " .. name)
end
check("assigned healer on friendly target", IsHealingFriendlyTarget())
assigned, talent = "DAMAGER", "HEALER"
check("healer talent overrides assigned damage", IsHealingFriendlyTarget())
talent, specRole = nil, "HEALER"
check("healer specialization overrides assigned damage", IsHealingFriendlyTarget())
friendly = secret
check("secret combat relationship keeps healer mode", IsHealingFriendlyTarget())
friendly = false
check("hostile target leaves healer mode", not IsHealingFriendlyTarget())
friendly, grouped = true, false
check("solo player leaves healer mode", not IsHealingFriendlyTarget())
grouped, assigned, specRole = true, "HEALER", nil
ScanTarget(true)
check("fallback scans own buffs", scanned[1] == "HELPFUL|PLAYER")
check("fallback scans dispellable debuffs", scanned[2] == "HARMFUL|RAID")
check("fallback renders both kinds", #targetAuras == 2 and targetAuras[2].kind == "debuff")
nativeHealerTarget = {}
scanned, targetAuras = {}, {}
ScanTarget(true)
check("native healer container owns aura display", #scanned == 0 and #targetAuras == 0)
nativeHealerTarget, friendly = nil, false
scanned = {}
ScanTarget(true)
check("normal target retains regular buff scan", #scanned == 1 and scanned[1] == "HELPFUL")
CreateFrame = function()
    local frame = {}
    frame.RegisterEvent = function() end
    frame.SetScript = function(self, name, handler) self[name] = handler end
    _G.eventFrame = frame
    return frame
end
initialized = true
Render = function() end
local function mockContainer()
    local container = {updates = 0}
    container.SetUnit = function(self, unit) self.unit = unit end
    container.UpdateAllAuras = function(self) self.updates = self.updates + 1 end
    container.ClearAllPoints = function() end
    container.SetPoint = function() end
    container.SetShown = function(self, shown) self.shown = shown end
    return container
end
nativeTarget = {container = mockContainer(), unit = "target"}
nativeHealerTarget = {container = mockContainer(), unit = "target"}
friendly = true
targetAuras = {{name = "old target", expires = 20}}
'''

event_checks = r'''
eventFrame.OnEvent(nil, "PLAYER_TARGET_CHANGED")
check("target switch clears old snapshot", #targetAuras == 0)
check("target switch refreshes normal native container", nativeTarget.container.updates == 1)
check("target switch refreshes healer native container", nativeHealerTarget.container.updates == 1)
'''

render_checks = r'''
HEIGHT, preview = 20, false
targetGroup.anchor, targetGroup.db = {}, {heightFactor = 1}
RenderNativeTarget({})
check("healer mode shows healer container", nativeHealerTarget.container.shown == true)
check("healer mode hides regular container", nativeTarget.container.shown == false)
friendly = false
RenderNativeTarget({})
check("hostile target shows regular container", nativeTarget.container.shown == true)
check("hostile target hides healer container", nativeHealerTarget.container.shown == false)
nativeHealerTarget, friendly = nil, true
RenderNativeTarget({})
check("healer fallback hides unfiltered debuffs", nativeTarget.container.shown == false)
'''

program = setup + functions + checks + events + event_checks + render_native + render_checks
with tempfile.TemporaryDirectory() as directory:
    script = Path(directory) / "healer_target_test.lua"
    script.write_text(program, encoding="utf-8")
    result = subprocess.run(
        ["npx.cmd", "--yes", "--package=fengari-node-cli", "fengari", str(script)],
        cwd=ROOT,
        capture_output=True,
        text=True,
    )
    print(result.stdout, end="")
    if result.returncode:
        print(result.stderr, end="")
        raise SystemExit(result.returncode)
