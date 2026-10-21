--[[
    MATCHA extrnal ui clone — made by LUNR

    .
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local Matcha = {}
Matcha.__index = Matcha

local COLORS = {
	bg = Color3.fromRGB(11, 11, 15),
	header = Color3.fromRGB(13, 13, 17),
	panel = Color3.fromRGB(17, 17, 22),
	control = Color3.fromRGB(21, 21, 27),
	hover = Color3.fromRGB(32, 31, 39),
	border = Color3.fromRGB(37, 36, 44),
	text = Color3.fromRGB(229, 227, 235),
	muted = Color3.fromRGB(137, 135, 148),
	accent = Color3.fromRGB(90, 226, 173),
	green = Color3.fromRGB(75, 205, 125),
	knob = Color3.fromRGB(215, 211, 222),
}

local FONT = Enum.Font.Gotham
local MEDIUM = Enum.Font.GothamMedium

local function create(className, props, parent)
	local object = Instance.new(className)
	for key, value in pairs(props or {}) do object[key] = value end
	object.Parent = parent
	return object
end

local function round(object, radius)
	create("UICorner", {CornerRadius = UDim.new(0, radius or 7)}, object)
end

local function outline(object, color, transparency)
	create("UIStroke", {
		Color = color or COLORS.border,
		Transparency = transparency or 0,
		Thickness = 1,
	}, object)
end

local function text(parent, value, size, position, color, textSize, font, alignment)
	return create("TextLabel", {
		BackgroundTransparency = 1,
		Size = size,
		Position = position,
		Text = value,
		TextColor3 = color or COLORS.text,
		TextSize = textSize or 11,
		Font = font or FONT,
		TextXAlignment = alignment or Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Center,
		TextWrapped = false,
	}, parent)
end

local function button(parent, value, size, position, zIndex)
	local b = create("TextButton", {
		Size = size,
		Position = position,
		BackgroundColor3 = COLORS.control,
		BorderSizePixel = 0,
		Text = value or "",
		TextColor3 = COLORS.text,
		TextSize = 10,
		Font = MEDIUM,
		AutoButtonColor = false,
		ZIndex = zIndex or 1,
	}, parent)
	round(b, 6)
	return b
end

local function tween(object, properties, duration)
	TweenService:Create(object, TweenInfo.new(duration or 0.14, Enum.EasingStyle.Quad), properties):Play()
end

local function formatValue(value, decimals)
	if decimals and decimals > 0 then
		return string.format("%." .. decimals .. "f", value)
	end
	return tostring(math.floor(value + 0.5))
end

function Matcha.new(e)
	e = e or {}
	-- Backwards compatibility: Matcha.new("MINT") still works.
	if typeof(e) == "string" then
		e = {Title = e}
	end

	local self = setmetatable({}, Matcha)
	self.Config = e
	self._connections = {}
	self._keybinds = {}
	self._tabButtons = {}
	self._tabs = {}
	self._activeTab = nil
	self._listening = nil
	self._popup = nil
	self._destroyed = false
	self._accentUpdaters = {}
	self._configControls = {}

	local player = Players.LocalPlayer
	local playerGui = game.CoreGui
	local old = playerGui:FindFirstChild("MINTREMAKE")
	if old then old:Destroy() end

	self.Gui = create("ScreenGui", {
		Name = "MINTREMAKE",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		DisplayOrder = 50,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	}, playerGui)

	-- Subtle accent-colored snowfall dots, visible only in the uncovered background.
	-- Adjust SNOW_COUNT for density and DOT_TRANSPARENCY for subtlety.
	local SNOW_COUNT = 55
	local DOT_TRANSPARENCY = 0.72
	local snowLayer = create("Frame", {
		Name = "SnowfallBackground",
		Size = UDim2.fromScale(1, 1),
		Position = UDim2.fromScale(0, 0),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		Selectable = false,
		ZIndex = 0,
	}, self.Gui)

	local random = Random.new()
	local snowflakes = {}
	self._snowSettings = {Count = SNOW_COUNT, Speed = 30, Transparency = DOT_TRANSPARENCY}
	for i = 1, SNOW_COUNT do
		local size = random:NextInteger(2, 4)
		local flake = create("Frame", {
			Name = "SnowDot",
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(random:NextNumber(), random:NextNumber()),
			Size = UDim2.fromOffset(size, size),
			BackgroundColor3 = COLORS.accent,
			BackgroundTransparency = math.clamp(DOT_TRANSPARENCY + random:NextNumber(-0.08, 0.12), 0.5, 0.92),
			BorderSizePixel = 0,
			ZIndex = 0,
			Active = false,
			Selectable = false,
		}, snowLayer)
		create("UICorner", { CornerRadius = UDim.new(1, 0) }, flake)

		table.insert(snowflakes, {
			Object = flake,
			Speed = random:NextNumber(0.65, 1.35),
			Drift = random:NextNumber(-9, 9),
			Sway = random:NextNumber(0.5, 2.2),
			Phase = random:NextNumber(0, math.pi * 2),
		})
	end

	-- Keep the particles synced with the live accent-color picker.
	table.insert(self._accentUpdaters, function(color)
		for _, snow in ipairs(snowflakes) do
			if snow.Object and snow.Object.Parent then
				snow.Object.BackgroundColor3 = color
			end
		end
	end)

	function self:SetSnowCount(value)
		value = math.clamp(math.floor(tonumber(value) or 55), 0, 200)
		self._snowSettings.Count = value
		for _, item in ipairs(snowflakes) do if item.Object then item.Object:Destroy() end end
		table.clear(snowflakes)
		for i = 1, value do
			local size = random:NextInteger(2, 4)
			local flake = create("Frame", {Name="SnowDot", AnchorPoint=Vector2.new(0.5,0.5),
				Position=UDim2.fromScale(random:NextNumber(), random:NextNumber()), Size=UDim2.fromOffset(size,size),
				BackgroundColor3=COLORS.accent, BackgroundTransparency=self._snowSettings.Transparency,
				BorderSizePixel=0, ZIndex=0, Active=false, Selectable=false}, snowLayer)
			round(flake, size)
			table.insert(snowflakes, {Object=flake, Speed=random:NextNumber(0.65,1.35), Drift=random:NextNumber(-9,9), Sway=random:NextNumber(0.5,2.2), Phase=random:NextNumber(0,math.pi*2)})
		end
	end
	function self:SetSnowSpeed(value)
		self._snowSettings.Speed = math.clamp(tonumber(value) or 30, 0, 150)
	end
	function self:SetSnowTransparency(value)
		self._snowSettings.Transparency = math.clamp(tonumber(value) or 0.72, 0, 1)
		for _, item in ipairs(snowflakes) do item.Object.BackgroundTransparency = self._snowSettings.Transparency end
	end
	local elapsed = 0
	local snowConnection = RunService.RenderStepped:Connect(function(deltaTime)
		if self._destroyed or not snowLayer.Parent then return end
		elapsed += deltaTime
		local camera = workspace.CurrentCamera
		local viewport = camera and camera.ViewportSize or Vector2.new(800, 600)

		for _, snow in ipairs(snowflakes) do
			local flake = snow.Object
			if flake.Parent then
				local position = flake.Position
				local x = position.X.Scale + (snow.Drift * deltaTime / math.max(viewport.X, 1))
				local y = position.Y.Scale + (snow.Speed * self._snowSettings.Speed * deltaTime / math.max(viewport.Y, 1))
				x += math.sin(elapsed * snow.Sway + snow.Phase) * deltaTime * 0.0008
				if y > 1.04 then
					y = -0.04
					x = random:NextNumber()
				elseif x < -0.03 then
					x = 1.03
				elseif x > 1.03 then
					x = -0.03
				end
				flake.Position = UDim2.fromScale(x, y)
			end
		end
	end)
	table.insert(self._connections, snowConnection)

	-- Popups live in their own unclipped overlay layer.
	self.Overlay = create("Frame", {
		Name = "PopupOverlay",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ClipsDescendants = false,
		ZIndex = 100,
	}, self.Gui)

	self.Window = create("Frame", {
		Name = "Window",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(674, 620),
		BackgroundColor3 = COLORS.bg,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, self.Gui)
	round(self.Window, 11)
	outline(self.Window, COLORS.border)

	-- The snowfall belongs to the window itself, not the full-screen ScreenGui.
	-- Keep it clipped to the rounded UI and behind all window content.
	snowLayer.Parent = self.Window
	snowLayer.Position = UDim2.fromScale(0, 0)
	snowLayer.Size = UDim2.fromScale(1, 1)
	snowLayer.ZIndex = 0

	self.Scale = create("UIScale", {Scale = 1}, self.Window)
	local function updateScale()
		local camera = workspace.CurrentCamera
		if not camera then return end
		local viewport = camera.ViewportSize
		-- Compact width, fixed design proportions, never full-screen wide.
		local scale = math.min((viewport.X - 24) / 674, (viewport.Y - 24) / 620, 1)
		self.Scale.Scale = math.clamp(scale, 0.45, 1)
	end
	updateScale()
	if workspace.CurrentCamera then
		table.insert(self._connections, workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale))
	end

	-- Header
	self.Header = create("Frame", {
		Size = UDim2.new(1, 0, 0, 39),
		BackgroundColor3 = COLORS.header,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, self.Window)
	-- Round the header itself and fill only its lower part. This prevents
	-- square header corners from showing through the rounded window corners.
	round(self.Header, 11)
	create("Frame", {
		Position = UDim2.fromOffset(0, 11),
		Size = UDim2.new(1, 0, 1, -11),
		BackgroundColor3 = COLORS.header,
		BorderSizePixel = 0,
	}, self.Header)
	-- Drag the window by its header. Interactive header labels remain harmless.
	local dragging = false
	local dragStart, windowStart
	self.Header.Active = true
	self.Header.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			windowStart = self.Window.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	table.insert(self._connections, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			local delta = input.Position - dragStart
			self.Window.Position = UDim2.new(
				windowStart.X.Scale, windowStart.X.Offset + delta.X,
				windowStart.Y.Scale, windowStart.Y.Offset + delta.Y
			)
		end
	end))
	-- Header text is configurable and laid out inline. The right-side tag
	-- remains independently anchored to the far right of the header.
	local headerTitle = tostring(e.Title or "MINT")
	local headerSeparator = tostring(e.Separator or "·")
	local headerSubtitle = tostring(e.Subtitle or "Interface")
	local headerBadge = tostring(e.Badge or "Standard")
	local headerRight = tostring(e.RightText or "mıq")

	local titleLabel = text(self.Header, headerTitle, UDim2.fromOffset(10, 20),
		UDim2.fromOffset(14, 9), COLORS.accent, 11, Enum.Font.GothamBold)
	local separatorLabel = text(self.Header, headerSeparator, UDim2.fromOffset(10, 20),
		UDim2.fromOffset(0, 9), COLORS.muted, 9)
	local subtitleLabel = text(self.Header, headerSubtitle, UDim2.fromOffset(10, 20),
		UDim2.fromOffset(0, 9), COLORS.muted, 10)

	local badge = create("TextLabel", {
		Size = UDim2.fromOffset(10, 19),
		Position = UDim2.fromOffset(0, 10),
		BackgroundColor3 = Color3.fromRGB(17, 17, 22),
		Text = headerBadge,
		TextColor3 = COLORS.text,
		TextSize = 10,
		Font = MEDIUM,
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.X,
	}, self.Header)
	create("UIPadding", {
		PaddingLeft = UDim.new(0, 8),
		PaddingRight = UDim.new(0, 8),
	}, badge)
	round(badge, 10)
	outline(badge, COLORS.border)
	-- Keep the badge neutral so it fits the dark UI regardless of accent color.
	table.insert(self._accentUpdaters, function(_color)
		badge.BackgroundColor3 = Color3.fromRGB(30, 30, 37)
		badge.TextColor3 = COLORS.text
	end)

	local rightLabel = text(self.Header, headerRight, UDim2.new(0, 0, 0, 18),
		UDim2.new(1, -12, 0, 9), COLORS.muted, 9, MEDIUM, Enum.TextXAlignment.Right)
	rightLabel.AutomaticSize = Enum.AutomaticSize.X
	rightLabel.AnchorPoint = Vector2.new(1, 0)

	local function measure(value, size, font)
		return TextService:GetTextSize(value, size, font, Vector2.new(1000, 24)).X
	end
	local function layoutHeader()
		local x = 14
		local titleWidth = measure(headerTitle, 11, Enum.Font.GothamBold)
		titleLabel.Position = UDim2.fromOffset(x, 9)
		titleLabel.Size = UDim2.fromOffset(titleWidth + 2, 20)
		x += titleWidth + 10

		local separatorWidth = measure(headerSeparator, 9, FONT)
		separatorLabel.Position = UDim2.fromOffset(x, 9)
		separatorLabel.Size = UDim2.fromOffset(separatorWidth + 2, 20)
		x += separatorWidth + 7

		local subtitleWidth = measure(headerSubtitle, 10, FONT)
		subtitleLabel.Position = UDim2.fromOffset(x, 9)
		subtitleLabel.Size = UDim2.fromOffset(subtitleWidth + 2, 20)
		x += subtitleWidth + 10

		badge.Position = UDim2.fromOffset(x, 10)
	end
	layoutHeader()

	-- Keep the title, separator, subtitle and badge inline.
	-- The right-side text remains pinned independently to the far edge.

	-- Navigation and page container
	self.Nav = create("Frame", {
		Position = UDim2.fromOffset(0, 39),
		Size = UDim2.new(1, 0, 0, 44),
		BackgroundColor3 = COLORS.bg,
		BorderSizePixel = 0,
	}, self.Window)
	self.PageHost = create("Frame", {
		Name = "PageHost",
		Position = UDim2.fromOffset(11, 83),
		Size = UDim2.new(1, -22, 1, -108),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
	}, self.Window)

	-- Footer

	-- Footer
	local footer = create("Frame", {
		Name = "Footer",
		Position = UDim2.new(0, 0, 1, -22),
		Size = UDim2.new(1, 0, 0, 22),
		BackgroundColor3 = COLORS.header,
		BorderSizePixel = 0,
		ClipsDescendants = true,
	}, self.Window)

	round(footer, 11)

	create("Frame", {
		Position = UDim2.fromOffset(0, 0),
		Size = UDim2.new(1, 0, 0, 11),
		BackgroundColor3 = COLORS.header,
		BorderSizePixel = 0,
	}, footer)

	create("Frame", {
		Size = UDim2.new(1, 0, 0, 1),
		BackgroundColor3 = COLORS.border,
		BorderSizePixel = 0,
	}, footer)

	local dot = create("Frame", {
		Position = UDim2.fromOffset(15, 9),
		Size = UDim2.fromOffset(5, 5),
		BackgroundColor3 = COLORS.green,
		BorderSizePixel = 0,
	}, footer)
	round(dot, 5)

	text(
		footer,
		tostring(e.OnlineText or "5240 online"),
		UDim2.fromOffset(120, 18),
		UDim2.fromOffset(27, 2),
		COLORS.muted,
		10
	)

	local url = text(
		footer,
		tostring(e.FooterText or "matcha.pink/discord"),
		UDim2.fromOffset(200, 18),
		UDim2.new(0.5, -100, 0, 2),
		COLORS.muted,
		10,
		FONT,
		Enum.TextXAlignment.Center
	)

	-- Build information: grouped together and aligned to the
	-- right edge with 15 pixels of padding, matching the left.
	local buildLabel = tostring(e.BuildLabel or "Build:")
	local buildText = tostring(e.BuildText or "Apr 10 2026")

	local buildGroup = create("Frame", {
		Name = "BuildInfo",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -15, 0, 2),
		Size = UDim2.fromOffset(0, 18),
		AutomaticSize = Enum.AutomaticSize.X,
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
	}, footer)

	local buildLayout = create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		HorizontalAlignment = Enum.HorizontalAlignment.Right,
		VerticalAlignment = Enum.VerticalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, 4),
	}, buildGroup)

	local buildLabelText = text(
		buildGroup,
		buildLabel,
		UDim2.fromOffset(42, 18),
		UDim2.new(),
		COLORS.muted,
		10
	)
	buildLabelText.LayoutOrder = 1

	local buildValueText = text(
		buildGroup,
		buildText,
		UDim2.fromOffset(84, 18),
		UDim2.new(),
		COLORS.accent,
		10,
		MEDIUM
	)
	buildValueText.LayoutOrder = 2

	-- Size the group to the actual text widths so the right padding
	-- remains exactly 15 pixels, regardless of the build text.
	local function updateBuildLayout()
		local labelWidth = TextService:GetTextSize(
			buildLabel,
			10,
			FONT,
			Vector2.new(1000, 18)
		).X

		local valueWidth = TextService:GetTextSize(
			buildText,
			10,
			MEDIUM,
			Vector2.new(1000, 18)
		).X

		buildLabelText.Size = UDim2.fromOffset(labelWidth + 1, 18)
		buildValueText.Size = UDim2.fromOffset(valueWidth + 1, 18)
		buildGroup.Size = UDim2.fromOffset(labelWidth + valueWidth + 5, 18)
	end

	updateBuildLayout()

	table.insert(self._accentUpdaters, function(color)
		titleLabel.TextColor3 = color
		badge.TextColor3 = color
		buildValueText.TextColor3 = color
	end)


	-- One global input listener handles keybind listening and activation.
	table.insert(self._connections, UserInputService.InputBegan:Connect(function(input, processed)
		if self._destroyed then return end
		if self._listening then
			if input.UserInputType == Enum.UserInputType.Keyboard then
				local key = input.KeyCode
				if key == Enum.KeyCode.Escape then
					self._listening.Button.Text = self._listening.PreviousText
				else
					self._listening:SetKey(key)
				end
				self._listening = nil
			elseif input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.MouseButton2
				or input.UserInputType == Enum.UserInputType.MouseButton3 then
				self._listening:SetKey(input.UserInputType)
				self._listening = nil
			end
			return
		end
		if processed then return end

		for _, item in ipairs(self._keybinds) do
			if item.Key == input.KeyCode or item.Key == input.UserInputType then
				item:Activate()
			end
		end
	end))

	-- Dismiss any open popup when clicking elsewhere. Clicking its own
	-- swatch is handled by that swatch so it can toggle the popup closed.
	table.insert(self._connections, UserInputService.InputBegan:Connect(function(input, processed)
		if self._destroyed or not self._popup then return end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1
			and input.UserInputType ~= Enum.UserInputType.MouseButton2
			and input.UserInputType ~= Enum.UserInputType.Touch then
			return
		end
		local point = input.Position
		local popup = self._popup
		local anchor = self._popupAnchor
		local function contains(gui, p)
			if not gui or not gui.Parent then return false end
			local pos, size = gui.AbsolutePosition, gui.AbsoluteSize
			return p.X >= pos.X and p.X <= pos.X + size.X
				and p.Y >= pos.Y and p.Y <= pos.Y + size.Y
		end
		if contains(popup, point) or (anchor and contains(anchor, point)) then
			return
		end
		self:_closePopup()
	end))

	table.insert(self._connections, UserInputService.InputChanged:Connect(function(input)
		if self._listening and input.UserInputType == Enum.UserInputType.MouseMovement then
			-- Mouse movement is intentionally not captured as a bind.
		end
	end))

	return self
