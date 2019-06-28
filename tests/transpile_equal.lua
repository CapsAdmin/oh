local test = ...

do
    local function check(strings)
        for i,v in ipairs(strings) do
            if v == false then
                break
            end
            if type(v) == "table" then
                test.transpile_check(v)
            else
                test.transpile_check({code = v, expect = v})
            end
        end
    end

    check {
        "if 1 then elseif 2 then elseif 3 then else end",
        "if 1 then elseif 2 then else end",
        "if 1 then else end",
        "if 1 then end",

        "while 1 do end",
        "repeat until 1",

        "for i = 1, 2 do end",
        "for a,b,c,d,e in 1,2,3,4,5 do end",

        "function test() end",
        "function test.asdf() end",
        "function test[asdf]() end",
        "function test[asdf].sadas:FOO() end",
        "local function test() end",

        "local test = function() end",

        "a = 1",
        "a,b = 1,2",
        "a,b = 1",
        "a,b,c = 1,2,3",
        "a.b.c, d.e.f = 1, 2",

        "a()",
        "a.b:c()",
        "a.b.c()",
        "(function(b) return 1 end)(2)",


        "local a = 1;",
        "local a,b,c",
        "local a,b,c = 1,2,3",
        "local a,c = 1,2,3",
        "local a = 1,2,3",
        "local a",
        "local a = -c+1",
        "local a = c",
        "(a)[b] = c",
        "local a = {[1+2+3] = 2}",
        "foo = bar",
        "foo--[[]].--[[]]bar--[[]]:--[[]]test--[[]](--[[]]1--[[]]--[[]],2--[[]])--------[[]]--[[]]--[[]]",
        "function foo.testadw() end",
        "asdf.a.b.c[5](1)[2](3)",
        "while true do end",
        "for i = 1, 10, 2 do end",
        "local a,b,c = 1,2,3",
        "local a = 1\nlocal b = 2\nlocal c = 3",
        "function test.foo() end",
        "local function test() end",
        "local a = {foo = true, c = {'bar'}}",
        "for k,v,b in pairs() do end",
        "for k in pairs do end",
        "foo()",
        "if true then print(1) elseif false then print(2) else print(3) end",
        "a.b = 1",
        "local a,b,c = 1,2,3",
        "repeat until false",
        "return true",
        "while true do break end",
        "do end",
        "local function test() end",
        "function test() end",
        "goto test ::test::",
        "#!shebang wadawd\nfoo = bar",
        "local a,b,c = 1 + (2 + 3) + v()()",
        "(function() end)(1,2,3)",
        "(function() end)(1,2,3){4}'5'",
        "(function() end)(1,2,3);(function() end)(1,2,3)",
        "local tbl = {a; b; c,d,e,f}",
        "aslk()",
        "a = #a()",
        "a()",
        "🐵=😍+🙅",
        "print(･✿ヾ╲｡◕‿◕｡╱✿･ﾟ)",
        "print(･✿ヾ╲｡◕‿◕｡╱✿･ﾟ)",
        "print(ด้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็ด้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็ด้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็็้้้้้้้้็็็็็้้้้้็็็็)",
        "local a = 1;;;",
        "local a = (1)+(1)",
        "local a = (1)+(((((1)))))",
        "local a = 1 --[[a]];",
        "local a = 1 --[=[a]=] + (1);",
        "local a = (--[[1]](--[[2]](--[[3]](--[[4]]4))))",
        "local a = 1 --[=[a]=] + (((1)));",
        "a=(foo.bar)()",
        "a=(foo.bar)",
        "if (player:IsValid()) then end",
        "if not true then end",
        "local function F (m) end",
        "msgs[#msgs+1] = string.sub(m, 3, -3)",
        "a = (--[[a]]((-a)))",

        "a = 1; b = 2; local a = 3; function a() end while true do end b = c; a,b,c=1,2,3",
        "if not a then return end",
        "foo = 'foo'\r\nbar = 'bar'\r\n",

        ";;print 'testing syntax';;",
        "#testse tseokt osektokseotk\nprint('ok')",
        "do ;;; end\n; do ; a = 3; assert(a == 3) end;\n;",
        "--[=TESTSUITE\n-- utilities\nlocal ops = {}\n--]=]",
        "assert(string.gsub('�lo �lo', '�', 'x') == 'xlo xlo')",

        'foo = "\200\220\2\3\r"\r\nfoo = "\200\220\2\3"\r\n',
        "goto:foo()",
        "a = " .. string.char(34,187,243,193,161,34),
        "local a = {foo,bar,faz,}",
        "local a = {{--[[1]]foo--[[2]],--[[3]]bar--[[4]],--[[5]]faz--[[6]],--[[7]]},}",
        "local a = {--[[1]]foo--[[2]],--[[3]]bar--[[4]],--[[5]]faz--[[6]]}",

        "local a = foo.bar\n{\nkey = key,\nhost = asdsad.wawaw,\nport = aa.bb\n}",
        "_IOW(string.byte'f', 126, 'uint32_t')",
        "return",
        "return 1",
        "function foo(a, ...) end",
        "function foo(...) end",

        "a = foo(0x89abcdef, 1)",
        "a = foo(0x20EA2, 1)",
        "a = foo(0Xabcdef.0, 1)",
        "a = foo(3.1416, 1)",
        "a = foo(314.16e-2, 1)",
        "a = foo(0.31416E1, 1)",
        "a = foo(34e1, 1)",
        "a = foo(0x0.1E, 1)",
        "a = foo(0xA23p-4, 1)",
        "a = foo(0X1.921FB54442D18P+1, 1)",
        "a = foo(2.E-1, 1)",
        "a = foo(.2e2, 1)",
        "a = foo(0., 1)",
        "a = foo(.0, 1)",
        "a = foo(0x.P1, 1)",
        "a = foo(0x.P+1, 1)",
        "a = foo(0b101001011, 1)",
        "a = foo(0b101001011ull, 1)",
        "a = foo(0b101001011i, 1)",
        "a = foo(0b01_101_101, 1)",
        "a = foo(0xDEAD_BEEF_CAFE_BABE, 1)",
        "a = foo(1_1_1_0e2, 1)",
        "a = foo(1_, 1)",
        'a = "a\\z\na"',
        "lol = 1 ÆØÅ",
        "lol = 1 ÆØÅÆ",

        {code = "return math.maxinteger // 80", expect = "return math.floor(math.maxinteger / 80)",     compare_tokens = true},

        {code = "\xEF\xBB\xBF foo = true", expect = " foo = true"},

        {code = "return math.maxinteger // 80", expect = "return math.floor(math.maxinteger / 80)",     compare_tokens = true},
        {code = "local a = ~1",                 expect = "local a = bit.bnot(1)",                       compare_tokens = true},
        {code = "local a = 1 >> 2",             expect = "local a = bit.rshift(1, 2)",                  compare_tokens = true},
        {code = "local a = 1 >> 2 << 23",       expect = "local a = bit.lshift(bit.rshift(1, 2), 23)",  compare_tokens = true},
        {code = "local a = a++",                expect = "local a = (a + 1)",                           compare_tokens = true},
    }
end
