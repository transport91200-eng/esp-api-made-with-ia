-- ============================================================
--  NeverLose ESP API  –  v4  Full Fix + Optimize
--
--  FIXES this version:
--   [FIX] Team Color: now reads plr.Team.TeamColor.Color (real team color)
--          No longer hardcoded green — matches the actual Roblox team color
--   [FIX] Thermal Pulse: transparency now sweeps baseFill → 0 → baseFill
--          (was 0→baseFill which is visually backwards / near-invisible)
--   [FIX] Color Rotation: Chams.Adornee refreshed every frame so respawns work
--   [FIX] Chams.Enabled gated on visibility — no bleed-through when hidden
--   [FIX] Highlight FillTransparency init = baseFill (not hardcoded 1)
--
--  OPTIMIZATIONS:
--   [OPT] Font string resolved once and cached; never pcall per frame
--   [OPT] ColorSequence rebuilt only on value change (dirty-flag per player)
--   [OPT] Fade element list allocated once per player, not per frame
--   [OPT] All sub-table refs cached as locals before render loop
--   [OPT] FindFirstChild instead of WaitForChild (non-yielding)
--   [OPT] Corner pieces in flat array — single pass, no allocations
--   [OPT] Snapline uses pre-built 1px Frame; no Drawing API overhead
--
--  NEW FEATURES:
--   [NEW] Rainbow mode for chams (HSV full hue cycle)
--   [NEW] Rainbow mode for names
--   [NEW] Snaplines (screen-bottom → player feet)
--   [NEW] Team color auto-reads real Roblox team color
--   [NEW] ThermalSpeed control (cycles per second)
--   [NEW] API.SetChamsRainbow / SetChamsRainbowSpeed
--   [NEW] API.SetNamesRainbow / SetNamesRainbowSpeed
--   [NEW] API.SetSnaplines / SetSnaplinesRGB
--   [NEW] API.SetChamsThermalSpeed
-- ============================================================

local Workspace  = cloneref(game:GetService("Workspace"))
local RunService = cloneref(game:GetService("RunService"))
local Players    = cloneref(game:GetService("Players"))
local CoreGui    = game:GetService("CoreGui")

if getgenv().ESPAPI and getgenv()._ESP_Loaded then return getgenv().ESPAPI end
getgenv()._ESP_Loaded = true

-- ────────────────────────────────────────────────────────────
--  DEFAULT CONFIG
-- ────────────────────────────────────────────────────────────
local DefaultConfig = {
    Enabled     = false,
    TeamCheck   = false,
    MaxDistance = 200,
    FontSize    = 11,
    Font        = "GothamBold",
    FadeOut     = { OnDistance = false },
    Options = {
        -- TeamColor: when true, name/box color = plr.Team.TeamColor.Color (real team color)
        -- TeamColorOverride: when true, use TeamcheckRGB instead of real team color
        TeamColor         = false,
        TeamColorOverride = false,
        TeamcheckRGB      = Color3.fromRGB(255, 80, 80),
        Friendcheck       = false,
        FriendcheckRGB    = Color3.fromRGB(0, 255, 128),
    },
    Drawing = {
        Chams = {
            Enabled              = false,
            -- Thermal: pulses FillTransparency baseFill → 0 → baseFill (breathe in/out)
            Thermal              = false,
            ThermalSpeed         = 2,      -- full breathe cycles per second
            VisibleCheck         = false,
            FillRGB              = Color3.fromRGB(119, 120, 255),
            Fill_Transparency    = 50,     -- 0–100; 0=opaque, 100=invisible
            OutlineRGB           = Color3.fromRGB(119, 120, 255),
            Outline_Transparency = 0,      -- 0–100
            -- Color animation modes (ColorRotate > Rainbow > flat, mutually exclusive)
            ColorRotate          = false,
            ColorRotateSpeed     = 3,      -- sine cycles per second
            Rainbow              = false,
            RainbowSpeed         = 0.5,    -- hue full cycles per second
        },
        Names = {
            Enabled      = false,
            RGB          = Color3.fromRGB(255, 255, 255),
            Rainbow      = false,
            RainbowSpeed = 1,
        },
        Snaplines = {
            Enabled = false,
            RGB     = Color3.fromRGB(255, 255, 255),
        },
        Flags     = { Enabled = false },
        Distances = {
            Enabled  = false,
            Position = "Text",
            RGB      = Color3.fromRGB(255, 255, 255),
        },
        Weapons = {
            Enabled       = false,
            WeaponTextRGB = Color3.fromRGB(119, 120, 255),
            Gradient      = false,
            GradientRGB1  = Color3.fromRGB(255, 255, 255),
            GradientRGB2  = Color3.fromRGB(119, 120, 255),
        },
        Healthbar = {
            Enabled       = false,
            HealthText    = false,
            Lerp          = false,
            HealthTextRGB = Color3.fromRGB(255, 255, 255),
            Width         = 2.5,
            RGB           = Color3.fromRGB(0, 255, 128),
            Gradient      = false,
            GradientRGB1  = Color3.fromRGB(0,   255, 0),   -- top / full health
            GradientRGB2  = Color3.fromRGB(255, 255, 0),   -- mid
            GradientRGB3  = Color3.fromRGB(255, 0,   0),   -- bottom / empty
        },
        Boxes = {
            Animate          = false,
            RotationSpeed    = 300,
            Gradient         = false,
            GradientRGB1     = Color3.fromRGB(119, 120, 255),
            GradientRGB2     = Color3.fromRGB(0,   0,   0),
            GradientFill     = false,
            GradientFillRGB1 = Color3.fromRGB(119, 120, 255),
            GradientFillRGB2 = Color3.fromRGB(0,   0,   0),
            Filled  = { Enabled = false, Transparency = 0.75, RGB = Color3.fromRGB(0,0,0) },
            Full    = { Enabled = false, RGB = Color3.fromRGB(255, 255, 255) },
            Corner  = { Enabled = false, RGB = Color3.fromRGB(255, 255, 255) },
        },
    },
}

