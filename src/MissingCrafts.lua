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
    DEFAULT_CHAT_FRAME:AddMessage("MC: " .. tostring(text))
end

---@param database Database
---@param repositories Repositories
local function registerDiagnosticCommand(database, repositories)
    ---@param list string[]
    ---@return string
    local function joinList(list)
        return table.concat(list, ", ")
    end

    local function run()
        local playerName, _ = UnitName("player")
        local realm = GetRealmName()
        debugPrint(format("player=%s realm=%s locale=%s", tostring(playerName), tostring(realm), tostring(GetLocale())))

        local nameToCharacter = database._db.global.realmToNameToCharacter[realm] or {}
        local player = nameToCharacter[playerName]
        local survival = player and player.professionsByLocalizedName["Survival"]
        if survival == nil then
            debugPrint("db: no Survival entry")
        else
            debugPrint(format("db: rank=%s names=%d ids=%d",
                tostring(survival.rank), getn(survival.knownLocalizedSkillNames), getn(survival.knownResultIds or {})))
        end

        local skills = LibCraftingProfessions:GetPlayerProfessionSkills("Survival")
        debugPrint(format("lcp: skills=%s", skills == nil and "nil" or tostring(getn(skills))))

        local crafts = repositories.craftRepository:GetCraftsByProfession("Survival")
        local missing = repositories.craftRepository:FindMissing(playerName, "Survival", "")
        debugPrint(format("crafts=%d filterKnown=%d filterMissing=%d",
            getn(crafts), getn(crafts) - getn(missing), getn(missing)))

        if survival ~= nil then
            local craftSet = {}
            for _, craft in ipairs(crafts) do
                craftSet[normalizeName(craft.localized_spell_name)] = true
            end
            local extras = {}
            for _, skillName in ipairs(survival.knownLocalizedSkillNames) do
                if craftSet[normalizeName(skillName)] == nil then
                    tinsert(extras, skillName)
                end
            end
            debugPrint(format("storedButNotInData(%d): %s", getn(extras), joinList(extras)))
        end
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
        local resultIds = {}
        for _, skill in ipairs(skills) do
            tinsert(skillNames, skill.localized_name)
            local resultId = parseItemId(skill.item_link)
            if resultId ~= nil then
                tinsert(resultIds, resultId)
            end
        end
        self.database:SaveCurrentPlayerSkills(profession.localized_name, profession.cur_rank, skillNames, resultIds)

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
