local _, ns = ...

-- UI: the host's window (glue). Copies ns.View models into frames and
-- computes no text and no number of its own.
-- Spec: docs/prd/visual/01-window.md (this shell: frame, title bar, corner,
-- main button, footer, grip, moving, resizing, showing, the state switch and
-- the redraw) and 02-form.md, 03-in-progress.md, 04-winner.md, which fill
-- the build / draw / onMain stubs below, one state each.
--
-- Helpers for the state packages (all local to this file):
--
--   newListBox(parent) -> box
--     A list box (visual.md 4.4): a Frame in the box colour with a 1 px border
--     (box.frame; anchor it in your content frame) holding a ScrollFrame
--     (UIPanelScrollFrameTemplate) over a child frame (box.content) that rows
--     hang off. box.content is always as wide as the visible area.
--     box:Layout(count, makeRow) -> rows
--       Makes sure rows 1..count exist, creating a missing one with
--       makeRow(box.content, i) (it returns a Frame; the box sets its height to
--       LAYOUT.rowHeight and stretches it to full width), shows rows 1..count,
--       hides the rest, stacks them top down and sets the content height so the
--       scroll bar is right. Returns box.rows; the caller then copies the view
--       model's fields into rows[i].
--
--   newFlatButton(parent, fontObject) -> Button with .bg (colour texture) and
--     .label (FontString, centred). paintButton(button, base, hover, textColour)
--     sets its look: base is the background colour ({ r, g, b [, a] }, nil for
--     none), hover the colour while the mouse is over it (nil for no change),
--     textColour the label colour. Flat buttons per visual.md 4.2.
--
--   setMainButton(label, enabled): the main button's label and whether it is
--     clickable (gray when not). 03's draw.rolling calls it every redraw.
--
--   shell: the built parts. shell.host (the host's short name), shell.faction
--     ("Alliance", "Horde" or nil for neutral), shell.tint (View.TINT entry),
--     shell.window, shell.content[state], shell.mainButton, shell.corner,
--     shell.footer. PALETTE and LAYOUT hold every colour and size of
--     visual.md 4.1 and 4.2.

local UI = {}
ns.UI = UI

-- Neutral palette (visual.md 4.2). { r, g, b } floats in 0..1.
local PALETTE = {
	window = { 0.106, 0.110, 0.137 },
	border = { 0.173, 0.180, 0.220 },
	box = { 0.141, 0.149, 0.184 },
	text = { 0.925, 0.929, 0.949 },
	muted = { 0.545, 0.553, 0.600 },
	disabled = { 0.463, 0.471, 0.518 },
	disabledButton = { 0.180, 0.188, 0.227 },
	pill = { 1, 1, 1, 0.16 }, -- the Cancel pill in the corner
	pillHover = { 1, 1, 1, 0.28 },
}
local HOVER_LIGHTEN = 0.08 -- added to each channel of a flat button on hover

-- Dimensions (visual.md 4.1).
local LAYOUT = {
	width = 300,
	height = 420,
	minWidth = 240,
	minHeight = 320,
	maxWidth = 600,
	maxHeight = 800,
	titleHeight = 36,
	padding = 12,
	rowHeight = 24,
	gap = 10,
	barHeight = 6,
	buttonHeight = 44,
	gripSize = 16,
	cornerInset = 8,
	iconSize = 16,
	scrollBarWidth = 16,
}

local WHITE8X8 = "Interface\\Buttons\\WHITE8x8"
local GRIP_TEXTURE = "Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up"
local ICON_TEXTURE = "Interface\\FriendsFrame\\PlusManz-" -- .. faction

local BACKDROP = {
	bgFile = WHITE8X8,
	edgeFile = WHITE8X8,
	edgeSize = 1,
}

-- Exact user-facing text of this package (01-window.md).
local TEXT = {
	title = "Death roll",
	close = "×",
	cancel = "Cancel",
	neutral = "Neutral",
}

-- The main button by state. rolling's label and enabled state are set by 03's
-- draw.rolling through setMainButton on every redraw.
local MAIN = {
	form = { label = "Start", enabled = true },
	lobby = { label = "Roll", enabled = false },
	rolling = { label = "Roll", enabled = false },
	winner = { label = "Reset", enabled = true },
}

local shell = {} -- the built parts; empty until the first build
local game -- the last game the Host reported (may be finished and dropped by Host)
local shown -- the state currently drawn, or nil before the first redraw

-- Hooks the state packages fill: build[state](parent) once at build,
-- draw[state](game, now) on every redraw, onMain[state]() on a main button click.
local build = {
	form = function() end, -- 02-form (package 07)
	lobby = function() end, -- 03-in-progress (package 08)
	rolling = function() end, -- 03-in-progress (package 08)
	winner = function() end, -- 04-winner (package 09)
}
local draw = {
	form = function() end, -- 02-form (package 07)
	lobby = function() end, -- 03-in-progress (package 08)
	rolling = function() end, -- 03-in-progress (package 08)
	winner = function() end, -- 04-winner (package 09)
}
local onMain = {
	form = function() end, -- 02-form (package 07)
	lobby = function() end, -- nothing: the button is gray
	rolling = function() end, -- 03-in-progress (package 08)
	winner = nil, -- set below: forget the game and redraw
}

local redraw -- defined after the parts it needs

local function lighten(colour)
	return {
		math.min(colour[1] + HOVER_LIGHTEN, 1),
		math.min(colour[2] + HOVER_LIGHTEN, 1),
		math.min(colour[3] + HOVER_LIGHTEN, 1),
		colour[4],
	}
end

local function colourTexture(parent, layer, colour)
	local texture = parent:CreateTexture(nil, layer)
	texture:SetColorTexture(unpack(colour))
	return texture
end

-- Flat buttons (visual.md 4.2): a colour texture, a centred label, lighter on hover.

local function newFlatButton(parent, fontObject)
	local button = CreateFrame("Button", nil, parent)
	button.bg = button:CreateTexture(nil, "BACKGROUND")
	button.bg:SetAllPoints()
	button.label = button:CreateFontString(nil, "OVERLAY")
	button.label:SetFontObject(fontObject)
	button.label:SetPoint("CENTER")
	button:SetScript("OnEnter", function(self)
		if self.hover and self:IsEnabled() then
			self.bg:SetColorTexture(unpack(self.hover))
		end
	end)
	button:SetScript("OnLeave", function(self)
		if self.base then
			self.bg:SetColorTexture(unpack(self.base))
		end
	end)
	return button
end

local function paintButton(button, base, hover, textColour)
	button.base = base
	button.hover = hover
	if base then
		button.bg:SetColorTexture(unpack(base))
		button.bg:Show()
	else
		button.bg:Hide()
	end
	button.label:SetTextColor(unpack(textColour))
end

local function setMainButton(label, enabled)
	local button = shell.mainButton
	button.label:SetText(label)
	button:SetEnabled(enabled)
	if enabled then
		paintButton(button, shell.tint.button, lighten(shell.tint.button), PALETTE.text)
	else
		paintButton(button, PALETTE.disabledButton, nil, PALETTE.disabled)
	end
end

-- The corner control: × with no game, Cancel in a translucent pill during one.
local function setCorner(live)
	local corner = shell.corner
	corner.live = live
	if live then
		corner.label:SetFontObject(GameFontHighlight)
		corner.label:SetText(TEXT.cancel)
		corner:SetSize(corner.label:GetStringWidth() + 2 * LAYOUT.cornerInset, 22)
		paintButton(corner, PALETTE.pill, PALETTE.pillHover, PALETTE.text)
	else
		corner.label:SetFontObject(GameFontNormalLarge)
		corner.label:SetText(TEXT.close)
		corner:SetSize(24, 24)
		paintButton(corner, nil, nil, PALETTE.text)
	end
end

-- List box (visual.md 4.4): used by 03 and 04. See the file comment.
-- The inline ignore goes away when package 08 adds the first caller.

local function newListBox(parent) -- luacheck: ignore 211
	local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	frame:SetBackdrop(BACKDROP)
	frame:SetBackdropColor(unpack(PALETTE.box))
	frame:SetBackdropBorderColor(unpack(PALETTE.border))

	local scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
	scroll:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -(LAYOUT.scrollBarWidth + 5), 1)
	local scrollBar = scroll.ScrollBar
	if scrollBar then -- keep the bar inside the box, right of the rows
		scrollBar:ClearAllPoints()
		scrollBar:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -2, -(LAYOUT.scrollBarWidth + 1))
		scrollBar:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -2, LAYOUT.scrollBarWidth + 1)
	end

	local content = CreateFrame("Frame", nil, scroll)
	content:SetSize(1, 1)
	scroll:SetScrollChild(content)
	scroll:SetScript("OnSizeChanged", function(_, width)
		content:SetWidth(width)
	end)

	local box = { frame = frame, scroll = scroll, content = content, rows = {} }

	function box:Layout(count, makeRow)
		for i = 1, count do
			local row = self.rows[i]
			if not row then
				row = makeRow(self.content, i)
				row:SetHeight(LAYOUT.rowHeight)
				row:SetPoint("TOPLEFT", self.content, "TOPLEFT", 0, -(i - 1) * LAYOUT.rowHeight)
				row:SetPoint("RIGHT", self.content, "RIGHT", 0, 0)
				self.rows[i] = row
			end
			row:Show()
		end
		for i = count + 1, #self.rows do
			self.rows[i]:Hide()
		end
		self.content:SetHeight(math.max(count * LAYOUT.rowHeight, 1))
		return self.rows
	end

	return box