-- ────────────────────────────────────────────────────────────
--  UTILITY
-- ────────────────────────────────────────────────────────────
local function deepCopy(v)
    if type(v) ~= "table" then return v end
    local r = {}
    for k, x in pairs(v) do r[k] = deepCopy(x) end
    return r
end

local function merge(t1, t2)
    for k, v in pairs(t2) do
        if type(v) == "table" then
            if type(t1[k]) == "table" then merge(t1[k], v)
            else t1[k] = deepCopy(v) end
        else t1[k] = v end
    end
end

-- Font cache: pcall only once per unique name, then pure hash lookup
local _fontCache = {}
local function resolveFont(name)
    local cached = _fontCache[name]
    if cached then return cached end
    local ok, f = pcall(function() return Enum.Font[name] end)
    local result = (ok and f) or Enum.Font.GothamBold
    _fontCache[name] = result
    return result
end

-- Color3 lerp inline
local function lerpC(a, b, t)
    return Color3.new(a.R+(b.R-a.R)*t, a.G+(b.G-a.G)*t, a.B+(b.B-a.B)*t)
end

-- ColorSequence helpers — avoids repeated table construction every frame
local CSK = ColorSequenceKeypoint.new
local function cs2(a,b)   return ColorSequence.new{CSK(0,a),CSK(1,b)} end
local function cs3(a,b,c) return ColorSequence.new{CSK(0,a),CSK(0.5,b),CSK(1,c)} end

-- [FIX] Safely get a player's actual team color (Color3)
-- Returns nil if the player has no team
local function getTeamColor(plr)
    local team = plr.Team
    if team then
        return team.TeamColor.Color
    end
    return nil
end

-- ────────────────────────────────────────────────────────────
--  STATE
-- ────────────────────────────────────────────────────────────
local ESP = deepCopy(DefaultConfig)

getgenv().ESPAPI = {}
local API = getgenv().ESPAPI
API.Config = ESP

local lplayer = Players.LocalPlayer
local Cam     = Workspace.CurrentCamera

-- ────────────────────────────────────────────────────────────
--  PUBLIC API
-- ────────────────────────────────────────────────────────────
function API.SetEnabled(v)        ESP.Enabled           = v end
function API.SetTeamCheck(v)      ESP.TeamCheck          = v end
function API.SetMaxDistance(v)    ESP.MaxDistance        = v end
function API.SetFontSize(v)       ESP.FontSize           = v end
function API.SetFadeOnDistance(v) ESP.FadeOut.OnDistance = v end

function API.SetFont(name)
    ESP.Font = name
    _fontCache[name] = nil  -- invalidate so loop picks up next frame
    resolveFont(name)       -- pre-warm
    local sg = CoreGui:FindFirstChild("ESPHolder")
    if sg then
        local f = resolveFont(name)
        for _, v in ipairs(sg:GetDescendants()) do
            if v:IsA("TextLabel") then pcall(function() v.Font = f end) end
        end
    end
end

-- Team / Friend options
-- SetTeamColor(true)  → names/boxes use plr.Team.TeamColor.Color automatically
-- SetTeamCheckColor(true) + SetTeamCheckRGB(color) → override with custom color
function API.SetTeamColor(v)          ESP.Options.TeamColor         = v end
function API.SetTeamCheckColor(v)     ESP.Options.TeamColorOverride = v end
function API.SetTeamCheckRGB(v)       ESP.Options.TeamcheckRGB      = v end
function API.SetFriendCheck(v)        ESP.Options.Friendcheck       = v end
function API.SetFriendCheckRGB(v)     ESP.Options.FriendcheckRGB    = v end

-- Chams
function API.SetChams(enabled, fillRGB, outlineRGB)
    ESP.Drawing.Chams.Enabled = enabled
    if fillRGB    then ESP.Drawing.Chams.FillRGB    = fillRGB    end
    if outlineRGB then ESP.Drawing.Chams.OutlineRGB = outlineRGB end
