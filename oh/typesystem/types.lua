local syntax = require("oh.lua.syntax")

local types = {}



--[[
    this keeps confusing me

    subset:
        A subsetof B
        A within B
        A inside B
        A compatible with B
        A child of B

    superset:
        A parent of B
        A supersetof B
        A covers B
        A contains B
        A has B
        A owns B
        A entails B
]]


types.errors = {
    subset = function(a, b, reason)
        local msg = tostring(a) .. " is not a subset of " .. tostring(b)

        if reason then
            msg = msg .. " because " .. reason
        end

        return false, msg
    end,
    missing = function(a, b)
        return false, tostring(a) .. " does not contain " .. tostring(b)
    end
}

function types.Cast(val)
    if type(val) == "string" then
        return types.Object:new("string", val, true)
    elseif type(val) == "boolean" then
        return types.Object:new("boolean", val, true)
    elseif type(val) == "number" then
        return types.Object:new("number", val, true)
    end
    return val
end

function types.GetSignature(obj)
    if type(obj) == "table" and obj.GetSignature then
        return obj:GetSignature()
    end

    return tostring(obj)
end

function types.IsPrimitiveType(val)
    return val == "string" or
    val == "number" or
    val == "boolean" or
    val == "true" or
    val == "false"
end

function types.IsTypeObject(obj)
    return type(obj) == "table" and obj.Type ~= nil
end

do
    local Base = {}

    do
        Base.truthy = 0

        function Base:GetTruthy()
            return self.truthy > 0
        end

        function Base:PushTruthy()
            self.truthy = self.truthy + 1
        end
        function Base:PopTruthy()
            self.truthy = self.truthy + 1
        end
    end


    Base["or"] = function(l, r, env)

        if l:IsTruthy() and l:IsFalsy() then
            return types.Set:new({l,r})
        end

        if r:IsTruthy() and r:IsFalsy() then
            return types.Set:new({l,r})
        end

        -- when true, or returns its first argument
        if l:IsTruthy() then
            return l
        end

        if r:IsTruthy() then
            return r
        end

        return r
    end

    Base["not"] = function(l, r, env)
        if l:IsTruthy() then
            if l:IsFalsy() then
                return Object:new("boolean")
            end

            return Object:new("boolean", false, true)
        end

        return Object:new("boolean", true, true)
    end

    Base["and"] = function(l,r,env)

        if l:IsTruthy() and r:IsFalsy() then
            if l:IsFalsy() or r:IsTruthy() then
                return types.Set:new({l,r})
            end

            return r
        end

        if l:IsFalsy() and r:IsTruthy() then
            if l:IsTruthy() or r:IsFalsy() then
                return types.Set:new({l,r})
            end

            return l
        end

        if l:IsTruthy() and r:IsTruthy() then
            if l:IsFalsy() and r:IsFalsy() then
                return types.Set:new({l,r})
            end

            return r
        else
            if l:IsTruthy() and r:IsTruthy() then
                return types.Set:new({l,r})
            end

            return l
        end
    end

    Base["=="] = function(l,r,env)
        do -- number specific
            if l.max and l.max.data then
                return types.Object:new("boolean", r.data >= l.data and r.data <= l.max.data, true)
            end

            if r.max and r.max.data then
                return types.Object:new("boolean", l.data >= r.data and l.data <= r.max.data, true)
            end
        end

        if (l.data ~= nil or l.type == "nil") and (r.data ~= nil or r.type == "nil") then
            return types.Object:new("boolean", l.data == r.data)
        end

        return types.Object:new("boolean")
    end

    Base["~="] = function(l,r,env)
        do -- number specific
            if l.max and l.max.data then
                return types.Object:new("boolean", not (r.data >= l.data and r.data <= l.max.data), true)
            end

            if r.max and r.max.data then
                return types.Object:new("boolean", not (l.data >= r.data and l.data <= r.max.data), true)
            end
        end

        if (l.data ~= nil or l.type == "nil") and (r.data ~= nil or r.type == "nil") then
            return types.Object:new("boolean", l.data ~= r.data)
        end

        return types.Object:new("boolean")
    end

    types.BaseObject = Base
end

function types.Initialize()
    types.Set = require("oh.typesystem.set")
    types.Dictionary = require("oh.typesystem.dictionary")
    types.Tuple = require("oh.typesystem.tuple")
    types.Object = require("oh.typesystem.object")
end

return types