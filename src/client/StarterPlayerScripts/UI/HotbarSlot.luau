local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.react)
local e = React.createElement

local function HotbarSlot()
    local Slots = {}

    for i = 1 , 8 do
        Slots["Slot"..i] = e("Frame",{
            Size = UDim2.new(1,0,1,0),
            LayoutOrder = i,
            BackgroundColor3 = Color3.fromRGB(255,0,0),
            BackgroundTransparency = 1
        },{
            e("ImageButton",{
                Image = "rbxassetid://"..8508980527,
                Size = UDim2.new(0.9,0,0.9,0),
                AnchorPoint = Vector2.new(0.5,0.5),
                Position = UDim2.new(0.5,0,0.5,0),

            },{
                e("UIStroke",{
                    Thickness = 2,
                }),
                e("UICorner",{
                    CornerRadius = UDim.new(0,4)
                }),
                e("TextLabel",{
                    AnchorPoint = Vector2.new(.5,.5),
                    Position = UDim2.new(.5,0,1,0),
                    Size = UDim2.new(1,0,0,30),
                    Text = "1X",
                    Font = Enum.Font.FredokaOne,
                    TextSize = 14,
                    TextScaled = false,
                    TextColor3 = Color3.fromRGB(255, 255, 255),
                    BackgroundColor3 = Color3.fromRGB(64, 71, 208),
                    BackgroundTransparency = 1
                },{
                    e("UIStroke",{
                        Thickness = 1,
                        ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
                    }),
                }),
            }),
            e("TextLabel",{
                AnchorPoint = Vector2.new(1,.5),
                Position = UDim2.new(1,0,0.06,0),
                Size = UDim2.new(1,0,0,30),
                Text = i,
                Font = Enum.Font.FredokaOne,
                TextScaled = true,
                TextColor3 = Color3.fromRGB(255, 255, 255),
                BackgroundColor3 = Color3.fromRGB(64, 71, 208),
                BackgroundTransparency = 1
            },{
                e("UIStroke",{
                    Thickness = 1,
                    ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual,
                }),
                e("UIPadding",{
                    PaddingTop = UDim.new(0,6),
                    PaddingLeft = UDim.new(0,0),
                    PaddingRight = UDim.new(0,0),
                    PaddingBottom = UDim.new(0,6),
                }),
            })
        })
    end

    return e("Frame",{
        Size = UDim2.new(0.8,0,0,80),
        AnchorPoint = Vector2.new(.5,1),
        Position = UDim2.new(0.5,0,0.98,0),
        BackgroundColor3 = Color3.fromRGB(0, 0, 0),
        BackgroundTransparency = 0.6
    },{
        Slots,
        e("UIListLayout",{
            FillDirection = Enum.FillDirection.Horizontal,
            HorizontalFlex = Enum.UIFlexAlignment.Fill,
            VerticalFlex = Enum.UIFlexAlignment.Fill
        }),
        e("UIAspectRatioConstraint",{
            AspectRatio = 8,
        }),
        e("UICorner"),
        e("UIStroke")
    })
end

return HotbarSlot