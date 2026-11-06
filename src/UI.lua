local _, ns = ...

-- UI: the host's window (glue). Copies ns.View models into frames and
-- computes no text and no number of its own.
-- Spec: docs/prd/visual/01-window.md (this shell: frame, title bar, the `?`
-- and its hover box, corner, main button, footer, grip, moving, resizing,
-- showing, the state switch and the redraw) and 02-form.md,
-- 03-in-progress.md, 04-winner.md, which fill the build / draw / onMain
-- stubs below, one state each.
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
--   newRow(parent) -> row and paintRow(row, model) (defined in 03's section):
--     a list row and the one painter for every list of players. The model is
--     a View row: { n, name, you } draws a numbered plain row (the lobby);
--     { name, you, value, tag, mark } draws the name, the tag, (you) and the
--     value painted by mark ("", "high", "low", "waiting", "out"). 03 uses it
--     for the lobby and the rolling list; 04 reuses it for the standings and
--     the debt row of the result.
--
--   shell: the built parts. shell.host (the host's short name), shell.faction
--     ("Alliance", "Horde" or nil for neutral), shell.tint (View.TINT entry),
--     shell.window, shell.content[state], shell.mainButton, shell.help,
--     shell.corner, shell.footer. PALETTE and LAYOUT hold every colour and
--     size of visual.md 4.1 and 4.2.

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
	helpSize = 20, -- the ? button, 8 px (cornerInset) left of the corner
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
	help = "?",
	helpTitle = "How it works", -- the hover box's title; its lines are View.Help
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
	form = nil, -- 02-form (package 14): set below
	lobby = nil, -- 03-in-progress (package 15): set below
	rolling = nil, -- 03-in-progress (package 15): set below
	winner = nil, -- 04-winner (package 16): set below
}
local draw = {
	form = nil, -- 02-form (package 14): set below
	lobby = nil, -- 03-in-progress (package 15): set below
	rolling = nil, -- 03-in-progress (package 15): set below
	winner = nil, -- 04-winner (package 16): set below
}
local onMain = {
	form = nil, -- 02-form (package 14): set below
	lobby = function() end, -- nothing: the button is gray
	rolling = nil, -- 03-in-progress (package 15): set below
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

local function newListBox(parent)
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

-- The hover box under the ? (01-window.md): the title, then the six lines of
-- View.Help in white, wrapped. The join word and roll max are the current
-- game's when there is one (live or finished), else Rules.DEFAULTS.
local function showHelp(button)
	local source = game or ns.Rules.DEFAULTS
	GameTooltip:SetOwner(button, "ANCHOR_BOTTOM")
	GameTooltip:AddLine(TEXT.helpTitle)
	for _, line in ipairs(ns.View.Help(source.joinWord, source.rollMax)) do
		GameTooltip:AddLine(line, 1, 1, 1, true)
	end
	GameTooltip:Show()
end

-- 02-form (package 14): the form. Chat, wager, roll max and the note; the
-- main button reads Start. Spec: docs/prd/visual/02-form.md.

-- Exact user-facing text of the form (02-form.md). The note's chat name and
-- numbers come from View.ChatName and Rules.DEFAULTS; so does the roll max
-- default.
local FORM_TEXT = {
	chat = "Chat",
	wager = "Wager per person",
	rollMax = "Roll max",
	hint = "1g, 50s, 1g50s or 1.5g",
	rollMaxHint = "Everyone rolls 1 to this. 100 makes the gap a percentage.",
	note = "Players join by typing %s in %s chat. %s s to join, %s s to roll.",
	wagerDefault = "1g",
}

local CHAT_BUTTONS = {
	{ channel = "GUILD", label = "Guild" },
	{ channel = "PARTY", label = "Party" },
	{ channel = "RAID", label = "Raid" },
}

-- Sizes the shell has no name for.
local FORM_LAYOUT = {
	labelGap = 5, -- label to its input
	chatHeight = 30, -- the chat strip
	boxHeight = 20, -- InputBoxTemplate's art is 20 px tall
	boxArtLeft = 5, -- the template's left art sits this far left of the box
	wagerLetters = 20,
	rollMaxLetters = 7,
}

local form = {} -- the form's parts and its selected channel; filled by build.form

-- A muted label in the body font.
local function newLabel(parent, text)
	local label = parent:CreateFontString(nil, "OVERLAY")
	label:SetFontObject(GameFontHighlight)
	label:SetTextColor(unpack(PALETTE.muted))
	label:SetText(text)
	return label
end

-- An InputBoxTemplate edit box, full content width, auto-focus off
-- [P0-TEMPLATES], over a box-coloured background (visual.md 4.2).
local function newEditBox(parent, maxLetters)
	local box = CreateFrame("EditBox", nil, parent, "InputBoxTemplate")
	box:SetAutoFocus(false)
	box:SetMaxLetters(maxLetters)
	box:SetHeight(FORM_LAYOUT.boxHeight)
	local bg = colourTexture(box, "BACKGROUND", PALETTE.box)
	bg:SetDrawLayer("BACKGROUND", -1) -- under the template's border art
	bg:SetPoint("TOPLEFT", box, "TOPLEFT", -FORM_LAYOUT.boxArtLeft, 0)
	bg:SetPoint("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
	box:SetScript("OnEnterPressed", function()
		onMain.form()
	end)
	return box
end

-- Selects a chat: paints the three buttons and rewrites the note.
local function selectChat(channel)
	form.channel = channel
	for _, button in ipairs(form.chatButtons) do
		if button.channel == channel then
			paintButton(button, shell.tint.title, lighten(shell.tint.title), PALETTE.text)
		else
			paintButton(button, PALETTE.box, lighten(PALETTE.box), PALETTE.muted)
		end
	end
	local defaults = ns.Rules.DEFAULTS
	form.note:SetText(string.format(
		FORM_TEXT.note,
		defaults.joinWord,
		ns.View.ChatName(channel),
		defaults.joinTime,
		defaults.rollTime
	))
end

-- A hint in the hint font, muted, under an edit box.
local function newHint(parent, box, text)
	local hint = parent:CreateFontString(nil, "OVERLAY")
	hint:SetFontObject(GameFontDisable)
	hint:SetTextColor(unpack(PALETTE.muted))
	hint:SetText(text)
	hint:SetPoint("TOPLEFT", box, "BOTTOMLEFT", -FORM_LAYOUT.boxArtLeft, -FORM_LAYOUT.labelGap)
	hint:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
	hint:SetJustifyH("LEFT")
	return hint
end

function build.form(parent)
	local gap = LAYOUT.gap
	local labelGap = FORM_LAYOUT.labelGap

	-- 1. Chat: three flat buttons in a box-coloured strip.
	local chatLabel = newLabel(parent, FORM_TEXT.chat)
	chatLabel:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)

	local strip = CreateFrame("Frame", nil, parent)
	strip:SetPoint("TOPLEFT", chatLabel, "BOTTOMLEFT", 0, -labelGap)
	strip:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
	strip:SetHeight(FORM_LAYOUT.chatHeight)
	colourTexture(strip, "BACKGROUND", PALETTE.box):SetAllPoints()

	form.chatButtons = {}
	for i, spec in ipairs(CHAT_BUTTONS) do
		local button = newFlatButton(strip, GameFontHighlight)
		button.channel = spec.channel
		button.label:SetText(spec.label)
		button:SetPoint("TOP", strip, "TOP", 0, 0)
		button:SetPoint("BOTTOM", strip, "BOTTOM", 0, 0)
		if i == 1 then
			button:SetPoint("LEFT", strip, "LEFT", 0, 0)
		else
			button:SetPoint("LEFT", form.chatButtons[i - 1], "RIGHT", 0, 0)
		end
		button:SetScript("OnClick", function(self)
			selectChat(self.channel)
		end)
		form.chatButtons[i] = button
	end
	local function sizeChatButtons(_, width)
		local each = width / #form.chatButtons
		for _, button in ipairs(form.chatButtons) do
			button:SetWidth(each)
		end
	end
	strip:SetScript("OnSizeChanged", sizeChatButtons)
	if strip:GetWidth() > 0 then
		sizeChatButtons(strip, strip:GetWidth())
	end

	-- 2. Wager per person: an edit box with a hint under it.
	local wagerLabel = newLabel(parent, FORM_TEXT.wager)
	wagerLabel:SetPoint("TOPLEFT", strip, "BOTTOMLEFT", 0, -gap)

	local wagerBox = newEditBox(parent, FORM_LAYOUT.wagerLetters)
	form.wagerBox = wagerBox
	wagerBox:SetPoint("TOPLEFT", wagerLabel, "BOTTOMLEFT", FORM_LAYOUT.boxArtLeft, -labelGap)
	wagerBox:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
	wagerBox:SetText(FORM_TEXT.wagerDefault)

	local hint = newHint(parent, wagerBox, FORM_TEXT.hint)

	-- 3. Roll max: a numeric edit box with a hint under it.
	local rollMaxLabel = newLabel(parent, FORM_TEXT.rollMax)
	rollMaxLabel:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -gap)

	local rollMaxBox = newEditBox(parent, FORM_LAYOUT.rollMaxLetters)
	form.rollMaxBox = rollMaxBox
	rollMaxBox:SetNumeric(true)
	rollMaxBox:SetPoint("TOPLEFT", rollMaxLabel, "BOTTOMLEFT", FORM_LAYOUT.boxArtLeft, -labelGap)
	rollMaxBox:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
	rollMaxBox:SetText(tostring(ns.Rules.DEFAULTS.rollMax))

	newHint(parent, rollMaxBox, FORM_TEXT.rollMaxHint)

	-- 4. The note, anchored above the main button.
	local note = parent:CreateFontString(nil, "OVERLAY")
	form.note = note
	note:SetFontObject(GameFontDisable)
	note:SetTextColor(unpack(PALETTE.muted))
	note:SetJustifyH("LEFT")
	note:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
	note:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

	selectChat(CHAT_BUTTONS[1].channel)
end

-- The form's values are its own, not the game's: nothing to copy, only the
-- selected chat's paint and the note to refresh.
function draw.form()
	selectChat(form.channel)
end

-- Start: what /dr g <wager> [roll max] does. Errors print through ns.Print.
function onMain.form()
	local opts, optsError = ns.View.StartOpts(form.channel, form.wagerBox:GetText(), form.rollMaxBox:GetText())
	if not opts then
		ns.Print(optsError)
		return
	end
	local ok, startError = ns.Host.Start(opts)
	if not ok then
		ns.Print(startError)
	end
end

-- 03-in-progress (package 15): the lobby and the rolling round. The
-- countdown, the join bar and who joined; then who is still to roll, the
-- highest and lowest so far, the rest, the roll bar and the Roll button.
-- Spec: docs/prd/visual/03-in-progress.md.

-- Exact user-facing text of the lobby and rolling states (03-in-progress.md).
-- The header, status lines, values, tags and button label come from
-- View.Lobby / View.Game.
local PROGRESS_TEXT = {
	secondsLeft = "SECONDS LEFT TO JOIN",
	joined = "Joined",
	you = "(you)",
	number = "%d.",
}

-- Sizes the shell has no name for.
local PROGRESS_LAYOUT = {
	rowInset = 8, -- row text to the row's edges
	numberWidth = 24, -- the row number column (lobby rows only)
	tagGap = 6, -- name to its tag, tag to (you)
	labelGap = 4, -- countdown number to its label; status line to the bar
	tagAlpha = 0.85, -- the tag on a tinted row: white at reduced alpha
}

local lobby = {} -- the lobby's parts; filled by build.lobby
local rolling = {} -- the rolling parts, the last drawn game and max; filled by build.rolling

-- A FontString in a font object and colour.
local function newText(parent, fontObject, colour)
	local text = parent:CreateFontString(nil, "OVERLAY")
	text:SetFontObject(fontObject)
	text:SetTextColor(unpack(colour))
	return text
end

-- A progress bar (visual.md 4.4): 6 px high, track in box, fill in tint
-- button, no text. Its value is the view model's fraction, 0..1.
local function newProgressBar(parent)
	local bar = CreateFrame("StatusBar", nil, parent)
	bar:SetHeight(LAYOUT.barHeight)
	colourTexture(bar, "BACKGROUND", PALETTE.box):SetAllPoints()
	bar:SetStatusBarTexture(WHITE8X8)
	bar:SetStatusBarColor(unpack(shell.tint.button))
	bar:SetMinMaxValues(0, 1)
	bar:SetValue(0)
	return bar
end

-- "|cffrrggbb" for a { r, g, b } colour.
local function colourCode(colour)
	return ("|cff%02x%02x%02x"):format(
		math.floor(colour[1] * 255 + 0.5),
		math.floor(colour[2] * 255 + 0.5),
		math.floor(colour[3] * 255 + 0.5)
	)
end

-- The lobby status with its join word (the one between spaces) wrapped in
-- the tint's colour code.
local function highlightWord(text, word, colour)
	local s, e = text:find(" " .. word .. " ", 1, true)
	if not s then
		return text
	end
	return text:sub(1, s) .. colourCode(colour) .. word .. "|r" .. text:sub(e)
end

-- A header row (visual.md 4.4): a label at the left and a count at the
-- right, both muted, anchored under `above` with the stacking gap.
local function newHeader(parent, above)
	local gap = LAYOUT.gap
	local label = newText(parent, GameFontHighlight, PALETTE.muted)
	label:SetPoint("TOPLEFT", above, "BOTTOMLEFT", 0, -gap)
	local count = newText(parent, GameFontHighlight, PALETTE.muted)
	count:SetPoint("TOPRIGHT", above, "BOTTOMRIGHT", 0, -gap)
	count:SetJustifyH("RIGHT")
	return label, count
end

-- A list row (visual.md 4.4): an optional number (lobby rows), the name, an
-- optional tag and `(you)` after it, and a right-aligned value, over a
-- background shown on a highest or lowest row. Rows are created by
-- box:Layout on the first draw that needs them and reused; paintRow sets
-- every field on every draw.
local function newRow(parent)
	local row = CreateFrame("Frame", nil, parent)
	local inset = PROGRESS_LAYOUT.rowInset
	row.bg = colourTexture(row, "BACKGROUND", shell.tint.title)
	row.bg:SetAllPoints()
	row.bg:Hide()

	row.number = newText(row, GameFontHighlight, PALETTE.muted)
	row.number:SetPoint("LEFT", row, "LEFT", inset, 0)
	row.number:SetWidth(PROGRESS_LAYOUT.numberWidth)
	row.number:SetJustifyH("LEFT")
	row.name = newText(row, GameFontHighlight, PALETTE.text)
	row.tag = newText(row, GameFontHighlight, PALETTE.muted)
	row.tag:SetPoint("LEFT", row.name, "RIGHT", PROGRESS_LAYOUT.tagGap, 0)
	row.tag:Hide()
	row.you = newText(row, GameFontHighlight, PALETTE.muted)
	row.you:SetText(PROGRESS_TEXT.you)
	row.you:Hide()
	row.value = newText(row, GameFontHighlight, PALETTE.muted)
	row.value:SetPoint("RIGHT", row, "RIGHT", -inset, 0)
	row.value:SetJustifyH("RIGHT")
	return row
end

-- The tag on a tinted row: white at reduced alpha.
local TAG_ON_TINT = { PALETTE.text[1], PALETTE.text[2], PALETTE.text[3], PROGRESS_LAYOUT.tagAlpha }

-- How a row is painted by its mark (03-in-progress.md, "Rolling"): the
-- background colour (nil for none) and the colours of the name, the tag,
-- (you) and the value. A row with no mark (the lobby) is plain.
local function rowColours(mark)
	local white = PALETTE.text
	if mark == "high" or mark == "low" then
		return (mark == "high") and shell.tint.title or shell.tint.low, white, TAG_ON_TINT, white, white
	elseif mark == "waiting" or mark == "out" then
		return nil, PALETTE.disabled, PALETTE.muted, PALETTE.muted, PALETTE.disabled
	end
	return nil, PALETTE.text, PALETTE.muted, PALETTE.muted, PALETTE.muted
end

-- Copies one view model row into a row frame. Serves the lobby (rows
-- { n, name, you }: numbered, plain), the rolling list (rows { name, you,
-- value, tag, mark }: no number, painted by mark) and the result (the same
-- without a tag; 04 paints its debt row through it too).
local function paintRow(row, model)
	row.name:ClearAllPoints()
	if model.n then
		row.number:SetText(PROGRESS_TEXT.number:format(model.n))
		row.number:Show()
		row.name:SetPoint("LEFT", row.number, "RIGHT", 0, 0)
	else
		row.number:Hide()
		row.name:SetPoint("LEFT", row, "LEFT", PROGRESS_LAYOUT.rowInset, 0)
	end
	row.name:SetText(model.name)
	row.value:SetText(model.value or "")

	local tag = model.tag or ""
	row.you:ClearAllPoints()
	if tag ~= "" then
		row.tag:SetText(tag)
		row.tag:Show()
		row.you:SetPoint("LEFT", row.tag, "RIGHT", PROGRESS_LAYOUT.tagGap, 0)
	else
		row.tag:Hide()
		row.you:SetPoint("LEFT", row.name, "RIGHT", PROGRESS_LAYOUT.tagGap, 0)
	end
	if model.you then
		row.you:Show()
	else
		row.you:Hide()
	end

	local bg, nameColour, tagColour, youColour, valueColour = rowColours(model.mark)
	if bg then
		row.bg:SetColorTexture(unpack(bg))
		row.bg:Show()
	else
		row.bg:Hide()
	end
	row.name:SetTextColor(unpack(nameColour))
	row.tag:SetTextColor(unpack(tagColour))
	row.you:SetTextColor(unpack(youColour))
	row.value:SetTextColor(unpack(valueColour))
end

-- A subtitle in the hint font, muted, across the top of a content frame.
local function newSubtitle(parent)
	local subtitle = newText(parent, GameFontDisable, PALETTE.muted)
	subtitle:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, 0)
	subtitle:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, 0)
	subtitle:SetJustifyH("LEFT")
	return subtitle
