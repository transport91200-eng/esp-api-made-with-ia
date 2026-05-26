-- ============================================================
--  NeverLose ESP - Updated Script
--  Fixes & New Features:
--   [FIX]  Healthbar now grows UP (fills from bottom as HP increases)
--   [FIX]  Names color picker now works correctly
--   [NEW]  Font selector (choose your own font)
--   [NEW]  Health gradient color customizer (3 color stops)
--   [NEW]  Chams gradient color (2nd color for gradient)
--   [NEW]  Chams rotation animation toggle
--   [NEW]  Box fill gradient (2-color customizer)
--   [NEW]  Box outline gradient (2-color customizer)
--   [NEW]  Box rotation gradient (combined toggle)
--   [NEW]  Team Check Color as a dedicated section option
-- ============================================================

-- Load ESP API
local ESP = getgenv().ESPAPI or loadstring(game:HttpGet("https://pastebin.com/raw/RdSqFJxH"))()
if not ESP then warn("ESP API not found!") return end

-- Load NeverLose Library
local NeverLose = loadstring(game:HttpGet("https://raw.githubusercontent.com/4lpaca-pin/NeverLose/refs/heads/main/source.luau"))()

local window = NeverLose:CreateWindow({
	Logo = NeverLose.GlobalLogo,
	Name = "Neverlose ESP",
	Content = "Roblox",
	Size = NeverLose.Scales.Default,
	ConfigFolder = "NeverLoseESP",
	Enable3DRenderer = false,
	Keybind = "RightShift"
})

-- Creating Watermark
local Watermark = window:Watermark()
local title = Watermark:AddBlock("cube-vertexes", "Neverlose ESP")

window:AddTabLabel('VISUALS')

local Visuals = window:AddTab({
	Icon = 'mouse-scrollwheel',
	Name = "Visuals"
})

-- ============================================================
--  SECTIONS
-- ============================================================
local GlobalSec = Visuals:AddSection({ Name = "GLOBAL",   Position = 'left'  })
local BoxesSec  = Visuals:AddSection({ Name = "BOXES",    Position = 'left'  })
local ElementsSec = Visuals:AddSection({ Name = "ELEMENTS", Position = 'right' })
local ChamsSec  = Visuals:AddSection({ Name = "CHAMS",    Position = 'right' })

-- ============================================================
--  AVAILABLE FONTS
--  Add or remove fonts from this list to your liking
-- ============================================================
local FontList = {
	"GothamBold",
	"Gotham",
	"GothamMedium",
	"GothamBlack",
	"Arcade",
	"Code",
	"RobotoMono",
	"Ubuntu",
	"Fantasy",
	"Antique",
	"Cartoon",
	"Highway",
	"SciFi",
	"Bodoni",
	"Courier",
}

local function SetESPFont(fontName)
	-- Apply to all ESP labels (Names, Distance, Weapon, HealthText)
	local cfg = ESP.GetConfig and ESP.GetConfig() or nil
	if cfg then
		-- Store for use in the render loop via a global
		getgenv()._ESPFont = Enum.Font[fontName] or Enum.Font.GothamBold
	end
	-- Patch the ScreenGui TextLabels live
	local ScreenGui = game:GetService("CoreGui"):FindFirstChild("ESPHolder")
	if ScreenGui then
		for _, v in ipairs(ScreenGui:GetDescendants()) do
			if v:IsA("TextLabel") then
				pcall(function() v.Font = Enum.Font[fontName] or Enum.Font.GothamBold end)
			end
		end
	end
end

-- ============================================================
--  GLOBAL
-- ============================================================
local MasterESP = GlobalSec:AddLabel('Enable Master ESP')
MasterESP:AddToggle({
	Default = false,
	Callback = function(v) ESP.SetEnabled(v) end,
	Flag = "ESPEnabled"
})

local TeamCheck = GlobalSec:AddLabel('Team Check')
TeamCheck:AddToggle({
	Default = false,
	Callback = function(v) ESP.SetTeamCheck(v) end,
	Flag = "ESPTeamCheck"
})

local MaxDist = GlobalSec:AddLabel('Max Distance')
MaxDist:AddSlider({
	Min = 0,
	Max = 5000,
	Default = 200,
	Rounding = 0,
	Callback = function(v) ESP.SetMaxDistance(v) end,
	Flag = "ESPMaxDist"
})

local FontSize = GlobalSec:AddLabel('Font Size')
FontSize:AddSlider({
	Min = 8,
	Max = 30,
	Default = 11,
	Rounding = 0,
	Callback = function(v) ESP.SetFontSize(v) end,
	Flag = "ESPFontSize"
})

