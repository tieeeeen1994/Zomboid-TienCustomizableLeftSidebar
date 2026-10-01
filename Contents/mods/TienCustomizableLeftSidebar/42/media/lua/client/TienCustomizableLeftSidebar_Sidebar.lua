require "ISUI/ISEquippedItem"
require "ISUI/ISButton"
require "ISUI/ISContextMenu"
require "TienCustomizableLeftSidebar_Core"

local Mod = TienCustomizableLeftSidebar

Mod.Sidebar = {}

local Sidebar = Mod.Sidebar

Sidebar.PARK_Y = -100000
Sidebar.SMALL_SCALE = 0.5
Sidebar.HIGHLIGHT = { r = 1, g = 0.8, b = 0.3 }

local function iconPath(size, state)
    local px = string.format("%d", size)
    return "media/ui/Sidebar/" .. px .. "/TienCustomizableLeftSidebar_" .. state .. "_" .. px .. ".png"
end

local function isButton(element)
    if type(element) ~= "table" then
        return false
    end
    local class = getmetatable(element)
    while class do
        if class == ISButton then
            return true
        end
        class = getmetatable(class)
    end
    return false
end

local function isParked(button)
    return button:getY() <= Sidebar.PARK_Y / 2
end

local function isActive(sidebar)
    if not sidebar.invBtn or not sidebar.offHand then
        return false
    end
    if getCore():getGameMode() == "Tutorial" then
        return false
    end
    local data = getPlayerData(sidebar.playerNum)
    return data ~= nil and data.equipped == sidebar
end

function Sidebar.Get()
    local data = getPlayerData(0)
    local sidebar = data and data.equipped
    if sidebar and isActive(sidebar) then
        return sidebar
    end
    return nil
end

local function cleanText(text)
    if type(text) ~= "string" then
        return nil
    end
    text = (string.gsub(text, "<[^>]*>", " "))
    text = string.match(text, "^[^\n]*") or text
    text = string.match(text, "^%s*(.-)%s*$") or text
    if text == "" then
        return nil
    end
    return text
end

local function tooltipOf(sidebar, button)
    if sidebar.mouseOverList then
        for _, entry in ipairs(sidebar.mouseOverList) do
            if entry.object == button then
                return cleanText(entry.displayString)
            end
        end
    end
    return nil
end

function Sidebar.NameOf(sidebar, button)
    if button.tclsName then
        return button.tclsName
    end
    local key = Mod.NAMES[button.tclsId]
    local name = key and getText(key)
        or tooltipOf(sidebar, button)
        or cleanText(button.tooltip)
        or cleanText(button.title)
        or cleanText(button.internal and tostring(button.internal))
        or button.tclsId
    button.tclsName = name
    return name
end

function Sidebar.NoteOf(button)
    local key = Mod.GAME_NOTES[button.tclsId] or "IGUI_TienCustomizableLeftSidebar_NotShownNow"
    return getText(key)
end

local function identify(sidebar, button, used)
    local id = nil
    for key, value in pairs(sidebar) do
        if value == button and type(key) == "string" and (id == nil or key < id) then
            id = key
        end
    end
    if not id and button.internal then
        id = "internal:" .. tostring(button.internal)
    end
    if not id then
        id = "button"
    end
    local unique = id
    local n = 1
    while used[unique] do
        n = n + 1
        unique = id .. "#" .. string.format("%d", n)
    end
    return unique
end

local function predecessorOf(present, button, inOrder)
    local best = nil
    local y = button:getY()
    for _, other in ipairs(present) do
        if other ~= button and inOrder[other.tclsId] and not isParked(other) then
            local oy = other:getY()
            if oy < y and (best == nil or oy > best:getY()) then
                best = other
            end
        end
    end
    return best
end

local function insertNew(order, id, predecessor, present)
    local index = predecessor and Mod.IndexOf(order, predecessor.tclsId)
    if index then
        table.insert(order, index + 1, id)
        return
    end
    for i, other in ipairs(order) do
        for _, button in ipairs(present) do
            if button.tclsId == other then
                table.insert(order, i, id)
                return
            end
        end
    end
    table.insert(order, id)
end

local function byYThenId(a, b)
    local ay, by = a:getY(), b:getY()
    if ay ~= by then
        return ay < by
    end
    return a.tclsId < b.tclsId
end