end

function Matcha:Tab(name)
	local tab = {
		Library = self,
		Name = name,
		Sections = {},
	}
	local width = math.max(48, #name * 6 + 22)
	local x = 14
	for _, b in ipairs(self._tabButtons) do
		x = math.max(x, b.Position.X.Offset + b.Size.X.Offset + 7)
	end

	local b = button(self.Nav, name, UDim2.fromOffset(width, 24), UDim2.fromOffset(x, 10))
	b.BackgroundColor3 = Color3.fromRGB(11, 11, 15)
	b.TextColor3 = COLORS.muted
	table.insert(self._tabButtons, b)

	tab.Page = create("Frame", {
		Name = name .. "Page",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		Visible = false,
	}, self.PageHost)

	tab.LeftStack = create("Frame", {
		Name = "LeftColumn",
		Size = UDim2.new(0.5, -5, 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
	}, tab.Page)
	tab.RightStack = create("Frame", {
		Name = "RightColumn",
		Position = UDim2.new(0.5, 5, 0, 0),
		Size = UDim2.new(0.5, -5, 1, 0),
		BackgroundTransparency = 1,
		ClipsDescendants = false,
	}, tab.Page)
	for _, stack in ipairs({tab.LeftStack, tab.RightStack}) do
		create("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, stack)
	end
	function tab:Section(sectionName, column)
		return self.Library:_section(self, sectionName, column or "left")
	end

	local function selectTab()
		self._activeTab = tab
		for _, other in ipairs(self._tabs) do
			other.Page.Visible = other == tab
			local btn = other.Button
			local active = other == tab
			btn.BackgroundColor3 = active and Color3.fromRGB(27, 25, 31) or COLORS.bg
			btn.TextColor3 = active and COLORS.text or COLORS.muted
		end
	end
	tab.Button = b
	tab.Select = selectTab
	table.insert(self._tabs, tab)
	b.Activated:Connect(selectTab)

	if not self._activeTab then selectTab() end
	return tab
end

function Matcha:_closePopup()
	if self._popup then
		self._popup:Destroy()
		self._popup = nil
	end
	self._popupAnchor = nil
end

function Matcha:_popupAt(anchor, size, preferredSide)
	-- Only one popup can exist at a time. Opening any dropdown or picker
	-- automatically destroys the previous popup.
	self:_closePopup()

	local abs = anchor.AbsolutePosition
	local anchorSize = anchor.AbsoluteSize
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1000, 800)
	local margin = 8
	local x, y

	if preferredSide == "right" then
		x = abs.X + anchorSize.X + 8
		y = abs.Y - 8
		if x + size.X > viewport.X - margin then
			x = abs.X - size.X - 8
		end
		-- If neither side fits, place it inside the viewport at the right edge.
		if x < margin then
			x = viewport.X - size.X - margin
		end
	else
		x = math.clamp(abs.X, margin, math.max(margin, viewport.X - size.X - margin))
		y = abs.Y + anchorSize.Y + 4
		if y + size.Y > viewport.Y - margin then
			y = abs.Y - size.Y - 4
		end
	end

	x = math.clamp(x, margin, math.max(margin, viewport.X - size.X - margin))
	y = math.clamp(y, margin, math.max(margin, viewport.Y - size.Y - margin))

	local popup = create("Frame", {
		Position = UDim2.fromOffset(x, y),
		Size = UDim2.fromOffset(size.X, size.Y),
		BackgroundColor3 = COLORS.control,
		BorderSizePixel = 0,
		ZIndex = 110,
		ClipsDescendants = false,
	}, self.Overlay)
	round(popup, 8)
	outline(popup, COLORS.border)
	self._popup = popup
	self._popupAnchor = anchor
	return popup
end

function Matcha:SetAccentColor(color)
	assert(typeof(color) == "Color3", "SetAccentColor expects a Color3")
	COLORS.accent = color
	self.Config.AccentColor = color
	for _, update in ipairs(self._accentUpdaters) do
		update(color)
	end
end

function Matcha:Destroy()
	self._destroyed = true
	for _, connection in ipairs(self._connections) do
		connection:Disconnect()
	end
	self._connections = {}
	self.Gui:Destroy()
end

local Section = {}
Section.__index = Section

function Matcha:_registerConfig(key, kind, getter, setter)
	local base, suffix = key, 2
	while self._configControls[key] do key = base .. " #" .. suffix; suffix += 1 end
	self._configControls[key] = {Kind = kind, Get = getter, Set = setter}
end

function Section:_configKey(name, flag)
	-- Explicit flags are stable config identifiers; fall back to a readable path.
	if flag ~= nil and tostring(flag) ~= "" then return tostring(flag) end
	return tostring(self.Tab.Name) .. "/" .. tostring(self.Name) .. "/" .. tostring(name)
end

function Matcha:_section(tab, name, column)
	local isRight = column == "right"
	local holder = isRight and tab.RightStack or tab.LeftStack
	local panel = create("Frame", {
		Name = name:gsub("%s+", "") .. "Section",
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundColor3 = COLORS.panel,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		LayoutOrder = #tab.Sections + 1,
	}, holder)
	round(panel, 10)

	local header = create("Frame", {
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
	}, panel)
	text(header, name, UDim2.new(1, -26, 1, 0), UDim2.fromOffset(13, 0), COLORS.text, 10, MEDIUM)
	create("Frame", {
		Position = UDim2.new(0, 13, 1, -1),
		Size = UDim2.new(1, -26, 0, 1),
		BackgroundColor3 = COLORS.border,
		BorderSizePixel = 0,
	}, header)

	local body = create("Frame", {
		Position = UDim2.fromOffset(0, 34),
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		ClipsDescendants = false,
	}, panel)
	create("UIPadding", {
		PaddingLeft = UDim.new(0, 13),
		PaddingRight = UDim.new(0, 13),
		PaddingTop = UDim.new(0, 8),
		PaddingBottom = UDim.new(0, 10),
	}, body)
	local layout = create("UIListLayout", {
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, body)

	local section = setmetatable({
		Library = self,
		Tab = tab,
		Name = name,
		Panel = panel,
		Body = body,
		Layout = layout,
		_order = 0,
	}, Section)

	table.insert(tab.Sections, section)
	return section
end

function Section:Button(name, callback)
	-- Preferred config-table format:
	-- section:Button({Name = "Apply", Callback = function() print("Applied") end})
	if type(name) == "table" then
		local e = name
		name, callback = e.Name or e.Text or "Button", e.Callback
	end
	self._order += 1
	local row = create("Frame", {
		Name = tostring(name):gsub("%s+", "") .. "ButtonRow",
		Size = UDim2.new(1, 0, 0, 30),
		BackgroundTransparency = 1,
		LayoutOrder = self._order,
	}, self.Body)
	local b = button(row, tostring(name), UDim2.new(1, 0, 0, 27), UDim2.fromOffset(0, 1))
	b.BackgroundColor3 = COLORS.control
	outline(b, COLORS.border)
	round(b, 6)
	b.Activated:Connect(function()
		if callback then callback() end
	end)
	return {Button = b, Click = function() if callback then callback() end end}
end

function Section:Toggle(name, default, callback, key, flag)
	-- Preferred config-table format:
	-- section:Toggle({Name = "Enabled", Default = false, Callback = fn, Key = Enum.KeyCode.E})
	if type(name) == "table" then
		local e = name
		name, default, callback, key, flag = e.Name or "Toggle", e.Default, e.Callback, e.Key, e.Flag
	end
	self._order += 1
	local row = create("Frame", {
		Name = name .. "Toggle",
		Size = UDim2.new(1, 0, 0, 21),
		BackgroundTransparency = 1,
		LayoutOrder = self._order,
	}, self.Body)
	local box = button(row, "", UDim2.fromOffset(18, 18), UDim2.fromOffset(0, 1))
	box.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
	outline(box, Color3.fromRGB(53, 53, 62))
	-- No check mark: the toggle's filled accent state indicates ON.
	if default then box.BackgroundColor3 = COLORS.accent end
	text(row, name, UDim2.new(1, -70, 1, 0), UDim2.fromOffset(26, 0), COLORS.muted, 10)

	local enabled = default == true
	local bind
	local function set(value, fire)
		enabled = value == true
		tween(box, {BackgroundColor3 = enabled and COLORS.accent or Color3.fromRGB(30, 30, 36)})
		if fire and callback then callback(enabled) end
	end
	table.insert(self.Library._accentUpdaters, function(color)
		if enabled then box.BackgroundColor3 = color end
	end)
	box.Activated:Connect(function() set(not enabled, true) end)

	if key then
		bind = self:Keybind({Name = name .. " bind", Flag = flag and (tostring(flag) .. "_key") or nil, DefaultKey = key, Parent = row, Callback = function()
			set(not enabled, true)
		end})
	end
	local api = {Get = function() return enabled end, Set = function(v) set(v, true) end, Keybind = bind}
	self.Library:_registerConfig(self:_configKey(name, flag), "toggle", function() return api.Get() end, function(v) api.Set(v) end)
	return api
end

function Section:Keybind(name, defaultKey, callback, parent, flag)
	-- Preferred config-table format:
	-- section:Keybind({Name = "Menu key", DefaultKey = Enum.KeyCode.RightShift, Callback = fn})
	if type(name) == "table" then
		local e = name
		name, defaultKey, callback, parent, flag = e.Name or "Keybind", e.DefaultKey or e.Key, e.Callback, e.Parent, e.Flag
	end
	local row = parent or create("Frame", {
		Name = name .. "KeybindRow",
		Size = UDim2.new(1, 0, 0, 21),
		BackgroundTransparency = 1,
		LayoutOrder = self._order + 1,
	}, self.Body)
	if not parent then
		self._order += 1
		text(row, name, UDim2.new(1, -66, 1, 0), UDim2.fromOffset(0, 0), COLORS.muted, 10)
	end

	local keyButton = button(row, "None", UDim2.fromOffset(46, 19), UDim2.new(1, -46, 0, 1))
	keyButton.BackgroundColor3 = COLORS.control
	round(keyButton, 10)

	local item = {
		Button = keyButton,
		Key = defaultKey,
		PreviousText = "",
		_callback = callback,
	}

	local function keyName(key)
		if typeof(key) == "EnumItem" then
			if key.EnumType == Enum.KeyCode then return key.Name end
			if key == Enum.UserInputType.MouseButton1 then return "m1" end
			if key == Enum.UserInputType.MouseButton2 then return "m2" end
			if key == Enum.UserInputType.MouseButton3 then return "m3" end
		end
		return "None"
	end

	function item:SetKey(key)
		item.Key = key
		keyButton.Text = keyName(key)
	end
	function item:Activate()
		if item._callback then item._callback(item.Key) end
	end

	item:SetKey(defaultKey)
	keyButton.Activated:Connect(function()
		item.PreviousText = keyButton.Text
		keyButton.Text = "..."
		self.Library._listening = item
	end)
	table.insert(self.Library._keybinds, item)
	self.Library:_registerConfig(self:_configKey(name, flag), "keybind", function() return keyName(item.Key) end, function(value)
		local key = type(value) == "string" and Enum.KeyCode[value] or nil
		if key then item:SetKey(key) end
	end)
	return item
end

function Section:Slider(name, minValue, maxValue, defaultValue, callback, decimals, flag)
	-- Preferred config-table format:
	-- section:Slider({Name = "Distance", Min = 0, Max = 1000, Default = 500, Decimals = 0, Callback = fn})
	if type(name) == "table" then
		local e = name
		name, minValue, maxValue, defaultValue, callback, decimals, flag =
			e.Name or "Slider", e.Min or 0, e.Max or 100, e.Default or e.Min or 0, e.Callback, e.Decimals, e.Flag
	end
	self._order += 1
	decimals = decimals or 0
	local holder = create("Frame", {
		Name = name .. "Slider",
		Size = UDim2.new(1, 0, 0, 36),
		BackgroundTransparency = 1,
		LayoutOrder = self._order,
	}, self.Body)
	text(holder, name, UDim2.new(0.7, 0, 0, 14), UDim2.fromOffset(0, 0), COLORS.muted, 10)
	local valueText = text(holder, formatValue(defaultValue, decimals), UDim2.new(0.3, 0, 0, 14), UDim2.new(0.7, 0, 0, 0), COLORS.text, 10, MEDIUM, Enum.TextXAlignment.Right)
	local track = button(holder, "", UDim2.new(1, 0, 0, 4), UDim2.fromOffset(0, 22))
	track.BackgroundColor3 = Color3.fromRGB(38, 38, 45)
	round(track, 4)
	local ratio = math.clamp((defaultValue - minValue) / (maxValue - minValue), 0, 1)
	local fill = create("Frame", {
		Size = UDim2.new(ratio, 0, 1, 0),
		BackgroundColor3 = COLORS.accent,
		BorderSizePixel = 0,
	}, track)
	round(fill, 4)
	table.insert(self.Library._accentUpdaters, function(color)
		fill.BackgroundColor3 = color
	end)
	local knob = create("Frame", {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(ratio, 0, 0.5, 0),
		Size = UDim2.fromOffset(10, 10),
		BackgroundColor3 = COLORS.knob,
		BorderSizePixel = 0,
	}, track)
	round(knob, 8)

	local value = defaultValue
	local dragging = false
	local function update(x, fire)
		local width = math.max(track.AbsoluteSize.X, 1)
		local r = math.clamp((x - track.AbsolutePosition.X) / width, 0, 1)
		value = minValue + (maxValue - minValue) * r
		if decimals == 0 then value = math.floor(value + 0.5)
		else local mult = 10 ^ decimals; value = math.floor(value * mult + 0.5) / mult end
		fill.Size = UDim2.new(r, 0, 1, 0)
		knob.Position = UDim2.new(r, 0, 0.5, 0)
		valueText.Text = formatValue(value, decimals)
		if fire and callback then callback(value) end
	end
	track.Activated:Connect(function()
		update(UserInputService:GetMouseLocation().X, true)
	end)
	track.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			update(input.Position.X, true)
		end
	end)
	table.insert(self.Library._connections, UserInputService.InputChanged:Connect(function(input)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			update(input.Position.X, true)
		end
	end))
	table.insert(self.Library._connections, UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end))

	local api = {
		Get = function() return value end,
		Set = function(_, v)
			value = math.clamp(tonumber(v) or minValue, minValue, maxValue)
			local r = (value - minValue) / math.max(maxValue - minValue, 1)
			fill.Size = UDim2.new(r, 0, 1, 0)
			knob.Position = UDim2.new(r, 0, 0.5, 0)
			valueText.Text = formatValue(value, decimals)
			if callback then callback(value) end
		end,
	}
	self.Library:_registerConfig(self:_configKey(name, flag), "slider", function() return api.Get() end, function(v) api.Set(api, v) end)
	return api
end

function Section:Dropdown(name, options, defaultValue, callback, flag)
	-- Preferred config-table format:
	-- section:Dropdown({Name = "Hit Part", Options = {"Head", "Torso"}, Default = "Head", Callback = fn})
	if type(name) == "table" then
		local e = name
		name, options, defaultValue, callback, flag =
			e.Name or "Dropdown", e.Options or {}, e.Default, e.Callback, e.Flag
	end
	options = options or {}
	self._order += 1
	local wrapper = create("Frame", {
		Name = name .. "Dropdown",
		Size = UDim2.new(1, 0, 0, 52),
		BackgroundTransparency = 1,
		LayoutOrder = self._order,
	}, self.Body)
	text(wrapper, name, UDim2.new(1, 0, 0, 16), UDim2.fromOffset(0, 0), COLORS.muted, 10)

	local b = button(wrapper, "", UDim2.new(1, 0, 0, 31), UDim2.fromOffset(0, 18))
	outline(b, COLORS.border)
	local current = defaultValue or options[1]
	local valueText = text(b, tostring(current), UDim2.new(1, -34, 1, 0), UDim2.fromOffset(11, 0), COLORS.text, 10, MEDIUM)
	local arrow = create("ImageLabel", {
		Name = "DropdownIcon",
		BackgroundTransparency = 1,
		Image = "rbxassetid://11944718875",
		ImageColor3 = COLORS.muted,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(16, 16),
		Position = UDim2.new(1, -24, 0.5, -8),
		ZIndex = 2,
	}, b)

	b.Activated:Connect(function()
		local popup = self.Library:_popupAt(b, Vector2.new(math.floor(b.AbsoluteSize.X), math.min(#options * 27, 189)))
		popup.ClipsDescendants = true
		local list = create("ScrollingFrame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ScrollBarThickness = 3,
			CanvasSize = UDim2.fromOffset(0, #options * 27),
			ZIndex = 111,
		}, popup)
		create("UIListLayout", {SortOrder = Enum.SortOrder.LayoutOrder}, list)
		for index, option in ipairs(options) do
			local opt = create("TextButton", {
				Size = UDim2.new(1, -3, 0, 27),
				BackgroundColor3 = COLORS.control,
				BorderSizePixel = 0,
				Text = tostring(option),
				TextColor3 = COLORS.text,
				Font = FONT,
				TextSize = 10,
				ZIndex = 112,
				LayoutOrder = index,
			}, list)
			opt.Activated:Connect(function()
				current = option
				valueText.Text = tostring(current)
				self.Library:_closePopup()
				if callback then callback(current) end
			end)
			opt.MouseEnter:Connect(function() opt.BackgroundColor3 = COLORS.hover end)
			opt.MouseLeave:Connect(function() opt.BackgroundColor3 = COLORS.control end)
		end
	end)

	local api = {
		Get = function() return current end,
		Set = function(_, value)
			if table.find(options, value) then
				current = value
				valueText.Text = tostring(value)
				if callback then callback(value) end
			end
		end,
	}
	self.Library:_registerConfig(self:_configKey(name, flag), "dropdown", function() return api.Get() end, function(v) api.Set(api, v) end)
	return api
end

function Section:ColorPicker(name, defaultColor, callback, flag)
	-- Preferred config-table format:
	-- section:ColorPicker({Name = "Accent Color", DefaultColor = Color3.fromRGB(90, 226, 173), Callback = fn})
	if type(name) == "table" then
		local e = name
		name, defaultColor, callback, flag = e.Name or "Color", e.DefaultColor or e.Default, e.Callback, e.Flag
	end
	self._order += 1
	local row = create("Frame", {
		Name = name .. "ColorPicker",
		Size = UDim2.new(1, 0, 0, 24),
		BackgroundTransparency = 1,
		LayoutOrder = self._order,
	}, self.Body)
	text(row, name, UDim2.new(1, -50, 1, 0), UDim2.fromOffset(0, 0), COLORS.muted, 10)
	local swatch = button(row, "", UDim2.fromOffset(36, 18), UDim2.new(1, -36, 0, 3))
	swatch.BackgroundColor3 = defaultColor or COLORS.accent
	outline(swatch, COLORS.border)

	local color = defaultColor or COLORS.accent
	local transparency = 0
	local h, s, v = color:ToHSV()
	-- Keep the Settings accent swatch and picker in sync when a theme changes.
	if string.lower(tostring(name)) == "accent color" then
		table.insert(self.Library._accentUpdaters, function(newAccent)
			color = newAccent
			h, s, v = color:ToHSV()
			swatch.BackgroundColor3 = newAccent
		end)
	end

	swatch.Activated:Connect(function()
		-- Clicking the active swatch closes its picker; opening another swatch
		-- replaces the existing popup via _popupAt().
		if self.Library._popup and self.Library._popupAnchor == swatch then
			self.Library:_closePopup()
			return
		end
		-- Compact picker opens beside the swatch, not over the controls below it.
		local popup = self.Library:_popupAt(swatch, Vector2.new(224, 292), "right")
		popup.ClipsDescendants = false
		local pad = create("UIPadding", {
			PaddingLeft = UDim.new(0, 10),
			PaddingRight = UDim.new(0, 10),
			PaddingTop = UDim.new(0, 10),
			PaddingBottom = UDim.new(0, 10),
		}, popup)

		text(popup, name, UDim2.new(1, -20, 0, 18), UDim2.fromOffset(10, 7), COLORS.text, 11, MEDIUM)

		-- Saturation/value square: hue base, white-to-transparent overlay,
		-- then transparent-to-black overlay for brightness control.
		local square = create("TextButton", {
			Position = UDim2.fromOffset(10, 32),
			Size = UDim2.new(1, -20, 0, 132),
			BackgroundColor3 = Color3.fromHSV(h, 1, 1),
			Text = "",
			BorderSizePixel = 0,
			AutoButtonColor = false,
			ZIndex = 111,
			ClipsDescendants = true,
		}, popup)
		round(square, 5)
		local whiteLayer = create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 112,
		}, square)
		round(whiteLayer, 5)
		create("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(1, 1, 1)),
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0),
				NumberSequenceKeypoint.new(1, 1),
			}),
		}, whiteLayer)
		local blackLayer = create("Frame", {
			Size = UDim2.fromScale(1, 1),
			BackgroundColor3 = Color3.new(0, 0, 0),
			BorderSizePixel = 0,
			ZIndex = 113,
		}, square)
		round(blackLayer, 5)
		create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(1, 0),
			}),
		}, blackLayer)

		local selector = create("Frame", {
			Size = UDim2.fromOffset(10, 10),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(s, 0, 1 - v, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			ZIndex = 115,
		}, square)
		round(selector, 8)
		outline(selector, Color3.new(1, 1, 1))
		outline(selector, Color3.new(0, 0, 0), 0.15)

		local hueBar = create("TextButton", {
			Position = UDim2.fromOffset(10, 169),
			Size = UDim2.new(1, -20, 0, 13),
			BackgroundColor3 = Color3.new(1, 1, 1),
			Text = "",
			BorderSizePixel = 0,
			AutoButtonColor = false,
			ZIndex = 111,
		}, popup)
		round(hueBar, 4)
		create("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 0)),
				ColorSequenceKeypoint.new(0.17, Color3.fromRGB(255, 255, 0)),
				ColorSequenceKeypoint.new(0.33, Color3.fromRGB(0, 255, 0)),
				ColorSequenceKeypoint.new(0.50, Color3.fromRGB(0, 255, 255)),
				ColorSequenceKeypoint.new(0.67, Color3.fromRGB(0, 0, 255)),
				ColorSequenceKeypoint.new(0.83, Color3.fromRGB(255, 0, 255)),
				ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 0)),
			}),
		}, hueBar)
		local hueKnob = create("Frame", {
			Size = UDim2.fromOffset(5, 17),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(h, 0, 0.5, 0),
			BackgroundColor3 = Color3.new(1, 1, 1),
			BorderSizePixel = 0,
			ZIndex = 113,
		}, hueBar)
		round(hueKnob, 3)
		outline(hueKnob, Color3.new(0, 0, 0))

		text(popup, "Transparency", UDim2.new(1, 0, 0, 16), UDim2.fromOffset(10, 191), COLORS.muted, 10)
		local alphaTrack = button(popup, "", UDim2.new(1, -20, 0, 9), UDim2.fromOffset(10, 212))
		alphaTrack.BackgroundColor3 = COLORS.border
		round(alphaTrack, 4)
		local alphaFill = create("Frame", {
			Size = UDim2.new(1 - transparency, 0, 1, 0),
			BackgroundColor3 = color,
			BorderSizePixel = 0,
		}, alphaTrack)
		round(alphaFill, 4)
		local alphaKnob = create("Frame", {
			Size = UDim2.fromOffset(10, 14),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(1 - transparency, 0, 0.5, 0),
			BackgroundColor3 = COLORS.knob,
			BorderSizePixel = 0,
		}, alphaTrack)
		round(alphaKnob, 5)

		local preview = create("Frame", {
			Position = UDim2.fromOffset(10, 236),
			Size = UDim2.new(1, -20, 0, 20),
			BackgroundColor3 = color,
			BackgroundTransparency = transparency,
			BorderSizePixel = 0,
		}, popup)
		round(preview, 5)
		outline(preview, COLORS.border)
		local hex = text(popup, "#", UDim2.new(1, -20, 0, 17), UDim2.fromOffset(10, 261), COLORS.muted, 10, FONT)

		local squareDragging, hueDragging, alphaDragging = false, false, false
		local function refresh()
			color = Color3.fromHSV(h, s, v)
			square.BackgroundColor3 = Color3.fromHSV(h, 1, 1)
			selector.Position = UDim2.new(s, 0, 1 - v, 0)
			hueKnob.Position = UDim2.new(h, 0, 0.5, 0)
			alphaFill.Size = UDim2.new(1 - transparency, 0, 1, 0)
			alphaFill.BackgroundColor3 = color
			alphaKnob.Position = UDim2.new(1 - transparency, 0, 0.5, 0)
			preview.BackgroundColor3 = color
			preview.BackgroundTransparency = transparency
			swatch.BackgroundColor3 = color
			hex.Text = string.format("#%02X%02X%02X   %.0f%%", math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255), transparency * 100)
			if string.lower(tostring(name)) == "accent color" then
				self.Library:SetAccentColor(color)
			end
			if callback then callback(color, transparency) end
		end
		local function squareUpdate(inputX, inputY)
			local p = square.AbsolutePosition
			local z = square.AbsoluteSize
			s = math.clamp((inputX - p.X) / z.X, 0, 1)
			v = 1 - math.clamp((inputY - p.Y) / z.Y, 0, 1)
			refresh()
		end
		local function hueUpdate(inputX)
			h = math.clamp((inputX - hueBar.AbsolutePosition.X) / hueBar.AbsoluteSize.X, 0, 1)
			refresh()
		end
		local function alphaUpdate(inputX)
			transparency = 1 - math.clamp((inputX - alphaTrack.AbsolutePosition.X) / alphaTrack.AbsoluteSize.X, 0, 1)
			refresh()
		end

		square.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				squareDragging = true
				squareUpdate(input.Position.X, input.Position.Y)
			end
		end)
		hueBar.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				hueDragging = true
				hueUpdate(input.Position.X)
			end
		end)
		alphaTrack.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				alphaDragging = true
				alphaUpdate(input.Position.X)
			end
		end)

		local moveConnection = UserInputService.InputChanged:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
				if squareDragging then squareUpdate(input.Position.X, input.Position.Y) end
				if hueDragging then hueUpdate(input.Position.X) end
				if alphaDragging then alphaUpdate(input.Position.X) end
			end
		end)
		local endConnection = UserInputService.InputEnded:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
				squareDragging, hueDragging, alphaDragging = false, false, false
			end
		end)
		table.insert(self.Library._connections, moveConnection)
		table.insert(self.Library._connections, endConnection)
		refresh()
	end)

	local api = {
		Get = function() return color, transparency end,
		Set = function(_, newColor, newTransparency)
			color = newColor
			transparency = math.clamp(newTransparency or transparency, 0, 1)
			h, s, v = color:ToHSV()
			swatch.BackgroundColor3 = color
			if string.lower(tostring(name)) == "accent color" then self.Library:SetAccentColor(color) end
			if callback then callback(color, transparency) end
		end,
	}
	self.Library:_registerConfig(self:_configKey(name, flag), "color", function()
		return {R=color.R, G=color.G, B=color.B, Transparency=transparency}
	end, function(newColor, newTransparency)
		api.Set(api, newColor, newTransparency)
	end)
	return api