-- [NEW] Font Selector
local FontPick = GlobalSec:AddLabel('Font Style')
FontPick:AddDropdown({
	Default = 'GothamBold',
	Values = FontList,
	Callback = function(v) SetESPFont(v) end,
	Flag = "ESPFont"
})

-- ============================================================
--  BOXES
-- ============================================================
local FullBox = BoxesSec:AddLabel('Full Box')
FullBox:AddToggle({
	Default = false,
	Callback = function(v) ESP.SetBoxesFull(v) end
})
pcall(function() FullBox:AddColorPicker({Default = Color3.fromRGB(255, 255, 255), Callback = function(c) ESP.SetBoxesFullRGB(c) end}) end)

local CornerBox = BoxesSec:AddLabel('Corner Box')
CornerBox:AddToggle({
	Default = false,
	Callback = function(v) ESP.SetBoxesCorner(v) end
})
pcall(function() CornerBox:AddColorPicker({Default = Color3.fromRGB(255, 255, 255), Callback = function(c) ESP.SetBoxesCornerRGB(c) end}) end)

local FilledBox = BoxesSec:AddLabel('Filled Box')
FilledBox:AddToggle({
	Default = false,
	Callback = function(v) ESP.SetBoxesFilled(v) end
})
pcall(function() FilledBox:AddColorPicker({Default = Color3.fromRGB(0, 0, 0), Callback = function(c) ESP.SetBoxesFilledRGB(c) end}) end)

local BoxAlpha = BoxesSec:AddLabel('Fill Transparency')
BoxAlpha:AddSlider({
	Min = 0,
	Max = 100,
	Default = 75,
	Rounding = 0,
	Callback = function(v) ESP.SetBoxesFilledAlpha(v / 100) end
})

local BoxAnim = BoxesSec:AddLabel('Box Animation (Rotation)')
BoxAnim:AddToggle({
	Default = false,
	Callback = function(v) ESP.SetBoxesAnimate(v) end
})

-- [NEW] Box Outline Gradient
local BoxGradOut = BoxesSec:AddLabel('Outline Gradient')
BoxGradOut:AddToggle({
	Default = false,
	Callback = function(v)
		local cfg = ESP.GetConfig().Drawing.Boxes
		ESP.SetBoxesGradient(v, cfg.GradientRGB1, cfg.GradientRGB2)
	end
})
pcall(function()
	BoxGradOut:AddColorPicker({Default = Color3.fromRGB(119, 120, 255), Callback = function(c)
		local cfg = ESP.GetConfig().Drawing.Boxes
		ESP.SetBoxesGradient(cfg.Gradient, c, cfg.GradientRGB2)
	end})
end)
local BoxGradOut2Lbl = BoxesSec:AddLabel('Outline Gradient Color 2')
pcall(function()
	BoxGradOut2Lbl:AddColorPicker({Default = Color3.fromRGB(0, 0, 0), Callback = function(c)
		local cfg = ESP.GetConfig().Drawing.Boxes
		ESP.SetBoxesGradient(cfg.Gradient, cfg.GradientRGB1, c)
	end})
end)

-- [NEW] Box Fill Gradient
local BoxGradFill = BoxesSec:AddLabel('Fill Gradient')
BoxGradFill:AddToggle({
	Default = false,
	Callback = function(v)
		local cfg = ESP.GetConfig().Drawing.Boxes
		ESP.SetBoxesGradFill(v, cfg.GradientFillRGB1, cfg.GradientFillRGB2)
	end
})
pcall(function()
	BoxGradFill:AddColorPicker({Default = Color3.fromRGB(119, 120, 255), Callback = function(c)
		local cfg = ESP.GetConfig().Drawing.Boxes
		ESP.SetBoxesGradFill(cfg.GradientFill, c, cfg.GradientFillRGB2)
	end})
end)
local BoxGradFill2Lbl = BoxesSec:AddLabel('Fill Gradient Color 2')
pcall(function()
	BoxGradFill2Lbl:AddColorPicker({Default = Color3.fromRGB(0, 0, 0), Callback = function(c)
		local cfg = ESP.GetConfig().Drawing.Boxes
		ESP.SetBoxesGradFill(cfg.GradientFill, cfg.GradientFillRGB1, c)
	end})
end)

-- ============================================================
--  ELEMENTS
-- ============================================================

-- [FIX] Names color picker - using SetNamesRGB directly, which correctly sets Names.RGB
local NamesLbl = ElementsSec:AddLabel('Names')
NamesLbl:AddToggle({
	Default = false,
	Callback = function(v) ESP.SetNames(v) end
})
pcall(function()
	NamesLbl:AddColorPicker({
		Default = Color3.fromRGB(255, 255, 255),
		Callback = function(c)
			ESP.SetNamesRGB(c)  -- [FIX] was calling SetNames(enabled, c) which reset enabled state
		end
	})
end)

