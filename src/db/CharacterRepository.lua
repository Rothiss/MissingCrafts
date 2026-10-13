setfenv(1, MissingCrafts)

---@class CharacterRepository
---@field _db Database
---@field _charactersByName table<string, Character>
---@field _cachedRevision number|nil
CharacterRepository = {}

---@param database Database
---@return self
function CharacterRepository:Create(database)
    self._db = database
    self._charactersByName = {}
    self._cachedRevision = nil
    return self
end

function CharacterRepository:_RefreshIfNeeded()
    local revision = self._db:GetRevision()
    if self._cachedRevision == revision then
        return
    end

    ---@type table<string, Character>
    local charactersByName = {}
    for _, dbCharacter in ipairs(self._db:GetCharacters()) do
        if charactersByName[dbCharacter.name] == nil then
            charactersByName[dbCharacter.name] = Character:Create(dbCharacter)
        end
    end
    self._charactersByName = charactersByName
    self._cachedRevision = revision
end

---@param exceptName ?string|nil
---@return Character[]
function CharacterRepository:FindAll(exceptName)
    self:_RefreshIfNeeded()
    ---@type Character[]
    local characters = {}
    for name, character in pairs(self._charactersByName) do
        if name ~= exceptName then
            tinsert(characters, character)
        end
    end
    return characters
end

---@param name string
---@return Character|nil
function CharacterRepository:Find(name)
    self:_RefreshIfNeeded()
    return self._charactersByName[name]
end