end

function Matcha:Section(name, column)
	assert(self._activeTab, "Create a tab before creating a section.")
	return self:_section(self._activeTab, name, column or "left")
end

-- A tab can create its own sections with tab:Section(...).
function Section:Section(name, column)
	return self.Library:_section(self.Tab, name, column or "left")
end



--==================================================
-- CONFIGURATION + EXAMPLE UI SETUP (SINGLE-SCRIPT)
--==================================================
-- Put this entire script in a LocalScript under:
-- StarterPlayer > StarterPlayerScripts
--
-- Function format for reusable functions:
-- local function example(e)
--     e = e or {}
--     local title = e.Title or "Default title"
-- end
--
-- You can use that same pattern for your own configuration helpers.
-- Header/footer text is configured below and uses safe default values.
--
-- All elements accept a config table in the same e = e or {} style:
-- section:Button({Name = "Apply", Callback = function() end})
-- section:Toggle({Name = "Enabled", Flag = "enabled", Default = false, Key = Enum.KeyCode.E, Callback = function(value) end})
-- section:Keybind({Name = "Menu key", Flag = "menu_key", DefaultKey = Enum.KeyCode.RightShift, Callback = function(key) end})
-- section:Slider({Name = "Distance", Flag = "distance", Min = 0, Max = 1000, Default = 500, Decimals = 0, Callback = function(value) end})
-- section:Dropdown({Name = "Hit Part", Flag = "hit_part", Options = {"Head", "Torso"}, Default = "Head", Callback = function(value) end})
-- section:ColorPicker({Name = "Accent Color", Flag = "accent_color", DefaultColor = Color3.fromRGB(90, 226, 173), Callback = function(color, transparency) end})