end

function build.lobby(parent)
	local gap = LAYOUT.gap

	-- 1. Subtitle.
	lobby.subtitle = newSubtitle(parent)

	-- 2. The countdown number and its label, centred.
	lobby.countdown = newText(parent, NumberFontNormalHuge, shell.tint.text)
	lobby.countdown:SetPoint("TOP", lobby.subtitle, "BOTTOM", 0, -gap)
	local label = newText(parent, GameFontDisable, PALETTE.muted)
	label:SetText(PROGRESS_TEXT.secondsLeft)
	label:SetPoint("TOP", lobby.countdown, "BOTTOM", 0, -PROGRESS_LAYOUT.labelGap)

	-- 3. The join bar.
	lobby.bar = newProgressBar(parent)
	lobby.bar:SetPoint("TOP", label, "BOTTOM", 0, -gap)
	lobby.bar:SetPoint("LEFT", parent, "LEFT", 0, 0)
	lobby.bar:SetPoint("RIGHT", parent, "RIGHT", 0, 0)

	-- 4. The header row: Joined at the left, the count at the right.
	local header
	header, lobby.count = newHeader(parent, lobby.bar)
	header:SetText(PROGRESS_TEXT.joined)

	-- 6. The status line, anchored above the main button, with the join word
	-- in tint text (one string, the word wrapped in the colour code).
	lobby.status = newText(parent, GameFontHighlight, PALETTE.text)
	lobby.status:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
	lobby.status:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
	lobby.status:SetJustifyH("LEFT")

	-- 5. The list box, filling the room down to the status line.
	lobby.list = newListBox(parent)
	lobby.list.frame:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -gap)
	lobby.list.frame:SetPoint("RIGHT", parent, "RIGHT", 0, 0)
	lobby.list.frame:SetPoint("BOTTOMLEFT", lobby.status, "TOPLEFT", 0, gap)
