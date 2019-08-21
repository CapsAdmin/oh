
local oh = require("oh")
local Crawler = require("oh.crawler")
local LuaEmitter = require("oh.lua_emitter")

local code = io.open("oh/parser.lua"):read("*all")
local base_lib = io.open("oh/base_lib.oh"):read("*all")

code = [[
function string.split(self, sSeparator, nMax, bRegexp)
    assert(sSeparator ~= '')
    assert(nMax == nil or nMax >= 1)

    local aRecord = {}

    if self:len() > 0 then
        local bPlain = not bRegexp
        nMax = nMax or -1

        local nField, nStart = 1, 1
        local nFirst,nLast = self:find(sSeparator, nStart, bPlain)
        TPRINT(nFirst, nMax, "!!!")
        while nFirst and nMax ~= 0 do
            aRecord[nField] = self:sub(nStart, nFirst-1)
            nField = nField+1
            nStart = nLast+1
            nFirst,nLast = self:find(sSeparator, nStart, bPlain)
            nMax = nMax-1
        end
        aRecord[nField] = self:sub(nStart)
    end

    return aRecord
end

local a= ("1 2 3")
string.split(a, " ", nil, false)
]]

code = [[
    local lol = nil
    local a = lol == nil or lol >= 1
]]


--code = base_lib .. "\n" .. code

local em = LuaEmitter()
local ast = assert(oh.TokensToAST(assert(oh.CodeToTokens(code, "test")), "test", code))
--require("oh.util").TablePrint(ast.statements[2], {tokens = "table", whitespace = "table", upvalue_or_global = "table"})
local crawler = Crawler()

--crawler.OnEvent = crawler.DumpEvent

crawler.code = code
crawler.name = "test"
crawler:CrawlStatement(ast)

print(em:BuildCode(ast))