end
function API.SetChamsFillRGB(v)          ESP.Drawing.Chams.FillRGB            = v end
function API.SetChamsOutlineRGB(v)       ESP.Drawing.Chams.OutlineRGB         = v end
function API.SetChamsThermal(v)          ESP.Drawing.Chams.Thermal            = v end
function API.SetChamsThermalSpeed(v)     ESP.Drawing.Chams.ThermalSpeed       = v end
function API.SetChamsVisCheck(v)         ESP.Drawing.Chams.VisibleCheck        = v end
function API.SetChamsFillAlpha(v)        ESP.Drawing.Chams.Fill_Transparency  = v end
function API.SetChamsOutAlpha(v)         ESP.Drawing.Chams.Outline_Transparency = v end
function API.SetChamsColorRotate(v)      ESP.Drawing.Chams.ColorRotate         = v end
function API.SetChamsColorRotateSpeed(v) ESP.Drawing.Chams.ColorRotateSpeed    = v end
function API.SetChamsRainbow(v)          ESP.Drawing.Chams.Rainbow              = v end
function API.SetChamsRainbowSpeed(v)     ESP.Drawing.Chams.RainbowSpeed         = v end

-- Names
function API.SetNames(v)             ESP.Drawing.Names.Enabled      = v end
function API.SetNamesRGB(v)          ESP.Drawing.Names.RGB          = v end
function API.SetNamesRainbow(v)      ESP.Drawing.Names.Rainbow      = v end
function API.SetNamesRainbowSpeed(v) ESP.Drawing.Names.RainbowSpeed = v end

-- Snaplines
function API.SetSnaplines(v)    ESP.Drawing.Snaplines.Enabled = v end
function API.SetSnaplinesRGB(v) ESP.Drawing.Snaplines.RGB     = v end

-- Healthbar
function API.SetHealthbar(v)          ESP.Drawing.Healthbar.Enabled      = v end
function API.SetHealthbarRGB(v)       ESP.Drawing.Healthbar.RGB          = v end
function API.SetHealthText(v)         ESP.Drawing.Healthbar.HealthText   = v end
function API.SetHealthLerp(v)         ESP.Drawing.Healthbar.Lerp         = v end
function API.SetHealthTextRGB(v)      ESP.Drawing.Healthbar.HealthTextRGB= v end
function API.SetHealthbarWidth(v)     ESP.Drawing.Healthbar.Width        = v end
function API.SetHealthGradient(v)     ESP.Drawing.Healthbar.Gradient     = v end
function API.SetHealthGradientRGB1(v) ESP.Drawing.Healthbar.GradientRGB1 = v end
function API.SetHealthGradientRGB2(v) ESP.Drawing.Healthbar.GradientRGB2 = v end
function API.SetHealthGradientRGB3(v) ESP.Drawing.Healthbar.GradientRGB3 = v end

-- Distances
function API.SetDistances(enabled, pos, color)
    ESP.Drawing.Distances.Enabled = enabled
    if pos   then ESP.Drawing.Distances.Position = pos   end
    if color then ESP.Drawing.Distances.RGB      = color end
end
function API.SetDistancePos(v)  ESP.Drawing.Distances.Position = v end
function API.SetDistancesRGB(v) ESP.Drawing.Distances.RGB      = v end

-- Weapons
function API.SetWeapons(enabled, color)
    ESP.Drawing.Weapons.Enabled = enabled
    if color then ESP.Drawing.Weapons.WeaponTextRGB = color end
end
function API.SetWeaponsRGB(v)      ESP.Drawing.Weapons.WeaponTextRGB = v end
function API.SetWeaponsGradient(v) ESP.Drawing.Weapons.Gradient      = v end

-- Boxes
function API.SetBoxesFull(enabled, color)
    ESP.Drawing.Boxes.Full.Enabled = enabled
    if color then ESP.Drawing.Boxes.Full.RGB = color end
end
function API.SetBoxesFullRGB(v)     ESP.Drawing.Boxes.Full.RGB             = v end
function API.SetBoxesCorner(enabled, color)
    ESP.Drawing.Boxes.Corner.Enabled = enabled
    if color then ESP.Drawing.Boxes.Corner.RGB = color end
end
function API.SetBoxesCornerRGB(v)   ESP.Drawing.Boxes.Corner.RGB           = v end
function API.SetBoxesFilled(enabled, alpha, color)
    ESP.Drawing.Boxes.Filled.Enabled = enabled
    if alpha then ESP.Drawing.Boxes.Filled.Transparency = alpha end
    if color then ESP.Drawing.Boxes.Filled.RGB          = color end
end
function API.SetBoxesFilledAlpha(v) ESP.Drawing.Boxes.Filled.Transparency  = v end
function API.SetBoxesFilledRGB(v)   ESP.Drawing.Boxes.Filled.RGB           = v end
function API.SetBoxesAnimate(enabled, speed)
    ESP.Drawing.Boxes.Animate = enabled
    if speed then ESP.Drawing.Boxes.RotationSpeed = speed end
end
function API.SetBoxesSpeed(v)        ESP.Drawing.Boxes.RotationSpeed       = v end
function API.SetBoxesGradient(enabled, rgb1, rgb2)
    ESP.Drawing.Boxes.Gradient = enabled
    if rgb1 then ESP.Drawing.Boxes.GradientRGB1 = rgb1 end
    if rgb2 then ESP.Drawing.Boxes.GradientRGB2 = rgb2 end