local function getUIConfig(e)
	e = e or {}
	return {
		Title = e.Title or "MINT",
		Separator = e.Separator or "·",
		Subtitle = e.Subtitle or "Interface",
		Badge = e.Badge or "Standard",
		RightText = e.RightText or "mıq",
		OnlineText = e.OnlineText or "5240 online",
		FooterText = e.FooterText or "matcha.pink/discord",
		BuildLabel = e.BuildLabel or "Build:",
		BuildText = e.BuildText or "Apr 10 2026",
	}
end


local function palette(bg,header,panel,control,hover,border,accent,text,muted,green,knob)
	return {bg=Color3.fromRGB(table.unpack(bg)),header=Color3.fromRGB(table.unpack(header)),panel=Color3.fromRGB(table.unpack(panel)),control=Color3.fromRGB(table.unpack(control)),hover=Color3.fromRGB(table.unpack(hover)),border=Color3.fromRGB(table.unpack(border)),accent=Color3.fromRGB(table.unpack(accent)),text=Color3.fromRGB(table.unpack(text)),muted=Color3.fromRGB(table.unpack(muted)),green=Color3.fromRGB(table.unpack(green)),knob=Color3.fromRGB(table.unpack(knob))}
end
local DEFAULT_THEME = palette({11,11,15},{13,13,17},{17,17,22},{21,21,27},{32,31,39},{37,36,44},{90, 226, 173},{229,227,235},{137,135,148},{75,205,125},{215,211,222})   
local THEMES = {
	Default=DEFAULT_THEME,
	Matcha=palette({11,11,15},{13,13,17},{17,17,22},{21,21,27},{32,31,39},{37,36,44},{222, 45, 164},{229,227,235},{137,135,148},{75,205,125},{215,211,222})  ,
	Midnight=palette({7,12,24},{9,15,30},{14,22,40},{20,29,49},{31,43,67},{42,55,80},{94,156,255},{232,238,250},{145,160,184},{85,210,170},{218,228,245}),
	Mint=palette({10,17,16},{12,22,20},{17,29,26},{22,36,32},{34,52,46},{43,63,56},{91,226,174},{229,240,235},{139,163,151},{91,226,174},{210,235,225}),
}
local function applyTheme(lib, themeName)
	local theme = THEMES[themeName]
	assert(theme, "Unknown theme: " .. tostring(themeName))
	local previous = table.clone(COLORS)
	-- Update the shared palette first, so controls created after this call use it too.
	for key, value in pairs(theme) do COLORS[key] = value end
	lib.Config.Theme = themeName

	-- Translate existing controls from the previous palette to the new palette.
	-- Use ordered roles to avoid ambiguous color collisions in the old palette.
	local roleOrder = {"accent", "text", "muted", "green", "knob", "border", "hover", "control", "panel", "header", "bg"}
	local roleMap = {}
	for _, role in ipairs(roleOrder) do
		local oldColor = previous[role]
		if oldColor then roleMap[oldColor] = role end
	end
	local specialMap = {
		[Color3.fromRGB(30,30,36)] = "control",
		[Color3.fromRGB(30,30,37)] = "control",
		[Color3.fromRGB(38,38,45)] = "border",
		[Color3.fromRGB(53,53,62)] = "border",
	}
	for _, obj in ipairs(lib.Gui:GetDescendants()) do
		for _, property in ipairs({"BackgroundColor3", "TextColor3", "ImageColor3", "Color"}) do
			local ok, value = pcall(function() return obj[property] end)
			if ok and typeof(value) == "Color3" then
				local role = roleMap[value] or specialMap[value]
				if role and theme[role] then pcall(function() obj[property] = theme[role] end) end
			end
		end
		if obj:IsA("UIStroke") then
			local role = roleMap[obj.Color] or specialMap[obj.Color]
			if role and theme[role] then obj.Color = theme[role] end
		end
		if obj.Name == "Window" then obj.BackgroundColor3 = theme.bg
		elseif obj.Name == "Header" or obj.Name == "Footer" then obj.BackgroundColor3 = theme.header
		elseif obj.Name == "Nav" then obj.BackgroundColor3 = theme.bg
		elseif obj.Name:find("Section") then obj.BackgroundColor3 = theme.panel
		elseif obj.Name == "SnowDot" then obj.BackgroundColor3 = theme.accent end
	end
	-- Refresh accent-driven controls (toggles, sliders, header title, snow, etc.).
	lib:SetAccentColor(theme.accent)
