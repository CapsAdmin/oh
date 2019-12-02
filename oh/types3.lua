local types = {}

function types.GetSignature(obj)
    if type(obj) == "table" and obj.GetSignature then
        return obj:GetSignature()
    end

    return tostring(obj)
end

function types.IsType(obj, what)
    return getmetatable(obj) == types[what]
end

function types.GetObjectType(val)
    return getmetatable(val) == types.Object and val.type
end

function types.GetType(val)
    local m = getmetatable(val)
    if m then
        if m == types.Set then
            return "set"
        elseif m == types.Tuple then
            return "tuple"
        elseif m == types.Object then
            return "object"
        elseif m == types.Dictionary then
            return "dictionary"
        end
    end
end

function types.SupersetOf(a, b)
    return a:SupersetOf(b)
end

function types.Union(a, b)
    if types.IsType(a, "Dictionary") and types.IsType(b, "Dictionary") then
        local copy = types.Dictionary:new({})

        for _, keyval in pairs(a.data) do
            copy:Set(keyval.key, keyval.val)
        end

        for _, keyval in pairs(b.data) do
            copy:Set(keyval.key, keyval.val)
        end

        return copy
    end
end

function types.NewIndex(obj, key, val)

end

function types.Index(obj, key)

end

function types.BinaryOperator(op, l, r, env)
    if env == "typesystem" then
        if op == "|" then
            return types.Set:new(l, r)
        end
    end
end

do

    local Dictionary = {}
    Dictionary.__index = Dictionary

    function Dictionary:GetSignature()
        if self.supress then
            return "*self*"
        end
        self.supress = true

        local s = {}

        for i, keyval in ipairs(self.data) do
            s[i] = keyval.key:GetSignature() .. "=" .. keyval.val:GetSignature()
        end
        self.supress = nil

        table.sort(s, function(a, b) return a > b end)

        return table.concat(s, "\n")
    end

    local level = 0
    function Dictionary:__tostring()
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

    function Dictionary:GetLength()
        return #self.data
    end

    function Dictionary:SupersetOf(sub)
        for _, keyval in ipairs(self.data) do
            local val = sub:Get(keyval.key)
            if not val then
                return false
            end

            if not types.SupersetOf(keyval.val, val) then
                return false
            end
        end


        return true
    end

    function Dictionary:Lock(b)
        self.locked = true
    end

    function Dictionary:Set(key, val)
        for _, keyval in ipairs(self.data) do
            if types.SupersetOf(key, keyval.key) and types.SupersetOf(val, keyval.val) then
                keyval.val = val
                return
            end
        end

        if not self.locked then
            table.insert(self.data, {key = key, val = val})
        end
    end

    function Dictionary:Get(key)
        local keyval = self:GetKeyVal(key)
        if keyval then
            return keyval.val
        end
    end

    function Dictionary:GetKeyVal(key)
        for _, keyval in ipairs(self.data) do
            if types.SupersetOf(key, keyval.key) then
                return keyval
            end
        end
    end


    function Dictionary:new(data)
        local self = setmetatable({}, self)

        self.data = data

        return self
    end

    types.Dictionary = Dictionary


end

do
    local Object = {}
    Object.__index = Object

    function Object:GetSignature()
        if self.const then
            return self.type .. "-" .. types.GetSignature(self.data)
        end

        return self.type
    end

    function Object:SetType(name)
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
        local val = self.data:Get(key)

        if not val and self.meta then
            local index = self.meta:Get(types.Object:new("string", "__index", true))
            if index.type == "table" then
                return index:Get(key)
            end
        end

        return val
    end

    function Object:Set(key, val)
        return self.data:Set(key, val)
    end

    function Object:Call(args)
        return self.data:Get(args)
    end

    function Object:SupersetOf(sub)
        if types.IsType(sub, "Set") then
           return sub:Get(self) ~= nil
        end

        if types.IsType(sub, "Object") then
            if self.type == sub.type then

                if self.const == true and sub.const == true then

                    if self.data == sub.data then
                        return true
                    end

                    if self.type == "number" and sub.type == "number" and types.IsType(self.data, "Tuple") then
                        local min = self:Get(1).data
                        local max = self:Get(2).data

                        if types.IsType(sub.data, "Tuple") then
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

                if self.const and not sub.const then
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

    function Object:__tostring()
        --return "「"..self.uid .. " 〉" .. self:GetSignature() .. "」"
        if types.IsType(self, "Tuple") then
            local a = self.data:Get(1)
            local b = self.data:Get(2)

            if types.IsType(a, "Tuple") then
                return tostring(a) .. " => " .. tostring(b)
            elseif types.IsType(a, "Object") then
                return "(" .. tostring(a) .. " .. " .. tostring(b) .. ")"
            end
        end

        if self.const then
            if self.type == "string" then
                return ("%q"):format(self.data)
            end

            return tostring(self.data)
        end

        if self.data == nil then
            return self.type
        end

        return self.type .. "(".. tostring(self.data) .. ")"
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
    Tuple.__index = Tuple

    function Tuple:GetSignature()
        local s = {}

        for i,v in ipairs(self.data) do
            s[i] = types.GetSignature(v)
        end

        return table.concat(s, " ")
    end

    function Tuple:GetLength()
        return #self.data
    end

    function Tuple:SupersetOf(sub)
        for i = 1, sub:GetLength() do
            if not self:Get(i) or not self:Get(i):SupersetOf(sub:Get(i)) then
                return false
            end
        end

        return true
    end

    function Tuple:Get(key)
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

        return table.concat(s, ", ")
    end

    function Tuple:new(...)
        local self = setmetatable({}, self)

        self.data = {...}

        return self
    end

    types.Tuple = Tuple
