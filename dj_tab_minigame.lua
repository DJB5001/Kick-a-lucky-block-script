-- dj_tab_ingame.lua
return function(Window, Rayfield, Utils)
    local Players           = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService        = game:GetService("RunService")
    local UserInputService  = game:GetService("UserInputService")
    local LocalPlayer       = Players.LocalPlayer

    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

    local IngameTab = Window:CreateTab("Ingame", nil)

    ----------------------------------------------------------------
    -- HELPERS
    ----------------------------------------------------------------
    local remoteCache = {}
    local function getRemote(name)
        if remoteCache[name] and remoteCache[name].Parent then return remoteCache[name] end
        local ok, remote = pcall(function()
            return ReplicatedStorage
                :WaitForChild("Shared",   10)
                :WaitForChild("Packages", 10)
                :WaitForChild("Network",  10)
                :WaitForChild(name,       10)
        end)
        if ok and remote then remoteCache[name] = remote end
        return remoteCache[name]
    end

    local function getObjCFrame(obj)
        if not obj then return nil end
        if obj:IsA("BasePart") then return obj.CFrame end
        if obj:IsA("Model") then
            if obj.PrimaryPart then return obj.PrimaryPart.CFrame end
            local ok, piv = pcall(function() return obj:GetPivot() end)
            if ok and piv then return piv end
            local p = obj:FindFirstChildWhichIsA("BasePart", true)
            if p then return p.CFrame end
        end
        return nil
    end

    local function tpToCFrame(cf)
        local char = LocalPlayer.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp or not cf then return false end
        hrp.CFrame = cf + Vector3.new(0, 3, 0)
        return true
    end

    local function walkToPos(targetPos, maxTime)
        maxTime = maxTime or 25
        local start = tick()
        while (tick() - start) < maxTime do
            local char     = LocalPlayer.Character
            local hrp      = char and char:FindFirstChild("HumanoidRootPart")
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            if not hrp or not humanoid then task.wait(0.3) continue end
            if (hrp.Position - targetPos).Magnitude < 10 then return true end
            humanoid:MoveTo(targetPos)
            task.wait(0.8)
        end
        return false
    end

    local function unequipAll()
        local char = LocalPlayer.Character
        local h    = char and char:FindFirstChildOfClass("Humanoid")
        if h then pcall(function() h:UnequipTools() end) end
        task.wait(0.3)
    end

    local function findPlayerPlot()
        local Plots = workspace:FindFirstChild("Plots")
        if not Plots then return nil end
        for _, plot in pairs(Plots:GetChildren()) do
            local ok, tl = pcall(function()
                return plot.Decorations.PlotOwner.OwnerGUI.TextLabel
            end)
            if ok and tl and tl.Text == LocalPlayer.Name then return plot end
        end
        return nil
    end

    local function getPlotSlots(plot)
        local buttons = plot and plot:FindFirstChild("Buttons")
        if not buttons then return {} end
        local slots = {}
        for i = 1, 30 do
            local slot = buttons:FindFirstChild("Slot" .. i)
            if slot then
                table.insert(slots, { index = i, obj = slot })
            end
        end
        return slots
    end

    local function slotHasAnimal(slotObj)
        return slotObj:FindFirstChild("ButtonGUI") ~= nil
    end

    local function isAnimalTool(tool)
        return tool:FindFirstChild("Handle") ~= nil
    end

    local function getFloor(slotIndex)
        return math.ceil(slotIndex / 10)
    end

    local function parseCPS(text)
        if not text then return 0 end
        local clean = tostring(text):lower()
            :gsub("%$",""):gsub("/s",""):gsub(",",""):gsub("%s+","")
        if clean == "" then return 0 end
        local entries = {
            {"s", 1e18}, {"q", 1e15}, {"t", 1e12},
            {"b", 1e9},  {"m", 1e6},  {"k", 1e3},
        }
        for _, e in ipairs(entries) do
            local num = clean:match("^([%d%.]+)" .. e[1] .. "$")
            if num then return (tonumber(num) or 0) * e[2] end
        end
        return tonumber(clean) or 0
    end

    local function readCPS(tool)
        local ok, text = pcall(function()
            local root = tool:FindFirstChild("Root", true)
            return root.EntityGUI.Frame.CPSFrame.Label.Text
        end)
        return ok and parseCPS(text) or 0
    end

    local function forceEquipTool(tool)
        local char = LocalPlayer.Character
        if not char then return false end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then pcall(function() hum:UnequipTools() end) end
        task.wait(0.3)
        local bp = LocalPlayer:FindFirstChild("Backpack")
        if bp and tool.Parent ~= bp then
            pcall(function() tool.Parent = bp end)
            task.wait(0.2)
        end
        pcall(function() tool.Parent = char end)
        task.wait(0.5)
        char = LocalPlayer.Character
        if char then
            for _, obj in pairs(char:GetChildren()) do
                if obj == tool then return true end
            end
        end
        pcall(function() LocalPlayer:EquipTool(tool) end)
        task.wait(0.5)
        char = LocalPlayer.Character
        if char then
            for _, obj in pairs(char:GetChildren()) do
                if obj == tool then return true end
            end
        end
        return false
    end

    local function isToolEquipped(tool)
        local char = LocalPlayer.Character
        if not char then return false end
        for _, obj in pairs(char:GetChildren()) do
            if obj == tool then return true end
        end
        return false
    end

    ----------------------------------------------------------------
    -- AUTO FARM
    ----------------------------------------------------------------
    IngameTab:CreateSection("Auto Farm")

    IngameTab:CreateParagraph({
        Title   = "Info",
        Content = "Auto Collect       — every 5 minutes. Only visits slots with animals.\n"
                .."Auto Collect Legit — walks within a floor, TPs only when floor changes.\n"
                .."Auto Upgrade All   — every 2 seconds (slots 1-30).\n"
                .."Auto Upgrade Speed — every 2 seconds.\n"
                .."Auto Buy Slots     — every 2 seconds."
    })

    ----------------------------------------------------------------
    -- AUTO COLLECT
    ----------------------------------------------------------------
    local autoCollectEnabled = false
    local collectLegitMode   = false

    local function runCollectOnce()
        local plot = findPlayerPlot()
        if not plot then
            print("[AUTO COLLECT] Plot nicht gefunden!")
            return
        end

        local slots = getPlotSlots(plot)
        if #slots == 0 then return end

        local currentFloor = 0

        for _, slotData in ipairs(slots) do
            if not autoCollectEnabled then break end
            if not slotHasAnimal(slotData.obj) then continue end

            local cf = getObjCFrame(slotData.obj)
            if not cf then continue end

            local slotFloor = getFloor(slotData.index)

            if collectLegitMode then
                if slotFloor ~= currentFloor then
                    tpToCFrame(cf)
                    task.wait(0.4)
                    currentFloor = slotFloor
                else
                    walkToPos(cf.Position + Vector3.new(0, 3, 0), 25)
                end
            else
                tpToCFrame(cf)
                task.wait(0.25)
            end

            pcall(function()
                getRemote("rev_B_Collect"):FireServer(slotData.index)
            end)
            task.wait(0.35)
        end
    end

    local function runAutoCollect()
        while autoCollectEnabled do
            _G.__DJ_CollectBusy = true
            print("[AUTO COLLECT] Sammle Geld von Slots...")
            runCollectOnce()
            _G.__DJ_CollectBusy = false
            local waited = 0
            while autoCollectEnabled and waited < 300 do
                task.wait(1)
                waited += 1
            end
        end
        _G.__DJ_CollectBusy = false
    end

    IngameTab:CreateToggle({
        Name         = "Auto Collect",
        CurrentValue = false,
        Flag         = "IngameAutoCollect",
        Callback     = function(value)
            autoCollectEnabled = value
            if value then
                Rayfield:Notify({ Title = "Auto Collect", Content = "Enabled — every 5 minutes.", Duration = 3 })
                task.spawn(runAutoCollect)
            else
                _G.__DJ_CollectBusy = false
                Rayfield:Notify({ Title = "Auto Collect", Content = "Disabled.", Duration = 3 })
            end
        end,
    })

    IngameTab:CreateToggle({
        Name         = "Auto Collect — Legit Mode",
        CurrentValue = false,
        Flag         = "IngameCollectLegit",
        Callback     = function(value)
            collectLegitMode = value
            Rayfield:Notify({
                Title   = "Collect Legit Mode",
                Content = value
                    and "On — walks within floor, TPs when floor changes."
                    or  "Off — teleporting to every slot.",
                Duration = 3
            })
        end,
    })

    ----------------------------------------------------------------
    -- AUTO UPGRADE ALL
    ----------------------------------------------------------------
    local autoUpgradeEnabled = false

    IngameTab:CreateToggle({
        Name         = "Auto Upgrade All",
        CurrentValue = false,
        Flag         = "IngameAutoUpgrade",
        Callback     = function(value)
            autoUpgradeEnabled = value
            if value then
                Rayfield:Notify({ Title = "Auto Upgrade All", Content = "Enabled — every 2 seconds.", Duration = 3 })
                task.spawn(function()
                    while autoUpgradeEnabled do
                        for i = 1, 30 do
                            if not autoUpgradeEnabled then break end
                            pcall(function() getRemote("rev_B_Upgrade"):FireServer(i) end)
                            task.wait(0.05)
                        end
                        task.wait(2)
                    end
                end)
            else
                Rayfield:Notify({ Title = "Auto Upgrade All", Content = "Disabled.", Duration = 3 })
            end
        end,
    })

    ----------------------------------------------------------------
    -- AUTO UPGRADE SPEED
    ----------------------------------------------------------------
    local autoUpgradeSpeedEnabled = false

    IngameTab:CreateToggle({
        Name         = "Auto Upgrade Speed",
        CurrentValue = false,
        Flag         = "IngameAutoUpgradeSpeed",
        Callback     = function(value)
            autoUpgradeSpeedEnabled = value
            if value then
                Rayfield:Notify({ Title = "Auto Upgrade Speed", Content = "Enabled — every 2 seconds.", Duration = 3 })
                task.spawn(function()
                    while autoUpgradeSpeedEnabled do
                        pcall(function() getRemote("rev_SPEED_UPGRADE"):FireServer(1) end)
                        task.wait(2)
                    end
                end)
            else
                Rayfield:Notify({ Title = "Auto Upgrade Speed", Content = "Disabled.", Duration = 3 })
            end
        end,
    })

    ----------------------------------------------------------------
    -- AUTO BUY SLOTS
    ----------------------------------------------------------------
    local autoBuySlotsEnabled = false

    IngameTab:CreateToggle({
        Name         = "Auto Buy Slots",
        CurrentValue = false,
        Flag         = "IngameAutoBuySlots",
        Callback     = function(value)
            autoBuySlotsEnabled = value
            if value then
                Rayfield:Notify({ Title = "Auto Buy Slots", Content = "Enabled — every 2 seconds.", Duration = 3 })
                task.spawn(function()
                    while autoBuySlotsEnabled do
                        pcall(function() getRemote("rev_bs_upgrade"):FireServer() end)
                        task.wait(2)
                    end
                end)
            else
                Rayfield:Notify({ Title = "Auto Buy Slots", Content = "Disabled.", Duration = 3 })
            end
        end,
    })

    ----------------------------------------------------------------
    -- EQUIP BEST
    ----------------------------------------------------------------
    IngameTab:CreateSection("Equip Best")

    IngameTab:CreateParagraph({
        Title   = "How it works",
        Content = "1. Picks up animals from occupied slots\n"
                .."2. Holds each animal — reads $/s WHILE in hand\n"
                .."   (CPS label is only filled when equipped)\n"
                .."3. Sorts best → worst, fills slots in order"
    })

    local function equipBestAnimals()
        local plot = findPlayerPlot()
        if not plot then
            Rayfield:Notify({ Title = "Equip Best", Content = "Your plot was not found!", Duration = 4 })
            return
        end

        local slots = getPlotSlots(plot)
        if #slots == 0 then
            Rayfield:Notify({ Title = "Equip Best", Content = "No slots found!", Duration = 4 })
            return
        end

        local occupiedCount = 0
        for _, s in ipairs(slots) do
            if slotHasAnimal(s.obj) then occupiedCount += 1 end
        end

        Rayfield:Notify({
            Title   = "Equip Best",
            Content = "Step 1/3: Picking up from " .. occupiedCount .. " slot(s)...",
            Duration = 4
        })

        unequipAll()

        for _, slotData in ipairs(slots) do
            if not slotHasAnimal(slotData.obj) then continue end
            local cf = getObjCFrame(slotData.obj)
            if cf then
                tpToCFrame(cf)
                task.wait(0.4)
                unequipAll()
                task.wait(0.2)
                pcall(function()
                    getRemote("rev_S_Interact"):FireServer(slotData.index)
                end)
                task.wait(0.4)
            end
        end

        task.wait(1)

        local backpack = LocalPlayer:FindFirstChild("Backpack")
        local animalsWithCPS = {}

        if backpack then
            local allTools = {}
            for _, item in pairs(backpack:GetChildren()) do
                if item:IsA("Tool") and isAnimalTool(item) then
                    table.insert(allTools, item)
                end
            end

            if #allTools == 0 then
                Rayfield:Notify({ Title = "Equip Best", Content = "No animals in backpack!", Duration = 4 })
                return
            end

            Rayfield:Notify({
                Title   = "Equip Best",
                Content = "Step 2/3: Reading $/s for " .. #allTools .. " animal(s)...",
                Duration = math.max(3, #allTools * 0.8)
            })

            for _, tool in ipairs(allTools) do
                forceEquipTool(tool)
                task.wait(0.5)
                local cps = readCPS(tool)
                table.insert(animalsWithCPS, { tool = tool, cps = cps, name = tool.Name })
                unequipAll()
                task.wait(0.2)
            end
        else
            Rayfield:Notify({ Title = "Equip Best", Content = "No backpack found!", Duration = 4 })
            return
        end

        if #animalsWithCPS == 0 then
            Rayfield:Notify({ Title = "Equip Best", Content = "No animals found!", Duration = 4 })
            return
        end

        task.wait(0.3)
        table.sort(animalsWithCPS, function(a, b) return a.cps > b.cps end)

        Rayfield:Notify({
            Title   = "Equip Best",
            Content = "Step 3/3: Equipping best → worst...\n"
                    .. "#1: " .. animalsWithCPS[1].name
                    .. " ($" .. animalsWithCPS[1].cps .. "/s)",
            Duration = 5
        })

        local slotIdx = 1

        for rank, animalData in ipairs(animalsWithCPS) do
            if slotIdx > #slots then break end
            local slotData = slots[slotIdx]
            unequipAll()
            local equipped = forceEquipTool(animalData.tool)
            if not equipped then continue end
            local cf = getObjCFrame(slotData.obj)
            if cf then tpToCFrame(cf) task.wait(0.4) end
            if not isToolEquipped(animalData.tool) then
                forceEquipTool(animalData.tool)
                task.wait(0.3)
            end
            if isToolEquipped(animalData.tool) then
                pcall(function() getRemote("rev_S_Interact"):FireServer(slotData.index) end)
                task.wait(0.5)
                slotIdx += 1
                Rayfield:Notify({
                    Title   = "Equip Best",
                    Content = "Slot " .. slotData.index .. " ← #" .. rank
                            .. " " .. animalData.name .. " ($" .. animalData.cps .. "/s)",
                    Duration = 2
                })
            end
            unequipAll()
            task.wait(0.3)
        end

        unequipAll()
        local filled = slotIdx - 1
        Rayfield:Notify({
            Title   = "Equip Best",
            Content = "Done! " .. filled .. " slot(s) filled.\n"
                    .. "Best: " .. animalsWithCPS[1].name
                    .. " ($" .. animalsWithCPS[1].cps .. "/s)",
            Duration = 5
        })
    end

    IngameTab:CreateButton({
        Name     = "Equip Best Animals",
        Callback = function() task.spawn(equipBestAnimals) end
    })

    ----------------------------------------------------------------
    -- AUTO REBIRTH
    ----------------------------------------------------------------
    IngameTab:CreateSection("Auto Rebirth")

    local autoRebirthEnabled = false

    IngameTab:CreateToggle({
        Name         = "Auto Rebirth",
        CurrentValue = false,
        Flag         = "IngameAutoRebirth",
        Callback     = function(value)
            autoRebirthEnabled = value
            if value then
                Rayfield:Notify({ Title = "Auto Rebirth", Content = "Enabled — every 5 seconds.", Duration = 3 })
                task.spawn(function()
                    while autoRebirthEnabled do
                        pcall(function() getRemote("rev_RebirthRequest"):FireServer() end)
                        task.wait(5)
                    end
                end)
            else
                Rayfield:Notify({ Title = "Auto Rebirth", Content = "Disabled.", Duration = 3 })
            end
        end,
    })

    ----------------------------------------------------------------
    -- PLAYER FEATURES
    ----------------------------------------------------------------
    IngameTab:CreateSection("Player Features")

    local flyEnabled    = false
    local flySpeed      = 50
    local flyConnection = nil
    local flyGui        = nil

    -- Mobile Fly Buttons (nur auf Mobile sichtbar)
    local mobileDir = {
        forward = false, back = false,
        left    = false, right = false,
        up      = false, down = false,
    }

    local function createMobileFlyGui()
        if not isMobile then return end
        local CoreGui = game:GetService("CoreGui")

        flyGui = Instance.new("ScreenGui")
        flyGui.Name            = "DJHUB_FlyButtons"
        flyGui.ResetOnSpawn    = false
        flyGui.DisplayOrder    = 99998
        flyGui.IgnoreGuiInset  = true
        flyGui.Parent          = CoreGui

        local function makeBtn(text, pos, dirKey)
            local btn = Instance.new("TextButton")
            btn.Size                  = UDim2.new(0, 80, 0, 80)
            btn.Position              = pos
            btn.AnchorPoint           = Vector2.new(0.5, 0.5)
            btn.BackgroundColor3      = Color3.fromRGB(30, 30, 30)
            btn.BackgroundTransparency = 0.3
            btn.TextColor3            = Color3.fromRGB(255, 255, 255)
            btn.Text                  = text
            btn.Font                  = Enum.Font.GothamBold
            btn.TextSize              = 22
            btn.BorderSizePixel       = 0
            btn.Parent                = flyGui
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 12)

            btn.InputBegan:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then
                    mobileDir[dirKey] = true
                end
            end)
            btn.InputEnded:Connect(function(input)
                if input.UserInputType == Enum.UserInputType.Touch then
                    mobileDir[dirKey] = false
                end
            end)
            return btn
        end

        -- Links unten: Bewegung (Forward/Back/Left/Right)
        makeBtn("▲", UDim2.new(0, 120, 1, -220), "forward")
        makeBtn("▼", UDim2.new(0, 120, 1, -100), "back")
        makeBtn("◄", UDim2.new(0, 50,  1, -160), "left")
        makeBtn("►", UDim2.new(0, 190, 1, -160), "right")

        -- Rechts unten: Hoch/Runter
        makeBtn("↑", UDim2.new(1, -60, 1, -220), "up")
        makeBtn("↓", UDim2.new(1, -60, 1, -120), "down")
    end

    local function destroyMobileFlyGui()
        if flyGui then
            pcall(function() flyGui:Destroy() end)
            flyGui = nil
        end
        for k in pairs(mobileDir) do mobileDir[k] = false end
    end

    IngameTab:CreateSlider({
        Name         = "Fly Speed",
        Range        = {10, 200},
        Increment    = 10,
        Suffix       = "Speed",
        CurrentValue = 50,
        Flag         = "IngameFlySpeed",
        Callback     = function(value) flySpeed = value end,
    })

    IngameTab:CreateToggle({
        Name         = "Fly",
        CurrentValue = false,
        Flag         = "IngameFly",
        Callback     = function(enabled)
            flyEnabled = enabled
            if enabled then
                local hrp = LocalPlayer.Character
                    and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if not hrp then
                    Rayfield:Notify({ Title = "Fly", Content = "Character not found!", Duration = 3 })
                    return
                end

                local bv = Instance.new("BodyVelocity")
                bv.Velocity = Vector3.new(0, 0, 0)
                bv.MaxForce = Vector3.new(9e9, 9e9, 9e9)
                bv.Parent   = hrp

                local bg = Instance.new("BodyGyro")
                bg.MaxTorque = Vector3.new(9e9, 9e9, 9e9)
                bg.P         = 9e4
                bg.Parent    = hrp

                -- Mobile Buttons erstellen
                if isMobile then createMobileFlyGui() end

                flyConnection = RunService.Heartbeat:Connect(function()
                    if not flyEnabled then return end
                    local camera = workspace.CurrentCamera
                    local dir    = Vector3.new(0, 0, 0)

                    if isMobile then
                        -- Mobile: Buttons
                        if mobileDir.forward then dir += camera.CFrame.LookVector  end
                        if mobileDir.back    then dir -= camera.CFrame.LookVector  end
                        if mobileDir.left    then dir -= camera.CFrame.RightVector end
                        if mobileDir.right   then dir += camera.CFrame.RightVector end
                        if mobileDir.up      then dir += Vector3.new(0, 1, 0)      end
                        if mobileDir.down    then dir -= Vector3.new(0, 1, 0)      end
                    else
                        -- PC: Keyboard
                        if UserInputService:IsKeyDown(Enum.KeyCode.W)         then dir += camera.CFrame.LookVector  end
                        if UserInputService:IsKeyDown(Enum.KeyCode.S)         then dir -= camera.CFrame.LookVector  end
                        if UserInputService:IsKeyDown(Enum.KeyCode.A)         then dir -= camera.CFrame.RightVector end
                        if UserInputService:IsKeyDown(Enum.KeyCode.D)         then dir += camera.CFrame.RightVector end
                        if UserInputService:IsKeyDown(Enum.KeyCode.Space)     then dir += Vector3.new(0, 1, 0)      end
                        if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then dir -= Vector3.new(0, 1, 0)      end
                    end

                    bv.Velocity = dir * flySpeed
                    bg.CFrame   = camera.CFrame
                end)

                if isMobile then
                    Rayfield:Notify({ Title = "Fly", Content = "Enabled! Buttons shown on screen.", Duration = 4 })
                else
                    Rayfield:Notify({ Title = "Fly", Content = "Enabled! WASD + Space/Shift", Duration = 4 })
                end
            else
                if flyConnection then flyConnection:Disconnect() flyConnection = nil end
                destroyMobileFlyGui()

                local hrp = LocalPlayer.Character
                    and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    for _, obj in pairs(hrp:GetChildren()) do
                        if obj:IsA("BodyVelocity") or obj:IsA("BodyGyro") then
                            obj:Destroy()
                        end
                    end
                end
                Rayfield:Notify({ Title = "Fly", Content = "Disabled.", Duration = 3 })
            end
        end,
    })

    ----------------------------------------------------------------
    -- VISUAL
    ----------------------------------------------------------------
    IngameTab:CreateSection("Visual")

    local espEnabled     = false
    local espConnections = {}

    IngameTab:CreateToggle({
        Name         = "Player ESP",
        CurrentValue = false,
        Flag         = "IngamePlayerESP",
        Callback     = function(enabled)
            espEnabled = enabled
            if enabled then
                local function addESP(character)
                    local hrp = character:WaitForChild("HumanoidRootPart", 5)
                    if not hrp then return end
                    local h = Instance.new("Highlight")
                    h.Adornee             = character
                    h.FillColor           = Color3.fromRGB(255, 0, 0)
                    h.OutlineColor        = Color3.fromRGB(255, 255, 255)
                    h.FillTransparency    = 0.5
                    h.OutlineTransparency = 0
                    h.Name                = "DJHUB_ESP"
                    h.Parent              = character
                end
                for _, player in pairs(Players:GetPlayers()) do
                    if player ~= LocalPlayer then
                        if player.Character then addESP(player.Character) end
                        table.insert(espConnections,
                            player.CharacterAdded:Connect(function(c)
                                if espEnabled then addESP(c) end
                            end)
                        )
                    end
                end
                table.insert(espConnections,
                    Players.PlayerAdded:Connect(function(player)
                        if espEnabled and player ~= LocalPlayer then
                            player.CharacterAdded:Connect(function(c)
                                if espEnabled then addESP(c) end
                            end)
                        end
                    end)
                )
                Rayfield:Notify({ Title = "ESP", Content = "Enabled.", Duration = 3 })
            else
                for _, c in pairs(espConnections) do c:Disconnect() end
                espConnections = {}
                for _, player in pairs(Players:GetPlayers()) do
                    if player.Character then
                        for _, obj in pairs(player.Character:GetDescendants()) do
                            if obj.Name == "DJHUB_ESP" and obj:IsA("Highlight") then
                                obj:Destroy()
                            end
                        end
                    end
                end
                Rayfield:Notify({ Title = "ESP", Content = "Disabled.", Duration = 3 })
            end
        end,
    })

    ----------------------------------------------------------------
    -- UTILITY
    ----------------------------------------------------------------
    IngameTab:CreateSection("Utility")

    local noclipEnabled    = false
    local noclipConnection = nil

    IngameTab:CreateToggle({
        Name         = "Noclip",
        CurrentValue = false,
        Flag         = "IngameNoclip",
        Callback     = function(enabled)
            noclipEnabled = enabled
            if enabled then
                noclipConnection = RunService.Stepped:Connect(function()
                    if not noclipEnabled then return end
                    local char = LocalPlayer.Character
                    if char then
                        for _, p in pairs(char:GetDescendants()) do
                            if p:IsA("BasePart") then p.CanCollide = false end
                        end
                    end
                end)
                Rayfield:Notify({ Title = "Noclip", Content = "Enabled.", Duration = 3 })
            else
                if noclipConnection then
                    noclipConnection:Disconnect()
                    noclipConnection = nil
                end
                local char = LocalPlayer.Character
                if char then
                    for _, p in pairs(char:GetDescendants()) do
                        if p:IsA("BasePart") then p.CanCollide = true end
                    end
                end
                Rayfield:Notify({ Title = "Noclip", Content = "Disabled.", Duration = 3 })
            end
        end,
    })

    print("[INGAME] Tab loaded")
end