end
function Matcha:ApplyTheme(name) applyTheme(self, name) end
local function cleanPathPart(value)
	value = tostring(value or "Matcha"):gsub("[/\\:*?\"<>|]", "_"):gsub("%.%.", "_"):gsub("^%s+", ""):gsub("%s+$", "")
	if value == "" then value = "Matcha" end
	return value
end
local function fsFunction(name)
	local ok, fn = pcall(function() return getfenv()[name] end)
	if ok and type(fn) == "function" then return fn end
	local env = _G
	if env and type(env[name]) == "function" then return env[name] end
	return nil
end
function Matcha:GetConfigDirectory()
	return "appdata/" .. cleanPathPart(self.Config.Title or "Matcha")
end
function Matcha:_ensureConfigDirectory()
	local isfolderFn, makefolderFn = fsFunction("isfolder"), fsFunction("makefolder")
	if not isfolderFn or not makefolderFn then return false, "Executor filesystem APIs (isfolder/makefolder) are unavailable." end
	local root = "appdata"
	local good, err = pcall(function()
		if not isfolderFn(root) then makefolderFn(root) end
		local dir = self:GetConfigDirectory()
		if not isfolderFn(dir) then makefolderFn(dir) end
	end)
	if not good then return false, tostring(err) end
	return true, self:GetConfigDirectory()
