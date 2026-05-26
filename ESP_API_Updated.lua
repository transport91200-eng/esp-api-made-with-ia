local Workspace, RunService, Players, CoreGui, Lighting = cloneref(game:GetService("Workspace")), cloneref(game:GetService("RunService")), cloneref(game:GetService("Players")), game:GetService("CoreGui"), cloneref(game:GetService("Lighting"))

if getgenv().ESPAPI and getgenv()._ESP_Loaded then return getgenv().ESPAPI end
getgenv()._ESP_Loaded = true

-- ============================================================
--  DEFAULT CONFIG
--  New fields vs original:
--   Drawing.Chams  → ColorRotate, ColorRotateSpeed
--   Drawing.Names  → Font (string)
--   Drawing.Healthbar → GradientRGB1/2/3 already existed, Gradient already existed
--   Drawing.Boxes  → GradientRGB1/2 + GradientFillRGB1/2 already existed
-- ============================================================
local DefaultConfig = {
    Enabled = false,
    TeamCheck = false,
    MaxDistance = 200,
    FontSize = 11,
    Font = "GothamBold",                        -- [NEW] global font name string
    FadeOut = { OnDistance = false, OnDeath = false, OnLeave = false },
    Options = {
        Teamcheck = false, TeamcheckRGB = Color3.fromRGB(0, 255, 0),
        Friendcheck = false, FriendcheckRGB = Color3.fromRGB(0, 255, 0),
        Highlight = false, HighlightRGB = Color3.fromRGB(255, 0, 0),
    },
    Drawing = {
        Chams = {
            Enabled = false, Thermal = false, VisibleCheck = false,
            FillRGB = Color3.fromRGB(119, 120, 255), Fill_Transparency = 50,
            OutlineRGB = Color3.fromRGB(119, 120, 255), Outline_Transparency = 0,
            ColorRotate = false,                -- [NEW] animate fill color between FillRGB ↔ OutlineRGB
            ColorRotateSpeed = 3,               -- [NEW] speed multiplier (1–10)
        },
        Names = { Enabled = false, RGB = Color3.fromRGB(255, 255, 255) },
        Flags = { Enabled = false },
        Distances = { Enabled = false, Position = "Text", RGB = Color3.fromRGB(255, 255, 255) },
        Weapons = {
            Enabled = false, WeaponTextRGB = Color3.fromRGB(119, 120, 255),
            Outlined = false, Gradient = false,
            GradientRGB1 = Color3.fromRGB(255, 255, 255), GradientRGB2 = Color3.fromRGB(119, 120, 255),
        },
        Healthbar = {
            Enabled = false, HealthText = false, Lerp = false,
            HealthTextRGB = Color3.fromRGB(255, 255, 255),
            Width = 2.5, RGB = Color3.fromRGB(0, 255, 128),
            -- Gradient: GradientRGB1 = top of bar (full health side)
            --           GradientRGB3 = bottom of bar (low health side)
            Gradient = false,
            GradientRGB1 = Color3.fromRGB(0, 255, 0),
            GradientRGB2 = Color3.fromRGB(255, 255, 0),
            GradientRGB3 = Color3.fromRGB(255, 0, 0),
        },
        Boxes = {
            Animate = false, RotationSpeed = 300,
            Gradient = false,
            GradientRGB1 = Color3.fromRGB(119, 120, 255), GradientRGB2 = Color3.fromRGB(0, 0, 0),
            GradientFill = false,
            GradientFillRGB1 = Color3.fromRGB(119, 120, 255), GradientFillRGB2 = Color3.fromRGB(0, 0, 0),
            Filled = { Enabled = false, Transparency = 0.75, RGB = Color3.fromRGB(0, 0, 0) },
            Full   = { Enabled = false, RGB = Color3.fromRGB(255, 255, 255) },
            Corner = { Enabled = false, RGB = Color3.fromRGB(255, 255, 255) },
        },
    },
}

local function deepCopy(v)
    if type(v) ~= "table" then return v end
    local r = {} for i, x in pairs(v) do r[i] = deepCopy(x) end return r
end
local ESP = deepCopy(DefaultConfig)
ESP.Connections = { RunService = RunService }
ESP.Fonts = {}

getgenv().ESPAPI = {}
local API = getgenv().ESPAPI
API.Config = ESP

local function merge(t1, t2)
    for k, v in pairs(t2) do
        if type(v) == "table" then
            if type(t1[k]) == "table" then merge(t1[k], v) else t1[k] = deepCopy(v) end
        else t1[k] = v end
    end
end

-- ============================================================
--  GLOBAL API
-- ============================================================
function API.SetEnabled(v)       ESP.Enabled = v end
function API.SetTeamCheck(v)     ESP.TeamCheck = v end
function API.SetMaxDistance(v)   ESP.MaxDistance = v end
function API.SetFontSize(v)      ESP.FontSize = v end
function API.SetFadeOnDistance(v) ESP.FadeOut.OnDistance = v end
function API.SetFadeOnDeath(v)   ESP.FadeOut.OnDeath = v end
function API.SetFadeOnLeave(v)   ESP.FadeOut.OnLeave = v end

