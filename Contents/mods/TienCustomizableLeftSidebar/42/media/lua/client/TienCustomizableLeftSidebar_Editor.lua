require "ISUI/ISCollapsableWindow"
require "ISUI/ISPanel"
require "ISUI/ISButton"
require "ISUI/ISComboBox"
require "ISUI/ISModalDialog"
require "RadioCom/ISUIRadio/ISSliderPanel"
require "TienCustomizableLeftSidebar_Core"

local Mod = TienCustomizableLeftSidebar

Mod.Editor = {}

local Editor = Mod.Editor

local FONT_HGT_SMALL = getTextManager():getFontHeight(UIFont.Small)
local FONT_HGT_MEDIUM = getTextManager():getFontHeight(UIFont.Medium)
local PAD = 10
local BUTTON_HGT = FONT_HGT_SMALL + 6
local ROW_HGT = math.max(44, FONT_HGT_MEDIUM + FONT_HGT_SMALL + 10)
local ICON_X = 30
local ICON_H = ROW_HGT - 10
local ICON_W = math.floor(ICON_H * 4 / 3)
local EYE_W = 35
local EYE_H = 20
local DRAG_THRESHOLD = 5
local AUTOSCROLL_EDGE = 24
local AUTOSCROLL_STEP = 6
local SLIDER_W = 170
local COMBO_W = 170
local MIN_WIDTH = 400
local WHITE = { r = 1, g = 1, b = 1, a = 1 }

local function txt(key, ...)
    return getText("IGUI_TienCustomizableLeftSidebar_" .. key, ...)
end

local function measure(text, font)
    return getTextManager():MeasureStringX(font or UIFont.Small, text)
end

local function shorten(text, font, width)
    if measure(text, font) <= width then
        return text
    end
    local cut = text
    while #cut > 1 and measure(cut .. "...", font) > width do
        cut = string.sub(cut, 1, -2)
    end
    return cut .. "..."
end

local List = ISPanel:derive("TienCustomizableLeftSidebar_List")

function List:new(x, y, width, height, editor)
    local o = ISPanel.new(self, x, y, width, height)
    o.editor = editor
    o.background = false
    o.eyeOn = getTexture("media/ui/foraging/eyeconOn.png")
    o.eyeOff = getTexture("media/ui/foraging/eyeconOff.png")
    o.press = nil
    o.dragging = nil
    o.shortNames = {}
    return o
end

function List:createChildren()
    ISPanel.createChildren(self)
    self:addScrollBars()
end

function List:rowWidth()
    if self:isVScrollBarVisible() then
        return self.width - self.vscroll:getWidth()
    end
    return self.width
end

function List:eyeX()
    return self:rowWidth() - EYE_W - PAD
end

function List:isOverEye(x)
    local ex = self:eyeX()
    return x >= ex - 4 and x <= ex + EYE_W + 4
end

function List:clampScroll()
    local max = math.max(0, self:getScrollHeight() - self.height)
    local y = self:getYScroll()
    if y < -max then
        self:setYScroll(-max)
    elseif y > 0 then
        self:setYScroll(0)
    end
end

function List:onMouseWheel(del)
    self:setYScroll(self:getYScroll() - del * ROW_HGT)
    self:clampScroll()
    return true
end

function List:entries()
    if self.dragging then
        return self.dragging.entries
    end
    return self.editor.entries or {}
end

function List:onMouseDown(x, y)
    local entries = self:entries()
    local index = math.floor(y / ROW_HGT) + 1
    local entry = entries[index]
    if not entry then
        return true
    end
    if self:isOverEye(x) then
        local settings = Mod.Settings()
        Mod.SetHidden(entry.id, not settings.hidden[entry.id])
        getSoundManager():playUISound("UIToggleTickBox")
        return true
    end
    self.press = { entry = entry, index = index, mouseY = getMouseY(), grab = y - (index - 1) * ROW_HGT }
    return true
end