end
local function encodeControlValue(item)
	local value = item.Get()
	if item.Kind == "color" and type(value) == "table" then return value end
	return value
end
local function decodeColor(value)
	if type(value) ~= "table" then return nil end
	local r,g,b = tonumber(value.R), tonumber(value.G), tonumber(value.B)
	if not r or not g or not b then return nil end
	return Color3.new(math.clamp(r,0,1),math.clamp(g,0,1),math.clamp(b,0,1))
end
function Matcha:GetConfigNames()
	local ok, dir = self:_ensureConfigDirectory()
	if not ok then return {} end
	local listfilesFn = fsFunction("listfiles")
	if not listfilesFn then return {} end
	local names = {}
	local success, files = pcall(listfilesFn, dir)
	if not success or type(files) ~= "table" then return names end
	for _, path in ipairs(files) do
		local name = tostring(path):gsub("\\", "/"):match("([^/]+)%.json$")
		if name then table.insert(names, name) end
	end
	table.sort(names)
	return names
end
function Matcha:SaveConfig(name)
	name = cleanPathPart(name)
	local ok, dir = self:_ensureConfigDirectory()
	if not ok then return false, dir end
	local writefileFn = fsFunction("writefile")
	if not writefileFn then return false, "Executor filesystem API writefile is unavailable." end
	local controls = {}
	for key, item in pairs(self._configControls or {}) do
		local good, value = pcall(encodeControlValue, item)
		if good then controls[key] = value end
	end
	local accent = COLORS.accent
	local payload = {
		Version=1, Title=self.Config.Title or "Matcha", Theme=self.Config.Theme or "Default",
		AccentColor={R=accent.R,G=accent.G,B=accent.B},
		Snow={Count=self._snowSettings.Count,Speed=self._snowSettings.Speed,Transparency=self._snowSettings.Transparency},
		Controls=controls,
	}
	local encoded = HttpService:JSONEncode(payload)
	local success, err = pcall(writefileFn, dir .. "/" .. name .. ".json", encoded)
	if not success then return false, tostring(err) end
	return true
