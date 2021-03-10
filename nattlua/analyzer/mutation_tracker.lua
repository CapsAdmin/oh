local types = require("nattlua.types.types")
local tprint = require("nattlua.other.tprint")

local META = {}
META.__index = META

local DEBUG = true

local function same_if_statement(a, b)
    return a.if_statement and a.if_statement == b.if_statement
end

function META:GetValueFromScope(scope, upvalue, key, analyzer)
    local mutations = {}

    do
        
        for from, mut in ipairs(self.mutations) do
            -- if we're inside an if statement, we know for sure that the other parts of that if statements have not been hit
            if same_if_statement(scope, mut.scope) and scope ~= mut.scope then
            else 
                table.insert(mutations, mut)                            
            end
        end

        do --[[
            if mutations occured in an if statement that has an else part, remove all mutations before the if statement
            but only if we are a sibling of the if statement's scope
        ]] 
            for i = #mutations, 1, -1 do
                local mut = mutations[i]

                if mut.scope.if_statement and mut.scope.test_condition_inverted then
                    
                    local if_statement = mut.scope.if_statement
                    while true do
                        local mut = mutations[i]
                        if not mut then break end
                        if mut.scope.if_statement ~= if_statement then
                            for i = i, 1, -1 do
                                if mutations[i].scope:Contains(scope) then
                                    table.remove(mutations, i)
                                end
                            end
                            break
                        end                                       
                    
                        i = i - 1
                    end

                    break
                end
            end
        end
        
        if scope.test_condition then -- make scopes that use the same type condition certrain
            for _, mut in ipairs(mutations) do
                if mut.scope ~= scope and mut.scope.test_condition and types.FindInType(mut.scope.test_condition, scope.test_condition) then
                    mut.certain_override = true
                end
            end
        end
    end
    
    local union = types.Union({})
    union.upvalue = upvalue
    union.upvalue_keyref = key
    
    for _, mut in ipairs(mutations) do
        local obj = mut.value

        do
            --[[
                local x: nil | true
                if not x then
                    x = true
                end

                -- x is true here
            ]]
            local scope, scope_union = mut.scope:FindScopeFromTestCondition(obj)
            if scope and mut.scope == scope and scope.test_condition.Type == "union" then
                local t
                if scope.test_condition_inverted then
                    t = scope_union.falsy_union or scope.test_condition:GetFalsy()
                else
                    t = scope_union.truthy_union or scope.test_condition:GetTruthy()
                end

                if t then
                    union:RemoveType(t)
                end
            end
        end
    
        if mut.certain_override or mut.scope:IsCertain(scope) then
            union:Clear()
        end

        if _ == 1 and obj.Type == "union" then
            if upvalue.Type == "table" then
                union = obj:Copy()
                union.upvalue = upvalue
                union.upvalue_keyref = key
            else 
                union = obj:Copy()
                union.upvalue = upvalue
                union.upvalue_keyref = key
            end
        else
            if obj.Type == "function" and not obj.called and not obj.explicit_return and union:HasType("function") then
                analyzer:Assert(obj:GetNode() or analyzer.current_expression, analyzer:Call(obj, obj:GetArguments():Copy()))
            end

            union:AddType(obj)
        end
    end

    local value = union
    
    if #union:GetData() == 1 then
        value = union:GetData()[1]
    end

    if value.Type == "union" then
        --[[

            this is only for when unions have been tested for

            local x = true | false

            if 
                x -- x is split into a falsy and truthy union in the binary operator
            then
                print(x) -- x is true here
            end
        ]]

        local scope, union = scope:FindScopeFromTestCondition(value)

        if scope then 
            local current_scope = scope

            if #self.mutations > 1 then
                for i = #self.mutations, 1, -1 do
                    if self.mutations[i].scope == current_scope then
                        return value
                    else
                        break
                    end
                end
            end
        

            local t

            -- the or part here refers to if *condition* then
            -- truthy/falsy _union is only created from binary operators and some others
            if scope.test_condition_inverted then
                t = union.falsy_union or value:GetFalsy()
            else
                t = union.truthy_union or value:GetTruthy()
            end
                        
            return t
        end
    end

    return value
end

function META:HasMutations()
    return self.mutations[1] ~= nil
end

function META:Mutate(value, scope)
    table.insert(self.mutations, {
        scope = scope,
        value = value,
    })
    return self
end

return function()
    return setmetatable({mutations = {}}, META)
end 