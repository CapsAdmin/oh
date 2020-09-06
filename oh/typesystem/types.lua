local analyzer_env = require("oh.lua.analyzer_env")

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

local function store_error(msg)
    do return end -- WIP
    local a = analyzer_env.GetCurrentAnalyzer()
    if a then
        a.error_stack = a.error_stack or {}
        table.insert(a.error_stack, {
            msg = msg,
            expression = a.current_expression,
            statement = a.current_statement,
        })
    end

end

types.errors = {
    subset = function(a, b, reason)
        local msg = tostring(a) .. " is not a subset of " .. tostring(b)

        if reason then
            msg = msg .. " because " .. reason
        end

        store_error(msg)
        return false, msg
    end,
    missing = function(a, b)
        local msg = tostring(a) .. " does not contain " .. tostring(b)
        store_error(msg)
        return false, msg
    end,
    other = function(msg)
        store_error(msg)
        return false, msg
    end,
}

function types.Cast(val)
    if type(val) == "string" then
        return types.String(val):MakeLiteral(true)
    elseif type(val) == "boolean" then
        return types.Symbol(val)
    elseif type(val) == "number" then
        return types.Number(val):MakeLiteral(true)
    end
    return val
end

function types.IsPrimitiveType(val)
    return val == "string" or
    val == "number" or
    val == "boolean" or
    val == "true" or
    val == "false" or
    val == "nil"
end

function types.IsTypeObject(obj)
    return type(obj) == "table" and obj.Type ~= nil
end

do
    local Base = {}

    function Base:IsUncertain()
        return self:IsTruthy() and self:IsFalsy()
    end

    function Base:GetSignature()
        error("NYI")
    end

    function Base:GetSignature()
        error("NYI")
    end

    Base.literal = false

    function Base:MakeExplicitNotLiteral(b)
        self.explicit_not_literal = b
        return self
    end

    function Base:MakeLiteral(b)
        self.literal = b
        return self
    end

    function Base:IsLiteral()
        return self.literal
    end

    types.BaseObject = Base
end

local uid = 0
function types.RegisterType(meta)
    for k, v in pairs(types.BaseObject) do
        if not meta[k] then
            meta[k] = v
        end
    end

    return function(data)
        local self = setmetatable({}, meta)
        self.data = data
        self.uid = uid
        uid = uid + 1
        
        if self.Initialize then
            local ok, err = self:Initialize(data)
            if not ok then
                return ok, err
            end
        end
    
        local a = analyzer_env.GetCurrentAnalyzer()
        if a then
            self.node = a.current_expression
        end

        return self
    end
end

function types.Initialize()
    types.Set = require("oh.typesystem.set")
    types.Table = require("oh.typesystem.table")
    types.Tuple = require("oh.typesystem.tuple")
    types.Number = require("oh.typesystem.number")
    types.Function = require("oh.typesystem.function")
    types.String = require("oh.typesystem.string")
    types.Any = require("oh.typesystem.any")
    types.Symbol = require("oh.typesystem.symbol")

    types.Nil = types.Symbol()
    types.True = types.Symbol(true)
    types.False = types.Symbol(false)
    types.Boolean = types.Set({types.True, types.False}):MakeExplicitNotLiteral(true)
    types.NumberType = types.Number()
    types.StringType = types.String()
end

return types