-- [NEW] Font setter — pass an Enum.Font name string e.g. "GothamBold", "Arcade"
function API.SetFont(fontName)
    ESP.Font = fontName
    -- Also apply live to any already-spawned TextLabels
    local sg = CoreGui:FindFirstChild("ESPHolder")
    if sg then
        local ok, font = pcall(function() return Enum.Font[fontName] end)
        if ok and font then
            for _, v in ipairs(sg:GetDescendants()) do
                if v:IsA("TextLabel") then pcall(function() v.Font = font end) end
            end
        end
    end
end

-- ============================================================
--  OPTIONS (Team / Friend)
-- ============================================================
function API.SetTeamCheckColor(v)  ESP.Options.Teamcheck = v end
function API.SetTeamCheckRGB(v)    ESP.Options.TeamcheckRGB = v end
function API.SetFriendCheck(v)     ESP.Options.Friendcheck = v end
function API.SetFriendCheckRGB(v)  ESP.Options.FriendcheckRGB = v end

-- ============================================================
--  CHAMS
-- ============================================================
function API.SetChams(enabled, fillRGB, outlineRGB)
    ESP.Drawing.Chams.Enabled = enabled
    if fillRGB    then ESP.Drawing.Chams.FillRGB    = fillRGB    end
    if outlineRGB then ESP.Drawing.Chams.OutlineRGB = outlineRGB end
end
function API.SetChamsFillRGB(v)     ESP.Drawing.Chams.FillRGB    = v end
function API.SetChamsOutlineRGB(v)  ESP.Drawing.Chams.OutlineRGB  = v end
function API.SetChamsThermal(v)     ESP.Drawing.Chams.Thermal      = v end
function API.SetChamsVisCheck(v)    ESP.Drawing.Chams.VisibleCheck  = v end
function API.SetChamsFillAlpha(v)   ESP.Drawing.Chams.Fill_Transparency = v end
function API.SetChamsOutAlpha(v)    ESP.Drawing.Chams.Outline_Transparency = v end
-- [NEW] Color rotation animation
function API.SetChamsColorRotate(v)      ESP.Drawing.Chams.ColorRotate      = v end
function API.SetChamsColorRotateSpeed(v) ESP.Drawing.Chams.ColorRotateSpeed = v end

-- ============================================================
--  NAMES
-- ============================================================
function API.SetNames(enabled)
    -- [FIX] No longer accepts color here to avoid accidentally resetting RGB
    ESP.Drawing.Names.Enabled = enabled
end
function API.SetNamesRGB(v) ESP.Drawing.Names.RGB = v end   -- [FIX] dedicated setter

-- ============================================================
--  HEALTHBAR
-- ============================================================
function API.SetHealthbar(enabled)
    -- [FIX] No longer accepts color here — use SetHealthbarRGB instead
    ESP.Drawing.Healthbar.Enabled = enabled
end
function API.SetHealthbarRGB(v)      ESP.Drawing.Healthbar.RGB = v end
function API.SetHealthText(v)        ESP.Drawing.Healthbar.HealthText = v end
function API.SetHealthLerp(v)        ESP.Drawing.Healthbar.Lerp = v end
function API.SetHealthTextRGB(v)     ESP.Drawing.Healthbar.HealthTextRGB = v end
function API.SetHealthbarWidth(v)    ESP.Drawing.Healthbar.Width = v end
-- [NEW] Gradient toggle + per-stop color setters
function API.SetHealthGradient(v)    ESP.Drawing.Healthbar.Gradient = v end
function API.SetHealthGradientRGB1(v) ESP.Drawing.Healthbar.GradientRGB1 = v end  -- high HP color
function API.SetHealthGradientRGB2(v) ESP.Drawing.Healthbar.GradientRGB2 = v end  -- mid HP color
function API.SetHealthGradientRGB3(v) ESP.Drawing.Healthbar.GradientRGB3 = v end  -- low HP color

-- ============================================================
--  DISTANCES
-- ============================================================
function API.SetDistances(enabled, pos, color)
    ESP.Drawing.Distances.Enabled = enabled
    if pos   then ESP.Drawing.Distances.Position = pos   end
    if color then ESP.Drawing.Distances.RGB      = color end
end
function API.SetDistancePos(v)   ESP.Drawing.Distances.Position = v end
function API.SetDistancesRGB(v)  ESP.Drawing.Distances.RGB      = v end

-- ============================================================
--  WEAPONS
-- ============================================================
function API.SetWeapons(enabled, color)
    ESP.Drawing.Weapons.Enabled = enabled
    if color then ESP.Drawing.Weapons.WeaponTextRGB = color end
end
function API.SetWeaponsRGB(v)      ESP.Drawing.Weapons.WeaponTextRGB = v end
function API.SetWeaponsGradient(v) ESP.Drawing.Weapons.Gradient = v end

-- ============================================================
--  BOXES
-- ============================================================
function API.SetBoxesFull(enabled, color)
    ESP.Drawing.Boxes.Full.Enabled = enabled
    if color then ESP.Drawing.Boxes.Full.RGB = color end
end
function API.SetBoxesFullRGB(v)    ESP.Drawing.Boxes.Full.RGB    = v end

function API.SetBoxesCorner(enabled, color)
    ESP.Drawing.Boxes.Corner.Enabled = enabled
    if color then ESP.Drawing.Boxes.Corner.RGB = color end
end
function API.SetBoxesCornerRGB(v)  ESP.Drawing.Boxes.Corner.RGB  = v end

