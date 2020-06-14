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

describe("table", function()
    it("reassignment should work", function()
        local analyzer = run[[
            local tbl = {}
            tbl.foo = true
            tbl.foo = false
        ]]

        local tbl = analyzer:GetValue("tbl", "runtime")

        assert.equal(false, tbl:Get("foo"):GetData())

        local analyzer = run[[
            local tbl = {foo = true}
            tbl.foo = false
        ]]

        local tbl = analyzer:GetValue("tbl", "runtime")
        assert.equal(false, tbl:Get("foo"):GetData())
    end)

    it("typed field should work", function()
        local analyzer = run[[
            local tbl: {foo = boolean} = {foo = true}
        ]]
        assert.equal(true, analyzer:GetValue("tbl", "runtime"):Get("foo"):GetData())
    end)

    it("typed table invalid reassignment should error", function()
        local analyzer = run(
            [[
                local tbl: {foo = 1} = {foo = 2}
            ]]
            ,"because 2 is not a subset of 1"
        )
    end)

    it("typed table invalid reassignment should error", function()
        local analyzer = run(
            [[
                local tbl: {foo = 1} = {foo = 1}
                tbl.foo = 2
            ]]
            ,"literal 1 is not a subset of literal 2"
        )
        local v = analyzer:GetValue("tbl", "runtime")

        run(
            [[
                local tbl: {foo = {number, number}} = {foo = {1,1}}
                tbl.foo = {66,66}
                tbl.foo = {1,true}
            ]]
            ,"number is not a subset of true"
        )
    end)

    it("typed table correct assignment not should error", function()
        run([[
            local tbl: {foo = true} = {foo = true}
            tbl.foo = true
        ]])
    end)

    it("self referenced tables should be equal", function()
        local analyzer = run([[
            local a = {a=true}
            a.foo = {lol = a}

            local b = {a=true}
            b.foo = {lol = b}
        ]])
        local a = analyzer:GetValue("a", "runtime")
        local b = analyzer:GetValue("b", "runtime")

        assert.equal(true, a:SubsetOf(b))
    end)
end)