local function discover(sidebar)
    local settings = Mod.Settings()
    local present = {}
    local fresh = {}
    local byId = {}
    for _, child in pairs(sidebar:getChildren()) do
        if child ~= sidebar.tclsEditBtn and isButton(child) then
            table.insert(present, child)
            if child.tclsId then
                byId[child.tclsId] = child
            else
                table.insert(fresh, child)
            end
        end
    end
    for _, button in ipairs(fresh) do
        button.tclsId = identify(sidebar, button, byId)
        byId[button.tclsId] = button
    end
    table.sort(fresh, byYThenId)
    for _, button in ipairs(fresh) do
        button.tclsNaturalY = button:getY()
    end

    local inOrder = {}
    for _, id in ipairs(settings.order) do
        inOrder[id] = true
    end
    local missing = {}
    for _, button in ipairs(present) do
        if not inOrder[button.tclsId] then
            table.insert(missing, button)
        end
    end
    if #missing > 0 then
        table.sort(missing, byYThenId)
        for _, button in ipairs(missing) do
            insertNew(settings.order, button.tclsId, predecessorOf(present, button, inOrder), present)
            inOrder[button.tclsId] = true
        end
        Mod.MarkDirty()
    end

    sidebar.tclsById = byId
    sidebar.tclsPresent = present
    return byId, present
end

function Sidebar.OnEditClick(sidebar, button)
    Mod.Editor.Toggle()
end

local function createEditButton(sidebar)
    local model = sidebar.invBtn
    local size = model:getWidth()
    local button = ISButton:new(0, sidebar.offHand:getBottom(), size, model:getHeight(), "", sidebar,
        Sidebar.OnEditClick)
    button.tclsIconOff = getTexture(iconPath(size, "Off"))
    button.tclsIconOn = getTexture(iconPath(size, "On"))
    button.tclsFullHeight = model:getHeight()
    button:setImage(button.tclsIconOff)
    button:initialise()
    button:instantiate()
    button:setDisplayBackground(false)
    button:ignoreWidthChange()
    button:ignoreHeightChange()
    sidebar:addChild(button)
    sidebar:addMouseOverToolTipItem(button, getText("IGUI_TienCustomizableLeftSidebar_EditTooltip"))
    sidebar.tclsEditBtn = button
    return button
end

local function shapeEditButton(button, mode)
    if button.tclsMode == mode then
        return
    end
    button.tclsMode = mode
    local width = button:getWidth()
    if mode == Mod.EDIT_SMALL then
        local w = math.floor(width * Sidebar.SMALL_SCALE + 0.5)
        local h = math.floor(button.tclsFullHeight * Sidebar.SMALL_SCALE + 0.5)
        button:setHeight(h)
        button:forceImageSize(w, h)
    else
        button:setHeight(button.tclsFullHeight)
        button:forceImageSize(nil, nil)
    end
end

local function place(button, y)
    if button:getY() ~= y then
        button:setY(y)
    end
end

local function syncAttachments(sidebar)
    local movable = sidebar.movableBtn
    if movable then
        if sidebar.movableTooltip then
            place(sidebar.movableTooltip, movable:getY())
        end
        if sidebar.movablePopup and not isParked(movable) then
            place(sidebar.movablePopup, sidebar:getAbsoluteY() + movable:getY())
        end
    end
    if sidebar.safetyBtn and sidebar.radialIcon then
        place(sidebar.radialIcon, sidebar.safetyBtn:getY())
    end
    if sidebar.mapBtn and sidebar.mapPopup and not isParked(sidebar.mapBtn) then
        place(sidebar.mapPopup, sidebar:getAbsoluteY() + sidebar.mapBtn:getY())
    end
end

function Sidebar.AfterPrerender(sidebar)
    Mod.Tick()
    if not isActive(sidebar) then
        if sidebar.tclsEditBtn then
            sidebar.tclsEditBtn:setVisible(false)
            place(sidebar.tclsEditBtn, Sidebar.PARK_Y)
        end
        return
    end
    local settings = Mod.Settings()
    local byId, present = discover(sidebar)
    local edit = sidebar.tclsEditBtn or createEditButton(sidebar)
    local gap = settings.gap
    local bottom = sidebar.offHand:getBottom()
    local y = bottom + gap
    local placed = {}

    local function layoutButton(button, id)
        placed[button] = true
        if settings.hidden[id] or not button:isVisible() then
            place(button, Sidebar.PARK_Y)
        else
            place(button, y)
            bottom = button:getBottom()
            y = bottom + gap
        end
    end

    for _, id in ipairs(Mod.previewOrder or settings.order) do
        local button = byId[id]
        if button and not placed[button] then
            layoutButton(button, id)
        end
    end
    for _, button in ipairs(present) do
        if not placed[button] then
            layoutButton(button, button.tclsId)
        end
    end

    if settings.editButton == Mod.EDIT_HIDDEN then
        edit:setVisible(false)
        place(edit, Sidebar.PARK_Y)
    else
        shapeEditButton(edit, settings.editButton)
        edit:setVisible(true)
        place(edit, y)
        bottom = edit:getBottom()
    end
    edit:setImage(Mod.Editor.IsOpen() and edit.tclsIconOn or edit.tclsIconOff)

    syncAttachments(sidebar)
    if sidebar:getHeight() ~= bottom then
        sidebar:setHeight(bottom)
    end
