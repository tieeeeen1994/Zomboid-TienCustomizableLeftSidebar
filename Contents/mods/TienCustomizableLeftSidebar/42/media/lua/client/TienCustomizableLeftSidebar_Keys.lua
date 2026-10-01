require "TienCustomizableLeftSidebar_Core"

local Mod = TienCustomizableLeftSidebar

Mod.Keys = {}

local Keys = Mod.Keys

Keys.SECTION = "[Customizable Sidebar]"
Keys.CUSTOMIZE = "TCLS Customize"

local function addKeyBindings()
    for _, bind in ipairs(keyBinding) do
        if bind.value == Keys.SECTION then
            return
        end
    end
    table.insert(keyBinding, { value = Keys.SECTION })
    table.insert(keyBinding, { value = Keys.CUSTOMIZE, key = 0 })
end

if keyBinding then
    addKeyBindings()
end

local function onKeyPressed(key)
    if not key or key == 0 then
        return
    end
    if not getCore():isKey(Keys.CUSTOMIZE, key) then
        return
    end
    if not getSpecificPlayer(0) then
        return
    end
    Mod.Editor.Toggle()
end

Events.OnKeyPressed.Add(onKeyPressed)
