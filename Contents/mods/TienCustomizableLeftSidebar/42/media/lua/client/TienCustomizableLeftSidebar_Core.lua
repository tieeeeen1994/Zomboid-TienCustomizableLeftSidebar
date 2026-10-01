TienCustomizableLeftSidebar = TienCustomizableLeftSidebar or {}

local Mod = TienCustomizableLeftSidebar

Mod.FILE = "TienCustomizableLeftSidebar.ini"
Mod.VERSION = 1
Mod.DEFAULT_GAP = 15
Mod.MIN_GAP = 0
Mod.MAX_GAP = 40
Mod.SAVE_DELAY_MS = 500

Mod.EDIT_FULL = "full"
Mod.EDIT_SMALL = "small"
Mod.EDIT_HIDDEN = "hidden"
Mod.EDIT_MODES = { Mod.EDIT_FULL, Mod.EDIT_SMALL, Mod.EDIT_HIDDEN }

Mod.NAMES = {
    invBtn = "IGUI_InventoryTooltip",
    healthBtn = "IGUI_HealthTooltip",
    craftingBtn = "IGUI_CraftingTooltip",
    buildBtn = "IGUI_Build_Name",
    movableBtn = "IGUI_MovableTooltip",
    searchBtn = "UI_investigate_area_window_title",
    zoneBtn = "IGUI_Zone_Name",
    mapBtn = "IGUI_TienCustomizableLeftSidebar_Map",
    debugBtn = "IGUI_DebugMenu",
    arfBtn = "IGUI_ARFRecording",
    safetyBtn = "IGUI_TienCustomizableLeftSidebar_Safety",
    clientBtn = "IGUI_TienCustomizableLeftSidebar_UserPanel",
    adminBtn = "IGUI_TienCustomizableLeftSidebar_AdminPanel",
    warManagerBtn = "IGUI_TienCustomizableLeftSidebar_WarManager",
}

Mod.GAME_NOTES = {
    adminBtn = "IGUI_TienCustomizableLeftSidebar_AdminOnly",
    safetyBtn = "IGUI_TienCustomizableLeftSidebar_SafetyOff",
    warManagerBtn = "IGUI_TienCustomizableLeftSidebar_WarOnly",
}

Mod.settings = nil
Mod.previewOrder = nil
Mod.highlightId = nil
Mod.dirtyAt = nil

local function defaults()
    return { order = {}, hidden = {}, gap = Mod.DEFAULT_GAP, editButton = Mod.EDIT_FULL }
end

function Mod.ClampGap(value)
    local n = tonumber(value)
    if not n then
        return Mod.DEFAULT_GAP
    end
    return math.max(Mod.MIN_GAP, math.min(Mod.MAX_GAP, math.floor(n + 0.5)))
end

function Mod.IsEditMode(value)
    for _, mode in ipairs(Mod.EDIT_MODES) do
        if mode == value then
            return true
        end
    end
    return false
end

function Mod.Load()
    local settings = defaults()
    local reader = getFileReader(Mod.FILE, false)
    if reader then
        local seen = {}
        local line = reader:readLine()
        while line do
            local key, value = string.match(line, "^%s*([%w_]+)%s*=(.-)%s*$")
            if key == "gap" then
                settings.gap = Mod.ClampGap(value)
            elseif key == "editButton" then
                if Mod.IsEditMode(value) then
                    settings.editButton = value
                end
            elseif key == "button" then
                if value ~= "" and not seen[value] then
                    seen[value] = true
                    table.insert(settings.order, value)
                end
            elseif key == "hidden" then
                if value ~= "" then
                    settings.hidden[value] = true
                end
            end
            line = reader:readLine()
        end
        reader:close()
    end
    Mod.settings = settings
    return settings
end

function Mod.Settings()
    return Mod.settings or Mod.Load()
end

function Mod.Save()
    Mod.dirtyAt = nil
    local settings = Mod.Settings()
    local writer = getFileWriter(Mod.FILE, true, false)
    if not writer then
        return
    end
    writer:write("version=" .. string.format("%d", Mod.VERSION) .. "\n")
    writer:write("gap=" .. string.format("%d", settings.gap) .. "\n")
    writer:write("editButton=" .. settings.editButton .. "\n")
    for _, id in ipairs(settings.order) do
        writer:write("button=" .. id .. "\n")
    end
    for _, id in ipairs(settings.order) do
        if settings.hidden[id] then
            writer:write("hidden=" .. id .. "\n")
        end
    end
    writer:close()
end

function Mod.MarkDirty()
    Mod.dirtyAt = getTimestampMs()
end

function Mod.SaveIfDirty()
    if Mod.dirtyAt then
        Mod.Save()
    end
end

function Mod.Tick()
    if Mod.dirtyAt and getTimestampMs() - Mod.dirtyAt >= Mod.SAVE_DELAY_MS then
        Mod.Save()
    end
end

function Mod.IndexOf(list, value)
    for i, v in ipairs(list) do
        if v == value then
            return i
        end
    end
    return nil
end

function Mod.Copy(list)
    local out = {}
    for i, v in ipairs(list) do
        out[i] = v
    end
    return out
end

function Mod.MoveTo(order, present, id, target)
    local others = {}
    for _, p in ipairs(present) do
        if p ~= id then
            table.insert(others, p)
        end
    end
    local result = {}
    for _, o in ipairs(order) do
        if o ~= id then
            table.insert(result, o)
        end
    end
    local before = others[target]
    if before then
        local index = Mod.IndexOf(result, before)
        if index then
            table.insert(result, index, id)
            return result
        end
    end
    local last = others[#others]
    local index = last and Mod.IndexOf(result, last)
    if index then
        table.insert(result, index + 1, id)
    else
        table.insert(result, id)
    end
    return result
end

function Mod.SetHidden(id, hidden)
    local settings = Mod.Settings()
    if hidden then
        settings.hidden[id] = true
    else
        settings.hidden[id] = nil
    end
    Mod.MarkDirty()
end

function Mod.ShowAll()
    Mod.Settings().hidden = {}
    Mod.MarkDirty()
end

function Mod.AnyHidden(ids)
    local hidden = Mod.Settings().hidden
    for _, id in ipairs(ids) do
        if hidden[id] then
            return true
        end
    end
    return false
end
