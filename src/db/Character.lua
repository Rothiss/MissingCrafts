setfenv(1, MissingCrafts)

---@shape CharacterProfession
---@field localizedName string
---@field rank number
---@field knownLocalizedSkillNamesSet table<string, boolean>
---@field knownResultIdsSet table<number, boolean>

---@class Character
---@field name string
---@field professionLocalizedNameToProfession table<string, CharacterProfession>
Character = {}

---@param dbCharacter DatabaseCharacter
---@return self
function Character:Create(dbCharacter)
    ---@type table<string, CharacterProfession>
    local nameToProfession = {}

    for professionName, profession in pairs(dbCharacter.professionsByLocalizedName) do
        ---@type table<string, boolean>
        local skillSet = {}
        for _, skillName in ipairs(profession.knownLocalizedSkillNames) do
            skillSet[normalizeName(skillName)] = true
        end

        ---@type table<number, boolean>
        local resultIdSet = {}
        for _, resultId in ipairs(profession.knownResultIds or {}) do
            resultIdSet[resultId] = true
        end

        nameToProfession[professionName] = {
            localizedName = professionName,
            rank = profession.rank,
            knownLocalizedSkillNamesSet = skillSet,
            knownResultIdsSet = resultIdSet,
        }
    end

    local object = --[[---@type self]] {}
    setmetatable(object, {__index = Character})
    object.name = dbCharacter.name
    object.professionLocalizedNameToProfession = nameToProfession
    return object
end

---@param localizedName string
---@return number
function Character:GetProfessionRank(localizedName)
    local profession = self.professionLocalizedNameToProfession[localizedName]
    if profession == nil then
        return 0
    end
    return profession.rank
end

---@param craft Craft
---@return boolean
function Character:Knows(craft)
    local profession = self.professionLocalizedNameToProfession[craft.localizedProfessionName]
    if profession == nil then
        return false
    end

    if craft.resultId ~= nil and profession.knownResultIdsSet[craft.resultId] == true then
        return true
    end

    return profession.knownLocalizedSkillNamesSet[normalizeName(craft.localizedName)] == true
end
