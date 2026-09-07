local Ronetik = {}

local function IsRonetikWrapper(Value)
    if type(Value) ~= "table" then
        return false
    end

    local Success, rawInstance = pcall(function()
        return Value._Instance
    end)

    return Success and rawInstance ~= nil
end

local function Unwrap(Value)
    if IsRonetikWrapper(Value) then
        return Value._Instance
    end
    return Value
end

local function IsClassSupported(RawInstance, ClassesList)
    for _, ClassName in ipairs(ClassesList) do
        if RawInstance:IsA(ClassName) then
            return true
        end
    end
    return false
end

local function FormatAnchorPoint(Value)
    if type(Value) == "number" then
        Value = math.clamp(Value, 0, 1)
        Value = Vector2.new(Value, Value)
    end
    if typeof(Value) == "Vector2" then
        local X = math.clamp(Value.X, 0, 1)
        local Y = math.clamp(Value.Y, 0, 1)
        return Vector2.new(X, Y)
    end
    return Vector2.new(0, 0)
end

local function RecalculatePosition(Wrapper)
    local Meta = getmetatable(Wrapper)
    local RawInstance = Meta._Instance
    local AnchorPoint = Meta._Props["AnchorPoint"] or Vector2.new(0, 0)
    local LogicalPos = Meta._Props["Position"] or RawInstance.Position

    local Size = RawInstance.Size
    local AbsoluteSize = RawInstance.AbsoluteSize

    local Width = AbsoluteSize.X > 0 and AbsoluteSize.X or Size.X.Offset
    local Height = AbsoluteSize.Y > 0 and AbsoluteSize.Y or Size.Y.Offset

    local OffsetX = Width * AnchorPoint.X
    local OffsetY = Height * AnchorPoint.Y

    RawInstance.Position = UDim2.new(
        LogicalPos.X.Scale,
        LogicalPos.X.Offset - OffsetX,
        LogicalPos.Y.Scale,
        LogicalPos.Y.Offset - OffsetY
    )
end

local CustomProps = {
    ["AnchorPoint"] = {
        Default = Vector2.new(0, 0),
        Get = function(Wrapper)
            local Meta = getmetatable(Wrapper)
            return Meta._Props["AnchorPoint"] or Vector2.new(0, 0)
        end,
        Set = function(Wrapper, Value)
            local Meta = getmetatable(Wrapper)
            Meta._Props["AnchorPoint"] = FormatAnchorPoint(Value)
            RecalculatePosition(Wrapper)
        end,
        Classes = { "Frame", "ImageLabel", "TextLabel", "ImageButton", "ScrollingFrame", "TextBox", "TextButton" }
    },
    ["Position"] = {
        Get = function(Wrapper)
            local Meta = getmetatable(Wrapper)
            return Meta._Props["Position"] or Meta._Instance.Position
        end,
        Set = function(Wrapper, Value)
            local Meta = getmetatable(Wrapper)
            Meta._Props["Position"] = Value
            RecalculatePosition(Wrapper)
        end,
        Classes = { "Frame", "ImageLabel", "TextLabel", "ImageButton", "ScrollingFrame", "TextBox", "TextButton" }
    },
    ["Size"] = {
        Get = function(Wrapper)
            local Meta = getmetatable(Wrapper)
            return Meta._Instance.Size
        end,
        Set = function(Wrapper, Value)
            local Meta = getmetatable(Wrapper)
            Meta._Instance.Size = Value
            RecalculatePosition(Wrapper)
        end,
        Classes = { "Frame", "ImageLabel", "TextLabel", "ImageButton", "ScrollingFrame", "TextBox", "TextButton" }
    }
}

function Ronetik:Create(Class, StarterProperties, Children)
    StarterProperties = StarterProperties or {}
    Children = Children or {}

    local RawInstance = Instance.new(Class)

    local Proxy = {}
    local Meta = {
        _Instance = RawInstance,
        _Props = {}
    }

    for PropName, Definition in pairs(CustomProps) do
        if IsClassSupported(RawInstance, Definition.Classes) then
            if Definition.Default ~= nil then
                Meta._Props[PropName] = Definition.Default
            end
        end
    end

    Meta.__index = function(_, Key)
        if Meta[Key] ~= nil then
            return Meta[Key]
        end

        if Key == "Parent" then
            local Parent = RawInstance.Parent
            return IsRonetikWrapper(Parent) and Parent or Parent
        end

        local Definition = CustomProps[Key]
        if Definition and IsClassSupported(RawInstance, Definition.Classes) then
            return Definition.Get(Proxy)
        end

        local Success, Prop = pcall(function()
            return RawInstance[Key]
        end)

        if Success and Prop ~= nil then
            if type(Prop) == "function" then
                return function(self, ...)
                    local Args = { ... }
                    for i = 1, #Args do
                        Args[i] = Unwrap(Args[i])
                    end
                    return Prop(RawInstance, table.unpack(Args))
                end
            end
            return Prop
        end

        local Child = RawInstance:FindFirstChild(Key)
        if Child then
            return Child
        end

        if not Success then
            warn(string.format('"%s" is not a valid member or child of %s', tostring(Key), RawInstance.ClassName))
        end

        return nil
    end

    Meta.__newindex = function(_, Key, Value)
        local UnwrappedValue = Unwrap(Value)
        local Definition = CustomProps[Key]

        if Definition and IsClassSupported(RawInstance, Definition.Classes) then
            Definition.Set(Proxy, UnwrappedValue)
        else
            RawInstance[Key] = UnwrappedValue
        end
    end

    setmetatable(Proxy, Meta)

    for PropName, PropValue in pairs(StarterProperties) do
        Proxy[PropName] = PropValue
    end

    for _, Child in pairs(Children) do
        local UnwrappedChild = Unwrap(Child)
        if typeof(UnwrappedChild) == "Instance" then
            UnwrappedChild.Parent = RawInstance
        end
    end

    return Proxy
end

return Ronetik
