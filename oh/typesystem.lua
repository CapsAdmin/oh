local syntax = require("oh.syntax")

local types = {}
types.newsystem = true

function types.Cast(val)
    if type(val) == "string" then
        return types.Object:new("string", val, true)
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
    return obj.Type ~= nil
end

function types.BinaryOperator(op, l, r, env)
    assert(types.IsTypeObject(l))
    assert(types.IsTypeObject(r))

    if env == "typesystem" then
        if op == "|" then
            return types.Set:new({l, r})
        end

        if op == "extends" then
            return l:Extend(r)
        end

        if op == "and" then
            return r and l
        end

        if op == "or" then
            return r or l
        end

        if r == false or r == nil then
            return false
        end

        if op == ".." then
            local new = l:Copy()
            new.max = r
            return new
        end
    end

    if op == "or" then
        if r.data ~= nil then
            return r
        end

        if l.data ~= nil then
            return l
        end

        return types.Set:new({l,r})
    end

    if op == "and" then
        if l.data ~= nil and r.data ~= nil then
            if l.data and r.data then
                return r
            end
        end
        return types.Object:new("boolean", false, true)
    end

    if op == "==" then
        if l.Type == "object" and r.Type == "object" then
            if l.max and l.max.data then
                return types.Object:new("boolean", r.data >= l.data and r.data <= l.max.data, true)
            end

            if r.max and r.max.data then
                return types.Object:new("boolean", l.data >= r.data and l.data <= r.max.data, true)
            end
        end

        if l.data ~= nil and r.data ~= nil then
            return types.Object:new("boolean", l.data == r.data)
        end

        return types.Object:new("boolean")
    end

    if op == ">" then
        if l.data ~= nil and r.data ~= nil then
            return types.Object:new("boolean", r.data > l.data)
        end

        return types.Object:new("boolean")
    end

    if op == "<" then
        if l.data ~= nil and r.data ~= nil then
            return types.Object:new("boolean", r.data < l.data)
        end

        return types.Object:new("boolean")
    end

    if op == "<=" then
        if l.data ~= nil and r.data ~= nil then
            return types.Object:new("boolean", r.data <= l.data)
        end

        return types.Object:new("boolean")
    end

    if op == ">=" then
        if l.data ~= nil and r.data ~= nil then
            return types.Object:new("boolean", r.data >= l.data)
        end

        return types.Object:new("boolean")
    end


    if op == "%" then
        if l.data ~= nil and r.data ~= nil then
            return types.Object:new("number", r.data % l.data)
        end
        local t = types.Object:new("number", 0)
        t.max = l:Copy()
        return t
    end

    if op == ".." then
        if l.data ~= nil and r.data ~= nil then
            return types.Object:new("string", r.data .. l.data)
        end
    end

    if syntax.CompiledBinaryOperatorFunctions[op] and l.data ~= nil and r.data ~= nil then

        if l.type ~= r.type then
            return false, "no operator for " .. tostring(r.type or r) .. " " .. op .. " " .. tostring(l.type or l)
        end

        local lval = l.data
        local rval = r.data
        local type = l.type

        if l.Type == "tuple" then
            lval = l.data[1].data
            type = l.data[1].type
        end

        if r.Type == "tuple" then
            rval = r.data[1].data
        end

        local ok, res = pcall(syntax.CompiledBinaryOperatorFunctions[op], rval, lval)

        if not ok then
            return false, res
        else
            return types.Object:new(type, res)
        end
    end

    -- todo
    if l.type == r.type then
        return types.Object:new(l.type)
    end

    if op == "or" then
        if l.data then
            return l
        end

        return r
    end

    error(" NYI " .. env .. ": "..tostring(l).." "..op.. " "..tostring(r))
end

function types.NewIndex(obj, key, val, env)
    if obj.Type ~= "dictionary" then
        return false, "undefined set: " .. tostring(obj) .. "[" .. tostring(key) .. "] = " .. tostring(val)
    end

    return obj:Set(key, val, env)
