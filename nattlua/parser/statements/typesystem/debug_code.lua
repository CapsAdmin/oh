return
	{
		ReadDebugCode = function(parser)
			if not parser:IsCurrentType("type_code") then return end
			local node = parser:Node("statement", "type_code")
			local code = parser:Node("expression", "value")
			code.value = parser:ReadType("type_code")
			node.lua_code = code
			return node
		end,
	}