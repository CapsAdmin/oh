local type_errors = require("nattlua.types.error_messages")

local META = {}
META.Type = "string"
require("nattlua.types.base")(META)

function META.Equal(a, b)
    if a.Type ~= b.Type then return false end
    
    if a:IsLiteral() and b:IsLiteral() then
        return a:GetData() == b:GetData()
    end
    
    if not a:IsLiteral() and not b:IsLiteral() then
        return true
    end

    return false
end

function META:GetLuaType()
    return self.Type
end

function META:Copy()
    local copy =  self:New(self:GetData()):SetLiteral(self:IsLiteral())
    copy.pattern_contract = self.pattern_contract
    copy:CopyInternalsFrom(self)
    return copy
end

function META:SetPattern(str)
    self.pattern_contract = str
end

function META.IsSubsetOf(A, B)
    if B.Type == "tuple" and B:GetLength() == 1 then B = B:Get(1) end
    
    if B.Type == "union" then
        local errors = {}
        for _, b in ipairs(B:GetData()) do
            local ok, reason = A:IsSubsetOf(b)
            if ok then
                return true
            end
            table.insert(errors, reason)
        end
        return type_errors.other(errors)
    end

    if B.Type == "any" then return true end

    if B.Type ~= "string" then
        return type_errors.type_mismatch(A, B)
    end

    if 
        (A:IsLiteral() and B:IsLiteral() and A:GetData() == B:GetData()) or -- "A" subsetof "B"
        (A:IsLiteral() and not B:IsLiteral()) or -- "A" subsetof string
        (not A:IsLiteral() and not B:IsLiteral()) -- string subsetof string
    then
        return true
    end

    if B.pattern_contract then
        if not A:GetData() then -- TODO: this is not correct, it should be :IsLiteral() but I have not yet decided this behavior yet
            return type_errors.literal(A)
        end

        if not A:GetData():find(B.pattern_contract) then
            return type_errors.string_pattern(A, B)
        end

        return true
    end

    if A:IsLiteral() and B:IsLiteral() then
        return type_errors.value_mismatch(A, B)
    end

    return type_errors.subset(A, B)
end

function META:__tostring()

    if self.pattern_contract then
        return "$(" .. self.pattern_contract .. ")"
    end

    if self:IsLiteral() then
        if self:GetData() then
            return "\"" .. self:GetData() .. "\""
        end

        if self:GetData() == nil then
            return "string"
        end

        return tostring(self:GetData())
    end

    if self:GetData() == nil then
        return "string"
    end

    return "string(".. tostring(self:GetData()) .. ")"
end

function META:IsFalsy()
    return false
end

function META:IsTruthy()
    return true
end

function META:Initialize()
    self:SetMetaTable(require("nattlua.runtime.string_meta"))

    return self
end

return META