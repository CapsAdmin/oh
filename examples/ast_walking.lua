local nl = require("nl")
local ast = assert(nl.Code(assert(io.open("nl/lua/parser.lua")):read("*all")):Parse()).SyntaxTree

print("==================================================")
print("all while statements:")
for i,v in ipairs(ast:FindStatementsByType("while")) do
    print(i, v:Render())
end

print("==================================================")
print("find ^node%.tokens%b[]")
for _, v in ipairs(ast:FindStatementsByType("assignment")) do
    if v.left then
        for _, expression in ipairs(v.left) do
            if expression:Render():find("^node%.tokens%b[]") then
                print(expression:Render())
            end
        end
    end
end