function List:checkDrag()
    local press = self.press
    if not press or self.dragging then
        return
    end
    if not isMouseButtonDown(0) then
        self.press = nil
        return
    end
    if math.abs(getMouseY() - press.mouseY) < DRAG_THRESHOLD then
        return
    end
    local entries = Mod.Copy(self.editor.entries or {})
    local present = {}
    for i, entry in ipairs(entries) do
        present[i] = entry.id
    end
    self.dragging = {
        id = press.entry.id,
        entry = press.entry,
        entries = entries,
        present = present,
        order = Mod.Copy(Mod.Settings().order),
        from = press.index,
        target = press.index,
        grab = press.grab,
    }
    self:setCapture(true)
    getSoundManager():playUISound("UISelectListItem")
end

function List:onMouseMove(dx, dy)
    self:checkDrag()
end

function List:onMouseMoveOutside(dx, dy)
    self:checkDrag()
end

function List:finishDrag()
    local drag = self.dragging
    self.dragging = nil
    self.press = nil
    self:setCapture(false)
    Mod.previewOrder = nil
    if not drag then
        return
    end
    if drag.target ~= drag.from then
        Mod.Settings().order = Mod.MoveTo(drag.order, drag.present, drag.id, drag.target)
        Mod.MarkDirty()
    end
end

function List:onMouseUp(x, y)
    if self.dragging then
        self:finishDrag()
        return true
    end
    self.press = nil
    return true
end

function List:onMouseUpOutside(x, y)
    ISPanel.onMouseUpOutside(self, x, y)
    if self.dragging then
        self:finishDrag()
    end
    self.press = nil
end

function List:updateDrag()
    local drag = self.dragging
    if not isMouseButtonDown(0) then
        self:finishDrag()
        return
    end
    local visibleY = self:getMouseY() + self:getYScroll()
    if visibleY < AUTOSCROLL_EDGE then
        self:setYScroll(self:getYScroll() + AUTOSCROLL_STEP)
        self:clampScroll()
    elseif visibleY > self.height - AUTOSCROLL_EDGE then
        self:setYScroll(self:getYScroll() - AUTOSCROLL_STEP)
        self:clampScroll()
    end
    local count = #drag.entries
    local top = self:getMouseY() - drag.grab
    local target = math.floor(top / ROW_HGT + 0.5) + 1
    target = math.max(1, math.min(count, target))
    if target ~= drag.target then
        drag.target = target
        Mod.previewOrder = Mod.MoveTo(drag.order, drag.present, drag.id, target)
    end
end

function List:shortName(entry, width)
    local cache = self.shortNames[entry.id]
    if not cache or cache.name ~= entry.name or cache.width ~= width then
        cache = { name = entry.name, width = width, text = shorten(entry.name, UIFont.Medium, width) }
        self.shortNames[entry.id] = cache
    end
    return cache.text
end

function List:drawGrip(y, alpha)
    local gx = 9
    local gy = y + math.floor(ROW_HGT / 2) - 5
    for i = 0, 2 do
        self:drawRect(gx, gy + i * 4, 12, 2, alpha, 0.85, 0.85, 0.85)
    end
end

