local mod = RegisterMod("Increase move speed outside of combat", 1)

local speedIncreaseEnabled = false
local function updateSpeed(unknown, player, cacheFlag)
    if cacheFlag == CacheFlag.CACHE_SPEED then
        if speedIncreaseEnabled then
            player.MoveSpeed = player.MoveSpeed + 10.0;
        end
    end
end

local function forceSpeedReevaluation()
    Game():GetPlayer(0):AddCacheFlags(CacheFlag.CACHE_SPEED)
    Game():GetPlayer(0):EvaluateItems()
end

local function checkIfSpeedIncreaseCanBeEnabled()
    local room = Game():GetRoom()
    -- room:IsClear() returns true after new enemies spawn in challenge rooms, so
    -- we have to use room:GetAliveEnemiesCount()
    enemiesCount = room:GetAliveEnemiesCount()
    if enemiesCount == 0 and (not speedIncreaseEnabled) then
        speedIncreaseEnabled = true
        forceSpeedReevaluation()
    elseif enemiesCount > 0 and speedIncreaseEnabled then
        speedIncreaseEnabled = false
        forceSpeedReevaluation()
    end
end


mod:AddCallback(ModCallbacks.MC_POST_UPDATE, checkIfSpeedIncreaseCanBeEnabled)
mod:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, updateSpeed)
