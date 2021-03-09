local types = {}

function types.Cast(val)
    if type(val) == "string" then
        return types.String(val):SetLiteral(true)
    elseif type(val) == "boolean" then
        return types.Symbol(val)
    elseif type(val) == "number" then
        return types.Number(val):SetLiteral(true)
    elseif type(val) == "table" then
        if val.kind == "value" then
            return types.String(val.value.value):SetLiteral(true)
        end

        if not val.Type then
            error("cannot cast" .. tostring(val), 2)
        end
    end

    return val
end

function types.IsTypeObject(obj)
    return type(obj) == "table" and obj.Type ~= nil
end

do
    local compare_condition

    local function cmp(a, b, context, source)
        if not context[a] then
            context[a] = {}
            context[a][b] = types.FindInType(a, b, context, source)
        end
        return context[a][b]
    end

    function types.FindInType(a, b, context, source)
        source = source or b
        context = context or {}

        if not a then return false end
        
        if a == b then return source end
            
        if a.upvalue and b.upvalue then

            if a.upvalue_keyref or b.upvalue_keyref then
                return a.upvalue_keyref == b.upvalue_keyref and source or false
            end

            if a.upvalue == b.upvalue then
                return source
            end
        end


        if a.upvalue and a.upvalue.value then
            return cmp(a.upvalue.value, b, context, a)
        end

        if a.type_checked then
            return cmp(a.type_checked, b, context, a)
        end

        if a.source_left then
            return cmp(a.source_left, b, context, a)
        end

        if a.source_right then
            return cmp(a.source_right, b, context, a)
        end

        if a.source then
            return cmp(a.source, b, context, a)
        end

        return false
    end
end

function types.RegisterType(meta)
    return function(data)
        local self = setmetatable({
            data = data,
        }, meta)
                
        if self.Initialize then
            local ok, err = self:Initialize(data)
            if not ok then
                return ok, err
            end
        end
    
        return self
    end
end

function types.Initialize()
    types.Union = types.RegisterType(require("nattlua.types.union"))
    types.Table = types.RegisterType(require("nattlua.types.table"))
    types.List = types.RegisterType(require("nattlua.types.list"))
    types.Tuple = types.RegisterType(require("nattlua.types.tuple"))
    types.Number = types.RegisterType(require("nattlua.types.number"))
    types.Function = types.RegisterType(require("nattlua.types.function"))
    types.String = types.RegisterType(require("nattlua.types.string"))
    types.Any = types.RegisterType(require("nattlua.types.any"))
    types.Symbol = types.RegisterType(require("nattlua.types.symbol"))
    
    types.Nil = function() return types.Symbol(nil) end
    types.True = function() return types.Symbol(true) end
    types.False = function() return types.Symbol(false) end
    types.Boolean = function() return types.Union({types.True(), types.False()}) end
end

return types