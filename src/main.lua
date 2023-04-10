local json = require("json")
local mod = RegisterMod("Increase move speed outside of combat", 1)

local CHOICE_YES = "Yes"
local CHOICE_NO = "No"
local CHOICE_AFTER_20_MINUTES_OR_BOSS_RUSH = "After 20 minutes or boss rush"
local CHOICE_AFTER_30_MINUTES_OR_HUSH = "After 30 minutes or Hush"
local enabledChoices = {
    CHOICE_YES,
    CHOICE_AFTER_20_MINUTES_OR_BOSS_RUSH,
    CHOICE_AFTER_30_MINUTES_OR_HUSH,
    CHOICE_NO,
}

local speedChoices = {
    1.4, 1.5, 1.6, 1.7, 1.8, 1.9, 2.0
}

local function getTableIndex(tbl, val)
    for i, v in ipairs(tbl) do
        if v == val then
            return i
        end
    end

    return 0
end

local defaultSettings = {
    speedOutsideCombat = speedChoices[7],
    enabled = enabledChoices[1],
}

local settings = defaultSettings
local speedIncreaseEnabled = false
local speed = settings.speedOutsideCombat

local function saveSettings()
    local jsonString = json.encode(settings)
    mod:SaveData(jsonString)
end

mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, saveSettings)

local function loadSettings()
    local jsonString = mod:LoadData()
    settings = json.decode(jsonString)
    -- newly added settings are set to default value
    for k, v in pairs(defaultSettings) do
        if settings[k] == nil then
            settings[k] = defaultSettings[k]
        end
    end

    speed = settings.speedOutsideCombat
end

local function initializeSettings()
    if not mod:HasData() then
        settings = defaultSettings
        return
    end

    if not pcall(loadSettings) then
        settings = defaultSettings
        Isaac.DebugString("Error: Failed to load " .. mod.Name .. " settings, reverting to default settings.")
    end
end

local optionsModName = "Increase move speed"

local function setupMyModConfigMenuSettings()
    if ModConfigMenu == nil then
        return
    end

    -- Remove menu if it exists, makes debugging easier
    ModConfigMenu.RemoveCategory(optionsModName)

    ModConfigMenu.AddSetting(
            optionsModName,
            nil,
            {
                Type = ModConfigMenu.OptionType.NUMBER,
                CurrentSetting = function()
                    return getTableIndex(enabledChoices, settings.enabled)
                end,
                Minimum = 1,
                Maximum = #enabledChoices,
                Display = function()
                    return "Enabled: " .. settings.enabled
                end,
                OnChange = function(n)
                    settings.enabled = enabledChoices[n]
                end,
                Info = {
                    "Use this setting if you don't want to cheat: if you're aiming for Hush, enable only after 30 minutes, ",
                    "if you're aiming for the boss rush, enable only after 20 minutes, enable otherwise.",
                }
            }
    )
    ModConfigMenu.AddSetting(
            optionsModName,
            nil,
            {
                Type = ModConfigMenu.OptionType.NUMBER,
                CurrentSetting = function()
                    return getTableIndex(speedChoices, settings.speedOutsideCombat)
                end,
                Minimum = 1,
                Maximum = #speedChoices,
                Display = function()
                    return "Speed: " .. settings.speedOutsideCombat
                end,
                OnChange = function(n)
                    settings.speedOutsideCombat = speedChoices[n]
                end,
                Info = {
                    ""
                }
            }
    )
end

setupMyModConfigMenuSettings()

local function updateSpeed(unknown, player, cacheFlag)
    if cacheFlag == CacheFlag.CACHE_SPEED then
        if speedIncreaseEnabled then
            player.MoveSpeed = speed
        end
    end
end

local function forceSpeedReevaluation()
    local nPlayers = Game():GetNumPlayers()
    for i=0, nPlayers do
        local player = Game():GetPlayer(i)
        player:AddCacheFlags(CacheFlag.CACHE_SPEED)
        player:EvaluateItems()
    end
end

local function isModEnabled()
    local game = Game()
    local minutesElapsed = (game.TimeCounter / 30) / 60

    local level = game:GetLevel()
    local stage = level:GetStage()
    local room = level:GetCurrentRoom()
    local isBossRush = room:GetType() == RoomType.ROOM_BOSSRUSH

    modEnabled = (settings.enabled == CHOICE_YES or
            (settings.enabled == CHOICE_AFTER_20_MINUTES_OR_BOSS_RUSH and (minutesElapsed > 20 or isBossRush or stage >= LevelStage.STAGE4_1)) or
            (settings.enabled == CHOICE_AFTER_30_MINUTES_OR_HUSH and (minutesElapsed > 30 or stage >= LevelStage.STAGE4_3)))
    return modEnabled
end

local function checkIfSpeedIncreaseCanBeEnabled()
    local game = Game()
    local room = game:GetRoom()
    -- room:IsClear() returns true after new enemies spawn in challenge rooms, so
    -- we have to use room:GetAliveEnemiesCount()
    local enemiesCount = room:GetAliveEnemiesCount()
    if isModEnabled() then
        if enemiesCount == 0 and (not speedIncreaseEnabled or speed ~= settings.speedOutsideCombat) then
            speed = settings.speedOutsideCombat
            speedIncreaseEnabled = true
            forceSpeedReevaluation()
        elseif enemiesCount > 0 and speedIncreaseEnabled then
            speedIncreaseEnabled = false
            forceSpeedReevaluation()
        end
    else
        if speedIncreaseEnabled then
            speedIncreaseEnabled = false
            forceSpeedReevaluation()
        end
    end
end

mod:AddCallback(ModCallbacks.MC_POST_UPDATE, checkIfSpeedIncreaseCanBeEnabled)
mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, updateSpeed)
mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, initializeSettings)
