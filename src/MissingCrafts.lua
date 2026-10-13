setfenv(1, MissingCrafts)

---@shape AddonInfo
---@field name string
---@field version string

---@type AddonInfo
local addonInfo = {
    name = ADDON_NAME,
    version = ADDON_VERSION
}

---@type LibStubDef
local LibStub = getglobal("LibStub")
assert(LibStub ~= nil, "LibStub is required to run this addon")

local AceAddon, _ = LibStub("AceAddon-3.0")
local AceDB, _ = LibStub("AceDB-3.0")
local AceGUI, _ = LibStub("AceGUI-3.0")
local AceHook, _ = LibStub("AceHook-3.0")

local AceLocale, _ = LibStub("AceLocale-3.0")
local L = --[[---@type MissingCraftsLocale]] AceLocale:GetLocale(ADDON_NAME, false)

local LibCraftingProfessions = --[[---@type LibCraftingProfessions]] LibStub("LibCraftingProfessions-1.0")
local LibCrafts = --[[---@type LibCrafts]] LibStub("LibCrafts-1.0")
local LibItemTooltip = --[[---@type LibItemTooltip]] LibStub("LibItemTooltip-1.0")

---@shape Repositories
---@field characterRepository CharacterRepository
---@field professionRepository ProfessionRepository
---@field craftRepository CraftRepository

---@shape Libraries
---@field AceGUI LibAceGUI
---@field AceHook LibAceHookDef
---@field LibCrafts LibCrafts
---@field LibItemTooltip LibItemTooltip

---@class MissingCrafts: AceAddonDef
---@field database Database
---@field uiManager UIManager

---@type MissingCrafts
local addon = --[[---@type MissingCrafts]] AceAddon:NewAddon("MissingCrafts")

---@param text string
local function debugPrint(text)
    DEFAULT_CHAT_FRAME:AddMessage("|cff40bf40MissingCrafts debug|r: " .. tostring(text))
end

---@param link string|nil
---@return string
local function itemIdFromLink(link)
    if type(link) ~= "string" then
        return "MISSING"
    end
    local _, _, id = strfind(link, "item:(%d+)")
    return id or "MISSING"
end

local function dumpTradeSkillWindow()
    local name, curRank, maxRank = GetTradeSkillLine()
    debugPrint(format("TradeSkillLine = %s (rank %s/%s)", tostring(name), tostring(curRank), tostring(maxRank)))
    local count = GetNumTradeSkills() or 0
    debugPrint(format("GetNumTradeSkills() = %d", count))
    for i = 1, count do
        local skillName, skillType, numAvailable = GetTradeSkillInfo(i)
        debugPrint(format("  [%d] name=%s type=%s numAvailable=%s item=%s",
            i, tostring(skillName), tostring(skillType), tostring(numAvailable), itemIdFromLink(GetTradeSkillItemLink(i))))
    end
end

local function dumpCraftWindow()
    local name, curRank, maxRank = GetCraftDisplaySkillLine()
    debugPrint(format("CraftDisplaySkillLine = %s (rank %s/%s)", tostring(name), tostring(curRank), tostring(maxRank)))
    local count = GetNumCrafts() or 0
    debugPrint(format("GetNumCrafts() = %d", count))
    for i = 1, count do
        local skillName, _, skillType, numAvailable = GetCraftInfo(i)
        debugPrint(format("  [%d] name=%s type=%s numAvailable=%s item=%s",
            i, tostring(skillName), tostring(skillType), tostring(numAvailable), itemIdFromLink(GetCraftItemLink(i))))
    end
end

local function dumpLcp()
    local skills = LibCraftingProfessions:GetPlayerProfessionSkills("Survival")
    if skills == nil then
        debugPrint("LCP GetPlayerProfessionSkills('Survival') = nil")
    else
        debugPrint(format("LCP GetPlayerProfessionSkills('Survival') = %d entries", getn(skills)))
        for _, skill in ipairs(skills) do
            debugPrint(format("  known: %s | item=%s", tostring(skill.localized_name), itemIdFromLink(skill.item_link)))
        end
    end

    local professions = LibCraftingProfessions:GetPlayerProfessions()
    if professions == nil then
        debugPrint("LCP GetPlayerProfessions() = nil")
    else
        for _, profession in ipairs(professions) do
            debugPrint(format("  profession: english=%s localized=%s rank=%s",
                tostring(profession.english_name), tostring(profession.localized_name), tostring(profession.cur_rank)))
        end
    end

    for _, supported in ipairs(LibCraftingProfessions:GetSupportedProfessions()) do
        if supported.english_name == "Survival" then
            debugPrint(format("LCP supported Survival localized_name = %s", tostring(supported.localized_name)))
        end
    end
end