end

do
    local Set = {}
    Set.__index = Set

    function Set:GetSignature()
        local s = {}

        for _, v in pairs(self.data) do
            table.insert(s, types.GetSignature(v))
        end

        table.sort(s, function(a, b) return a < b end)

        return table.concat(s, "|")
    end

    function Set:__tostring()
        local s = {}
        for _, v in pairs(self.data) do
            table.insert(s, tostring(v))
        end

        table.sort(s, function(a, b) return a < b end)

        return table.concat(s, " | ")
    end

    function Set:AddElement(e)
        self.data[types.GetSignature(e)] = e

        return self
    end

    function Set:GetLength()
        local len = 0
        for _, v in pairs(self.data) do
            len = len + 1
        end
        return len
    end

    function Set:RemoveElement(e)
        self.data[types.GetSignature(e)] = nil
    end

    function Set:Get(key)
        return self.data[key:GetSignature()]
    end

    function Set:Set(key, val)
        return self:AddElement(val)
    end

    function Set:SupersetOf(sub)
        if types.IsType(sub, "Object") then
            return false
        end

        for _, e in pairs(self.data) do
            if not sub:Get(e) then
                return false
            end
        end

        return true
    end

    function Set:Union(set)
        local copy = self:Copy()

        for _, e in pairs(set.data) do
            copy:AddElement(e)
        end

        return copy
    end


    function Set:Intersect(set)
        local copy = types.Set:new()

        for _, e in pairs(self.data) do
            if set:Get(e) then
                copy:AddElement(e)
            end
        end

        return copy
    end


    function Set:Subtract(set)
        local copy = self:Copy()

        for _, e in pairs(self.data) do
            copy:RemoveElement(e)
        end

        return copy
    end

    function Set:Copy()
        local copy = Set:new()
        for _, e in pairs(self.data) do
            copy:AddElement(e)
        end
        return copy
    end


    function Set:new(...)
        local self = setmetatable({}, Set)

        self.data = {}

        for _, v in ipairs({...}) do
            self:AddElement(v)
        end

        return self
    end

    types.Set = Set
end

function types.Create(type, ...)
    if type == "nil" then
        return types.Object:new(type)
    elseif type == "any" then
        return types.Object:new(type)
    elseif type == "table" then
        print(...)
        return types.Dictionary:new({})
    elseif type == "boolean" then
        return types.Object:new("boolean", ...)
    elseif type == "..." then
        return types.Tuple:new(...)
    elseif type == "number" or type == "string" then
        return types.Object:new(type, ...)
    elseif type == "function" then
        local returns, arguments = ...
        local dict = types.Dictionary:new({})
        dict:Set(types.Tuple:new(unpack(arguments)), types.Tuple:new(unpack(returns)))
        return types.Object:new(type, dict)
    end
end

do return types end

