local META = {}
META.__index = META

type META.@Self = {
    foo = {[number] = string},
    i = number,
}

local type Foo = META.@Self

local function test2(x: Foo)
    --print(x)
end

local function test(x: Foo & {extra = boolean | nil})
    type_assert(x.asdf, true)
    print(x)
    x.extra = true

    --test2(x)
end

META.asdf = true

function META:Lol()
    print("FROM LOL")
    --print(self.__index)
    test(self)
end


print("UNREACHABLE:")