end

-- The resize grip: the size-grabber texture, or three diagonal rows of dots
-- in the muted colour when the client lacks it (IG-06-12).
local function drawGrip(grip)
	local texture = grip:CreateTexture(nil, "ARTWORK")
	texture:SetAllPoints()
	local ok = texture:SetTexture(GRIP_TEXTURE)
	if ok ~= false and texture:GetTexture() then
		return
	end
	texture:Hide()
	local dot = 2
	local step = 4
	for line = 1, 3 do
		for i = 1, line do
			local square = colourTexture(grip, "ARTWORK", PALETTE.muted)
			square:SetSize(dot, dot)
			-- the lines run from the bottom-right corner up and to the left
			local x = -(2 + (line - i) * step)
			local y = 2 + (i - 1) * step
			square:SetPoint("BOTTOMRIGHT", grip, "BOTTOMRIGHT", x, y)
		end
	end
end

local function cancel()
	local ok, cancelError = ns.Host.Cancel()
	if not ok then
		ns.Print(cancelError)
	end
end

-- Builds the window once. Needs UnitFactionGroup and UnitName, so it runs on
-- the first UI.Show() or the first Host change, never at file load.
local function ensureBuilt()
	if shell.window then
		return
	end
	local p = LAYOUT.padding

	local faction = UnitFactionGroup("player") -- [P0-FACTION]
	if faction ~= "Alliance" and faction ~= "Horde" then
		faction = nil
	end
	shell.faction = faction
	shell.tint = ns.View.TINT[faction or "Alliance"]
	shell.host = Ambiguate(UnitName("player"), "short")

	local window = CreateFrame("Frame", nil, UIParent, "BackdropTemplate") -- [P0-TEMPLATES]
	shell.window = window
	window:SetSize(LAYOUT.width, LAYOUT.height)
	window:SetPoint("CENTER")
	window:SetFrameStrata("DIALOG")
	window:SetClampedToScreen(true)
	window:SetMovable(true)
	window:SetResizable(true)
	window:SetResizeBounds(LAYOUT.minWidth, LAYOUT.minHeight, LAYOUT.maxWidth, LAYOUT.maxHeight)
	window:EnableMouse(true)
	window:SetBackdrop(BACKDROP)
	window:SetBackdropColor(unpack(PALETTE.window))
	window:SetBackdropBorderColor(unpack(PALETTE.border))
	window:Hide()

	-- 1. Title bar: drag to move.
	local titleBar = CreateFrame("Frame", nil, window)
	shell.titleBar = titleBar
	titleBar:SetPoint("TOPLEFT", window, "TOPLEFT", 1, -1)
	titleBar:SetPoint("TOPRIGHT", window, "TOPRIGHT", -1, -1)
	titleBar:SetHeight(LAYOUT.titleHeight)
	titleBar:EnableMouse(true)
	titleBar:RegisterForDrag("LeftButton")
	titleBar:SetScript("OnDragStart", function()
		window:StartMoving()
	end)
	titleBar:SetScript("OnDragStop", function()
		window:StopMovingOrSizing()
	end)
	colourTexture(titleBar, "BACKGROUND", shell.tint.title):SetAllPoints()

	local title = titleBar:CreateFontString(nil, "OVERLAY")
	title:SetFontObject(GameFontNormalLarge)
	title:SetTextColor(unpack(PALETTE.text))
	title:SetText(TEXT.title)
	if faction then
		local icon = titleBar:CreateTexture(nil, "ARTWORK")
		icon:SetSize(LAYOUT.iconSize, LAYOUT.iconSize)
		icon:SetPoint("LEFT", titleBar, "LEFT", p, 0)
		icon:SetTexture(ICON_TEXTURE .. faction)
		title:SetPoint("LEFT", icon, "RIGHT", 8, 0)
	else
		title:SetPoint("LEFT", titleBar, "LEFT", p, 0)
	end

	local corner = newFlatButton(titleBar, GameFontNormalLarge)
	shell.corner = corner
	corner:SetPoint("RIGHT", titleBar, "RIGHT", -LAYOUT.cornerInset, 0)
	corner:SetScript("OnClick", function(self)
		if self.live then
			cancel()
		else
			UI.Hide()
		end
	end)

	-- 4. Footer: the faction name under the main button.
	local footer = window:CreateFontString(nil, "OVERLAY")
	shell.footer = footer
	footer:SetFontObject(GameFontDisable)
	footer:SetTextColor(unpack(PALETTE.muted))
	footer:SetText(faction or TEXT.neutral)
	footer:SetPoint("BOTTOM", window, "BOTTOM", 0, p)

	-- 3. Main button: one button whose label reads by state.
	local mainButton = newFlatButton(window, GameFontNormalLarge)
	shell.mainButton = mainButton
	mainButton:SetHeight(LAYOUT.buttonHeight)
	mainButton:SetPoint("LEFT", window, "LEFT", p, 0)
	mainButton:SetPoint("RIGHT", window, "RIGHT", -p, 0)
	mainButton:SetPoint("BOTTOM", footer, "TOP", 0, p)
	mainButton:SetScript("OnClick", function()
		if shown then
			onMain[shown]()
		end
	end)

	-- 2. Content area: one frame per state between the title bar and the main button.
	shell.content = {}
	for _, state in ipairs({ "form", "lobby", "rolling", "winner" }) do
		local frame = CreateFrame("Frame", nil, window)
		frame:SetPoint("TOPLEFT", titleBar, "BOTTOMLEFT", p, -p)
		frame:SetPoint("BOTTOMRIGHT", mainButton, "TOPRIGHT", 0, p)
		frame:Hide()
		shell.content[state] = frame
		build[state](frame)
	end

	-- 5. Resize grip.
	local grip = CreateFrame("Button", nil, window)
	shell.grip = grip
	grip:SetSize(LAYOUT.gripSize, LAYOUT.gripSize)
	grip:SetPoint("BOTTOMRIGHT", window, "BOTTOMRIGHT", -1, 1)
	grip:SetFrameLevel(window:GetFrameLevel() + 5)
	grip:SetScript("OnMouseDown", function()
		window:StartSizing("BOTTOMRIGHT")
	end)
	grip:SetScript("OnMouseUp", function()
		window:StopMovingOrSizing()
	end)
	drawGrip(grip)

	-- Between ticks, redraw at most every 0.1 s while a game is live so the
	-- bars move smoothly. OnUpdate only runs while the window is shown.
	local sinceRedraw = 0
	window:SetScript("OnUpdate", function(_, elapsed)
		if shown ~= "lobby" and shown ~= "rolling" then
			return
		end
		sinceRedraw = sinceRedraw + elapsed
		if sinceRedraw >= 0.1 then
			sinceRedraw = 0
			redraw(GetTime())
		end
	end)