end

function draw.lobby(g, now)
	local model = ns.View.Lobby(g, shell.host, now)
	lobby.subtitle:SetText(model.subtitle)
	lobby.countdown:SetText(model.secondsLeft)
	lobby.bar:SetValue(model.fraction)
	lobby.count:SetText(model.count)
	lobby.status:SetText(highlightWord(model.status, g.joinWord, shell.tint.text))
	local rows = lobby.list:Layout(#model.rows, newRow)
	for i, row in ipairs(model.rows) do
		paintRow(rows[i], row)
	end
end

function build.rolling(parent)
	local gap = LAYOUT.gap

	-- 1. Subtitle.
	rolling.subtitle = newSubtitle(parent)

	-- 2. The header row: the round's label at the left, the count at the right.
	rolling.header, rolling.count = newHeader(parent, rolling.subtitle)

	-- 5. The roll bar, at the bottom.
	rolling.bar = newProgressBar(parent)
	rolling.bar:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", 0, 0)
	rolling.bar:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)

	-- 4. The status line, in tint text, directly over the bar.
	rolling.status = newText(parent, GameFontHighlight, shell.tint.text)
	rolling.status:SetPoint("BOTTOMLEFT", rolling.bar, "TOPLEFT", 0, PROGRESS_LAYOUT.labelGap)
	rolling.status:SetPoint("BOTTOMRIGHT", rolling.bar, "TOPRIGHT", 0, PROGRESS_LAYOUT.labelGap)
	rolling.status:SetJustifyH("LEFT")

	-- 3. The list box, filling the room down to the status line.
	rolling.list = newListBox(parent)
	rolling.list.frame:SetPoint("TOPLEFT", rolling.header, "BOTTOMLEFT", 0, -gap)
	rolling.list.frame:SetPoint("BOTTOMRIGHT", rolling.status, "TOPRIGHT", 0, gap)