function List:drawEntry(entry, y, floating, hovered, mouseX)
    local settings = Mod.Settings()
    local width = self:rowWidth()
    if floating then
        self:drawRect(0, y, width, ROW_HGT, 0.92, 0.12, 0.12, 0.12)
        local c = Mod.Sidebar.HIGHLIGHT
        self:drawRectBorder(0, y, width, ROW_HGT, 1, c.r, c.g, c.b)
    elseif hovered then
        self:drawRect(0, y, width, ROW_HGT, 0.1, 1, 1, 1)
    end
    if not floating then
        self:drawRect(PAD, y + ROW_HGT - 1, width - PAD * 2, 1, 0.12, 1, 1, 1)
    end

    local hidden = settings.hidden[entry.id] == true
    local shown = entry.button:isVisible()
    self:drawGrip(y, (hovered or floating) and 0.9 or 0.45)

    local alpha = 1
    if hidden then
        alpha = 0.3
    elseif not shown then
        alpha = 0.55
    end
    local texture = entry.button.image
    if texture then
        local c = entry.button.textureColor or WHITE
        self:drawTextureScaledAspect(texture, ICON_X, y + math.floor((ROW_HGT - ICON_H) / 2), ICON_W, ICON_H,
            alpha * (c.a or 1), c.r, c.g, c.b)
    end

    local textX = ICON_X + ICON_W + PAD
    local textW = self:eyeX() - PAD - textX
    local name = self:shortName(entry, textW)
    local note = nil
    if hidden then
        note = txt("Hidden")
    elseif not shown then
        note = Mod.Sidebar.NoteOf(entry.button)
    end
    local nameShade = hidden and 0.5 or 1
    if note then
        local top = y + math.floor((ROW_HGT - FONT_HGT_MEDIUM - FONT_HGT_SMALL) / 2)
        self:drawText(name, textX, top, nameShade, nameShade, nameShade, 1, UIFont.Medium)
        self:drawText(shorten(note, UIFont.Small, textW), textX, top + FONT_HGT_MEDIUM, 0.65, 0.65, 0.65, 1,
            UIFont.Small)
    else
        self:drawText(name, textX, y + math.floor((ROW_HGT - FONT_HGT_MEDIUM) / 2), 1, 1, 1, 1, UIFont.Medium)
    end

    local eye = hidden and self.eyeOff or self.eyeOn
    if eye then
        local overEye = hovered and mouseX and self:isOverEye(mouseX)
        local eyeAlpha = overEye and 1 or (hidden and 0.75 or 0.85)
        self:drawTextureScaled(eye, self:eyeX(), y + math.floor((ROW_HGT - EYE_H) / 2), EYE_W, EYE_H, eyeAlpha,
            1, 1, 1)
    end
end

function List:prerender()
    if self.dragging then
        self:updateDrag()
    end
    local entries = self:entries()
    local count = #entries
    self:setScrollHeight(count * ROW_HGT)
    self:clampScroll()

    self:drawRect(0, -self:getYScroll(), self.width, self.height, 0.45, 0, 0, 0)
    self:drawRectBorder(0, -self:getYScroll(), self.width, self.height, 1, 0.4, 0.4, 0.4)
    self:setStencilRect(1, 1, self.width - 2, self.height - 2)

    local mouseX = self:getMouseX()
    local mouseY = self:getMouseY()
    local over = self:isMouseOver()
    local top = -self:getYScroll()
    local bottom = top + self.height
    local drag = self.dragging
    local highlight = nil

    if drag then
        local slot = 0
        for _, entry in ipairs(entries) do
            if entry.id ~= drag.id then
                slot = slot + 1
                local index = slot
                if slot >= drag.target then
                    index = slot + 1
                end
                local y = (index - 1) * ROW_HGT
                if y + ROW_HGT >= top and y <= bottom then
                    self:drawEntry(entry, y, false, false, nil)
                end
            end
        end
        local c = Mod.Sidebar.HIGHLIGHT
        local gapY = (drag.target - 1) * ROW_HGT
        self:drawRect(2, gapY + 2, self:rowWidth() - 4, ROW_HGT - 4, 0.12, c.r, c.g, c.b)
        self:drawRectBorder(2, gapY + 2, self:rowWidth() - 4, ROW_HGT - 4, 0.6, c.r, c.g, c.b)
        local floatY = math.max(0, math.min((count - 1) * ROW_HGT, mouseY - drag.grab))
        self:drawEntry(drag.entry, floatY, true, false, nil)
        highlight = drag.id
    else
        for i, entry in ipairs(entries) do
            local y = (i - 1) * ROW_HGT
            if y + ROW_HGT >= top and y <= bottom then
                local hovered = over and mouseY >= y and mouseY < y + ROW_HGT
                self:drawEntry(entry, y, false, hovered, hovered and mouseX or nil)
                if hovered then
                    highlight = entry.id
                end
            end
        end
    end

    self:clearStencilRect()
    Mod.highlightId = highlight
end