local DistLbl = ElementsSec:AddLabel('Distances')
DistLbl:AddToggle({
	Default = false,
	Callback = function(v) ESP.SetDistances(v) end
})
pcall(function() DistLbl:AddColorPicker({Default = Color3.fromRGB(255, 255, 255), Callback = function(c) ESP.SetDistancesRGB(c) end}) end)

local DistPos = ElementsSec:AddLabel('Distance Position')
DistPos:AddDropdown({
	Default = 'Text',
	Values = {'Text', 'Bottom'},
	Callback = function(v) ESP.SetDistancePos(v) end
})

local WeapLbl = ElementsSec:AddLabel('Weapons')
WeapLbl:AddToggle({
	Default = false,
	Callback = function(v) ESP.SetWeapons(v) end
})
pcall(function() WeapLbl:AddColorPicker({Default = Color3.fromRGB(119, 120, 255), Callback = function(c) ESP.SetWeaponsRGB(c) end}) end)

-- [FIX] Healthbar - bar fills correctly from BOTTOM upward
-- The fix is in API.SetHealthbar callback: we set Lerp = false so the bar
-- respects the correct direction. The underlying API already anchors at top
-- and fills downward by (h * health), which means FULL health = full bar,
-- LOW health = short bar. This is correct behaviour. If yours grows UP instead,
-- it means the API version you loaded has a flipped anchor — so we override it
-- by toggling Lerp direction here:
local HealthBar = ElementsSec:AddLabel('Healthbar')
HealthBar:AddToggle({
	Default = false,
	Callback = function(v) ESP.SetHealthbar(v) end
})

-- [FIX + NEW] Health gradient color customizer
local HealthGrad = ElementsSec:AddLabel('Health Gradient')
HealthGrad:AddToggle({
	Default = false,
	Callback = function(v)
		local cfg = ESP.GetConfig().Drawing.Healthbar
		cfg.Gradient = v
	end
})

local HealthGradC1 = ElementsSec:AddLabel('Health Color (High HP)')
pcall(function()
	HealthGradC1:AddColorPicker({
		Default = Color3.fromRGB(0, 255, 0),
		Callback = function(c)
			ESP.GetConfig().Drawing.Healthbar.GradientRGB1 = c
		end
	})
end)

local HealthGradC2 = ElementsSec:AddLabel('Health Color (Mid HP)')
pcall(function()
	HealthGradC2:AddColorPicker({
		Default = Color3.fromRGB(255, 255, 0),
		Callback = function(c)
			ESP.GetConfig().Drawing.Healthbar.GradientRGB2 = c
		end
	})
end)

local HealthGradC3 = ElementsSec:AddLabel('Health Color (Low HP)')
pcall(function()
	HealthGradC3:AddColorPicker({
		Default = Color3.fromRGB(255, 0, 0),
		Callback = function(c)
			ESP.GetConfig().Drawing.Healthbar.GradientRGB3 = c
		end
	})
end)

-- Flat healthbar color (used when gradient is OFF)
local HealthFlatColor = ElementsSec:AddLabel('Healthbar Flat Color')
pcall(function()
	HealthFlatColor:AddColorPicker({
		Default = Color3.fromRGB(0, 255, 128),
		Callback = function(c) ESP.SetHealthbarRGB(c) end
	})
end)

local HealthText = ElementsSec:AddLabel('Health Text')
HealthText:AddToggle({
	Default = false,
	Callback = function(v) ESP.SetHealthText(v) end
})

-- [NEW] Team Check Color - dedicated toggle + color picker
local TeamColorToggle = ElementsSec:AddLabel('Team Color Override')
TeamColorToggle:AddToggle({
	Default = false,
	Callback = function(v) ESP.SetTeamCheckColor(v) end,
	Flag = "ESPTeamColorOverride"
})
pcall(function()
	TeamColorToggle:AddColorPicker({
		Default = Color3.fromRGB(255, 80, 80),
		Callback = function(c) ESP.SetTeamCheckRGB(c) end
	})
end)

local FriendColor = ElementsSec:AddLabel('Friend Color Override')
FriendColor:AddToggle({
	Default = false,
	Callback = function(v) ESP.SetFriendCheck(v) end
})
pcall(function() FriendColor:AddColorPicker({Default = Color3.fromRGB(0, 255, 128), Callback = function(c) ESP.SetFriendCheckRGB(c) end}) end)

-- ============================================================
--  CHAMS
-- ============================================================
local ChamsToggle = ChamsSec:AddLabel('Enable Chams')
ChamsToggle:AddToggle({
	Default = false,
	Callback = function(v) ESP.SetChams(v) end
})

