local util = require("oh.util")
local B = string.byte

local syntax = {}

syntax.UTF8 = true

syntax.SymbolCharacters = {
    ",", ";",
    "(", ")", "{", "}", "[", "]",
    "=", "::", "\"", "'", "`",
}

syntax.NumberAnnotations = {
    "ull", "ll", "ul", "i",
}

syntax.Keywords = {
    "and", "break", "do", "else", "elseif", "end",
    "false", "for", "function", "if", "in", "of", "local",
    "nil", "not", "or", "repeat", "until", "return", "then",
    "...", 

    -- these are just to make sure all code is covered by tests
    "ÆØÅ", "ÆØÅÆ",
}

syntax.KeywordValues = {
    "...",
    "nil",
    "true",
    "false",
}

syntax.PrefixOperators = {
    "-", "#", "not", "~",
}

syntax.PostfixOperators = {
    -- these are just to make sure all code is covered by tests
    "++", "ÆØÅ", "ÆØÅÆ", 
}

syntax.BinaryOperators = {
    {"or"},
    {"and"},
    {"<", ">", "<=", ">=", "~=", "=="},
    {"|"},
    {"~"},
    {"&"},
    {"<<", ">>"},
    {"R.."}, -- right associative
    {"+", "-"},
    {"*", "/", "//", "%"},
    {"R^"}, -- right associative
    {".", ":"},
}

syntax.BinaryOperatorFunctionTranslate = {
    [">>"] = "bit.rshift(A, B)",
    ["<<"] = "bit.lshift(A, B)",
    ["|"] = "bit.bor(A, B)",
    ["&"] = "bit.band(A, B)",
    ["//"] = "math.floor(A / B)",
    ["~"] = "bit.bxor(A, B)",
}

syntax.PrefixOperatorFunctionTranslate = {
    ["~"] = "bit.bnot(A)",
}

syntax.PostfixOperatorFunctionTranslate = {
    ["++"] = "(A+1)",
}

do
    local map = {}

    map.space = syntax.SpaceCharacters or {B" ", B"\r", B"\t", B"\n"}

    if syntax.NumberCharacters then
        map.number = syntax.NumberCharacters
    else
        map.number = {}
        for i = 0, 9 do
            map.number[i+1] = B(tostring(i))
        end
    end

    if syntax.LetterCharacters then
        map.letter = syntax.LetterCharacters
    else
        map.letter = {B"_"}

        for i = B"A", B"Z" do
            table.insert(map.letter, i)
        end

        for i = B"a", B"z" do
            table.insert(map.letter, i)
        end

        -- although not accurate, we consider anything above 128 to be unicode
        for i = 128, 255 do
            table.insert(map.letter, i)
        end
    end

    if syntax.SymbolCharacters then
        map.symbol = syntax.SymbolCharacters
    else
        error("syntax.SymbolCharacters not defined", 2)
    end

    map.end_of_file = {syntax.EndOfFileCharacter or ""}

    syntax.CharacterMap = map
end

do -- extend the symbol map from grammar rules
    for _, symbol in pairs(syntax.PrefixOperators) do
        if symbol:find("%p") then
            table.insert(syntax.CharacterMap.symbol, symbol)
        end
    end

    for _, symbol in pairs(syntax.PostfixOperators) do
        if symbol:find("%p") then
            table.insert(syntax.CharacterMap.symbol, symbol)
        end
    end

    for _, group in ipairs(syntax.BinaryOperators) do
        for _, token in ipairs(group) do
            if token:find("%p") then
                if token:sub(1, 1) == "R" then
                    token = token:sub(2)
                end

                table.insert(syntax.CharacterMap.symbol, token)
            end
        end
    end

    for _, symbol in ipairs(syntax.Keywords) do
        if symbol:find("%p") then
            table.insert(syntax.CharacterMap.symbol, symbol)
        end
    end
end