---@param database Database
---@return DatabaseCharacter|nil
local function findCurrentDbCharacter(database)
    local realm = GetRealmName()
    local name, _ = UnitName("player")
    return database._db.global.realmToNameToCharacter[realm][name]
end

---@param database Database
local function dumpStored(database)
    local player = findCurrentDbCharacter(database)
    if player == nil then
        debugPrint("DB: no player entry")
        return
    end

    local professionNames = {}
    for professionName, _ in pairs(player.professionsByLocalizedName) do
        tinsert(professionNames, professionName)
    end
    table.sort(professionNames)
    debugPrint("DB professions: " .. table.concat(professionNames, ", "))

    local survival = player.professionsByLocalizedName["Survival"]
    if survival == nil then
        debugPrint("DB: no 'Survival' entry")
        return
    end

    local known = survival.knownLocalizedSkillNames
    debugPrint(format("DB Survival rank=%s known=%d", tostring(survival.rank), getn(known)))
    for _, skillName in ipairs(known) do
        debugPrint("  stored: " .. tostring(skillName))
    end
end

---@param database Database
---@param repositories Repositories
local function crossCheck(database, repositories)
    local player = findCurrentDbCharacter(database)
    local survival = player and player.professionsByLocalizedName["Survival"]
    if survival == nil then
        debugPrint("Cross-check skipped (no stored Survival entry)")
        return
    end

    local storedSet = {}
    for _, skillName in ipairs(survival.knownLocalizedSkillNames) do
        storedSet[skillName] = true
    end

    local crafts = repositories.craftRepository:GetCraftsByProfession("Survival")
    local craftSet = {}
    for _, craft in ipairs(crafts) do
        craftSet[craft.localized_spell_name] = true
    end

    debugPrint(format("Cross-check: stored=%d crafts=%d", getn(survival.knownLocalizedSkillNames), getn(crafts)))
    for skillName, _ in pairs(storedSet) do
        if craftSet[skillName] == nil then
            debugPrint("  stored but NOT in Survival.lua: " .. tostring(skillName))
        end
    end
end

---@param database Database
---@param repositories Repositories
local function registerDiagnosticCommand(database, repositories)
    ---@param msg string|nil
    local function run(msg)
        debugPrint(format("player=%s realm=%s locale=%s", tostring((UnitName("player"))), tostring(GetRealmName()), tostring(GetLocale())))
        dumpTradeSkillWindow()
        dumpCraftWindow()
        dumpLcp()
        dumpStored(database)
        crossCheck(database, repositories)
    end

    local globalScope = MissingCrafts._G
    globalScope["SLASH_MISSINGCRAFTSDBG1"] = "/mcdbg"
    globalScope["SLASH_MISSINGCRAFTSDBG2"] = "/missingcrafts-debug"
    globalScope["SlashCmdList"]["MISSINGCRAFTSDBG"] = run
end

function addon:OnEnable()
    ---@type Libraries
    local libraries = {
        AceGUI = AceGUI,
        AceHook = AceHook,
        LibCrafts = LibCrafts,
        LibItemTooltip = LibItemTooltip,
    }

    self.database = Database:Create(AceDB)

    local characterRepository = CharacterRepository:Create(self.database)
    ---@type Repositories
    local repositories = {
        characterRepository = characterRepository,
        professionRepository = ProfessionRepository:Create(LibCraftingProfessions),
        craftRepository = CraftRepository:Create(self.database, characterRepository, LibCrafts)
    }

    self.uiManager = UIManager:Create(addonInfo, repositories, L, libraries)

    LibCraftingProfessions:RegisterEvent("LCP_SKILLS_UPDATE", function(profession, skills)
        local skillNames = {}
        for _, skill in ipairs(skills) do
            tinsert(skillNames, skill.localized_name)
        end
        self.database:SaveCurrentPlayerSkills(profession.localized_name, profession.cur_rank, skillNames)

        local playerProfessions = LibCraftingProfessions:GetPlayerProfessions()
        if playerProfessions ~= nil then
            local playerProfessionNames = {}
            for _, playerProfession in ipairs(playerProfessions or {}) do
                tinsert(playerProfessionNames, playerProfession.localized_name)
            end
            self.database:SaveCurrentPlayerProfessions(playerProfessionNames)
        end

        self.uiManager:OnDataUpdated(profession.localized_name)
    end)

    LibCraftingProfessions:RegisterEvent("LCP_FRAME_SHOW", function(profession, frame, frameType)
        self.uiManager:OnProfessionFrameOpened(profession.localized_name, frame, frameType)
    end)

    LibCraftingProfessions:RegisterEvent("LCP_FRAME_CLOSE", function(frame, frameType)
        self.uiManager:OnProfessionFrameClosed(frame, frameType)
    end)

    registerDiagnosticCommand(self.database, repositories)
end
