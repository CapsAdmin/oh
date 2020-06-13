local types = require("oh.typesystem.types")

local Dictionary = {}
Dictionary.Type = "dictionary"
Dictionary.__index = Dictionary

function Dictionary:GetSignature()
    if self.supress then
        return "*self*"
    end
    self.supress = true

    if not self.data[1] then
        return "{}"
    end

    local s = {}

    for i, keyval in ipairs(self.data) do
        s[i] = keyval.key:GetSignature() .. "=" .. keyval.val:GetSignature()
    end
    self.supress = nil

    table.sort(s, function(a, b) return a > b end)

    return table.concat(s, "\n")
end

local level = 0
function Dictionary:Serialize()
    if not self.data[1] then
        return "{}"
    end

    if self.supress then
        return "*self*"
    end
    self.supress = true

    local s = {}

    level = level + 1
    for i, keyval in ipairs(self.data) do
        s[i] = ("\t"):rep(level) .. tostring(keyval.key) .. " = " .. tostring(keyval.val)
    end
    level = level - 1

    self.supress = nil

    table.sort(s, function(a, b) return a < b end)

    return "{\n" .. table.concat(s, ",\n") .. "\n" .. ("\t"):rep(level) .. "}"
end

function Dictionary:__tostring()
    return self:Serialize()--(self:Serialize():gsub("%s+", " "))
end

function Dictionary:GetLength()
    return #self.data
end

function Dictionary:SupersetOf(sub)
    if self == sub then
        return true
    end

    if sub.Type == "tuple" then
        if sub:GetLength() > 0 then
            for i, keyval in ipairs(self.data) do
                if keyval.key.type == "number" then
                    if not sub:Get(i) then
                        return false, "index " .. i .. " does not exist"
                    end
                    if not sub:Get(i):SupersetOf(keyval.val) then
                        return false, tostring(sub:Get(i)) " is not a superset of " .. tostring(keyval.val)
                    end
                end
            end
        else
            local count = 0
            for i, keyval in ipairs(self.data) do
                if keyval.key.data ~= i then
                    return false, "index " .. tostring(keyval.key.data) .. " is not the same as " .. tostring(i)
                end

                count = count + 1
            end
            if count ~= sub:GetMaxLength() then
                return false, " count " .. tostring(count) .. " is not the same as max length " .. tostring(sub:GetMaxLength())
            end
        end

        return true
    end

    if sub.Type == "dictionary" then

        if sub.meta and sub.meta == self then
            return true
        end

        done = done or {}
        for _, keyval in ipairs(self.data) do
            local val = sub:Get(keyval.key, true)

            if not val then
                return false, tostring(keyval.key) .. " does not exist in source table"
            end


            local key = keyval.val:Serialize() .. val:Serialize()
            if not done or not done[key] then
                if done then
                    done[key] = true
                end

                if not keyval.val:SupersetOf(val) then
                    return false, tostring(keyval.val) .. " is not a superset of " .. tostring(val)
                end
            end
        end
        done = nil

        return true
    end

    return false, tostring(self) .." is not a superset of " .. tostring(sub)
end

function Dictionary:Lock(b)
    self.locked = b
end

function Dictionary:Union(dict)
    local copy = types.Dictionary:new({})

    for _, keyval in ipairs(self.data) do
        copy:Set(keyval.key, keyval.val)
    end

    for _, keyval in ipairs(dict.data) do
        copy:Set(keyval.key, keyval.val)
    end

    return copy
end

function Dictionary:Set(key, val, env)
    key = types.Cast(key)
    val = types.Cast(val)

    if key.type == "nil" then
        return false, "key is nil"
    end

    if val == nil or val.type == "nil" then
        for i, keyval in ipairs(self.data) do
            if key:SupersetOf(keyval.key) then
                table.remove(self.data, i)
                return true
            end
        end
        return false
    end

    for _, keyval in ipairs(self.data) do
        if key:SupersetOf(keyval.key) and (env == "typesystem" or val:SupersetOf(keyval.val)) then
            if not self.locked then
                keyval.val = val
            end
            return true
        end
    end

    if not self.locked then
        table.insert(self.data, {key = key, val = val})
        return true
    end

    local obj = self

    local expected_keys = {}
    local expected_values = {}
    for _, keyval in ipairs(obj.data) do
        if not key:SupersetOf(keyval.key) then
            table.insert(expected_keys, tostring(keyval.key))
        elseif not val:SupersetOf(keyval.val) then
            table.insert(expected_values, tostring(keyval.val))
        end
    end

    if #expected_values > 0 then
        return false, "invalid value " .. tostring(val.type or val) .. " expected " .. table.concat(expected_values, " | ")
    elseif #expected_keys > 0 then
        return false, "invalid key " .. tostring(key.type or key) .. " expected " .. table.concat(expected_keys, " | ")
    end

    if env == "runtime" then
        for _, keyval in ipairs(self.data) do
            if key:SupersetOf(keyval.key) and not val:SupersetOf(keyval.val) then
                return false, tostring(val) .. " is not a superset of " .. tostring(keyval.val)
            end
        end
    end

    return false, "invalid key " .. tostring(key)
end

function Dictionary:Get(key, env)
    key = types.Cast(key)

    local keyval = self:GetKeyVal(key, env)
    if not keyval and self.meta then
        local index = self.meta:Get("__index")

        if index then
            if index.Type == "dictionary" then
                return index:Get(key)
            end

            if index.Type == "object" then
                local analyzer = require("oh").current_analyzer
                if analyzer then
                    return analyzer:Call(index, types.Tuple:new({self, key}), key.node)[1]
                end
                return index:Call(self, key):GetData()[1]
            end
        end
    end

    if keyval then
        return keyval.val
    end
end

function Dictionary:GetKeyVal(key, env)
    for _, keyval in ipairs(env == "typesystem" and self.structure or self.data) do
        if key:SupersetOf(keyval.key) then
            return keyval
        end
    end
end

function Dictionary:Copy()
    local copy = Dictionary:new({})

    for _, keyval in ipairs(self.data) do
        local k,v = keyval.key, keyval.val

        if k == self then
            k = copy
        else
            k = k:Copy()
        end

        if v == self then
            v = copy
        else
            k = k:Copy()
        end

        copy:Set(k,v)
    end

    copy.meta = self.meta

    return copy
end

function Dictionary:Extend(t)
    local copy = self:Copy()

    for _, keyval in ipairs(t.data) do
        if not copy:Get(keyval.key) then
            copy:Set(keyval.key, keyval.val)
        end
    end

    return copy
end

function Dictionary:IsConst()
    for _, v in ipairs(self.data) do
        if v.val ~= self and not v.val:IsConst() then
            return true
        end
    end
    return false
end

function Dictionary:IsFalsy()
    return false
end

function Dictionary:IsTruthy()
    return true
end

function Dictionary:PrefixOperator(op, val)
    if op == "not" then
        return types.Create("boolean", false)
    end

    if op == "#" then
        if self.meta and self.meta:Get("__len") then
            error("NYI")
        end

        return types.Create("number", #self.data, true)
    end

    return false, "NYI " .. op
end

function Dictionary:new(data)
    local self = setmetatable({}, self)

    self.data = {}
    self.structure = {}

    if data then
        for _, v in ipairs(data) do
            self:Set(v.key, v.val)
        end
    end

    return self
end

for k,v in pairs(types.BaseObject) do Dictionary[k] = v end
types.Dictionary = Dictionary

return Dictionary