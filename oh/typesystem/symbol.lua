local types = require("oh.typesystem.types")

local META = {}
META.Type = "symbol"
META.__index = META

function META:GetSignature()
    return "symbol" .. "-" .. tostring(self.data)
end

function META:Get(key)
    return false, "cannot " .. tostring(self) .. "[" .. tostring(key) .."]"
    --return self.data
end

function META:Set(key, val)
    return false, "cannot " .. tostring(self) .. "[" .. tostring(key) .."] = " .. tostring(val)
    --self.data = val
end

function META:GetData()
    return self.data
end

function META:Copy()
    local copy = META:new(self:GetData())
    copy.truthy = self.truthy

    return copy
end

function META.SubsetOf(A, B)
    if B.Type == "tuple" and B:GetLength() == 1 then B = B:Get(1) end

    if B.Type == "set" then
        local errors = {}
        for _, b in ipairs(B:GetElements()) do
            local ok, reason = A:SubsetOf(b)
            if ok then
                return true
            end
            table.insert(errors, reason)
        end
        return false, table.concat(errors, "\n")
    end

    if A.Type == "any" or A.volatile then return true end
    if B.Type == "any" or B.volatile then return true end


    if A.data ~= B.data then
        return false, tostring(A) .. " is not the same as " .. tostring(B)
    end

    return true
end

function META:__tostring()
    return tostring(self.data)
end

function META:Serialize()
    return self:__tostring()
end

function META:IsVolatile()
    return self.volatile == true
end

function META:IsFalsy()
    return not self.truthy
end

function META:IsTruthy()
   return self.truthy
end

local uid = 0

function META:new(data)
    local self = setmetatable({}, self)

    uid = uid + 1

    self.uid = uid
    self.data = data
    self.literal = true

    self.truthy = not not self.data

    return self
end

types.RegisterType(META)

return META