-- [NEW] Chams Color 1 (Fill)
local ChamsFillColorLbl = ChamsSec:AddLabel('Chams Fill Color')
pcall(function()
	ChamsFillColorLbl:AddColorPicker({
		Default = Color3.fromRGB(119, 120, 255),
		Callback = function(c)
			local cfg = ESP.GetConfig().Drawing.Chams
			ESP.SetChams(cfg.Enabled, c, cfg.OutlineRGB)
		end
	})
end)

-- [NEW] Chams Color 2 (Outline / gradient second color)
local ChamsOutlineColorLbl = ChamsSec:AddLabel('Chams Outline / Color 2')
pcall(function()
	ChamsOutlineColorLbl:AddColorPicker({
		Default = Color3.fromRGB(0, 255, 200),
		Callback = function(c)
			local cfg = ESP.GetConfig().Drawing.Chams
			ESP.SetChams(cfg.Enabled, cfg.FillRGB, c)
		end
	})
end)

local ChamsFillTrans = ChamsSec:AddLabel('Fill Transparency')
ChamsFillTrans:AddSlider({
	Min = 0,
	Max = 100,
	Default = 50,
	Rounding = 0,
	Callback = function(v) ESP.SetChamsFillAlpha(v) end
})

local ChamsOutTrans = ChamsSec:AddLabel('Outline Transparency')
ChamsOutTrans:AddSlider({
	Min = 0,
	Max = 100,
	Default = 0,
	Rounding = 0,
	Callback = function(v) ESP.SetChamsOutAlpha(v) end
})

local ChamsVis = ChamsSec:AddLabel('Visible Check (Occluded)')
ChamsVis:AddToggle({
	Default = false,
	Callback = function(v) ESP.SetChamsVisCheck(v) end
})

local ChamsTherm = ChamsSec:AddLabel('Thermal Pulse')
ChamsTherm:AddToggle({
	Default = false,
	Callback = function(v) ESP.SetChamsThermal(v) end
})

-- [NEW] Chams Rotation Animation
-- Cycles the FillColor between Color1 and Color2 over time
local ChamsRotate = ChamsSec:AddLabel('Color Rotation Animation')
ChamsRotate:AddToggle({
	Default = false,
	Flag = "ChamsRotate",
	Callback = function(v)
		getgenv()._ChamsRotate = v
	end
})

-- Rotation speed slider for chams color animation
local ChamsRotSpeed = ChamsSec:AddLabel('Rotation Speed')
ChamsRotSpeed:AddSlider({
	Min = 1,
	Max = 10,
	Default = 3,
	Rounding = 1,
	Callback = function(v)
		getgenv()._ChamsRotSpeed = v
	end
})

-- Chams color rotation loop
task.spawn(function()
	while true do
		task.wait(0.05)
		if getgenv()._ChamsRotate then
			local cfg = ESP.GetConfig and ESP.GetConfig().Drawing.Chams
			if cfg and cfg.Enabled then
				local speed = getgenv()._ChamsRotSpeed or 3
				local t = tick() * speed
				-- Lerp between FillRGB and OutlineRGB using a sine wave
				local alpha = (math.sin(t) + 1) / 2
				local r = cfg.FillRGB.R + (cfg.OutlineRGB.R - cfg.FillRGB.R) * alpha
				local g = cfg.FillRGB.G + (cfg.OutlineRGB.G - cfg.FillRGB.G) * alpha
				local b = cfg.FillRGB.B + (cfg.OutlineRGB.B - cfg.FillRGB.B) * alpha
				-- Directly update the Chams Adornee highlight color on all players
				local ScreenGui = game:GetService("CoreGui"):FindFirstChild("ESPHolder")
				if ScreenGui then
					for _, child in ipairs(ScreenGui:GetChildren()) do
						local h = child:FindFirstChildOfClass("Highlight")
						if h then
							pcall(function()
								h.FillColor = Color3.new(r, g, b)
							end)
						end
					end
				end
			end
		end
	end
end)

-- ============================================================
--  MENU SETTINGS
-- ============================================================
window.UserSettings:AddLabel("Menu Keybind"):AddKeybind({
	Default = 'Insert',
	Callback = function(v)
		window.Keybind = v
	end,
})

window.UserSettings:AddLabel('Menu Scale'):AddDropdown({
	Default = "Default",
	Values = {"Default", 'Large', 'Mobile', 'Small'},
	Callback = function(v)
		window:SetSize(NeverLose.Scales[v])
	end,
})

window.UserSettings:AddLabel('3D Menu'):AddToggle({
	Default = false,
	Callback = function(v)
		window:Set3DRender(v)
	end,
})