end

-- Every redraw repaints every row from the model and sets the main button
-- from button.label and button.enabled. After a click on Roll the button
-- stays gray until that roll has arrived: rolling.pending is the game and
-- round the click was for, and clears on the first draw where the host is
-- no longer waiting, or the game or round has changed (a tie-break the host
-- is in re-enables the button).
function draw.rolling(g, now)
	local model = ns.View.Game(g, shell.host, now)
	rolling.subtitle:SetText(model.subtitle)
	rolling.header:SetText(model.header.label)
	rolling.count:SetText(model.header.count)
	rolling.status:SetText(model.status)
	rolling.bar:SetValue(model.fraction)
	local rows = rolling.list:Layout(#model.rows, newRow)
	for i, row in ipairs(model.rows) do
		paintRow(rows[i], row)
	end

	local pending = rolling.pending
	if pending and (not model.button.enabled or pending.game ~= g or pending.round ~= g.round) then
		rolling.pending = nil
	end
	rolling.game = g
	rolling.round = g.round
	rolling.label = model.button.label
	rolling.max = model.button.max
	setMainButton(model.button.label, model.button.enabled and not rolling.pending)
end

-- Roll: RandomRoll(1, max) with the max from the last draw [P0-CLICKROLL];
-- the button is gray until the roll result arrives, so a second click before
-- then does nothing.
function onMain.rolling()
	if rolling.pending then
		return
	end
	rolling.pending = { game = rolling.game, round = rolling.round }
	setMainButton(rolling.label, false)
	RandomRoll(1, rolling.max)
end


-- 04-winner (package 16): the result until Reset. The winner and their roll,
-- the final standings and the one debt; the main button reads Reset and 01
-- handles the click (onMain.winner below). Spec: docs/prd/visual/04-winner.md.

-- Exact user-facing text of the winner state (04-winner.md). The winner's
-- name and roll, the row values and the debt come from View.Result.
local WINNER_TEXT = {
	label = "WINNER",
}

-- Sizes the shell has no name for.
local WINNER_LAYOUT = {
	labelGap = 4, -- the WINNER label to the name under it
	rollGap = 10, -- the winner's name to their roll at the right
}

local winner = {} -- the winner's parts; filled by build.winner

-- A row of the result list: a standings row (03's newRow, painted by
-- paintRow) with a 1 px line along its top in the border colour that only
-- the debt row shows. Rows are created by box:Layout on the first draw that
-- needs them and reused, so every draw sets every field.
local function newWinnerRow(parent)
	local row = newRow(parent)
	row.line = colourTexture(row, "ARTWORK", PALETTE.border)
	row.line:SetHeight(1)
	row.line:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
	row.line:SetPoint("TOPRIGHT", row, "TOPRIGHT", 0, 0)
	row.line:Hide()
	return row
end

-- The last row: the debt text at the left with (you) after it when the host
-- is the loser, the amount right-aligned, both in text colour, and the line
-- above. Painted as a plain standings row, then the amount's colour and the
-- line set on top.
local function paintDebt(row, debt)
	paintRow(row, { name = debt.text, you = debt.you, value = debt.amount, mark = "" })
	row.value:SetTextColor(unpack(PALETTE.text))
	row.line:Show()
end

function build.winner(parent)
	local gap = LAYOUT.gap

	-- 1. Subtitle.
	winner.subtitle = newSubtitle(parent)

	-- 2. The WINNER label, muted and small, with the winner's name under it
	-- in the big font and tint text at the left and their roll in the same
	-- font and colour, right-aligned on the same line.
	local label = newText(parent, GameFontDisable, PALETTE.muted)
	label:SetText(WINNER_TEXT.label)
	label:SetPoint("TOPLEFT", winner.subtitle, "BOTTOMLEFT", 0, -gap)
	winner.roll = newText(parent, GameFontNormalHuge, shell.tint.text)
	winner.roll:SetJustifyH("RIGHT")
	winner.name = newText(parent, GameFontNormalHuge, shell.tint.text)
	winner.name:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -WINNER_LAYOUT.labelGap)
	winner.name:SetPoint("RIGHT", winner.roll, "LEFT", -WINNER_LAYOUT.rollGap, 0)
	winner.name:SetJustifyH("LEFT")
	winner.roll:SetPoint("TOP", winner.name, "TOP", 0, 0)
	winner.roll:SetPoint("RIGHT", parent, "RIGHT", 0, 0)

	-- 3. The list box, filling the room down to the main button.
	winner.list = newListBox(parent)
	winner.list.frame:SetPoint("TOPLEFT", winner.name, "BOTTOMLEFT", 0, -gap)
	winner.list.frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", 0, 0)
end

-- The standings painted by mark, then the debt as the last row of the same
-- list.
function draw.winner(g)
	local model = ns.View.Result(g, shell.host)
	winner.subtitle:SetText(model.subtitle)
	winner.name:SetText(model.winner)
	winner.roll:SetText(model.winningRoll)
	local rows = winner.list:Layout(#model.rows + 1, newWinnerRow)
	for i, row in ipairs(model.rows) do
		paintRow(rows[i], row)
		rows[i].line:Hide()
	end
	paintDebt(rows[#model.rows + 1], model.debt)
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

	-- The ? help button: a translucent white pill like Cancel's, 8 px left of
	-- the corner, present in every state; hovering shows the hover box.
	local help = newFlatButton(titleBar, GameFontHighlight)
	shell.help = help
	help:SetSize(LAYOUT.helpSize, LAYOUT.helpSize)
	help:SetPoint("RIGHT", corner, "LEFT", -LAYOUT.cornerInset, 0)
	help.label:SetText(TEXT.help)
	paintButton(help, PALETTE.pill, PALETTE.pillHover, PALETTE.text)
	help:HookScript("OnEnter", showHelp)
	help:HookScript("OnLeave", function()
		GameTooltip:Hide()
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
