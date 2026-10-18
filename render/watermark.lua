    -- РУЧНАЯ РАСКЛАДКА (БЕЗ UIListLayout внутри)
    function self:AddCombinedBlock(elements)
        local block = {}
        
        local PAD_X = 14       -- Отступ внутри овала (слева/справа)
        local ICON_SIZE = 16   -- Размер иконки
        local GAP = 6          -- Зазор между иконкой и текстом
        local HEIGHT = 32      -- Высота овала
        local TEXT_SIZE = 13   -- Размер текста
        
        local oval = Instance.new("Frame")
        oval.Parent = self.container
        oval.BackgroundColor3 = Color3.fromRGB(8, 8, 13)
        oval.BackgroundTransparency = 0.15
        oval.BorderSizePixel = 0
        oval.Size = UDim2.new(0, 0, 0, HEIGHT)
        oval.ZIndex = 999
        oval.LayoutOrder = #self.blocks + 1
        
        Instance.new("UICorner", oval).CornerRadius = UDim.new(0, 10)
        local outline = Instance.new("UIStroke", oval)
        outline.Thickness = 2; outline.Transparency = 0.8; outline.Color = Color3.fromRGB(0, 0, 0)

        local elementsData = {}
        local totalWidth = 0

        for i, el in ipairs(elements) do
            local section = Instance.new("Frame")
            section.BackgroundTransparency = 1
            section.Size = UDim2.new(0, 0, 1, 0)
            section.Position = UDim2.new(0, totalWidth, 0, 0)
            section.ZIndex = 1000
            section.Parent = oval

            local textStr = tostring(el.text or "")
            local tSize = TextService:GetTextSize(textStr, TEXT_SIZE, Enum.Font.GothamBold, Vector2.new(10000, 10000))
            local textWidth = math.ceil(tSize.X)

            local iconLabel = nil
            if el.icon then
                iconLabel = Instance.new("TextLabel")
                iconLabel.Parent = section
                iconLabel.BackgroundTransparency = 1
                iconLabel.Size = UDim2.new(0, ICON_SIZE, 0, ICON_SIZE)
                iconLabel.Position = UDim2.new(0, PAD_X, 0.5, -ICON_SIZE/2) -- Иконка с отступом
                iconLabel.ZIndex = 1001
                iconLabel.FontFace = Font.new("rbxasset://LuaPackages/Packages/_Index/BuilderIcons/BuilderIcons/BuilderIcons.json", Enum.FontWeight.Bold, Enum.FontStyle.Normal)
                iconLabel.Text = el.icon
                iconLabel.TextColor3 = el.color or Color3.fromRGB(255,255,255)
                iconLabel.TextSize = 14
                iconLabel.TextTransparency = 0.15
            end

            local tLabel = Instance.new("TextLabel")
            tLabel.Parent = section
            tLabel.BackgroundTransparency = 1
            tLabel.Size = UDim2.new(0, textWidth, 1, 0)
            tLabel.Position = UDim2.new(0, PAD_X + (el.icon and (ICON_SIZE + GAP) or 0), 0, 0) -- Текст с отступом
            tLabel.Font = Enum.Font.GothamBold
            tLabel.Text = textStr
            tLabel.TextColor3 = el.color or Color3.fromRGB(255,255,255)
            tLabel.TextSize = TEXT_SIZE
            tLabel.TextXAlignment = Enum.TextXAlignment.Left
            tLabel.ZIndex = 1001
            
            if el.isMissWare then self.misswareTextLabel = tLabel end

            -- Ширина секции = (padding * 2) + иконка + зазор + текст
            local secWidth = (PAD_X * 2) + (el.icon and (ICON_SIZE + GAP) or 0) + textWidth
            section.Size = UDim2.new(0, secWidth, 1, 0)

            elementsData[i] = { Section = section, Text = tLabel, Width = textWidth, Data = el }
            totalWidth = totalWidth + secWidth + (i < #elements and 12 or 0) -- 12 пикселей между секциями (разделитель)

            if i < #elements then
                local divider = Instance.new("Frame")
                divider.Size = UDim2.new(0, 1, 0, 14)
                divider.Position = UDim2.new(0, totalWidth - 12 + 5, 0.5, -7)
                divider.BackgroundColor3 = Color3.fromRGB(60, 60, 75)
                divider.BackgroundTransparency = 0.5
                divider.BorderSizePixel = 0
                divider.ZIndex = 1000
                divider.Parent = oval
            end
        end

        oval.Size = UDim2.new(0, totalWidth, 0, HEIGHT)

        function block:SetElementText(index, newText)
            local fr = elementsData[index]
            if not fr then return end
            local t = tostring(newText)
            if fr.Text.Text == t then return end
            fr.Text.Text = t
            
            local tSize = TextService:GetTextSize(t, TEXT_SIZE, Enum.Font.GothamBold, Vector2.new(10000, 10000))
            local newWidth = math.ceil(tSize.X)
            
            -- Пересчитываем раскладку ТОЛЬКО если ширина текста реально изменилась
            if newWidth ~= fr.Width then
                fr.Width = newWidth
                fr.Text.Size = UDim2.new(0, newWidth, 1, 0)
                
                local curX = 0
                for i = 1, #elementsData do
                    local el = elementsData[i]
                    local secWidth = (PAD_X * 2) + (el.Data.icon and (ICON_SIZE + GAP) or 0) + el.Width
                    el.Section.Size = UDim2.new(0, secWidth, 1, 0)
                    el.Section.Position = UDim2.new(0, curX, 0, 0)
                    curX = curX + secWidth + (i < #elementsData and 12 or 0)
                end
                oval.Size = UDim2.new(0, curX, 0, HEIGHT)
            end
        end
        
        function block:SetVisible(v) oval.Visible = v end

        table.insert(self.blocks, block)
        return block
    end