end
function Matcha:LoadConfig(name)
	name = cleanPathPart(name)
	local ok, dir = self:_ensureConfigDirectory()
	if not ok then return false, dir end
	local isfileFn, readfileFn = fsFunction("isfile"), fsFunction("readfile")
	if not isfileFn or not readfileFn then return false, "Executor filesystem APIs (isfile/readfile) are unavailable." end
	local path = dir .. "/" .. name .. ".json"
	if not isfileFn(path) then return false, "Config not found: " .. name end
	local success, raw = pcall(readfileFn, path)
	if not success then return false, tostring(raw) end
	local parsed, data = pcall(function() return HttpService:JSONDecode(raw) end)
	if not parsed or type(data) ~= "table" then return false, "Config file is invalid JSON." end
	if data.Theme and THEMES[data.Theme] then self:ApplyTheme(data.Theme) end
	local accent = decodeColor(data.AccentColor)
	if accent then self:SetAccentColor(accent) end
	local snow = data.Snow or {}
	if snow.Count ~= nil then self:SetSnowCount(snow.Count) end
	if snow.Speed ~= nil then self:SetSnowSpeed(snow.Speed) end
	if snow.Transparency ~= nil then self:SetSnowTransparency(snow.Transparency) end
	for key, value in pairs(data.Controls or {}) do
		local item = self._configControls and self._configControls[key]
		if item then
			pcall(function()
				if item.Kind == "color" then
					local color = decodeColor(value)
					if color then item.Set(color, value.Transparency) end
				else item.Set(value) end
			end)
		end
	end
	return true