do
    local Set = function(...) return types.Set:new(...) end
    local Tuple = function(...) return types.Tuple:new(...) end
    local Object = function(...) return types.Object:new(...) end
    local Dictionary = function(...) return types.Dictionary:new(...) end
    local N = function(n) return Object("number", n, true) end
    local S = function(n) return Object("string", n, true) end
    local O = Object

    assert(Set(S"a", S"b", S"a", S"a"):SupersetOf(Set(S"a", S"b", S"c")))
    assert(Set(S"c", S"d"):SupersetOf(Set(S"c", S"d")))
    assert(Set(S"c", S"d"):SupersetOf(Set(S"c", S"d")))
    assert(Set(S"a"):SupersetOf(Set(Set(S"a")))) -- should be false?
    assert(Set():SupersetOf(Set(S"a", S"b", S"c"))) -- should be false?
    assert(Set(N(1), N(4), N(5), N(9), N(13)):Intersect(Set(N(2), N(5), N(6), N(8), N(9))):GetSignature() == Set(N(5), N(9)):GetSignature())
    --print(Set(N(1), N(4), N(5), N(9), N(13)):Union(Set(N(2), N(5), N(6), N(8), N(9))))

    local A = Set(N(1),N(2),N(3))
    local B = Set(N(1),N(2),N(3),N(4))

    assert(B:GetSignature() == A:Union(B):GetSignature(), tostring(B) .. " should equal the union of "..tostring(A).." and " .. tostring(B))
    assert(B:GetLength() == 4)
    assert(A:SupersetOf(B))

    local yes = Object("boolean", true, true)
    local no = Object("boolean", false, true)
    local yes_and_no =  Set(yes, no)

    assert(types.SupersetOf(yes, yes_and_no), tostring(yes) .. "should be a subset of " .. tostring(yes_and_no))
    assert(types.SupersetOf(no, yes_and_no), tostring(no) .. " should be a subset of " .. tostring(yes_and_no))
    assert(not types.SupersetOf(yes_and_no, yes), tostring(yes_and_no) .. " is NOT a subset of " .. tostring(yes))
    assert(not types.SupersetOf(yes_and_no, no), tostring(yes_and_no) .. " is NOT a subset of " .. tostring(no))

    local tbl = Dictionary({})
    tbl:Set(yes_and_no, Object("boolean", false))
    tbl:Lock()
    tbl:Set(yes, yes)
    assert(tbl:Get(yes).data == true, " should be true")

    do
        local IAge = Dictionary({})
        IAge:Set(Object("string", "age", true), Object("number"))

        local IName = Dictionary({})
        IName:Set(Object("string", "name", true), Object("string"))
        IName:Set(Object("string", "magic", true), Object("string", "deadbeef", true))

        local function introduce(person)
            print(string.format("Hello, my name is %s and I am %s years old.", person:Get(Object("string", "name")), person:Get(Object("string", "age")) ))
        end

        local Human = types.Union(IAge, IName)
        Human:Lock()


        assert(IAge:SupersetOf(Human), "IAge should be a subset of Human")
        Human:Set(Object("string", "name", true), Object("string", "gunnar"))
        Human:Set(Object("string", "age", true), Object("number", 40))

        assert(Human:Get(Object("string", "name", true)).data == "gunnar")
        assert(Human:Get(Object("string", "age", true)).data == 40)

     --   print(Human:Get(Object("string", "magic")))
        Human:Set(Object("string", "magic"), Object("string", "lol"))
    end

    assert(Object("number", Tuple(N(-10), N(10)), true):SupersetOf(Object("number", 5, true)) == true, "5 should contain within -10..10")
    assert(Object("number", 5, true):SupersetOf(Object("number", Tuple(N(-10), N(10)), true)) == false, "5 should not contain -10..10")

    local overloads = Dictionary({})
    overloads:Set(Tuple(O"number", O"string"), Tuple(O"ROFL"))
    overloads:Set(Tuple(O"string", O"number"), Tuple(O"LOL"))
    local func = Object("function", overloads)
    assert(func:Call(Tuple(O"string", O"number")):GetSignature() == "LOL")
    assert(func:Call(Tuple(O("number", 5, true), O"string")):GetSignature() == "ROFL")


    assert(O("number"):SupersetOf(O("number", 5, true)) == false)
    assert(O("number", 5, true):SupersetOf(O("number")) == true)

    do
        local T = function()
            local obj = Object("table", Dictionary({}))

            return setmetatable({obj = obj}, {
                __newindex = function(_, key, val)
                    if type(key) == "string" then
                        key = Object("string", key, true)
                    elseif type(key) == "number" then
                        key = Object("number", key, true)
                    end

                    if val == _ then
                        val = obj
                    end

                    obj:Set(key, val)
                end,
                __index = function(_, key)
                    return obj:Get(S(key))
                end,
            })
        end

        local function F(overloads)
            local dict = Dictionary({})
            for k,v in pairs(overloads) do
                dict:Set(k,v)
            end
            return Object("function", dict)
        end

        local tbl = T()
        tbl.test = N(1)

        local meta = T()
        meta.__index = meta
        meta.__add = F({
            [O"string"] = O"self+string",
            [O"number"] = O"self+number",
        })

        tbl.meta = meta.obj

        function tbl:BinaryOperator(operator, value)
            if self.meta then
                local func = self.meta:Get(operator)
                if func then
                    return func:Call(value)
                end

                return nil, "the metatable does not have the " .. tostring(operator) .. " assigned"
            end
        end

        print(tbl:BinaryOperator(S"__add", N(1)))
    end

    --print(O("function", Tuple(Tuple(O"number", O"string"), Tuple(O"ROFL")), true):Call())
end