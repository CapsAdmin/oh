local T = require("test.helpers")
local run = T.RunCode

it("should work", function()
    local a = run[[local type a = 1337 | 8888]]:GetValue("a", "typesystem")
    equal(2, a:GetLength())
    equal(1337, a:GetElements()[1].data)
    equal(8888, a:GetElements()[2].data)
end)

it("union operator should work", function()
    local a = run[[
        local type a = 1337 | 888
        local type b = 666 | 777
        local type c = a | b
    ]]:GetValue("c", "typesystem")
    equal(4, a:GetLength())
end)

it("set + object", function()
    run[[
        local a = _ as (1 | 2) + 3
        type_assert(a, _ as 4 | 5)
    ]]
end)

it("set + set", function()
    run[[
        local a = _ as 1 | 2
        local b = _ as 10 | 20

        type_assert(a + b, _ as 11 | 12 | 21 | 22)
    ]]
end)

it("set.foo", function()
    run[[
        local a = _ as {foo = true} | {foo = false}

        type_assert(a.foo, _ as true | false)
    ]]
end)

it("set.foo = bar", function()
    run[[
        local a = { foo = 4 } as { foo = 1|2 } | { foo = 3 }
        type_assert(a.foo,  _ as 1 | 2 | 3)
        a.foo = 4
        type_assert(a.foo, _ as 4|4)
    ]]
end)

it("is literal", function()
    local a = run[[
        local type a = 1 | 2 | 3
    ]]
    assert(a:GetValue("a", "typesystem"):IsLiteral() == true)
end)

it("is not literal", function()
    local a = run[[
        local type a = 1 | 2 | 3 | string
    ]]
    assert(a:GetValue("a", "typesystem"):IsLiteral() == false)
end)