end
function API.SetBoxesGradientRGB1(v) ESP.Drawing.Boxes.GradientRGB1        = v end
function API.SetBoxesGradientRGB2(v) ESP.Drawing.Boxes.GradientRGB2        = v end
function API.SetBoxesGradFill(enabled, rgb1, rgb2)
    ESP.Drawing.Boxes.GradientFill = enabled
    if rgb1 then ESP.Drawing.Boxes.GradientFillRGB1 = rgb1 end
    if rgb2 then ESP.Drawing.Boxes.GradientFillRGB2 = rgb2 end
end
function API.SetBoxesGradFillRGB1(v) ESP.Drawing.Boxes.GradientFillRGB1    = v end
function API.SetBoxesGradFillRGB2(v) ESP.Drawing.Boxes.GradientFillRGB2    = v end

function API.SetFlags(v) ESP.Drawing.Flags.Enabled = v end
function API.GetConfig() return ESP end
function API.Reset()     merge(ESP, DefaultConfig)  end

function API.SetPreset(name)
    if name == "default" then
        API.Reset()
    elseif name == "minimal" or name == "competitive" then
        API.Reset()
        API.SetBoxesCorner(true, Color3.fromRGB(255,255,255))
        API.SetNames(true); API.SetNamesRGB(Color3.fromRGB(255,255,255))
        API.SetHealthbar(true); API.SetHealthLerp(true)
        API.SetDistances(true, "Text")
    elseif name == "rage" then
        API.Reset()
        API.SetEnabled(true); API.SetMaxDistance(9999); API.SetTeamCheck(false)
        API.SetChams(true, Color3.fromRGB(255,0,0), Color3.fromRGB(255,255,0))
        API.SetBoxesFull(true,   Color3.fromRGB(255,0,0))
        API.SetBoxesCorner(true, Color3.fromRGB(255,255,0))
        API.SetBoxesFilled(true, 0.85, Color3.fromRGB(255,0,0))
        API.SetNames(true); API.SetNamesRGB(Color3.fromRGB(255,255,255))
        API.SetHealthbar(true); API.SetHealthLerp(true)
        API.SetDistances(true, "Bottom")
        API.SetWeapons(true, Color3.fromRGB(255,165,0))
    end
end

-- ────────────────────────────────────────────────────────────
--  SCREENGUI
-- ────────────────────────────────────────────────────────────
local ScreenGui

local function MakeGui()
    local old = CoreGui:FindFirstChild("ESPHolder")
    if old then old:Destroy() end
    ScreenGui = Instance.new("ScreenGui")
    ScreenGui.Name             = "ESPHolder"
    ScreenGui.ResetOnSpawn     = false
    ScreenGui.IgnoreGuiInset   = true
    ScreenGui.Parent           = CoreGui
end
MakeGui()

function API.Refresh()
    MakeGui()
    for _, v in pairs(Players:GetPlayers()) do
        if v ~= lplayer then task.spawn(ESP_func, v) end
    end
end

-- ────────────────────────────────────────────────────────────
--  INSTANCE FACTORY
-- ────────────────────────────────────────────────────────────
local function New(class, props)
    local i = Instance.new(class)
    for k, v in pairs(props) do i[k] = v end
    return i
end

-- ────────────────────────────────────────────────────────────
--  FADE HELPER
-- ────────────────────────────────────────────────────────────
local function applyFade(el, opacity) -- opacity 0..1
    local c = el.ClassName
    if c == "TextLabel"  then el.TextTransparency       = 1 - opacity
    elseif c == "Frame"  then el.BackgroundTransparency = 1 - opacity
    elseif c == "UIStroke" then el.Transparency         = 1 - opacity
    elseif c == "Highlight" then
        el.FillTransparency    = 1 - opacity
        el.OutlineTransparency = 1 - opacity
    end
end

