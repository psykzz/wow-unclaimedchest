local addonName, addon = ...
local ldbName = "Unclaimed Chest"
local ldb = LibStub:GetLibrary("LibDataBroker-1.1")
local Translit = LibStub:GetLibrary("LibTranslit-1.0")
local ldbData = ldb:NewDataObject(ldbName, {
    type = "data source",
    text = "n/a",
    value = "n/a",
    OnClick = function() updateMythicChests() end
})
local frame = CreateFrame("FRAME")

frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:RegisterEvent("CHALLENGE_MODE_MAPS_UPDATE")


local rewardsRequested = false
function frame:OnEvent(event, arg1)
    if event == "ADDON_LOADED" and arg1 ~= addonName then
        return
    end

    if event == "CHALLENGE_MODE_MAPS_UPDATE" then
        rewardsRequested = true
    elseif not rewardsRequested then
        C_MythicPlus.RequestRewards()
        print("requested rewards")
        return
    end

    if UnclaimedChestGlobal == nil then
        UnclaimedChestGlobal = {}
    end

    if UnitLevel("player") ~= GetMaxPlayerLevel() then
        return
    end

    updateMythicChests()
    -- C_Timer.After(3, function() updateMythicChests() end) -- for some reason it starts off wrong.
end
frame:SetScript("OnEvent", frame.OnEvent)

function updateMythicChests()
    local chestAvailable = C_MythicPlus.IsWeeklyRewardAvailable()
    local currentLevel, rewardLevel, _, _ = C_MythicPlus.GetWeeklyChestRewardLevel()
    if currentLevel == 0 and rewardLevel == -1 then
        currentLevel, rewardLevel, _ = getHighestCompletion() -- Try a manual approach?
    end
    local currentDate = C_DateAndTime.GetCurrentCalendarTime()
    local map = {
        Monday = 2,
        Tuesday = 1,
        Wednesday = 0,
        Thursday = 6,
        Friday = 5,
        Saturday = 4,
        Sunday = 3,
    }
    local nextAvailableDate = C_DateAndTime.AdjustTimeByDays(currentDate, map[CALENDAR_WEEKDAY_NAMES[currentDate.weekday]])

    local chestData = {
        claimable = chestAvailable,
        level = currentLevel,
        ilvl = rewardLevel,
        nextAvailableDate = nextAvailableDate,
    }

    local playerName = UnitName("player")
    UnclaimedChestGlobal[playerName] = chestData

    local claimableChestCount = availableChestCount(UnclaimedChestGlobal, 2) or 0
    ldbData.text = string.format("Unclaimed Chest: |cffFFFFFF%s|r", claimableChestCount)
    ldbData.value = claimableChestCount
end

-- LDB
function ldbData:OnTooltipShow()
    local claimableChestCount = availableChestCount(UnclaimedChestGlobal, 2) or 0
    local completeChestCount = availableChestCount(UnclaimedChestGlobal, 1) or 0

    self:AddLine("Weekly Mythic+ Chests")
    self:AddLine("----------------------------")
    self:AddLine(" ")
    self:AddLine(string.format("Unclaimed chests: |cffffffff%s|r", claimableChestCount))
    self:AddLine(string.format("Complete this week: |cffffffff%s|r", completeChestCount))
    self:AddLine(" ")
    for characteName, data in spairs(UnclaimedChestGlobal, chestSort) do
        self:AddDoubleLine(characteName, formatLine(data), 1,1,1, 1,1,1)
    end
end



-- Test command to show the output
SLASH_UNCLAIMEDCHESTS1 = "/unclaimed";
function SlashCmdList.UNCLAIMEDCHESTS(msg)

    updateMythicChests()
    print(ldbData.text);
    for characteName, data in spairs(UnclaimedChestGlobal, chestSort) do
        print(characteName, formatLine(data))
    end
    return true
end


function availableChestCount(T, chestStatus)
  local count = 0
  for _, data in pairs(T) do
    if getChestStatus(data) == chestStatus then
        count = count + 1
    end
  end
  return count
end


string.lpad = function(str, len, char)
    if char == nil then char = ' ' end
    return str .. string.rep(char, len - #str)
end


function isAfter(date1, date2)
    if date1 == nil or date2 == nil then
        return false
    end
    if date1["year"] < date2["year"] then
        return false
    elseif date1["month"] < date2["month"] then
        return false
    elseif date1["monthDay"] < date2["monthDay"] then
        return false
    else
        return true
    end
end


function spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

function getChestStatus(data)
    local currentDate = C_DateAndTime.GetCurrentCalendarTime()
    if data["level"] < 1 then
        return 0 -- incomplete
    elseif data["claimable"] or isAfter(currentDate, data["nextAvailableDate"]) then
        return 2 -- claimable
    else
        return 1 -- complete
    end
end


function formatLine(data)
    local chestStatus = getChestStatus(data)
    if chestStatus == 0 then
        chestStatus = "|cffff0000Incomplete|r"
    elseif chestStatus == 1 then
        chestStatus = "|cffffffffComplete|r"
    elseif chestStatus == 2 then
        chestStatus = "|cff00ff00Claimable|r"
    else
        chestStatus = "|cffff00ffUnknown|r"
    end
    return string.format("|cffffffff+%d (|cffffff00%d ilvl|cffffffff) |cffffffff%s|r", data["level"], data["ilvl"], chestStatus)
end


function getHighestCompletion()
    local maps = C_ChallengeMode.GetMapTable()
    local maxCompleted = 0
    for _, mapID in pairs(maps) do
        local _, level, _, _, members = C_MythicPlus.GetWeeklyBestForMap(mapID)
        if members then
            for _,member in pairs(members) do
                if member.name == UnitName("player") then
                    if level and level > maxCompleted then
                        maxCompleted = level
                    end
                    break;
                end
            end
        end
    end
    return maxCompleted, C_MythicPlus.GetRewardLevelForDifficultyLevel(maxCompleted)
end


chestSort = function(t,a,b)
    if t[b]["level"] == t[a]["level"] then
        return b > a -- This is sort by name
    end
    return t[b]["level"] < t[a]["level"]
end