function API.SetBoxesFilled(enabled, alpha, color)
    ESP.Drawing.Boxes.Filled.Enabled = enabled
    if alpha then ESP.Drawing.Boxes.Filled.Transparency = alpha end
    if color then ESP.Drawing.Boxes.Filled.RGB          = color end
end
function API.SetBoxesFilledAlpha(v) ESP.Drawing.Boxes.Filled.Transparency = v end
function API.SetBoxesFilledRGB(v)   ESP.Drawing.Boxes.Filled.RGB          = v end

function API.SetBoxesAnimate(enabled, speed)
    ESP.Drawing.Boxes.Animate = enabled
    if speed then ESP.Drawing.Boxes.RotationSpeed = speed end
end
function API.SetBoxesSpeed(v) ESP.Drawing.Boxes.RotationSpeed = v end

-- Outline gradient (UIStroke > UIGradient)
function API.SetBoxesGradient(enabled, rgb1, rgb2)
    ESP.Drawing.Boxes.Gradient = enabled
    if rgb1 then ESP.Drawing.Boxes.GradientRGB1 = rgb1 end
    if rgb2 then ESP.Drawing.Boxes.GradientRGB2 = rgb2 end
end
function API.SetBoxesGradientRGB1(v) ESP.Drawing.Boxes.GradientRGB1 = v end
function API.SetBoxesGradientRGB2(v) ESP.Drawing.Boxes.GradientRGB2 = v end

-- Fill gradient (Box Frame > UIGradient)
function API.SetBoxesGradFill(enabled, rgb1, rgb2)
    ESP.Drawing.Boxes.GradientFill = enabled
    if rgb1 then ESP.Drawing.Boxes.GradientFillRGB1 = rgb1 end
    if rgb2 then ESP.Drawing.Boxes.GradientFillRGB2 = rgb2 end
end
function API.SetBoxesGradFillRGB1(v) ESP.Drawing.Boxes.GradientFillRGB1 = v end
function API.SetBoxesGradFillRGB2(v) ESP.Drawing.Boxes.GradientFillRGB2 = v end

function API.SetFlags(v) ESP.Drawing.Flags.Enabled = v end
function API.GetConfig() return ESP end

-- ============================================================
--  RESET / PRESETS
-- ============================================================
function API.Reset() merge(ESP, DefaultConfig) end

function API.SetPreset(name)
    if name == "default" then
        API.Reset()
    elseif name == "minimal" or name == "competitive" then
        API.Reset()
        API.SetBoxesFull(false)
        API.SetBoxesCorner(true, Color3.fromRGB(255, 255, 255))
        API.SetBoxesFilled(false)
        API.SetNames(true) API.SetNamesRGB(Color3.fromRGB(255, 255, 255))
        API.SetHealthbar(true)
        API.SetHealthLerp(true)
        API.SetDistances(true, "Text")
        API.SetWeapons(false)
        API.SetChams(false)
    elseif name == "rage" then
        API.Reset()
        API.SetEnabled(true)
        API.SetMaxDistance(9999)
        API.SetTeamCheck(false)
        API.SetChams(true, Color3.fromRGB(255, 0, 0), Color3.fromRGB(255, 255, 0))
        API.SetChamsThermal(false)
        API.SetChamsVisCheck(false)
        API.SetBoxesFull(true, Color3.fromRGB(255, 0, 0))
        API.SetBoxesCorner(true, Color3.fromRGB(255, 255, 0))
        API.SetBoxesFilled(true, 0.85, Color3.fromRGB(255, 0, 0))
        API.SetNames(true) API.SetNamesRGB(Color3.fromRGB(255, 255, 255))
        API.SetHealthbar(true)
        API.SetHealthLerp(true)
        API.SetDistances(true, "Bottom")
        API.SetWeapons(true, Color3.fromRGB(255, 165, 0))
    end
end

-- ============================================================
--  INTERNAL HELPERS
-- ============================================================
local Euphoria = ESP.Connections
local lplayer  = Players.LocalPlayer
local Cam      = Workspace.CurrentCamera

local Functions = {}
do
    function Functions:Create(Class, Properties)
        local inst = typeof(Class) == "string" and Instance.new(Class) or Class
        for k, v in pairs(Properties) do inst[k] = v end
        return inst
    end

    function Functions:FadeOutOnDist(element, distance)
        local t = math.max(0.1, 1 - (distance / ESP.MaxDistance))
        if element:IsA("TextLabel")  then element.TextTransparency       = 1 - t
        elseif element:IsA("ImageLabel") then element.ImageTransparency  = 1 - t
        elseif element:IsA("UIStroke")   then element.Transparency       = 1 - t
        elseif element:IsA("Frame")      then element.BackgroundTransparency = 1 - t
        elseif element:IsA("Highlight")  then
            element.FillTransparency    = 1 - t
            element.OutlineTransparency = 1 - t
        end
    end

    -- [NEW] Resolve font: returns Enum.Font from a string name, falls back to GothamBold
    function Functions:ResolveFont(name)
        local ok, f = pcall(function() return Enum.Font[name] end)
        return (ok and f) or Enum.Font.GothamBold
    end

    -- [NEW] Lerp two Color3 values by alpha (0→1)
    function Functions:LerpColor(c1, c2, alpha)
        return Color3.new(
            c1.R + (c2.R - c1.R) * alpha,
            c1.G + (c2.G - c1.G) * alpha,
            c1.B + (c2.B - c1.B) * alpha
        )
    end