local Window = ISCollapsableWindow:derive("TienCustomizableLeftSidebar_Editor")

function Window:new(x, y)
    local labelW = math.max(measure(txt("Spacing")), measure(txt("EditButton")))
    local controlsW = PAD + labelW + PAD + math.max(SLIDER_W + PAD + measure(txt("Pixels", "40")), COMBO_W) + PAD
    local buttonsW = PAD + measure(txt("ShowAll")) + measure(txt("Reset")) + measure(txt("Close")) + 3 * 24 + 2 * PAD + PAD
    local width = math.max(MIN_WIDTH, controlsW, buttonsW, measure(txt("Hint")) + PAD * 2,
        measure(txt("Tip")) + PAD * 2)
    local o = ISCollapsableWindow.new(self, x, y, width, 300)
    o.title = txt("Title")
    o.resizable = false
    o.labelW = labelW
    o.entries = {}
    o.layoutCount = -1
    return o
end

function Window:createChildren()
    ISCollapsableWindow.createChildren(self)
    local settings = Mod.Settings()

    self.list = List:new(PAD, 0, self.width - PAD * 2, ROW_HGT, self)
    self.list:initialise()
    self:addChild(self.list)

    local controlX = PAD + self.labelW + PAD
    self.gapSlider = ISSliderPanel:new(controlX, 0, SLIDER_W, BUTTON_HGT, self, Window.onGapChange)
    self.gapSlider.doToolTip = false
    self.gapSlider:initialise()
    self:addChild(self.gapSlider)
    self.gapSlider:setValues(Mod.MIN_GAP, Mod.MAX_GAP, 1, 5, true)
    self.gapSlider:setCurrentValue(settings.gap, true)

    self.editCombo = ISComboBox:new(controlX, 0, COMBO_W, BUTTON_HGT, self, Window.onEditModeChange)
    self.editCombo:initialise()
    self:addChild(self.editCombo)
    self.editCombo:addOptionWithData(txt("EditFull"), Mod.EDIT_FULL)
    self.editCombo:addOptionWithData(txt("EditSmall"), Mod.EDIT_SMALL)
    self.editCombo:addOptionWithData(txt("EditHidden"), Mod.EDIT_HIDDEN)
    self.editCombo:selectData(settings.editButton)

    self.showAllButton = self:addButton(txt("ShowAll"), Window.onShowAll)
    self.resetButton = self:addButton(txt("Reset"), Window.onReset)
    self.doneButton = self:addButton(txt("Close"), Window.onDone)

    self:refreshEntries()
    self:layoutControls()
end

function Window:addButton(title, onclick)
    local button = ISButton:new(0, 0, measure(title) + 24, BUTTON_HGT, title, self, onclick)
    button:initialise()
    button:instantiate()
    self:addChild(button)
    return button
end

function Window:refreshEntries()
    self.entries = Mod.Sidebar.Entries(Mod.Sidebar.Get())
end

function Window:layoutControls()
    local count = #self.entries
    local maxRows = math.max(3, math.floor((getCore():getScreenHeight() - 300) / ROW_HGT))
    local rows = math.max(1, math.min(count, maxRows))

    local y = self:titleBarHeight() + PAD
    self.hintY = y
    y = y + FONT_HGT_SMALL + 6
    self.list:setY(y)
    self.list:setHeight(rows * ROW_HGT)
    y = self.list:getBottom() + PAD

    self.gapSlider:setY(y)
    self.gapLabelY = y + math.floor((BUTTON_HGT - FONT_HGT_SMALL) / 2)
    y = y + BUTTON_HGT + 6

    self.editCombo:setY(y)
    self.editLabelY = y + math.floor((BUTTON_HGT - FONT_HGT_SMALL) / 2)
    y = y + BUTTON_HGT + PAD

    self.tipY = y
    y = y + FONT_HGT_SMALL + PAD

    local x = self.width - PAD
    for _, button in ipairs({ self.doneButton, self.resetButton, self.showAllButton }) do
        x = x - button:getWidth()
        button:setX(x)
        button:setY(y)
        x = x - PAD
    end
    y = y + BUTTON_HGT + PAD

    self:setHeight(y)
    self.layoutCount = count
    local maxY = getCore():getScreenHeight() - y - 10
    if self:getY() > maxY then
        self:setY(math.max(0, maxY))
    end
