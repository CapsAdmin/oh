local syntax = {}

return function(syntax)
    do -- extend the symbol characters from grammar rules
        local function add_symbols(tbl)
            for _, symbol in pairs(tbl) do
                if symbol:find("%p") then
                    table.insert(syntax.SymbolCharacters, symbol)
                end
            end
        end

        local function add_binary_symbols(tbl)
            for _, group in ipairs(tbl) do
                for _, token in ipairs(group) do
                    if token:find("%p") then
                        if token:sub(1, 1) == "R" then
                            token = token:sub(2)
                        end

                        table.insert(syntax.SymbolCharacters, token)
                    end
                end
            end
        end

        add_binary_symbols(syntax.BinaryOperators)
        add_binary_symbols(syntax.BinaryTypeOperators)

        add_symbols(syntax.PrefixOperators)
        add_symbols(syntax.PostfixOperators)
        add_symbols(syntax.PrimaryBinaryOperators)

        add_symbols(syntax.PrefixTypeOperators)
        add_symbols(syntax.PostfixTypeOperators)
        add_symbols(syntax.PrimaryBinaryTypeOperators)

        for _, str in ipairs(syntax.KeywordValues) do
            table.insert(syntax.Keywords, str)
        end

        for _, symbol in ipairs(syntax.Keywords) do
            if symbol:find("%p") then
                table.insert(syntax.SymbolCharacters, symbol)
            end
        end
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


    -- optimize lookup if we have ffi
    local ffi = jit and require("ffi")

    if ffi then
        for key, func in pairs(syntax) do

            if key:sub(1, 2) == "Is" then
                local map = ffi.new("uint8_t[256]", 0)

                for i = 0, 255 do
                    if func(i) then
                        map[i] = 1
                    end
                end
                syntax[key] = function(i) return map[i] == 1 end
            end
        end
    end

    do -- grammar rules
        function syntax.IsValue(token)
            return token.type == "number" or token.type == "string" or syntax.KeywordValues[token.value]
        end

        function syntax.IsTypeValue(token)
            return token.type == "number" or token.type == "string" or token.value == "function" or syntax.KeywordValues[token.value]
        end

        function syntax.IsDefinetlyNotStartOfExpression(token)
            return
            not token or token.type == "end_of_file" or
            token.value == "}" or token.value == "," or
            --[[token.value == "[" or]] token.value == "]" or
            (
                syntax.IsKeyword(token) and
                not syntax.IsPrefixOperator(token) and
                not syntax.IsValue(token) and
                token.value ~= "function"
            )
        end

        function syntax.IsBinaryOperator(token)
            return syntax.BinaryOperators[token.value] ~= nil
        end

        function syntax.IsBinaryTypeOperator(token)
            return syntax.BinaryTypeOperators[token.value] ~= nil
        end

        function syntax.GetLeftOperatorPriority(token)
            return syntax.BinaryOperators[token.value] and syntax.BinaryOperators[token.value][1]
        end

        function syntax.GetRightOperatorPriority(token)
            return syntax.BinaryOperators[token.value] and syntax.BinaryOperators[token.value][2]
        end

        function syntax.GetLeftTypeOperatorPriority(token)
            return syntax.BinaryTypeOperators[token.value] and syntax.BinaryTypeOperators[token.value][1]
        end

        function syntax.GetRightTypeOperatorPriority(token)
            return syntax.BinaryTypeOperators[token.value] and syntax.BinaryTypeOperators[token.value][2]
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

        function syntax.IsPrimaryBinaryOperator(token)
            return syntax.PrimaryBinaryOperators[token.value]
        end

        function syntax.IsPrimaryBinaryTypeOperator(token)
            return syntax.PrimaryBinaryTypeOperators[token.value]
        end

        function syntax.IsPrefixOperator(token)
            return syntax.PrefixOperators[token.value]
        end

        function syntax.IsTypePrefixOperator(token)
            return syntax.PrefixTypeOperators[token.value]
        end

        function syntax.IsPostfixOperator(token)
            return syntax.PostfixOperators[token.value]
        end

        function syntax.IsPostfixTypeOperator(token)
            return syntax.PostfixTypeOperators[token.value]
        end

        function syntax.IsKeyword(token)
            return syntax.Keywords[token.value]
        end


        local function convert_binary_operators(tbl)
            local temp = {}
            for priority, group in ipairs(tbl) do
                for _, token in ipairs(group) do
                    if token:sub(1, 1) == "R" then
                        temp[token:sub(2)] = {priority + 1, priority}
                    else
                        temp[token] = {priority, priority}
                    end
                end
            end
            return temp
        end

        syntax.BinaryOperators = convert_binary_operators(syntax.BinaryOperators)
        syntax.BinaryTypeOperators = convert_binary_operators(syntax.BinaryTypeOperators)

        local function to_lookup(tbl)
            local out = {}
            for _, v in pairs(tbl) do
                out[v] = v
            end
            return out
        end

        syntax.PrimaryBinaryOperators = to_lookup(syntax.PrimaryBinaryOperators)
        syntax.PrefixOperators = to_lookup(syntax.PrefixOperators)
        syntax.PostfixOperators = to_lookup(syntax.PostfixOperators)
        syntax.Keywords = to_lookup(syntax.Keywords)
        syntax.KeywordValues = to_lookup(syntax.KeywordValues)

        syntax.PrimaryBinaryTypeOperators = to_lookup(syntax.PrimaryBinaryTypeOperators)
        syntax.PrefixTypeOperators = to_lookup(syntax.PrefixTypeOperators)
        syntax.PostfixTypeOperators = to_lookup(syntax.PostfixTypeOperators)
    end

    do
        ---
        syntax.CompiledBinaryOperatorFunctions = {}

        for op in pairs(syntax.BinaryOperators) do
            local tr = syntax.BinaryOperatorFunctionTranslate[op]
            if tr then
                syntax.CompiledBinaryOperatorFunctions[op] = assert(load("return function(a,b) return" .. tr[1] .. "a" .. tr[2] .. "b" .. tr[3] .. " end"))()
            else
                syntax.CompiledBinaryOperatorFunctions[op] = assert(load("return function(a, b) return a " .. op .. " b end"))()
            end
        end

        syntax.CompiledPrefixOperatorFunctions = {}
        for op in pairs(syntax.PrefixOperators) do
            local tr = syntax.PrefixOperatorFunctionTranslate[op]
            if tr then
                syntax.CompiledPrefixOperatorFunctions[op] = assert(load("return function(a) return" .. tr[1] .. "a" ..  tr[2] .. " end"))()
            else
                syntax.CompiledPrefixOperatorFunctions[op] = assert(load("return function(a) return " .. op .. " a end"))()
            end
        end

        syntax.CompiledPostfixOperatorFunctions = {}
        for op in pairs(syntax.PostfixOperators) do
            local tr = syntax.PostfixOperatorFunctionTranslate[op]
            if tr then
                syntax.CompiledPostfixOperatorFunctions[op] = assert(load("return function(a) return" .. tr[1] .. "a" ..  tr[2] .. " end"))()
            else
                syntax.CompiledPostfixOperatorFunctions[op] = assert(load("return function(a) return a " .. op .. " end"))()
            end
        end
    end

    return syntax
end