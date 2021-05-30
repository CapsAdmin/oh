local function_body = require("nattlua.parser.statements.function_body").ReadFunctionBody
return
	{
		ReadFunction = function(parser)
			if not parser:IsCurrentValue("function") then return end
			local node = parser:Node("expression", "function"):ExpectKeyword("function")
			function_body(parser, node)
			return node:End()
		end,
	}