end

function redraw(now)
	local state = ns.View.State(game)
	if state == "form" then
		game = nil -- a cancelled game is forgotten
	end
	if state ~= shown then
		for _, frame in pairs(shell.content) do
			frame:Hide()
		end
		shell.content[state]:Show()
		setCorner(state ~= "form" and state ~= "winner")
		setMainButton(MAIN[state].label, MAIN[state].enabled)
		shown = state
	end
	draw[state](game, now)
	if state == "lobby" and not shell.window:IsShown() then
		shell.window:Show() -- a game started while the window was hidden
	end
end

function onMain.winner()
	game = nil
	redraw(GetTime())
end

function UI.Show()
	ensureBuilt()
	redraw(GetTime())
	shell.window:Show()
end

-- Does nothing while a game is live (lobby or rolling).
function UI.Hide()
	local state = ns.View.State(game)
	if state ~= "form" and state ~= "winner" then
		return
	end
	if shell.window then
		shell.window:Hide()
	end
end

local events = CreateFrame("Frame")
events:RegisterEvent("PLAYER_LOGIN")
events:SetScript("OnEvent", function(self)
	self:UnregisterAllEvents()
	ns.Host.OnChange(function(g)
		game = g
		ensureBuilt()
		redraw(GetTime())
	end)
end)
