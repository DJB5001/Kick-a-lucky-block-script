-- DJ HUB — Kick a Lucky Block Script
-- Author: DJB5001
-- Discord: discord.gg/MTXnFfHXW9

local GAME_NAME = "Kick a Lucky Block"
local VERSION   = "1.0.0"
local REPO_BASE = "https://raw.githubusercontent.com/DJB5001/Kick-a-lucky-block-test/main/"

-- ================================================================
-- CONFIG (Key System)
-- ================================================================
local Config = {
    api      = "ef8c4422-f7d4-4b3c-ab4e-c3363317dba9",
    provider = "Keys",
    service  = "RaiseAnimal_DJHUB",
}

-- ================================================================
-- SAVE SYSTEM
-- ================================================================
local SaveSystem  = {}
local SAVE_DIR    = "DJHub/Settings"
local HttpService = game:GetService("HttpService")

local function hasFS()
    return typeof(writefile)  == "function"
       and typeof(readfile)   == "function"
       and typeof(makefolder) == "function"
       and typeof(isfile)     == "function"
       and typeof(isfolder)   == "function"
       and typeof(delfile)    == "function"
end

local function ensureDir()
    if not hasFS() then return false end
    pcall(function()
        if not isfolder("DJHub")  then makefolder("DJHub")  end
        if not isfolder(SAVE_DIR) then makefolder(SAVE_DIR) end
    end)
    return isfolder(SAVE_DIR)
end

function SaveSystem.save(name)
    if not ensureDir() then return false, "Filesystem not available" end

    local flags = {}
    local RF = _G.Rayfield
    if RF and RF.Flags then
        for flagName, flag in pairs(RF.Flags) do
            local val
            if     flag.CurrentOption  ~= nil then val = flag.CurrentOption
            elseif flag.CurrentKeybind ~= nil then val = flag.CurrentKeybind
            elseif flag.CurrentValue   ~= nil then val = flag.CurrentValue
            end
            local t = type(val)
            if t == "boolean" or t == "number" or t == "string" or t == "table" then
                flags[flagName] = val
            end
        end
    end

    local data = { version = VERSION, saved = os.time(), flags = flags }
    local ok, json = pcall(function() return HttpService:JSONEncode(data) end)
    if not ok then return false, "Encoding failed" end

    local path = ("%s/%s.json"):format(SAVE_DIR, name:gsub("[^%w%-_]", "_"))
    local okw  = pcall(function() writefile(path, json) end)
    return okw, okw and nil or "Write failed"
end

function SaveSystem.load(name)
    if not hasFS() then return false, "Filesystem not available" end

    local path = ("%s/%s.json"):format(SAVE_DIR, name:gsub("[^%w%-_]", "_"))
    if not isfile(path) then return false, "File not found" end

    local okr, raw = pcall(readfile, path)
    if not okr or type(raw) ~= "string" then return false, "Read failed" end

    local ok, data = pcall(function() return HttpService:JSONDecode(raw) end)
    if not ok or type(data) ~= "table" then return false, "Decode failed" end

    local RF = _G.Rayfield
    if data.flags and RF and RF.Flags then
        for flagName, val in pairs(data.flags) do
            local flag = RF.Flags[flagName]
            if flag and typeof(flag.Set) == "function" then
                pcall(function() flag:Set(val) end)
            end
        end
    end

    if _G.__DJ_Notify then _G.__DJ_Notify("settings:applied") end
    return true
end

function SaveSystem.delete(name)
    if not hasFS() then return false end
    local path = ("%s/%s.json"):format(SAVE_DIR, name:gsub("[^%w%-_]", "_"))
    if isfile(path) then pcall(delfile, path) end
    if _G.__DJ_Notify then _G.__DJ_Notify("saves:changed") end
    return true
end

function SaveSystem.list()
    if not hasFS() or not isfolder(SAVE_DIR) then return {} end
    local files = {}
    pcall(function()
        for _, file in ipairs(listfiles(SAVE_DIR)) do
            if file:match("%.json$") then
                local name = file:match("([^/\\]+)%.json$")
                local okr, raw = pcall(readfile, file)
                if okr and raw then
                    local ok2, data = pcall(function() return HttpService:JSONDecode(raw) end)
                    if ok2 and data then
                        table.insert(files, {
                            name    = name,
                            time    = data.saved or 0,
                            version = data.version or "?",
                        })
                    end
                end
            end
        end
    end)
    return files
