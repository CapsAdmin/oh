local T = require("spec.lua.helpers")
local run = T.RunCode

describe("metatable", function()
    it("index function should work", function()
        local analyzer = run[[
            local t = setmetatable({}, {__index = function() return 1 end})
            local a = t.lol
        ]]

        local a = analyzer:GetValue("a", "runtime")
        assert.equal(1, a:GetData())

        run[[
            local meta = {} as {num = number, __index = self}

            local a = setmetatable({}, meta)

            type_assert(a.num, _ as number)
        ]]
    end)

    it("basic inheritance should work", function()
        local analyzer = run[[
            local META = {}
            META.__index = META

            META.Foo = 2

            function META:Test(v)
                return self.Bar + v, META.Foo + v
            end

            local obj = setmetatable({Bar = 1}, META)
            local a, b = obj:Test(1)
        ]]

        local obj = analyzer:GetValue("obj", "runtime")

        local a = analyzer:GetValue("a", "runtime")
        local b = analyzer:GetValue("b", "runtime")

        assert.equal(2, a:GetData())
        assert.equal(3, b:GetData())
    end)

    it("empty table should be compatible with metatable", function()
        local analyzer = run[[
            local META = {}
            META.__index = META
            META.Foo = "foo"

            function META:Test()
              --  TPRINT(self.Foo, self.Bar)
            end

            local obj = setmetatable({Bar = "bar"}, META)

            obj:Test()
        ]]

        local META = analyzer:GetValue("META", "runtime")
        local obj = analyzer:GetValue("obj", "runtime")

        --print(META:Get("Foo"))

    end)

    it("__call method should work", function()
        local analyzer = run[[
            local META = {}
            META.__index = META

            function META:__call(a,b,c)
                return a+b+c
            end

            local obj = setmetatable({}, META)

            local lol = obj(100,2,3)
        ]]

        local obj = analyzer:GetValue("obj", "runtime")

        assert.equal(105, analyzer:GetValue("lol", "runtime"):GetData())
    end)

    it("__call method should not mess with scopes", function()
        local analyzer = run[[
            local META = {}
            META.__index = META

            function META:__call(a,b,c)
                return a+b+c
            end

            local a = setmetatable({}, META)(100,2,3)
        ]]

        local a = analyzer:GetValue("a", "runtime")

        assert.equal(105, a:GetData())
    end)

    it("vector test", function()
        local analyzer = run[[
            local Vector = {}
            Vector.__index = Vector

            setmetatable(Vector, {
                __call = function(_, a)
                    return setmetatable({lol = a}, Vector)
                end
            })

            local v = Vector(123).lol
        ]]

        local v = analyzer:GetValue("v", "runtime")
        assert.equal(123, v:GetData())
    end)

    it("vector test2", function()
        local analyzer = run[[
            local Vector = {}
            Vector.__index = Vector

            function Vector.__add(a, b)
                return Vector(a.x + b.x, a.y + b.y, a.z + b.z)
            end

            setmetatable(Vector, {
                __call = function(_, x,y,z)
                    return setmetatable({x=x,y=y,z=z}, Vector)
                end
            })

            local v = Vector(1,2,3) + Vector(100,100,100)
            local x, y, z = v.x, v.y, v.z
        ]]

        local x = analyzer:GetValue("x", "runtime")
        local y = analyzer:GetValue("y", "runtime")
        local z = analyzer:GetValue("z", "runtime")

        assert.equal(101, x:GetData())
        assert.equal(102, y:GetData())
        assert.equal(103, z:GetData())
    end)

    it("interface extensions", function()
        run[[
            local type Vec2 = {x = number, y = number}
            local type Vec3 = {z = number} extends Vec2

            local type Base = {
                Test = function(self): number,
            }

            local type Foo = Base extends {
                SetPos = (function(self, pos: Vec3): nil),
                GetPos = (function(self): Vec3),
            }

            -- have to use as here because {} would not be a subset of Foo
            local x = {} as Foo

            x:SetPos({x = 1, y = 2, z = 3})
            local a = x:GetPos()
            local z = a.x + 1

            type_assert(z, _ as number)

            local test = x:Test()
            type_assert(test, _ as number)
        ]]
    end)

    it("error on newindex", function()
        run([[
            type error = function(msg: string)
                assert(type(msg.data) == "string", "msg does not contain a string?")
                error(msg.data)
            end

            local META = {}
            META.__index = META

            function META:__newindex(key, val)
                if key == "foo" then
                    error("cannot use " .. key)
                end
            end

            local self = setmetatable({}, META)

            self.foo = true

            -- should error
            self.bar = true
        ]], "cannot use foo")
    end)
end)