function syntax.LongestLookup(tbl, what, lower)
    local longest = 0
    local map = {}

    for _, str in ipairs(tbl) do
        local node = map

        for i = 1, #str do
            local char = str:byte(i)
            node[char] = node[char] or {}
            node = node[char]
        end

        node.DONE = {str = str, length = #str}

        longest = math.max(longest, #str)
    end

    longest = longest - 1

    return function(tk)
        local node = map

        for i = 0, longest do
            local found = lower and node[string.char(tk:GetChar(i)):lower():byte()] or node[tk:GetChar(i)]

            if not found and i == 0 then return end
            if not found then break end

            node = found
        end

        if node.DONE then
            tk:Advance(node.DONE.length)
            return what
        end
    end
end

do
    local symbols = {}
    local temp = {}
    for type, chars in pairs(syntax.CharacterMap) do
        for _, char in ipairs(chars) do
            if type == "symbol" then
                table.insert(symbols, char)
            end
            if _G.type(char) == "string" then
                char = char:byte() or 0
            end
            temp[char] = type
        end
    end
    syntax.CharacterMap = temp

    syntax.ReadLongestSymbol = syntax.LongestLookup(symbols, "symbol")
    syntax.ReadLongestNumberAnnotation = syntax.LongestLookup(syntax.NumberAnnotations, true, true)
end

do
    for k, v in pairs(syntax.BinaryOperatorFunctionTranslate) do
        local a,b,c = v:match("(.-)A(.-)B(.*)")
        syntax.BinaryOperatorFunctionTranslate[k] = {" " .. a, b, c .. " "}
    end

    for k, v in pairs(syntax.PrefixOperatorFunctionTranslate) do
        local a, b = v:match("^(.-)A(.-)$")
        syntax.PrefixOperatorFunctionTranslate[k] = {" " .. a, b .. " "}
    end

    for k, v in pairs(syntax.PostfixOperatorFunctionTranslate) do
        local a, b = v:match("^(.-)A(.-)$")
        syntax.PostfixOperatorFunctionTranslate[k] = {" " .. a, b .. " "}
    end
end

do -- grammar rules
    function syntax.GetCharacterType(char)
        return syntax.CharacterMap[char]
    end

    function syntax.IsValue(token)
        return token.type == "number" or token.type == "string" or syntax.KeywordValues[token.value]
    end

    function syntax.IsDefinetlyNotStartOfExpression(token)
        return
        not token or token.type == "end_of_file" or
        token.value == "}" or token.value == "," or
        token.value == "[" or token.value == "]" or
        (
            syntax.IsKeyword(token) and
            not syntax.IsPrefixOperator(token) and
            not syntax.IsValue(token) and
            token.value ~= "function"
        )
    end

    function syntax.IsOperator(token)
        return syntax.BinaryOperators[token.value] ~= nil
    end

    function syntax.GetLeftOperatorPriority(token)
        return syntax.BinaryOperators[token.value] and syntax.BinaryOperators[token.value][1]
    end

    function syntax.GetRightOperatorPriority(token)
        return syntax.BinaryOperators[token.value] and syntax.BinaryOperators[token.value][2]
    end

    function syntax.GetFunctionForBinaryOperator(token)
        return syntax.BinaryOperatorFunctionTranslate[token.value]
    end

    function syntax.GetFunctionForPrefixOperator(token)
        return syntax.PrefixOperatorFunctionTranslate[token.value]
    end

    function syntax.GetFunctionForPostfixOperator(token)
        return syntax.PostfixOperatorFunctionTranslate[token.value]
    end

    function syntax.IsPrefixOperator(token)
        return syntax.PrefixOperators[token.value]
    end

    function syntax.IsPostfixOperator(token)
        return syntax.PostfixOperators[token.value]
    end

    function syntax.IsKeyword(token)
        return syntax.Keywords[token.value]
    end

    local temp = {}
    for priority, group in ipairs(syntax.BinaryOperators) do
        for _, token in ipairs(group) do
            if token:sub(1, 1) == "R" then
                temp[token:sub(2)] = {priority + 1, priority}
            else
                temp[token] = {priority, priority}
            end
        end
    end
    syntax.BinaryOperators = temp

    local function to_lookup(tbl)
        local out = {}
        for _, v in pairs(tbl) do
            out[v] = v
        end
        return out
    end

    syntax.PrefixOperators = to_lookup(syntax.PrefixOperators)
    syntax.PostfixOperators = to_lookup(syntax.PostfixOperators)
    syntax.Keywords = to_lookup(syntax.Keywords)
    syntax.KeywordValues = to_lookup(syntax.KeywordValues)
end

return syntax