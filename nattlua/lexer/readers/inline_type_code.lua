--[[#local type { TokenReturnType } = import_type("nattlua/lexer/token.nlua")]]

return
	{
		ReadInlineTypeCode = function(lexer--[[#: Lexer]])--[[#: TokenReturnType]]
			if lexer:IsByte(194, 0) and lexer:IsByte(167, 1) then
				lexer:Advance(1)

				while not lexer:TheEnd() do
					if lexer:IsCurrentValue("\n") then break end
					lexer:Advance(1)
				end

				return "type_code"
			end

			return false
		end,
	}