end

function Window:prerender()
    Mod.highlightId = nil
    self:refreshEntries()
    if #self.entries ~= self.layoutCount then
        self:layoutControls()
    end
    ISCollapsableWindow.prerender(self)
end

function Window:render()
    ISCollapsableWindow.render(self)
    if self.isCollapsed then
        return
    end
    self:drawText(txt("Hint"), PAD, self.hintY, 0.85, 0.85, 0.85, 1, UIFont.Small)
    if #self.entries == 0 then
        self:drawText(txt("NoButtons"), PAD * 2, self.list:getY() + math.floor((ROW_HGT - FONT_HGT_SMALL) / 2),
            0.65, 0.65, 0.65, 1, UIFont.Small)
    end
    self:drawText(txt("Spacing"), PAD, self.gapLabelY, 1, 1, 1, 1, UIFont.Small)
    self:drawText(txt("Pixels", string.format("%d", Mod.Settings().gap)), self.gapSlider:getRight() + PAD,
        self.gapLabelY, 0.85, 0.85, 0.85, 1, UIFont.Small)
    self:drawText(txt("EditButton"), PAD, self.editLabelY, 1, 1, 1, 1, UIFont.Small)
    self:drawText(txt("Tip"), PAD, self.tipY, 0.65, 0.65, 0.65, 1, UIFont.Small)
end

function Window:onGapChange(value)
    local settings = Mod.Settings()
    local gap = Mod.ClampGap(value)
    if settings.gap ~= gap then
        settings.gap = gap
        Mod.MarkDirty()
    end
end

function Window:onEditModeChange(combo)
    local mode = combo:getOptionData(combo.selected)
    if Mod.IsEditMode(mode) then
        Mod.Settings().editButton = mode
        Mod.MarkDirty()
    end
end

function Window:onShowAll()
    Mod.ShowAll()
end

function Window:onReset()
    local w, h = 360, 150
    local modal = ISModalDialog:new((getCore():getScreenWidth() - w) / 2, (getCore():getScreenHeight() - h) / 2, w, h,
        txt("ResetConfirm"), true, self, Window.onResetConfirm)
    modal:initialise()
    modal:addToUIManager()
    modal:bringToTop()
end

function Window:onResetConfirm(button)
    if button.internal ~= "YES" then
        return
    end
    Mod.Sidebar.Reset()
    local settings = Mod.Settings()
    self.gapSlider:setCurrentValue(settings.gap, true)
    self.editCombo:selectData(settings.editButton)
end

function Window:onDone()
    self:close()
end

function Window:close()
    if self.list then
        self.list:finishDrag()
    end
    Mod.previewOrder = nil
    Mod.highlightId = nil
    Mod.SaveIfDirty()
    self:setVisible(false)
    self:removeFromUIManager()
    if Editor.instance == self then
        Editor.instance = nil
    end
end

function Editor.IsOpen()
    return Editor.instance ~= nil
end

function Editor.Open()
    if Editor.instance then
        Editor.instance:setVisible(true)
        Editor.instance:bringToTop()
        return
    end
    local sidebar = Mod.Sidebar.Get()
    if not sidebar then
        return
    end
    local x = sidebar:getAbsoluteX() + sidebar:getWidth() + 30
    local y = sidebar:getAbsoluteY()
    local window = Window:new(x, y)
    window:initialise()
    window:addToUIManager()
    local maxX = getCore():getScreenWidth() - window:getWidth() - 10
    if window:getX() > maxX then
        window:setX(math.max(0, maxX))
    end
    Editor.instance = window
end

function Editor.Close()
    if Editor.instance then
        Editor.instance:close()
    end
end

function Editor.Toggle()
    if Editor.instance then
        Editor.Close()
    else
        Editor.Open()
    end
end
