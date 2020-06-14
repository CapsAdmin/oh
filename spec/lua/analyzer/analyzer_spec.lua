local oh = require("oh")
local C = oh.Code

local function run(code, expect_error)
    local code_data = oh.Code(code, nil, nil, 3)
    local ok, err = code_data:Analyze()

    if expect_error then
        if not err then
            error("expected error, got\n\n\n[" .. tostring(ok) .. ", " .. tostring(err) .. "]")
        elseif type(expect_error) == "string" and not err:find(expect_error) then
            error("expected error " .. expect_error .. " got\n\n\n" .. err)
        end
    else
        if not ok then
            code_data = C(code_data.code)
            local ok, err2 = code_data:Analyze(true)
            print(code_data.code)
            error(err)
        end
    end

    return code_data.Analyzer
end

describe("analyzer", function()
    it("runtime scopes should work", function()
        local v = run("local a = 1"):GetValue("a", "runtime")
        assert.equal(v.Type, "object")
        assert.equal(true, v:IsType("number"))
    end)

    it("runtime block scopes should work", function()

        local analyzer = run("do local a = 1 end")
        assert.equal(nil, analyzer:GetValue("a", "runtime"))
        assert.equal(1, analyzer:GetScope().children[1].upvalues.runtime.map.a.data:GetData()) -- TODO: awkward access

        local v = run[[
            local a = 1
            do
                local a = 2
            end
        ]]:GetValue("a", "runtime")

        assert.equal(v:GetData(), 1)
    end)

    it("runtime reassignment should work", function()
        local v = run[[
            local a = 1
            do
                a = 2
            end
        ]]:GetValue("a", "runtime")

        assert.equal(v:GetData(), 2)
    end)

    it("typesystem differs from runtime", function()
        local analyzer = run[[
            local a = 1
            local type a = 2
        ]]

        assert.equal(analyzer:GetValue("a", "runtime"):GetData(), 1)
        assert.equal(analyzer:GetValue("a", "typesystem"):GetData(), 2)
    end)

    it("global types should work", function()
        local analyzer = run[[
            do
                type a = 2
            end
            local b: a
        ]]

        assert.equal(2, analyzer:GetValue("b", "runtime"):GetData())
    end)

    it("constant types should work", function()
        local analyzer = run[[
            local a: 1
            local b: number
        ]]

        assert.equal(true, analyzer:GetValue("a", "runtime"):IsConst())
        assert.equal(false, analyzer:GetValue("b", "runtime"):IsConst())
    end)

    -- literal + vague = vague
    it("1 + number = number", function()
        local analyzer = run[[
            local a: 1
            local b: number
            local c = a + b
        ]]

        local v = analyzer:GetValue("c", "runtime")
        assert.equal(v.Type, "object")
        assert.equal(true, v:IsType("number"))
        assert.equal(false, v:IsConst())
    end)

    it("1 + 2 = 3", function()
        local analyzer = run[[
            local a = 1
            local b = 2
            local c = a + b
        ]]

        local v = analyzer:GetValue("c", "runtime")
        assert.equal(v.Type, "object")
        assert.equal(true, v:IsType("number"))
        assert.equal(3, v:GetData())
    end)

    it("function return value should work", function()
        local analyzer = run[[
            local function test()
                return 1+2+3
            end
            local a = test()
        ]]

        local v = analyzer:GetValue("a", "runtime")
        assert.equal(6, v:GetData())
    end)

    it("multiple function return values should work", function()
        local analyzer = run[[
            local function test()
                return 1,2,3
            end
            local a,b,c = test()
        ]]

        assert.equal(1, analyzer:GetValue("a", "runtime"):GetData())
        assert.equal(2, analyzer:GetValue("b", "runtime"):GetData())
        assert.equal(3, analyzer:GetValue("c", "runtime"):GetData())
    end)


    it("scopes shouldn't leak", function()
        local analyzer = run[[
            local a = {}
            function a:test(a, b)
                return nil, a+b
            end
            local _, a = a:test(1, 2)
        ]]

        assert.equal(3, analyzer:GetValue("a", "runtime"):GetData())
    end)

    it("explicitly annotated variables need to be set properly", function()
        local analyzer = run[[
            local a: number | string = 1
        ]]
    end)

    it("functions can modify parent scope", function()
        local analyzer = run[[
            local a = 1
            local c = a
            local function test()
                a = 2
            end
            test()
        ]]

        assert.equal(2, analyzer:GetValue("a", "runtime"):GetData())
        assert.equal(1, analyzer:GetValue("c", "runtime"):GetData())
    end)

    it("uncalled functions should be called", function()
        local analyzer = run[[
            local lib = {}

            function lib.foo1(a, b)
                return lib.foo2(a, b)
            end

            function lib.main()
                return lib.foo1(1, 2)
            end

            function lib.foo2(a, b)
                return a + b
            end
        ]]
        local lib = analyzer:GetValue("lib", "runtime")

        assert.equal(true, lib:Get("foo1"):GetArguments().data[1]:IsType("number"))
        assert.equal(true, lib:Get("foo1"):GetArguments().data[2]:IsType("number"))
        assert.equal(true, lib:Get("foo1"):GetReturnTypes().data[1]:IsType("number"))

        assert.equal(true, lib:Get("foo2"):GetArguments().data[1]:IsType("number"))
        assert.equal(true, lib:Get("foo2"):GetArguments().data[2]:IsType("number"))
        assert.equal(true, lib:Get("foo2"):GetReturnTypes().data[1]:IsType("number"))
    end)
end)