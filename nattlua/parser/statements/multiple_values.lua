return
	{
		ReadMultipleValues = function(parser, max, reader, a, b, c)
			local out = {}

			for i = 1, max or parser:GetLength() do
				local node = reader(parser, a, b, c)
				if not node then break end
				out[i] = node
				if not parser:IsValue(",") then break end
				node.tokens[","] = parser:ExpectValue(",")
			end

			return out
		end,
	}