end
function Matcha:DeleteConfig(name)
	name = cleanPathPart(name)
	local ok, dir = self:_ensureConfigDirectory()
	if not ok then return false, dir end
	local isfileFn, delfileFn = fsFunction("isfile"), fsFunction("delfile")
	if not isfileFn or not delfileFn then return false, "Executor filesystem APIs (isfile/delfile) are unavailable." end
	local path = dir .. "/" .. name .. ".json"
	if not isfileFn(path) then return false, "Config not found: " .. name end
	local success, err = pcall(delfileFn, path)
	if not success then return false, tostring(err) end
	return true
end
-- Backwards-compatible aliases for older preset button code.
function Matcha:GetPresetNames() return self:GetConfigNames() end
function Matcha:SavePreset(name) return self:SaveConfig(name) end
function Matcha:LoadPreset(name) return self:LoadConfig(name) end
function Matcha:DeletePreset(name) return self:DeleteConfig(name) end

-- Call this on any Matcha instance: local settingsTab = ui:SettingsTab()
function Matcha:SettingsTab()
	if self._settingsTab then return self._settingsTab end
	local tab = self:Tab("Settings")
	self._settingsTab = tab
	local settings = tab:Section("Appearance & Snow", "left")
	settings:Dropdown({Name="UI Theme", Flag="ui_theme", Options={"Default","Matcha","Midnight","Mint"}, Default=self.Config.Theme or "Default", Callback=function(value) self:ApplyTheme(value) end})
	settings:ColorPicker({Name="Accent Color", Flag="settings_accent_color", DefaultColor=COLORS.accent, Callback=function(color) self:SetAccentColor(color) end})
	settings:Slider({Name="Snowflake Count",Flag="snowflake_count",Min=0,Max=200,Default=self._snowSettings.Count,Decimals=0,Callback=function(v) self:SetSnowCount(v) end})
	settings:Slider({Name="Snowflake Speed",Flag="snowflake_speed",Min=0,Max=150,Default=self._snowSettings.Speed,Decimals=0,Callback=function(v) self:SetSnowSpeed(v) end})
	settings:Slider({Name="Snow Transparency",Flag="snow_transparency",Min=0,Max=1,Default=self._snowSettings.Transparency,Decimals=2,Callback=function(v) self:SetSnowTransparency(v) end})
	local section = tab:Section("Saved Configs", "right")
	local nameBox = create("TextBox",{Name="PresetName",Size=UDim2.new(1,0,0,27),BackgroundColor3=COLORS.control,BorderSizePixel=0,ClearTextOnFocus=false,PlaceholderText="Preset name...",Text="",TextColor3=COLORS.text,PlaceholderColor3=COLORS.muted,TextSize=10,Font=FONT,LayoutOrder=1},section.Body)
	round(nameBox,6); outline(nameBox,COLORS.border); section._order += 1
	local listHolder = create("Frame",{Name="PresetButtons",Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,LayoutOrder=2},section.Body)
	create("UIListLayout",{Padding=UDim.new(0,4),SortOrder=Enum.SortOrder.LayoutOrder},listHolder)
	section._order += 1
	local status = text(section.Body,"Configs save under appdata/" .. cleanPathPart(self.Config.Title or "Matcha"),UDim2.new(1,0,0,24),UDim2.new(),COLORS.muted,10)
	section._order += 1; status.LayoutOrder = section._order
	local selected
	local function refresh()
		for _, child in ipairs(listHolder:GetChildren()) do if child:IsA("TextButton") then child:Destroy() end end
		local names = self:GetPresetNames()
		if #names == 0 then
			local empty = text(listHolder,"No saved configs yet.",UDim2.new(1,0,0,24),UDim2.new(),COLORS.muted,10)
			empty.LayoutOrder = 1
			selected = nil
			return
		end
		if not selected or not table.find(names, selected) then selected = names[1] end
		for i, presetName in ipairs(names) do
			local b = button(listHolder, (presetName == selected and "✓  " or "") .. presetName, UDim2.new(1,0,0,27), UDim2.new(), 1)
			b.LayoutOrder = i
			b.Activated:Connect(function()
				selected = presetName; nameBox.Text = presetName; status.Text = "Selected: " .. presetName
				refresh()
			end)
		end
	end
	local function action(label, callback)
		section._order += 1
		local b = button(section.Body,label,UDim2.new(1,0,0,27),UDim2.new(),1)
		b.LayoutOrder = section._order; b.Activated:Connect(callback); return b
	end
	action("Save Config",function()
		local name = nameBox.Text:match("^%s*(.-)%s*$")
		if name == "" then status.Text = "Enter a preset name first."; return end
		local ok, err = self:SaveConfig(name)
		if not ok then status.Text = "Save failed: " .. tostring(err); return end
		selected = cleanPathPart(name); status.Text = "Saved config: " .. selected; refresh()
	end)
	action("Load Selected Config",function()
		local name = selected or nameBox.Text:match("^%s*(.-)%s*$")
		if not name or name == "" then status.Text = "Select a config first."; return end
		local ok, err = self:LoadConfig(name)
		if not ok then status.Text = "Load failed: " .. tostring(err); return end
		selected = name; status.Text = "Loaded config: " .. name; refresh()
	end)
	action("Delete Selected Config",function()
		local name = selected or nameBox.Text:match("^%s*(.-)%s*$")
		if not name or name == "" then status.Text = "Select a config first."; return end
		local ok, err = self:DeleteConfig(name)
		if not ok then status.Text = "Delete failed: " .. tostring(err); return end
		selected = nil; nameBox.Text = ""; status.Text = "Config deleted."; refresh()
	end)
	refresh()
	return tab
end

 return Matcha;