end

_G.saveSettings   = SaveSystem.save
_G.loadSettings   = SaveSystem.load
_G.deleteSettings = SaveSystem.delete
_G.listSettings   = SaveSystem.list

local subscribers = {}
_G.__DJ_Subscribe = function(fn)  table.insert(subscribers, fn) end
_G.__DJ_Notify    = function(evt) for _, fn in ipairs(subscribers) do pcall(fn, evt) end end

-- ================================================================
-- MODULE LOADER
-- ================================================================
local function httpGet(url)
    local ok, res = pcall(function() return game:HttpGet(url, true) end)
    return (ok and type(res) == "string" and #res > 0) and res or nil
end

local function loadModule(name)
    local src = httpGet(REPO_BASE .. name)
    if not src then
        warn("[DJ HUB] Download failed: " .. name)
        return nil
    end
    local ok, chunk = pcall(loadstring, src)
    if not ok or not chunk then
        warn("[DJ HUB] Compile failed: " .. name)
        return nil
    end
    local ok2, mod = pcall(chunk)
    if not ok2 then
        warn("[DJ HUB] Execution failed: " .. name)
        return nil
    end
    return mod
end

-- ================================================================
-- BOOTSTRAP
-- ================================================================
print("[DJ HUB] Starting " .. GAME_NAME .. " v" .. VERSION .. "...")

local Utils = loadModule("dj_utils.lua")
if not Utils then warn("[DJ HUB] Utils failed to load") end

local Overlay = loadModule("dj_overlay.lua")
if Overlay then
    Overlay.showDiscordProgress(
        "Loading DJ HUB v" .. VERSION .. "\nGame: " .. GAME_NAME,
        6
    )
end

local UIBase = loadModule("dj_ui_base.lua")
if not UIBase then
    error("[DJ HUB] FATAL: UI base failed to load")
end

local Rayfield, Window = UIBase.createWindow()
if not Rayfield or not Window then
    error("[DJ HUB] FATAL: Window could not be created")
end

_G.Rayfield = Rayfield

-- ================================================================
-- LOAD TABS AFTER KEY VERIFICATION
-- ================================================================
local function onKeyVerified()
    task.wait(0.2)
    print("[DJ HUB] Loading tabs...")

    local tabs = {
        { file = "main.lua",            label = "Home"     },
        { file = "dj_tab_ingame.lua",   label = "Ingame"   },
        { file = "dj_tab_minigame.lua", label = "Minigame" },
        { file = "dj_tab_misc.lua",     label = "Misc"     },
    }

    for _, entry in ipairs(tabs) do
        local build = loadModule(entry.file)
        if build then
            local ok, err = pcall(build, Window, Rayfield, Utils)
            if ok then
                print("[DJ HUB] " .. entry.label .. " tab loaded")
            else
                warn("[DJ HUB] " .. entry.label .. " tab error: " .. tostring(err))
            end
        else
            warn("[DJ HUB] Could not load: " .. entry.file)
        end
    end

    Rayfield:Notify({
        Title   = "DJ HUB Ready!",
        Content = "Kick a Lucky Block Script loaded!\nDiscord: discord.gg/MTXnFfHXW9",
        Duration = 6,
    })

    print("[DJ HUB] All tabs loaded.")
end

-- ================================================================
-- KEY SYSTEM
-- ================================================================
local buildKey = loadModule("dj_tab_key.lua")
if buildKey then
    local ok, err = pcall(buildKey, Window, Rayfield, Utils, Config, onKeyVerified)
    if not ok then
        warn("[DJ HUB] Key tab error: " .. tostring(err))
        onKeyVerified()
    end
else
    warn("[DJ HUB] Key tab failed to load — skipping key check")
    onKeyVerified()
end

print("[DJ HUB] Loader complete.")
