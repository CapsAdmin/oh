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

    it("typed table invalid reassignment should error", function()
        run(
            [[
                local tbl: {foo = true} = {foo = true}
                tbl.foo = false
            ]],
            "invalid value boolean expected true"
        )

        run(
            [[
                local tbl: {foo = {number, number}} = {foo = {1,1}}
                tbl.foo = {1,true}
            ]],
            ".-1 = 1.-2 = true.-is not a superset of.-1 = number.-2 = number"
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

        assert.equal(true, a:SupersetOf(b))
    end)
end)