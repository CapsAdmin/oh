return
	{
		ReadContinue = function(parser)
			return
				parser:IsValue("continue") and
				parser:Node("statement", "continue"):ExpectKeyword("continue"):End()
		end,
	}