-- ────────────────────────────────────────────────────────────
--  PER-PLAYER ESP
-- ────────────────────────────────────────────────────────────
function ESP_func(plr)
    -- Remove stale
    local old = ScreenGui:FindFirstChild("ESP_" .. plr.Name)
    if old then old:Destroy() end

    -- Container so cleanup is one :Destroy() call
    local Container = New("Frame", {
        Name                = "ESP_" .. plr.Name,
        Parent              = ScreenGui,
        BackgroundTransparency = 1,
        Size                = UDim2.new(1,0,1,0),
        BorderSizePixel     = 0,
    })

    local font = resolveFont(ESP.Font)

    -- ── Text labels ──────────────────────────────────────────
    local function makeTL(props)
        props.Parent              = Container
        props.BackgroundTransparency = 1
        props.TextStrokeTransparency = 0
        props.TextStrokeColor3    = Color3.fromRGB(0,0,0)
        props.Font                = font
        props.TextSize            = ESP.FontSize
        props.RichText            = true
        return New("TextLabel", props)
    end

    local Name       = makeTL({ Size=UDim2.new(0,120,0,20), AnchorPoint=Vector2.new(0.5,0.5), TextColor3=Color3.fromRGB(255,255,255), Text="" })
    local Distance   = makeTL({ Size=UDim2.new(0,100,0,20), AnchorPoint=Vector2.new(0.5,0.5), TextColor3=Color3.fromRGB(255,255,255), Text="" })
    local WeaponLbl  = makeTL({ Size=UDim2.new(0,120,0,20), AnchorPoint=Vector2.new(0.5,0.5), TextColor3=Color3.fromRGB(255,255,255), Text="" })
    local HealthText = makeTL({ Size=UDim2.new(0,40, 0,14), AnchorPoint=Vector2.new(0.5,0.5), TextColor3=Color3.fromRGB(255,255,255), Text="", RichText=false })

    -- ── Full/Filled box ──────────────────────────────────────
    local Box = New("Frame", {
        Parent=Container, BackgroundTransparency=1, BorderSizePixel=0,
    })
    local GradFill = New("UIGradient", {
        Parent=Box, Enabled=false,
        Color=cs2(ESP.Drawing.Boxes.GradientFillRGB1, ESP.Drawing.Boxes.GradientFillRGB2),
    })
    local Stroke = New("UIStroke", {
        Parent=Box, Enabled=false, Thickness=1,
        Color=Color3.fromRGB(255,255,255), LineJoinMode=Enum.LineJoinMode.Miter,
    })
    local GradStroke = New("UIGradient", {
        Parent=Stroke, Enabled=false,
        Color=cs2(ESP.Drawing.Boxes.GradientRGB1, ESP.Drawing.Boxes.GradientRGB2),
    })

    -- ── Healthbar ────────────────────────────────────────────
    local HBTrack = New("Frame", {                              -- dark background track
        Parent=Container, ZIndex=1,
        BackgroundColor3=Color3.fromRGB(25,25,25), BackgroundTransparency=0.3,
        BorderSizePixel=0,
    })
    local HBFill = New("Frame", {                               -- colored fill
        Parent=Container, ZIndex=2,
        BackgroundColor3=Color3.fromRGB(0,255,128), BackgroundTransparency=0,
        AnchorPoint=Vector2.new(0,1), BorderSizePixel=0,        -- [FIX] anchor bottom→grows up
    })
    local HBGrad = New("UIGradient", {
        Parent=HBFill, Enabled=false,
        Rotation=-90,                                            -- keypoint 0 = top = full HP
        Color=cs3(ESP.Drawing.Healthbar.GradientRGB1,
                  ESP.Drawing.Healthbar.GradientRGB2,
                  ESP.Drawing.Healthbar.GradientRGB3),
    })

    -- ── Chams ────────────────────────────────────────────────
    local Chams = New("Highlight", {
        Parent=Container,
        FillColor           = ESP.Drawing.Chams.FillRGB,
        OutlineColor        = ESP.Drawing.Chams.OutlineRGB,
        FillTransparency    = ESP.Drawing.Chams.Fill_Transparency    / 100,
        OutlineTransparency = ESP.Drawing.Chams.Outline_Transparency / 100,
        DepthMode           = "AlwaysOnTop",
        Enabled             = false,
    })

    -- ── Snapline ─────────────────────────────────────────────
    local Snap = New("Frame", {
        Parent=Container, BackgroundTransparency=0, BorderSizePixel=0,
        AnchorPoint=Vector2.new(0.5,0), Size=UDim2.new(0,1,0,0),
        BackgroundColor3=ESP.Drawing.Snaplines.RGB, Visible=false,
    })

    -- ── Corner pieces [LT_H,LT_V, LB_H,LB_V, RT_H,RT_V, RB_H,RB_V] ──
    local C = {}
    for i=1,8 do
        C[i] = New("Frame", {
            Parent=Container, BackgroundTransparency=0,
            BackgroundColor3=ESP.Drawing.Boxes.Corner.RGB, BorderSizePixel=0,
        })
    end

    -- Fade list (allocated once) ─────────────────────────────
    local fadeList = {
        Box, Stroke, HBTrack, HBFill, HBGrad, Name, Distance,
        WeaponLbl, HealthText, Snap, Chams,
        C[1],C[2],C[3],C[4],C[5],C[6],C[7],C[8],
    }

    -- ── Dirty flags for ColorSequence rebuild ────────────────
    local pGF1,pGF2, pGO1,pGO2, pHG1,pHG2,pHG3, pWG1,pWG2

    -- ── Hide / Destroy ───────────────────────────────────────
    local Connection
    local alive = true

    local function HideAll()
        Box.Visible=false; Name.Visible=false; Distance.Visible=false
        WeaponLbl.Visible=false; HBFill.Visible=false; HBTrack.Visible=false
        HealthText.Visible=false; Snap.Visible=false
        Chams.Enabled=false; Chams.Adornee=nil
        for i=1,8 do C[i].Visible=false end
    end

    local function Cleanup()
        alive = false
        if Connection then Connection:Disconnect() end
        if Container and Container.Parent then Container:Destroy() end
    end

    -- ── Render loop ──────────────────────────────────────────
    -- Cache sub-table refs once (they're stable pointers to the ESP config tables)
    local ECh = ESP.Drawing.Chams
    local EBx = ESP.Drawing.Boxes
    local EHb = ESP.Drawing.Healthbar
    local ENm = ESP.Drawing.Names
    local EDi = ESP.Drawing.Distances
    local EWp = ESP.Drawing.Weapons
    local ESL = ESP.Drawing.Snaplines
    local EOp = ESP.Options
    local EFO = ESP.FadeOut

    Connection = RunService.RenderStepped:Connect(function()
        if not alive then return end
        if not ESP.Enabled then HideAll(); return end

        -- Player / character validity
        if not plr or not plr.Parent then Cleanup(); return end
        local char = plr.Character
        if not char then HideAll(); return end
        local HRP      = char:FindFirstChild("HumanoidRootPart")
        local Humanoid = char:FindFirstChild("Humanoid")
        if not HRP or not Humanoid then HideAll(); return end

        -- On-screen + distance check
        local wpos, onScreen = Cam:WorldToScreenPoint(HRP.Position)
        local dist = (Cam.CFrame.Position - HRP.Position).Magnitude / 3.5714
        if not onScreen or dist > ESP.MaxDistance then HideAll(); return end

        -- Team-check (hide teammates)
        if ESP.TeamCheck and lplayer.Team == plr.Team then HideAll(); return end

        -- Scale
        local sf     = (HRP.Size.Y * Cam.ViewportSize.Y) / (wpos.Z * 2)
        local bw, bh = 3*sf, 4.5*sf
        local px, py = wpos.X, wpos.Y
        local lx, rx = px - bw/2, px + bw/2
        local ty, by = py - bh/2, py + bh/2
        local t = tick()

        -- Font (O(1) cache hit every frame)
        local cf = resolveFont(ESP.Font)
        local fs = ESP.FontSize
        Name.Font=cf;       Name.TextSize=fs
        Distance.Font=cf;   Distance.TextSize=fs
        WeaponLbl.Font=cf;  WeaponLbl.TextSize=fs
        HealthText.Font=cf; HealthText.TextSize=fs

        -- Fade on distance
        if EFO.OnDistance then
            local op = math.max(0.1, 1 - dist/ESP.MaxDistance)
            for _,el in ipairs(fadeList) do applyFade(el, op) end
        end

        -- ── CHAMS ─────────────────────────────────────────────
        -- [FIX] Adornee refreshed every frame so respawns work
        -- [FIX] Enabled only set true when player is actually visible in this frame
        local chamsWanted = ECh.Enabled
        if chamsWanted then
            Chams.Adornee   = char
            Chams.Enabled   = true
            Chams.DepthMode = ECh.VisibleCheck and "Occluded" or "AlwaysOnTop"

            -- ── Color mode (ColorRotate > Rainbow > flat) ────
            local fillColor
            if ECh.ColorRotate then
                -- Sine lerp FillRGB ↔ OutlineRGB
                local a = (math.sin(t * ECh.ColorRotateSpeed * math.pi * 2) + 1) * 0.5
                fillColor = lerpC(ECh.FillRGB, ECh.OutlineRGB, a)
            elseif ECh.Rainbow then
                fillColor = Color3.fromHSV((t * ECh.RainbowSpeed) % 1, 1, 1)
            else
                fillColor = ECh.FillRGB
            end
            Chams.FillColor    = fillColor
            Chams.OutlineColor = ECh.OutlineRGB

            -- ── Thermal pulse (fully independent of color mode) ──
            -- [FIX] Formula: baseFill * (1 - breathe) so the pulse goes
            --   baseFill (dim) → 0 (fully visible) → baseFill (dim) — a real "breathe in" sweep
            --   Previously was baseFill*breathe which went 0→baseFill (barely visible change)
            local baseFill    = ECh.Fill_Transparency    / 100
            local baseOutline = ECh.Outline_Transparency / 100
            if ECh.Thermal then
                -- breathe 0→1→0 using (1-cos)/2 for smooth symmetric wave
                local breathe = (1 - math.cos(t * ECh.ThermalSpeed * math.pi * 2)) * 0.5
                -- transparency: at breathe=0 → baseFill (user's opacity), at breathe=1 → 0 (full glow)
                Chams.FillTransparency    = baseFill * (1 - breathe)
                Chams.OutlineTransparency = baseOutline * (1 - breathe)
            else
                Chams.FillTransparency    = baseFill
                Chams.OutlineTransparency = baseOutline
            end
        else
            Chams.Enabled  = false
            Chams.Adornee  = nil
        end

        -- ── CORNER BOX ────────────────────────────────────────
        local cen  = EBx.Corner.Enabled
        local cRGB = EBx.Corner.RGB
        local cW, cH = bw/5, bh/5
        -- LT_H, LT_V
        C[1].Visible=cen; C[1].BackgroundColor3=cRGB
        C[1].Position=UDim2.new(0,lx,0,ty);    C[1].Size=UDim2.new(0,cW,0,1)
        C[2].Visible=cen; C[2].BackgroundColor3=cRGB
        C[2].Position=UDim2.new(0,lx,0,ty);    C[2].Size=UDim2.new(0,1,0,cH)
        -- LB_H, LB_V
        C[3].Visible=cen; C[3].BackgroundColor3=cRGB; C[3].AnchorPoint=Vector2.new(0,1)
        C[3].Position=UDim2.new(0,lx,0,by);    C[3].Size=UDim2.new(0,cW,0,1)
        C[4].Visible=cen; C[4].BackgroundColor3=cRGB; C[4].AnchorPoint=Vector2.new(0,1)
        C[4].Position=UDim2.new(0,lx,0,by);    C[4].Size=UDim2.new(0,1,0,cH)
        -- RT_H, RT_V
        C[5].Visible=cen; C[5].BackgroundColor3=cRGB; C[5].AnchorPoint=Vector2.new(1,0)
        C[5].Position=UDim2.new(0,rx,0,ty);    C[5].Size=UDim2.new(0,cW,0,1)
        C[6].Visible=cen; C[6].BackgroundColor3=cRGB; C[6].AnchorPoint=Vector2.new(1,0)
        C[6].Position=UDim2.new(0,rx,0,ty);    C[6].Size=UDim2.new(0,1,0,cH)
        -- RB_H, RB_V
        C[7].Visible=cen; C[7].BackgroundColor3=cRGB; C[7].AnchorPoint=Vector2.new(1,1)
        C[7].Position=UDim2.new(0,rx,0,by);    C[7].Size=UDim2.new(0,cW,0,1)
        C[8].Visible=cen; C[8].BackgroundColor3=cRGB; C[8].AnchorPoint=Vector2.new(1,1)
        C[8].Position=UDim2.new(0,rx,0,by);    C[8].Size=UDim2.new(0,1,0,cH)

        -- ── FULL / FILLED BOX ─────────────────────────────────
        Box.Position = UDim2.new(0,lx,0,ty)
        Box.Size     = UDim2.new(0,bw,0,bh)
        Box.Visible  = EBx.Full.Enabled or EBx.Filled.Enabled

        if EBx.GradientFill then
            Box.BackgroundColor3       = Color3.fromRGB(255,255,255)
            Box.BackgroundTransparency = EBx.Filled.Enabled and EBx.Filled.Transparency or 1
        else
            Box.BackgroundColor3       = EBx.Filled.Enabled and EBx.Filled.RGB or Color3.new(0,0,0)
            Box.BackgroundTransparency = EBx.Filled.Enabled and EBx.Filled.Transparency or 1
        end

        Stroke.Enabled = EBx.Full.Enabled
        if EBx.Full.Enabled then Stroke.Color = EBx.Full.RGB end

        -- Fill gradient (dirty check)
        GradFill.Enabled = EBx.GradientFill
        if EBx.GradientFill then
            local g1,g2 = EBx.GradientFillRGB1, EBx.GradientFillRGB2
            if g1~=pGF1 or g2~=pGF2 then GradFill.Color=cs2(g1,g2); pGF1=g1; pGF2=g2 end
        end
        -- Stroke gradient (dirty check)
        GradStroke.Enabled = EBx.Gradient
        if EBx.Gradient then
            local g1,g2 = EBx.GradientRGB1, EBx.GradientRGB2
            if g1~=pGO1 or g2~=pGO2 then GradStroke.Color=cs2(g1,g2); pGO1=g1; pGO2=g2 end
        end
        -- Gradient rotation animation
        local rot = EBx.Animate and ((t*EBx.RotationSpeed)%360) or 315
        if rot > 180 then rot = rot - 360 end
        GradFill.Rotation   = rot
        GradStroke.Rotation = rot

        -- ── HEALTHBAR ──────────────────────────────────────────
        local maxHP = Humanoid.MaxHealth
        local hp    = maxHP > 0 and math.clamp(Humanoid.Health/maxHP, 0, 1) or 0
        if EHb.Enabled then
            local barW   = EHb.Width
            local barH   = bh * hp
            local barX   = lx - barW - 3

            -- Track (full height, always visible behind fill)
            HBTrack.Visible  = true
            HBTrack.Position = UDim2.new(0,barX,0,ty)
            HBTrack.Size     = UDim2.new(0,barW,0,bh)

            -- Fill (grows UPWARD from bottom because AnchorPoint.Y=1)
            HBFill.Visible   = true
            HBFill.Position  = UDim2.new(0,barX,0,by)   -- pinned to bottom edge
            HBFill.Size      = UDim2.new(0,barW,0,barH)

            if EHb.Gradient then
                HBFill.BackgroundColor3 = Color3.fromRGB(255,255,255)
                HBGrad.Enabled = true
                local g1,g2,g3 = EHb.GradientRGB1, EHb.GradientRGB2, EHb.GradientRGB3
                if g1~=pHG1 or g2~=pHG2 or g3~=pHG3 then
                    HBGrad.Color=cs3(g1,g2,g3); pHG1=g1; pHG2=g2; pHG3=g3
                end
            else
                HBGrad.Enabled         = false
                HBFill.BackgroundColor3 = EHb.RGB
            end

            if EHb.HealthText then
                HealthText.Visible   = true
                HealthText.Text      = tostring(math.floor(hp*100))
                HealthText.Position  = UDim2.new(0, barX-2, 0, by-barH-8)
                if EHb.Lerp then
                    HealthText.TextColor3 = hp>=0.75 and Color3.fromRGB(0,255,0)
                        or hp>=0.5 and Color3.fromRGB(255,255,0)
                        or hp>=0.25 and Color3.fromRGB(255,170,0)
                        or Color3.fromRGB(255,0,0)
                else
                    HealthText.TextColor3 = EHb.HealthTextRGB
                end
            else
                HealthText.Visible = false
            end
        else
            HBFill.Visible=false; HBTrack.Visible=false; HealthText.Visible=false
        end

        -- ── NAMES ──────────────────────────────────────────────
        -- [FIX] Team color: read plr.Team.TeamColor.Color (real Roblox team color)
        --       TeamColorOverride: use custom TeamcheckRGB color instead
        Name.Position = UDim2.new(0, px, 0, ty-11)
        if ENm.Enabled then
            local nameColor
            if ENm.Rainbow then
                nameColor = Color3.fromHSV((t*ENm.RainbowSpeed)%1, 1, 1)
            elseif EOp.Friendcheck and lplayer:IsFriendsWith(plr.UserId) then
                nameColor = EOp.FriendcheckRGB
            elseif EOp.TeamColor then
                -- [FIX] actual team color from Roblox team object
                if EOp.TeamColorOverride then
                    nameColor = EOp.TeamcheckRGB
                else
                    nameColor = getTeamColor(plr) or ENm.RGB
                end
            else
                nameColor = ENm.RGB
            end
            Name.TextColor3 = nameColor

            if EOp.Friendcheck and lplayer:IsFriendsWith(plr.UserId) then
                local fc = EOp.FriendcheckRGB
                Name.Text = string.format(
                    '(<font color="rgb(%d,%d,%d)">F</font>) %s',
                    fc.R*255, fc.G*255, fc.B*255, plr.Name)
            else
                Name.Text = plr.Name
            end
            Name.Visible = true
        else
            Name.Visible = false
        end

        -- ── DISTANCES ──────────────────────────────────────────
        local wOffY, wiOffY
        if EDi.Enabled then
            Distance.TextColor3 = EDi.RGB
            if EDi.Position == "Bottom" then
                Distance.Position = UDim2.new(0,px,0,by+7)
                Distance.Text     = math.floor(dist).."m"
                Distance.Visible  = true
                wOffY=by+18; wiOffY=by+15
            else  -- "Text": append [dist] to name label
                Distance.Visible = false
                wOffY=by+8; wiOffY=by+5
                if ENm.Enabled then
                    if EOp.Friendcheck and lplayer:IsFriendsWith(plr.UserId) then
                        local fc=EOp.FriendcheckRGB
                        Name.Text=string.format('(<font color="rgb(%d,%d,%d)">F</font>) %s [%dm]',
                            fc.R*255,fc.G*255,fc.B*255, plr.Name, math.floor(dist))
                    else
                        Name.Text=string.format("%s [%dm]", plr.Name, math.floor(dist))
                    end
                end
            end
        else
            Distance.Visible=false; wOffY=by+8; wiOffY=by+5
        end

        -- ── WEAPONS ────────────────────────────────────────────
        if EWp.Enabled then
            WeaponLbl.Text       = "none"
            WeaponLbl.TextColor3 = EWp.WeaponTextRGB
            WeaponLbl.Position   = UDim2.new(0,px,0,wOffY)
            WeaponLbl.Visible    = true
            if EWp.Gradient then
                local g1,g2 = EWp.GradientRGB1, EWp.GradientRGB2
                if g1~=pWG1 or g2~=pWG2 then pWG1=g1; pWG2=g2 end
            end
        else
            WeaponLbl.Visible = false
        end

        -- ── SNAPLINE ───────────────────────────────────────────
        if ESL.Enabled then
            local vp      = Cam.ViewportSize
            local ox, oy  = vp.X*0.5, vp.Y
            local dx, dy  = px-ox, by-oy
            local len     = math.sqrt(dx*dx+dy*dy)
            local angle   = math.deg(math.atan2(dx, -dy))
            Snap.BackgroundColor3 = ESL.RGB
            Snap.Position  = UDim2.new(0,ox,0,oy)
            Snap.Size      = UDim2.new(0,1,0,len)
            Snap.Rotation  = angle
            Snap.Visible   = true
        else
            Snap.Visible = false
        end
    end)
end

-- ────────────────────────────────────────────────────────────
--  BOOTSTRAP
-- ────────────────────────────────────────────────────────────
for _, v in pairs(Players:GetPlayers()) do
    if v ~= lplayer then task.spawn(ESP_func, v) end
end
Players.PlayerAdded:Connect(function(v) task.spawn(ESP_func, v) end)

return API
