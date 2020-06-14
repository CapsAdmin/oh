local T = require("spec.lua.typesystem_helpers")
local O = T.Object
local N = T.Number
local S = T.String
local Dictionary = T.Dictionary
local Set = T.Set
local Tuple = T.Tuple

describe("dictionary", function()
    it("set and get should work", function()
        local interface = Dictionary()
        assert(interface:Set(S("foo"), O("number")))
        assert(assert(interface:Get("foo")):IsType("number"))
        assert.equal(false, interface:Get(S("asdf")))

        local dict = Dictionary()
        dict.contract = interface
        assert(dict:Set(S("foo"), N(1337)))
        assert.equal(1337, dict:Get(S("foo")):GetData())

        assert(not dict:SubsetOf(interface))
        assert(interface:SubsetOf(dict))
    end)

    it("set string and get constant string should work", function()
        local interface = Dictionary()
        assert(interface:Set(O("string"), O("number")))

        local dict = Dictionary()
        dict.contract = interface
        dict:Set(O("string"), N(1337))
        assert.equal(1337, assert(dict:Get(O("string"))):GetData())

        assert(not dict:SubsetOf(interface))
        assert(interface:SubsetOf(dict))
    end)


    it("errors when trying to modify a dictionary without a defined structure", function()
        local dict = Dictionary()
        dict.contract = Dictionary()
        local ok, err = dict:Set(S("foo"), N(1337))
        assert(err:find("foo.-is not a subset of any of the keys in"))
    end)

    it("copy from constness should work", function()
        local interface = Dictionary()
        interface:Set(S("foo"), S("bar"))
        interface:Set(S("a"), O("number"))

        local dict = Dictionary()
        dict:Set(S("foo"), O("string", "bar"))
        dict:Set(S("a"), N(1337))

        assert(dict:CopyConstness(interface))
        assert(assert(dict:Get(S("foo"))):IsConst())
    end)

    do return end
    do
        local IAge = Dictionary()
        IAge:Set(Object("string", "age", true), Object("number"), true)

        local IName = Dictionary()
        IName:Set(Object("string", "name", true), Object("string"))
        IName:Set(Object("string", "magic", true), Object("string", "deadbeef", true))

        local function introduce(person)
            io.write(string.format("Hello, my name is %s and I am %s years old.", person:Get(Object("string", "name")), person:Get(Object("string", "age")) ),"\n")
        end

        local Human = IAge:Union(IName)
        Human:Lock()


        assert(IAge:SubsetOf(Human), "IAge should be a subset of Human")
        Human:Set(Object("string", "name", true), Object("string", "gunnar"))
        Human:Set(Object("string", "age", true), Object("number", 40))

        assert(Human:Get(Object("string", "name", true)).data == "gunnar")
        assert(Human:Get(Object("string", "age", true)).data == 40)

        Human:Set(Object("string", "magic"), Object("string", "lol"))
    end
end)