end


function types.Index(obj, key)
    if obj.Type ~= "dictionary" and obj.Type ~= "tuple" and (obj.Type ~= "object" or obj.type ~= "string") then
        return false, "undefined get: " .. tostring(obj) .. "[" .. tostring(key) .. "]"
    end

    return obj:Get(key)
end

do
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

        table.sort(s, function(a, b) return a > b end)

        return "{\n" .. table.concat(s, ",\n") .. "\n" .. ("\t"):rep(level) .. "}"
    end

    function Dictionary:__tostring()
        return (self:Serialize():gsub("%s+", " "))
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
                        if not sub:Get(i) or not sub:Get(i):SupersetOf(keyval.val) then
                            return false
                        end
                    end
                end
            else
                local count = 0
                for i, keyval in ipairs(self.data) do
                    if keyval.key.data ~= i then
                        return false
                    end

                    count = count + 1
                end
                if count ~= sub:GetMaxLength() then
                    return false
                end
            end

            return true
        end


        for _, keyval in ipairs(self.data) do
            local val = sub:Get(keyval.key, true)

            if not val then
                return false
            end

            if not keyval.val:SupersetOf(val) then
                return false
            end
        end


        return true
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

        local data = self.data

        if val == nil or val.type == "nil" then
            for i, keyval in ipairs(data) do
                if key:SupersetOf(keyval.key) then
                    table.remove(data, i)
                    return true
                end
            end
            return false
        end

        for _, keyval in ipairs(data) do
            if key:SupersetOf(keyval.key) and (env == "typesystem" or val:SupersetOf(keyval.val)) then
                if not self.locked then
                    keyval.val = val
                end
                return true
            end
        end

        if not self.locked then
            table.insert(data, {key = key, val = val})
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

        return false, "invalid key " .. tostring(key.type or key)
    end

    function Dictionary:Get(key, env)
        key = types.Cast(key)

        local keyval = self:GetKeyVal(key, env)

        if not keyval and self.meta then
            local index = self.meta:Get("__index")
            if index.Type == "dictionary" then
                return index:Get(key)
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
            copy:Set(keyval.key, keyval.val)
        end

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

    function Dictionary:IsTruthy()
        return true
    end

    function Dictionary:PrefixOperator(op, val)
        if op == "#" then
            if self.meta and self.meta:Get("__len") then
                error("NYI")
            end

            return types.Create("number", #self.data, true)
        end
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

    types.Dictionary = Dictionary


end

do
    local Object = {}
    Object.Type = "object"
    Object.__index = Object

    function Object:GetSignature()
        if self.type == "function" then
            return self.type .. "-"..types.GetSignature(self.data)
        end
        if self.const then
            return self.type .. "-" .. types.GetSignature(self.data)
        end

        return self.type
    end

    function Object:SetType(name)
        assert(name)
        self.type = name
    end

    function Object:IsType(name)
        return self.type == name
    end

    function Object:GetLength()
        if type(self.data) == "table" then
            if self.data.GetLength then
                return self.data:GetLength()
            end

            return #self.data
        end

        return 0
    end

    function Object:Get(key)
        local val = type(self.data) == "table" and self.data:Get(key)

        if not val and self.meta then
            local index = self.meta:Get("__index")
            if index.Type == "dictionary" then
                return index:Get(key)
            end
        end

        return val
    end

    function Object:Set(key, val)
        return self.data:Set(key, val)
    end

    function Object:GetArguments()
        return self.data.arg
    end

    function Object:GetReturnTypes()
        return self.data.ret
    end



    function Object:SupersetOf(sub)
        if sub.Type == "tuple" and sub:GetLength() == 1 then
            sub = sub.data[1]
        end

        if self.type == "any" or self.volatile then
            return true
        end

        if sub.Type == "set" then
           return sub:Get(self) ~= nil
        end

        if sub.Type == "object" then
            if sub.type == "any" or sub.volatile then
                return true
            end

            if self.type == sub.type then

                if self.const == true and sub.const == true then

                    if self.data == sub.data then
                        return true
                    end

                    if self.type == "number" and sub.type == "number" and self.max then
                        if sub.data > self.data and sub.data < self.max.data then
                            return true
                        end
                    end

                    if self.type == "number" and sub.type == "number" and self.type == "list" and self.data and self.data.Type == "tuple" then
                        local min = self:Get(1).data
                        local max = self:Get(2).data

                        if sub.data and sub.data.Type == "tuple" then
                            if sub:Get(1) >= min and sub:Get(2) <= max then
                                return true
                            end
                        else
                            if sub.data >= min and sub.data <= max then
                                return true
                            end
                        end
                    end
                end

                -- "5" must be within "number"
                if self.data == nil and sub.data ~= nil then
                    return true
                end

                -- self = number(1)
                -- sub = 1
                if self.data ~= nil and self.data == sub.data then
                    return true
                end

                if sub.data == nil or self.data == nil then
                    return true
                end

                if not self.const and not sub.const then
                    return true
                end
            end

            return false
        end

        return false
    end

    function Object.SubsetOf(a,b)
        return b:SupersetOf(a)
    end

    function Object:__tostring()
        --return "「"..self.uid .. " 〉" .. self:GetSignature() .. "」"

        if self.type == "function" then
            return "function" .. tostring(self.data.arg) .. ": " .. tostring(self.data.ret)
        end


        if self.volatile then
            local str = self.type

            if self.data ~= nil then
                str = str .. "(" .. tostring(self.data) .. ")"
            end

            str = str .. "💥"

            return str
        end

        if self.const then
            if self.type == "string" then
                if self.data then
                    return ("%q"):format(self.data)
                end
            end

            if self.data == nil then
                return self.type
            end

            return tostring(self.data) .. (self.max and (".." .. self.max.data) or "")
        end

        if self.data == nil then
            return self.type
        end

        return self.type .. "(".. tostring(self.data) .. (self.max and (".." .. self.max.data) or "") .. ")"
    end

    function Object:Serialize()
        return self:__tostring()
    end

    do
        Object.truthy = 0

        function Object:GetTruthy()
            return self.truthy > 0
        end

        function Object:PushTruthy()
            self.truthy = self.truthy + 1
        end
        function Object:PopTruthy()
            self.truthy = self.truthy + 1
        end
    end

    function Object:Max(val)
        if self.type == "number" then
            self.max = val
        end
        return self
    end

    function Object:IsTruthy()
        return self.type ~= "nil" and self.type ~= "false" and self.data ~= false
    end

    function Object:RemoveNonTruthy()
        return self
    end

    function Object:IsConst()
        return self.const
    end

    function Object:Call(arguments)
        if self.type == "function" and self.data.lua_function then
            _G.self = require("oh").current_analyzer
            local res = {pcall(self.data.lua_function, unpack(arguments.data))}
            _G.self = nil

            if not res[1] then
                return false, res[2]
            end

            if not res[2] then
                res[2] = types.Object:new("nil")
            end

            table.remove(res, 1)

            return types.Tuple:new(res)
        end
        if not self.data.arg:SupersetOf(arguments) then
            return false, "cannot call " .. tostring(self) .. " with arguments " ..  tostring(arguments)
        end

        return self.data.ret
    end

    function Object:PrefixOperator(op, val)
        if syntax.CompiledPrefixOperatorFunctions[op] and val.data ~= nil then
            local ok, res = pcall(syntax.CompiledPrefixOperatorFunctions[op], val.data)

            if not ok then
                return false, res
            else
                return types.Object:new(val.type, res)
            end
        end
        return false, "NYI " .. op
    end

    local uid = 0

    function Object:new(type, data, const)
        local self = setmetatable({}, self)

        uid = uid + 1

        self.uid = uid
        self:SetType(type)
        self.data = data
        self.const = const

        return self
    end

    types.Object = Object
end

do
    local Tuple = {}
    Tuple.Type = "tuple"
    Tuple.__index = Tuple

    function Tuple:GetSignature()
        local s = {}

        for i,v in ipairs(self.data) do
            s[i] = types.GetSignature(v)
        end

        return table.concat(s, " ")
    end

    function Tuple:Merge(tup)
        local src = self.data
        local dst = tup.data

        for i,v in ipairs(dst) do
            if src[i] and src[i].type ~= "any" then
                if src[i].volatile then
                    v.volatile = true -- todo: mutation, copy instead?
                end
                src[i] = types.Set:new({src[i], v})
            else
                local prev = src[i]

                src[i] = dst[i]

                if prev and prev.volatile then
                    src[i].volatile = true -- todo: mutation, copy instead?
                end
            end
        end

        return self
    end

    function Tuple:GetMaxLength()
        return self.max or 0
    end

    function Tuple:GetLength()
        return #self.data
    end

    function Tuple:SupersetOf(sub)
        if self:GetLength() == 1 then
            return self.data[1]:SupersetOf(sub)
        end

        if sub.Type == "dictionary" then
            local hm = {}

            for i,v in ipairs(sub.data) do
                if v.key.type == "number" then
                    hm[v.key.data] = v.val.data
                end
            end

            if #hm ~= #sub.data then
                return false
            end
        end

        for i = 1, sub:GetLength() do
            local a = self:Get(i)
            local b = sub:Get(i)

            -- vararg
            if a and a.max == math.huge and a:Get(1):SupersetOf(b) then
                return true
            end

            if b.type ~= "any" and (not a or not a:SupersetOf(b)) then
                return false
            end
        end

        return true
    end

    function Tuple:Get(key)
        if type(key) == "number" then
            return self.data[key]
        end

        if key.Type == "object" then
            if key:IsType("number") then
                key = key.data
            elseif key:IsType("string") then
                key = key.data
            end
        end

        return self.data[key]
    end

    function Tuple:Set(key, val)
        self.data[key] =  val
    end

    function Tuple:__tostring()
        local s = {}

        for i,v in ipairs(self.data) do
            s[i] = tostring(v)
        end

        return "(" .. table.concat(s, ", ") .. (self.max == math.huge and "..." or (self.max and ("#" .. self.max)) or "") .. ")"
    end

    function Tuple:Serialize()
        return self:__tostring()
    end

    function Tuple:IsConst()
        for i,v in ipairs(self.data) do
            if not v:IsConst() then
                return false
            end
        end
        return true
    end

    function Tuple:IsTruthy()
        return self.data[1] and self.data[1]:IsTruthy()
    end

    function Tuple:new(tbl)
        local self = setmetatable({}, self)
        self.data = tbl or {}

        for i,v in ipairs(self.data) do
            if not types.IsTypeObject(v) then
                error(tostring(v) .. " is not a type object")
            end
        end

        return self
    end

    types.Tuple = Tuple
end

do
    local Set = {}
    Set.Type = "set"
    Set.__index = Set

    local sort = function(a, b) return a < b end

    function Set:GetSignature()
        local s = {}

        for _, v in ipairs(self.datai) do
            table.insert(s, types.GetSignature(v))
        end

        table.sort(s, sort)

        return table.concat(s, "|")
    end

    function Set:Call(arguments)
        local out = types.Set:new()

        for _, obj in ipairs(self.datai) do
            if not obj.Call then
                return false, "set contains uncallable object " .. tostring(obj)
            end

            local return_tuple = obj:Call(arguments)

            if return_tuple then
                out:AddElement(return_tuple)
            end
        end

        return types.Tuple:new({out})
    end

    function Set:__tostring()
        local s = {}
        for _, v in ipairs(self.datai) do
            table.insert(s, tostring(v))
        end

        table.sort(s, function(a, b) return a < b end)

        return table.concat(s, " | ")
    end

    function Set:Serialize()
        return self:__tostring()
    end

    function Set:AddElement(e)
        if e.Type == "set" then
            for _, e in ipairs(e.datai) do
                self:AddElement(e)
            end
            return self
        end

        if not self.data[types.GetSignature(e)] then
            self.data[types.GetSignature(e)] = e
            table.insert(self.datai, e)
        end

        return self
    end

    function Set:GetLength()
        return #self.datai
    end

    function Set:RemoveElement(e)
        self.data[types.GetSignature(e)] = nil
        for i,v in ipairs(self.datai) do
            if types.GetSignature(v) == types.GetSignature(e) then
                table.remove(self.datai, i)
                return
            end
        end
    end

    function Set:Get(key, from_dictionary)
        key = types.Cast(key)

        if from_dictionary then
            for _, obj in ipairs(self.datai) do
                if obj.Get then
                    local val = obj:Get(key)
                    if val then
                        return val
                    end
                end
            end
        end

        local val = self.data[key.type] or self.data[key:GetSignature()]
        if val then
            return val
        end

        for _, obj in ipairs(self.datai) do
            if obj.volatile then
                return obj
            end
        end
    end

    function Set:Set(key, val)
        return self:AddElement(val)
    end

    function Set:SupersetOf(sub)
        if sub.Type == "tuple" and sub:GetLength() == 1 then
            sub = sub.data[1]
        end

        if sub.Type == "object" then
            return self:Get(sub) ~= nil
        end

        if sub.Type == "set" then
            for k,v in ipairs(sub.datai) do
                if self.data[types.GetSignature(v)] == nil or not v:SupersetOf(self.data[types.GetSignature(v)]) then
                    return false
                end
            end
            return true
        elseif not self:Get(sub) then
            return false
        end

        for _, e in ipairs(self.datai) do
            if not sub:Get(e)then
                return false
            end
        end

        return true
    end

    function Set:Union(set)
        local copy = self:Copy()

        for _, e in ipairs(set.datai) do
            copy:AddElement(e)
        end

        return copy
    end


    function Set:Intersect(set)
        local copy = types.Set:new()

        for _, e in ipairs(self.datai) do
            if set:Get(e) then
                copy:AddElement(e)
            end
        end

        return copy
    end


    function Set:Subtract(set)
        local copy = self:Copy()

        for _, e in ipairs(self.datai) do
            copy:RemoveElement(e)
        end

        return copy
    end

    function Set:Copy()
        local copy = Set:new()
        for _, e in ipairs(self.datai) do
            copy:AddElement(e)
        end
        return copy
    end

    function Set:IsConst()
        for _, v in ipairs(self.datai) do
            if not v.const then
                return false
            end
        end

        return true
    end

    function Set:IsTruthy()
        for _, v in ipairs(self.datai) do
            if v:IsTruthy() then
                return true
            end
        end

        return false
    end

    function Set:new(values)
        local self = setmetatable({}, Set)

        self.data = {}
        self.datai = {}

        if values then
            for _, v in ipairs(values) do
                self:AddElement(v)
            end
        end

        return self
    end

    types.Set = Set
end

function types.Create(type, data, const)
    if type == "table" then
        return types.Dictionary:new(data)
    elseif type == "..." then
        return types.Tuple:new(data)
    elseif type == "number" or type == "string" or type == "function" or type == "boolean" then
        return types.Object:new(type, data, const)
    elseif type == "nil" then
        return types.Object:new(type, const)
    elseif type == "any" then
        return types.Object:new(type, const)
    elseif type == "list" then
        data = data or {}
        local tup = types.Tuple:new(data.values)
        tup.max = data.length
        return tup
    end
    error("NYI " .. type)
end

return types