end

-- ============================================================
--  SCREENGUI
-- ============================================================
local ScreenGui
function API.Refresh()
    if CoreGui:FindFirstChild("ESPHolder") then
        CoreGui:FindFirstChild("ESPHolder"):Destroy()
    end
    ScreenGui = Functions:Create("ScreenGui", { Parent = CoreGui, Name = "ESPHolder" })
    for _, v in pairs(Players:GetPlayers()) do
        if v ~= lplayer then coroutine.wrap(ESP_func)(v) end
    end
end

ScreenGui = CoreGui:FindFirstChild("ESPHolder")
    or Functions:Create("ScreenGui", { Parent = CoreGui, Name = "ESPHolder" })

local DupeCheck = function(plr)
    if ScreenGui:FindFirstChild(plr.Name) then
        ScreenGui[plr.Name]:Destroy()
    end
end

-- ============================================================
--  PER-PLAYER ESP FUNCTION
-- ============================================================
function ESP_func(plr)
    coroutine.wrap(DupeCheck)(plr)

    local font = Functions:ResolveFont(ESP.Font)

    -- Text labels
    local Name = Functions:Create("TextLabel", {
        Name = plr.Name, Parent = ScreenGui,
        Position = UDim2.new(0.5, 0, 0, -11), Size = UDim2.new(0, 100, 0, 20),
        AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(255, 255, 255), Font = font,
        TextSize = ESP.FontSize, TextStrokeTransparency = 0,
        TextStrokeColor3 = Color3.fromRGB(0, 0, 0), RichText = true
    })
    local Distance = Functions:Create("TextLabel", {
        Parent = ScreenGui,
        Position = UDim2.new(0.5, 0, 0, 11), Size = UDim2.new(0, 100, 0, 20),
        AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(255, 255, 255), Font = font,
        TextSize = ESP.FontSize, TextStrokeTransparency = 0,
        TextStrokeColor3 = Color3.fromRGB(0, 0, 0), RichText = true
    })
    local Weapon = Functions:Create("TextLabel", {
        Parent = ScreenGui,
        Position = UDim2.new(0.5, 0, 0, 31), Size = UDim2.new(0, 100, 0, 20),
        AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(255, 255, 255), Font = font,
        TextSize = ESP.FontSize, TextStrokeTransparency = 0,
        TextStrokeColor3 = Color3.fromRGB(0, 0, 0), RichText = true
    })
    local HealthText = Functions:Create("TextLabel", {
        Parent = ScreenGui,
        Position = UDim2.new(0.5, 0, 0, 31), Size = UDim2.new(0, 100, 0, 20),
        AnchorPoint = Vector2.new(0.5, 0.5), BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(255, 255, 255), Font = font,
        TextSize = ESP.FontSize, TextStrokeTransparency = 0,
        TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
    })

    -- Box
    local Box = Functions:Create("Frame", {
        Parent = ScreenGui,
        BackgroundColor3 = Color3.fromRGB(0, 0, 0), BackgroundTransparency = 0.75,
        BorderSizePixel = 0
    })
    local Gradient1 = Functions:Create("UIGradient", {
        Parent = Box, Enabled = ESP.Drawing.Boxes.GradientFill,
        Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, ESP.Drawing.Boxes.GradientFillRGB1),
            ColorSequenceKeypoint.new(1, ESP.Drawing.Boxes.GradientFillRGB2)
        }
    })
    local Outline = Functions:Create("UIStroke", {
        Parent = Box, Enabled = true, Transparency = 0,
        Color = Color3.fromRGB(255, 255, 255), LineJoinMode = Enum.LineJoinMode.Miter
    })
    local Gradient2 = Functions:Create("UIGradient", {
        Parent = Outline, Enabled = ESP.Drawing.Boxes.Gradient,
        Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, ESP.Drawing.Boxes.GradientRGB1),
            ColorSequenceKeypoint.new(1, ESP.Drawing.Boxes.GradientRGB2)
        }
    })

    -- Healthbar
    -- [FIX] Bar is anchored at the BOTTOM of the player bounding box.
    --       Size grows upward as health increases (AnchorPoint.Y = 1).
    local BehindHealthbar = Functions:Create("Frame", {
        Parent = ScreenGui, ZIndex = 1,
        BackgroundColor3 = Color3.fromRGB(30, 30, 30), BackgroundTransparency = 0
    })
    local Healthbar = Functions:Create("Frame", {
        Parent = ScreenGui, ZIndex = 2,
        BackgroundColor3 = Color3.fromRGB(0, 255, 128), BackgroundTransparency = 0,
        AnchorPoint = Vector2.new(0, 1)   -- [FIX] anchor bottom so bar grows upward
    })
    -- [FIX] Gradient rotation = 90 so GradientRGB1 is at top (high HP side)
    --       and GradientRGB3 is at bottom (low HP side) — matches visual expectation
    local HealthbarGradient = Functions:Create("UIGradient", {
        Parent = Healthbar, Enabled = ESP.Drawing.Healthbar.Gradient,
        Rotation = -90,    -- [FIX] -90 = top of bar is keypoint 0 (GradientRGB1 = high HP)
        Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0,   ESP.Drawing.Healthbar.GradientRGB1),
            ColorSequenceKeypoint.new(0.5, ESP.Drawing.Healthbar.GradientRGB2),
            ColorSequenceKeypoint.new(1,   ESP.Drawing.Healthbar.GradientRGB3)
        }
    })

    -- Chams (Highlight)
    local Chams = Functions:Create("Highlight", {
        Parent = ScreenGui, FillTransparency = 1, OutlineTransparency = 0,
        OutlineColor = Color3.fromRGB(119, 120, 255), DepthMode = "AlwaysOnTop"
    })

    -- Weapon icon
    local WeaponIcon = Functions:Create("ImageLabel", {
        Parent = ScreenGui, BackgroundTransparency = 1,
        BorderColor3 = Color3.fromRGB(0, 0, 0), BorderSizePixel = 0,
        Size = UDim2.new(0, 40, 0, 40)
    })
    local Gradient3 = Functions:Create("UIGradient", {
        Parent = WeaponIcon, Rotation = -90,
        Enabled = ESP.Drawing.Weapons.Gradient,
        Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, ESP.Drawing.Weapons.GradientRGB1),
            ColorSequenceKeypoint.new(1, ESP.Drawing.Weapons.GradientRGB2)
        }
    })

    -- Corner box pieces
    local LeftTop        = Functions:Create("Frame", {Parent = ScreenGui, BackgroundColor3 = ESP.Drawing.Boxes.Corner.RGB, Position = UDim2.new(0,0,0,0)})
    local LeftSide       = Functions:Create("Frame", {Parent = ScreenGui, BackgroundColor3 = ESP.Drawing.Boxes.Corner.RGB, Position = UDim2.new(0,0,0,0)})
    local RightTop       = Functions:Create("Frame", {Parent = ScreenGui, BackgroundColor3 = ESP.Drawing.Boxes.Corner.RGB, Position = UDim2.new(0,0,0,0)})
    local RightSide      = Functions:Create("Frame", {Parent = ScreenGui, BackgroundColor3 = ESP.Drawing.Boxes.Corner.RGB, Position = UDim2.new(0,0,0,0)})
    local BottomSide     = Functions:Create("Frame", {Parent = ScreenGui, BackgroundColor3 = ESP.Drawing.Boxes.Corner.RGB, Position = UDim2.new(0,0,0,0)})
    local BottomDown     = Functions:Create("Frame", {Parent = ScreenGui, BackgroundColor3 = ESP.Drawing.Boxes.Corner.RGB, Position = UDim2.new(0,0,0,0)})
    local BottomRightSide = Functions:Create("Frame",{Parent = ScreenGui, BackgroundColor3 = ESP.Drawing.Boxes.Corner.RGB, Position = UDim2.new(0,0,0,0)})
    local BottomRightDown = Functions:Create("Frame",{Parent = ScreenGui, BackgroundColor3 = ESP.Drawing.Boxes.Corner.RGB, Position = UDim2.new(0,0,0,0)})

    -- ============================================================
    --  UPDATER (runs every RenderStepped)
    -- ============================================================
    local Updater = function()
        local Connection
        local function HideESP()
            Box.Visible = false; Name.Visible = false; Distance.Visible = false
            Weapon.Visible = false; Healthbar.Visible = false; BehindHealthbar.Visible = false
            HealthText.Visible = false; WeaponIcon.Visible = false
            LeftTop.Visible = false; LeftSide.Visible = false
            BottomSide.Visible = false; BottomDown.Visible = false
            RightTop.Visible = false; RightSide.Visible = false
            BottomRightSide.Visible = false; BottomRightDown.Visible = false
            Chams.Enabled = false
            if not plr or not plr.Parent then
                Name:Destroy(); Distance:Destroy(); Weapon:Destroy(); Box:Destroy()
                Healthbar:Destroy(); BehindHealthbar:Destroy(); HealthText:Destroy()
                WeaponIcon:Destroy()
                LeftTop:Destroy(); LeftSide:Destroy(); BottomSide:Destroy(); BottomDown:Destroy()
                RightTop:Destroy(); RightSide:Destroy()
                BottomRightSide:Destroy(); BottomRightDown:Destroy()
                Chams:Destroy()
                if Connection then Connection:Disconnect() end
            end
        end

        Connection = Euphoria.RunService.RenderStepped:Connect(function()
            if not ESP.Enabled then HideESP(); return end
            if not plr.Character or not plr.Character:FindFirstChild("HumanoidRootPart") then
                HideESP(); return
            end

            local HRP      = plr.Character.HumanoidRootPart
            local Humanoid = plr.Character:WaitForChild("Humanoid")
            local Pos, OnScreen = Cam:WorldToScreenPoint(HRP.Position)
            local Dist = (Cam.CFrame.Position - HRP.Position).Magnitude / 3.5714285714

            if OnScreen and Dist <= ESP.MaxDistance then
                local Size = HRP.Size.Y
                local scaleFactor = (Size * Cam.ViewportSize.Y) / (Pos.Z * 2)
                local w, h = 3 * scaleFactor, 4.5 * scaleFactor

                if ESP.FadeOut.OnDistance then
                    for _, el in pairs({Box, Outline, Name, Distance, Weapon,
                        Healthbar, BehindHealthbar, HealthText, WeaponIcon,
                        LeftTop, LeftSide, BottomSide, BottomDown,
                        RightTop, RightSide, BottomRightSide, BottomRightDown, Chams}) do
                        Functions:FadeOutOnDist(el, Dist)
                    end
                end

                local passTeam = (ESP.TeamCheck and plr ~= lplayer and
                    ((lplayer.Team ~= plr.Team and plr.Team) or
                     (not lplayer.Team and not plr.Team)))
                    or (not ESP.TeamCheck and plr ~= lplayer)

                if passTeam then
                    -- ── Font (live update) ──────────────────────────────
                    local currentFont = Functions:ResolveFont(ESP.Font)
                    Name.Font       = currentFont
                    Distance.Font   = currentFont
                    Weapon.Font     = currentFont
                    HealthText.Font = currentFont

                    Name.TextSize       = ESP.FontSize
                    Distance.TextSize   = ESP.FontSize
                    Weapon.TextSize     = ESP.FontSize
                    HealthText.TextSize = ESP.FontSize

                    -- ── CHAMS ────────────────────────────────────────────
                    Chams.Adornee = plr.Character
                    Chams.Enabled = ESP.Drawing.Chams.Enabled

                    -- [NEW] Color rotation animation: lerp FillRGB ↔ OutlineRGB via sine wave
                    if ESP.Drawing.Chams.Enabled and ESP.Drawing.Chams.ColorRotate then
                        local alpha = (math.sin(tick() * ESP.Drawing.Chams.ColorRotateSpeed) + 1) / 2
                        Chams.FillColor = Functions:LerpColor(
                            ESP.Drawing.Chams.FillRGB,
                            ESP.Drawing.Chams.OutlineRGB,
                            alpha
                        )
                    else
                        Chams.FillColor = ESP.Drawing.Chams.FillRGB
                    end
                    Chams.OutlineColor = ESP.Drawing.Chams.OutlineRGB

                    if ESP.Drawing.Chams.Thermal then
                        local breathe = math.atan(math.sin(tick() * 2)) * 2 / math.pi
                        Chams.FillTransparency    = (ESP.Drawing.Chams.Fill_Transparency / 100)    * breathe * 0.01 + (ESP.Drawing.Chams.Fill_Transparency / 100)
                        Chams.OutlineTransparency = (ESP.Drawing.Chams.Outline_Transparency / 100) * breathe * 0.01 + (ESP.Drawing.Chams.Outline_Transparency / 100)
                    else
                        Chams.FillTransparency    = ESP.Drawing.Chams.Fill_Transparency    / 100
                        Chams.OutlineTransparency = ESP.Drawing.Chams.Outline_Transparency / 100
                    end
                    Chams.DepthMode = ESP.Drawing.Chams.VisibleCheck and "Occluded" or "AlwaysOnTop"

                    -- ── CORNER BOXES ─────────────────────────────────────
                    for _, c in pairs({LeftTop, LeftSide, BottomSide, BottomDown, RightTop, RightSide, BottomRightSide, BottomRightDown}) do
                        c.BackgroundColor3 = ESP.Drawing.Boxes.Corner.RGB
                        c.Visible          = ESP.Drawing.Boxes.Corner.Enabled
                    end
                    LeftTop.Position         = UDim2.new(0, Pos.X - w/2,     0, Pos.Y - h/2)
                    LeftTop.Size             = UDim2.new(0, w/5, 0, 1)
                    LeftSide.Position        = UDim2.new(0, Pos.X - w/2,     0, Pos.Y - h/2)
                    LeftSide.Size            = UDim2.new(0, 1,   0, h/5)
                    BottomSide.Position      = UDim2.new(0, Pos.X - w/2,     0, Pos.Y + h/2)
                    BottomSide.Size          = UDim2.new(0, 1,   0, h/5)
                    BottomSide.AnchorPoint   = Vector2.new(0, 5)
                    BottomDown.Position      = UDim2.new(0, Pos.X - w/2,     0, Pos.Y + h/2)
                    BottomDown.Size          = UDim2.new(0, w/5, 0, 1)
                    BottomDown.AnchorPoint   = Vector2.new(0, 1)
                    RightTop.Position        = UDim2.new(0, Pos.X + w/2,     0, Pos.Y - h/2)
                    RightTop.Size            = UDim2.new(0, w/5, 0, 1)
                    RightTop.AnchorPoint     = Vector2.new(1, 0)
                    RightSide.Position       = UDim2.new(0, Pos.X + w/2 - 1, 0, Pos.Y - h/2)
                    RightSide.Size           = UDim2.new(0, 1,   0, h/5)
                    RightSide.AnchorPoint    = Vector2.new(0, 0)
                    BottomRightSide.Position = UDim2.new(0, Pos.X + w/2,     0, Pos.Y + h/2)
                    BottomRightSide.Size     = UDim2.new(0, 1,   0, h/5)
                    BottomRightSide.AnchorPoint = Vector2.new(1, 1)
                    BottomRightDown.Position = UDim2.new(0, Pos.X + w/2,     0, Pos.Y + h/2)
                    BottomRightDown.Size     = UDim2.new(0, w/5, 0, 1)
                    BottomRightDown.AnchorPoint = Vector2.new(1, 1)

                    -- ── FULL / FILLED BOX ────────────────────────────────
                    Box.Position = UDim2.new(0, Pos.X - w/2, 0, Pos.Y - h/2)
                    Box.Size     = UDim2.new(0, w, 0, h)
                    Box.Visible  = ESP.Drawing.Boxes.Full.Enabled or ESP.Drawing.Boxes.Filled.Enabled

                    if ESP.Drawing.Boxes.GradientFill then
                        Box.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                    else
                        Box.BackgroundColor3 = ESP.Drawing.Boxes.Filled.Enabled
                            and ESP.Drawing.Boxes.Filled.RGB or Color3.fromRGB(0, 0, 0)
                    end
                    Box.BackgroundTransparency = ESP.Drawing.Boxes.Filled.Enabled
                        and ESP.Drawing.Boxes.Filled.Transparency or 1
                    Box.BorderSizePixel = ESP.Drawing.Boxes.Filled.Enabled and 1 or 0

                    -- Outline stroke (Full Box)
                    Outline.Enabled = ESP.Drawing.Boxes.Full.Enabled
                    Outline.Color   = ESP.Drawing.Boxes.Full.RGB

                    -- Fill gradient
                    Gradient1.Enabled = ESP.Drawing.Boxes.GradientFill
                    if ESP.Drawing.Boxes.GradientFill then
                        Gradient1.Color = ColorSequence.new{
                            ColorSequenceKeypoint.new(0, ESP.Drawing.Boxes.GradientFillRGB1),
                            ColorSequenceKeypoint.new(1, ESP.Drawing.Boxes.GradientFillRGB2)
                        }
                    end

                    -- Outline gradient
                    Gradient2.Enabled = ESP.Drawing.Boxes.Gradient
                    if ESP.Drawing.Boxes.Gradient then
                        Gradient2.Color = ColorSequence.new{
                            ColorSequenceKeypoint.new(0, ESP.Drawing.Boxes.GradientRGB1),
                            ColorSequenceKeypoint.new(1, ESP.Drawing.Boxes.GradientRGB2)
                        }
                    end

                    -- Rotation animation for gradients
                    local rawRot = ESP.Drawing.Boxes.Animate
                        and ((tick() * ESP.Drawing.Boxes.RotationSpeed) % 360) or 315
                    if rawRot > 180 then rawRot = rawRot - 360 end
                    Gradient1.Rotation = rawRot
                    Gradient2.Rotation = rawRot

                    -- ── HEALTHBAR ────────────────────────────────────────
                    -- [FIX] Bar bottom is pinned to bottom of player bbox.
                    --       As health rises, the bar grows UPWARD (AnchorPoint.Y=1).
                    local health = math.clamp(Humanoid.Health / Humanoid.MaxHealth, 0, 1)
                    if ESP.Drawing.Healthbar.Enabled then
                        local barH   = h * health
                        local barX   = Pos.X - w/2 - 6
                        local barBot = Pos.Y + h/2   -- bottom edge of player box

                        -- Background (full height, dark grey)
                        BehindHealthbar.Visible  = true
                        BehindHealthbar.Position = UDim2.new(0, barX, 0, barBot - h)
                        BehindHealthbar.Size     = UDim2.new(0, ESP.Drawing.Healthbar.Width, 0, h)

                        -- Foreground bar (grows upward from bottom)
                        Healthbar.Visible   = true
                        Healthbar.Position  = UDim2.new(0, barX, 0, barBot)   -- pinned to bottom
                        Healthbar.Size      = UDim2.new(0, ESP.Drawing.Healthbar.Width, 0, barH)
                        -- AnchorPoint.Y = 1 means the frame extends upward from Position

                        if ESP.Drawing.Healthbar.Gradient then
                            Healthbar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
                            HealthbarGradient.Enabled  = true
                            -- [FIX] Gradient rotation -90: keypoint 0 = top of bar = high HP color
                            HealthbarGradient.Rotation = -90
                            HealthbarGradient.Color = ColorSequence.new{
                                ColorSequenceKeypoint.new(0,   ESP.Drawing.Healthbar.GradientRGB1),
                                ColorSequenceKeypoint.new(0.5, ESP.Drawing.Healthbar.GradientRGB2),
                                ColorSequenceKeypoint.new(1,   ESP.Drawing.Healthbar.GradientRGB3)
                            }
                        else
                            HealthbarGradient.Enabled    = false
                            Healthbar.BackgroundColor3   = ESP.Drawing.Healthbar.RGB
                        end

                        if ESP.Drawing.Healthbar.HealthText then
                            local hp = math.floor(health * 100)
                            -- Text sits just above the top of the health bar
                            HealthText.Position = UDim2.new(0, barX - 6, 0, barBot - barH - 2)
                            HealthText.Text     = tostring(hp)
                            HealthText.Visible  = Humanoid.Health < Humanoid.MaxHealth
                            HealthText.TextColor3 = ESP.Drawing.Healthbar.Lerp
                                and (health >= 0.75 and Color3.fromRGB(0,255,0)
                                    or health >= 0.5 and Color3.fromRGB(255,255,0)
                                    or health >= 0.25 and Color3.fromRGB(255,170,0)
                                    or Color3.fromRGB(255,0,0))
                                or ESP.Drawing.Healthbar.HealthTextRGB
                        else
                            HealthText.Visible = false
                        end
                    else
                        Healthbar.Visible        = false
                        BehindHealthbar.Visible  = false
                        HealthText.Visible       = false
                    end

                    -- ── NAMES ────────────────────────────────────────────
                    -- [FIX] Name color now always reads from ESP.Drawing.Names.RGB
                    --       Team/Friend overrides only change color, not RGB config.
                    Name.Position = UDim2.new(0, Pos.X, 0, Pos.Y - h/2 - 9)
                    if ESP.Drawing.Names.Enabled then
                        if ESP.Options.Friendcheck and lplayer:IsFriendsWith(plr.UserId) then
                            Name.TextColor3 = ESP.Options.FriendcheckRGB
                            Name.Text = string.format(
                                '(<font color="rgb(%d,%d,%d)">F</font>) %s',
                                ESP.Options.FriendcheckRGB.R * 255,
                                ESP.Options.FriendcheckRGB.G * 255,
                                ESP.Options.FriendcheckRGB.B * 255,
                                plr.Name
                            )
                        elseif ESP.Options.Teamcheck then
                            Name.TextColor3 = ESP.Options.TeamcheckRGB
                            Name.Text       = plr.Name
                        else
                            Name.TextColor3 = ESP.Drawing.Names.RGB   -- [FIX] was being ignored
                            Name.Text       = plr.Name
                        end
                        Name.Visible = true
                    else
                        Name.Visible = false
                    end

                    -- ── DISTANCES ────────────────────────────────────────
                    if ESP.Drawing.Distances.Enabled then
                        Distance.TextColor3 = ESP.Drawing.Distances.RGB
                        if ESP.Drawing.Distances.Position == "Bottom" then
                            Weapon.Position   = UDim2.new(0, Pos.X, 0, Pos.Y + h/2 + 18)
                            WeaponIcon.Position = UDim2.new(0, Pos.X - 21, 0, Pos.Y + h/2 + 15)
                            Distance.Position = UDim2.new(0, Pos.X, 0, Pos.Y + h/2 + 7)
                            Distance.Text     = string.format("%d meters", math.floor(Dist))
                            Distance.Visible  = true
                            if ESP.Drawing.Names.Enabled then
                                if ESP.Options.Friendcheck and lplayer:IsFriendsWith(plr.UserId) then
                                    Name.Text = string.format(
                                        '(<font color="rgb(%d,%d,%d)">F</font>) %s',
                                        ESP.Options.FriendcheckRGB.R*255,
                                        ESP.Options.FriendcheckRGB.G*255,
                                        ESP.Options.FriendcheckRGB.B*255,
                                        plr.Name
                                    )
                                else
                                    Name.Text = plr.Name
                                end
                            end
                        elseif ESP.Drawing.Distances.Position == "Text" then
                            Weapon.Position   = UDim2.new(0, Pos.X, 0, Pos.Y + h/2 + 8)
                            WeaponIcon.Position = UDim2.new(0, Pos.X - 21, 0, Pos.Y + h/2 + 5)
                            Distance.Visible  = false
                            if ESP.Drawing.Names.Enabled then
                                if ESP.Options.Friendcheck and lplayer:IsFriendsWith(plr.UserId) then
                                    Name.Text = string.format(
                                        '(<font color="rgb(%d,%d,%d)">F</font>) %s [%d]',
                                        ESP.Options.FriendcheckRGB.R*255,
                                        ESP.Options.FriendcheckRGB.G*255,
                                        ESP.Options.FriendcheckRGB.B*255,
                                        plr.Name, math.floor(Dist)
                                    )
                                elseif ESP.Options.Teamcheck then
                                    Name.Text = string.format('%s [%d]', plr.Name, math.floor(Dist))
                                else
                                    Name.Text = string.format('%s [%d]', plr.Name, math.floor(Dist))
                                end
                            end
                        end
                    else
                        Distance.Visible    = false
                        Weapon.Position     = UDim2.new(0, Pos.X, 0, Pos.Y + h/2 + 8)
                        WeaponIcon.Position = UDim2.new(0, Pos.X - 21, 0, Pos.Y + h/2 + 5)
                    end

                    -- ── WEAPONS ──────────────────────────────────────────
                    if ESP.Drawing.Weapons.Enabled then
                        Weapon.Text       = "none"
                        Weapon.TextColor3 = ESP.Drawing.Weapons.WeaponTextRGB
                        Weapon.Visible    = true
                        WeaponIcon.Visible = true
                        Gradient3.Enabled = ESP.Drawing.Weapons.Gradient
                        if ESP.Drawing.Weapons.Gradient then
                            Gradient3.Color = ColorSequence.new{
                                ColorSequenceKeypoint.new(0, ESP.Drawing.Weapons.GradientRGB1),
                                ColorSequenceKeypoint.new(1, ESP.Drawing.Weapons.GradientRGB2)
                            }
                        end
                    else
                        Weapon.Visible    = false
                        WeaponIcon.Visible = false
                    end

                else
                    HideESP()
                end
            else
                HideESP()
            end
        end)
    end
    coroutine.wrap(Updater)()
end

-- ============================================================
--  SPAWN ESP FOR ALL CURRENT + FUTURE PLAYERS
-- ============================================================
for _, v in pairs(Players:GetPlayers()) do
    if v ~= lplayer then coroutine.wrap(ESP_func)(v) end
end
Players.PlayerAdded:Connect(function(v)
    coroutine.wrap(ESP_func)(v)
end)

return API