end

function Sidebar.AfterRender(sidebar)
    local id = Mod.highlightId
    if not id or not sidebar.tclsById or not isActive(sidebar) then
        return
    end
    local button = sidebar.tclsById[id]
    if not button or isParked(button) or not button:isVisible() then
        return
    end
    local c = Sidebar.HIGHLIGHT
    sidebar:drawRectBorder(button:getX() - 3, button:getY() - 3, button:getWidth() + 6, button:getHeight() + 6,
        0.95, c.r, c.g, c.b)
    sidebar:drawRectBorder(button:getX() - 2, button:getY() - 2, button:getWidth() + 4, button:getHeight() + 4,
        0.95, c.r, c.g, c.b)
end

function Sidebar.Entries(sidebar)
    local entries = {}
    if not sidebar or not sidebar.tclsById then
        return entries
    end
    local byId = sidebar.tclsById
    for _, id in ipairs(Mod.Settings().order) do
        local button = byId[id]
        if button then
            table.insert(entries, { id = id, button = button, name = Sidebar.NameOf(sidebar, button) })
        end
    end
    return entries
end

function Sidebar.PresentIds(sidebar)
    local ids = {}
    for _, entry in ipairs(Sidebar.Entries(sidebar)) do
        table.insert(ids, entry.id)
    end
    return ids
end

function Sidebar.Reset()
    local settings = Mod.Settings()
    local sidebar = Sidebar.Get()
    local present = {}
    if sidebar and sidebar.tclsPresent then
        for _, button in ipairs(sidebar.tclsPresent) do
            table.insert(present, button)
        end
    end
    table.sort(present, function(a, b)
        local ay, by = a.tclsNaturalY or 0, b.tclsNaturalY or 0
        if ay ~= by then
            return ay < by
        end
        return a.tclsId < b.tclsId
    end)
    local order = {}
    for _, button in ipairs(present) do
        table.insert(order, button.tclsId)
    end
    settings.order = order
    settings.hidden = {}
    settings.gap = Mod.DEFAULT_GAP
    settings.editButton = Mod.EDIT_FULL
    Mod.previewOrder = nil
    Mod.MarkDirty()
end

local function buttonAt(sidebar, x, y)
    for _, button in ipairs(sidebar.tclsPresent or {}) do
        if button:isVisible() and not isParked(button)
            and x >= button:getX() and x < button:getX() + button:getWidth()
            and y >= button:getY() and y < button:getY() + button:getHeight() then
            return button
        end
    end
    return nil
end

function Sidebar.HideButton(_, id)
    Mod.SetHidden(id, true)
end

function Sidebar.ShowAllButtons()
    Mod.ShowAll()
end

function Sidebar.OpenEditor()
    Mod.Editor.Open()
end

function Sidebar.OnRightMouseUp(sidebar, x, y)
    if not isActive(sidebar) then
        return false
    end
    local context = ISContextMenu.get(sidebar.playerNum, getMouseX(), getMouseY())
    local button = buttonAt(sidebar, x, y)
    if button then
        context:addOption(getText("IGUI_TienCustomizableLeftSidebar_MenuHide", Sidebar.NameOf(sidebar, button)), nil,
            Sidebar.HideButton, button.tclsId)
    end
    if Mod.AnyHidden(Sidebar.PresentIds(sidebar)) then
        context:addOption(getText("IGUI_TienCustomizableLeftSidebar_MenuShowAll"), nil, Sidebar.ShowAllButtons)
    end
    context:addOption(getText("IGUI_TienCustomizableLeftSidebar_MenuCustomize"), nil, Sidebar.OpenEditor)
    return true
end

local installed = false

local function install()
    if installed then
        return
    end
    installed = true

    local innerPrerender = ISEquippedItem.prerender
    function ISEquippedItem:prerender()
        innerPrerender(self)
        Sidebar.AfterPrerender(self)
    end

    local innerRender = ISEquippedItem.render
    function ISEquippedItem:render()
        innerRender(self)
        Sidebar.AfterRender(self)
    end

    local innerRightMouseUp = ISEquippedItem.onRightMouseUp
    function ISEquippedItem:onRightMouseUp(x, y)
        if Sidebar.OnRightMouseUp(self, x, y) then
            return true
        end
        if innerRightMouseUp then
            return innerRightMouseUp(self, x, y)
        end
    end
end

Events.OnGameStart.Add(install)
