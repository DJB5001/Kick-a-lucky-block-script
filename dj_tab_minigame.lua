-- dj_tab_minigame.lua
-- Minigame tab for DJ HUB | Kick a Lucky Block
-- Rayfield-docs-compliant | Updated Godmode

return function(Window, Rayfield, Utils)
    local Players           = game:GetService("Players")
    local ReplicatedStorage = game:GetService("ReplicatedStorage")
    local RunService        = game:GetService("RunService")
    local UserInputService  = game:GetService("UserInputService")
    local LocalPlayer       = Players.LocalPlayer

    local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

    local MinigameTab = Window:CreateTab("Minigame", nil)

    -- ================================================================
    -- MUTATIONS
    -- ================================================================
    local ALL_MUTATIONS = {
        "All", "Normal", "Golden", "Diamond", "Plasma", "Molten",
        "Radioactive", "Shadow", "Electrified", "Rainbow", "Astral",
        "Wet", "Alien", "Bacon", "Virus", "Void", "Enchanted", "Phantom",
    }

    local MUTATION_SET = {}
    for _, m in ipairs(ALL_MUTATIONS) do MUTATION_SET[m] = true end

    local acceptAll         = true
    local acceptedMutations = {}

    -- ================================================================
    -- DEBRIS SCAN
    -- ================================================================
    local function getDebrisMutation()
        local debris = workspace:FindFirstChild("Debris")
        if not debris then return nil end
        for _, topModel in ipairs(debris:GetChildren()) do
            if not topModel:IsA("Model") then continue end
            local animalModel = topModel:FindFirstChildWhichIsA("Model")
            if not animalModel then continue end
            for _, child in ipairs(animalModel:GetChildren()) do
                if MUTATION_SET[child.Name] and child.Name ~= "All" then
                    return child.Name
                end
            end
            return "Normal"
        end
        return nil
    end

    -- ================================================================
    -- GODMODE (Wave-Dodge)
    -- Struktur: Waves > [FloorName] > [Speed] > [Back/Bottom/Front/Left/Right/Top]
    -- Wenn eine Wave zu nah ist -> TP hinter die Wave (hinter "Back"-Part)
    -- ================================================================
    local godmodeEnabled    = false
    local godmodeHeartbeat  = nil
    local godmodeCharConn   = nil
    local godmodeTpCooldown = false

    -- Alle Wave-Parts sammeln die aktiv sind
    local function getActiveWaveParts()
        local parts = {}
        local waves = workspace:FindFirstChild("Waves")
        if not waves then return parts end
        for _, floorFolder in ipairs(waves:GetChildren()) do
            for _, speedFolder in ipairs(floorFolder:GetChildren()) do
                for _, part in ipairs(speedFolder:GetChildren()) do
                    if part:IsA("BasePart") then
                        table.insert(parts, part)
                    end
                end
                if speedFolder:IsA("BasePart") then
                    table.insert(parts, speedFolder)
                end
            end
        end
        return parts
    end

    -- Naechste Wave-Part + Distanz finden
    local function getNearestWavePart(hrpPos)
        local nearest     = nil
        local nearestDist = math.huge
        for _, part in ipairs(getActiveWaveParts()) do
            local ok, dist = pcall(function()
                return (part.Position - hrpPos).Magnitude
            end)
            if ok and dist < nearestDist then
                nearestDist = dist
                nearest     = part
            end
        end
        return nearest, nearestDist
    end

    -- "Back"-Part der Wave finden (Spieler dahinter TP-en)
    local function getBackPart(wavePart)
        local speedFolder = wavePart.Parent
        if not speedFolder then return nil end
        local back = speedFolder:FindFirstChild("Back")
        if back and back:IsA("BasePart") then return back end
        local root = speedFolder:FindFirstChild("RootPart")
        if root and root:IsA("BasePart") then return root end
        return nil
    end

    local TP_DISTANCE   = 25  -- Wenn Wave naeher als X Studs -> TP
    local TP_BEHIND_OFF = 15  -- Wie weit hinter die Wave TP-en

    local lastDebugPrint = 0  -- Throttle fuer Wave-Detected prints

    local function dodgeWave(hrp, nearestPart)
        if godmodeTpCooldown then return end
        godmodeTpCooldown = true

        local partName    = tostring(nearestPart.Name)
        local floorName   = tostring(nearestPart.Parent and nearestPart.Parent.Parent and nearestPart.Parent.Parent.Name or "?")
        local speedName   = tostring(nearestPart.Parent and nearestPart.Parent.Name or "?")
        local dist        = math.floor((nearestPart.Position - hrp.Position).Magnitude)

        print(string.format("[GODMODE] TP ausgeloest | Wave: %s > %s > %s | Distanz: %d Studs",
            floorName, speedName, partName, dist))

        pcall(function()
            local backPart = getBackPart(nearestPart)
            local tpTarget

            if backPart then
                local dir = (backPart.Position - nearestPart.Position).Unit
                tpTarget  = backPart.CFrame + dir * TP_BEHIND_OFF + Vector3.new(0, 3, 0)
                print(string.format("[GODMODE] TP hinter Back-Part | Ziel: (%.1f, %.1f, %.1f)",
                    tpTarget.X, tpTarget.Y, tpTarget.Z))
            else
                local dir = (hrp.Position - nearestPart.Position).Unit
                dir       = Vector3.new(dir.X, 0, dir.Z).Unit
                tpTarget  = CFrame.new(hrp.Position + dir * TP_BEHIND_OFF)
                print(string.format("[GODMODE] TP Fallback (kein Back-Part) | Ziel: (%.1f, %.1f, %.1f)",
                    tpTarget.X, tpTarget.Y, tpTarget.Z))
            end

            hrp.CFrame = tpTarget
        end)

        print("[GODMODE] TP abgeschlossen | Cooldown 1.5s...")

        task.delay(1.5, function()
            godmodeTpCooldown = false
            print("[GODMODE] Cooldown abgelaufen, bereit fuer naechsten Dodge")
        end)
    end

    local function enableGodmode()
        godmodeEnabled = true
        print("[GODMODE] Wave-Dodge gestartet | TP_DISTANCE=" .. TP_DISTANCE .. " | TP_BEHIND_OFF=" .. TP_BEHIND_OFF)

        if godmodeHeartbeat then godmodeHeartbeat:Disconnect() end
        godmodeHeartbeat = RunService.Heartbeat:Connect(function()
            if not godmodeEnabled then return end
            local c   = LocalPlayer.Character
            local hrp = c and c:FindFirstChild("HumanoidRootPart")
            if not hrp then return end

            local nearestPart, dist = getNearestWavePart(hrp.Position)

            -- Alle 2 Sekunden ausgeben ob Wave gefunden (nicht jeden Frame)
            local now = tick()
            if now - lastDebugPrint >= 2 then
                lastDebugPrint = now
                if nearestPart then
                    local floorName = tostring(nearestPart.Parent and nearestPart.Parent.Parent and nearestPart.Parent.Parent.Name or "?")
                    local speedName = tostring(nearestPart.Parent and nearestPart.Parent.Name or "?")
                    print(string.format("[GODMODE] Wave aktiv: %s > %s > %s | Distanz: %.1f Studs",
                        floorName, speedName, nearestPart.Name, dist))
                else
                    print("[GODMODE] Keine Wave im Workspace gefunden")
                end
            end

            if nearestPart and dist < TP_DISTANCE then
                dodgeWave(hrp, nearestPart)
            end
        end)

        if godmodeCharConn then godmodeCharConn:Disconnect() end
        godmodeCharConn = LocalPlayer.CharacterAdded:Connect(function()
            if not godmodeEnabled then return end
            godmodeTpCooldown = false
        end)

        print("[GODMODE] Wave-Dodge aktiv")
    end

    local function disableGodmode()
        godmodeEnabled    = false
        godmodeTpCooldown = false
        if godmodeHeartbeat then godmodeHeartbeat:Disconnect() godmodeHeartbeat = nil end
        if godmodeCharConn  then godmodeCharConn:Disconnect()  godmodeCharConn  = nil end
        print("[GODMODE] Deaktiviert")
    end

    local godmodeWasActive = false

    -- ================================================================
    -- FLOOR / WAVE HELPER
    -- ================================================================
    local FLOOR_ORDER = {
        "Common","Rare","Epic","Legendary","Mythic",
        "Godly","Secret","Divine","Hacked","OG","Celestial","Eternal",
    }
    local FLOOR_INDEX = {}
    for i, n in ipairs(FLOOR_ORDER) do FLOOR_INDEX[n] = i end

    local function getActiveWaveFloor()
        local waves = workspace:FindFirstChild("Waves")
        if not waves then return nil end
        for _, child in ipairs(waves:GetChildren()) do
            if FLOOR_INDEX[child.Name] then return child.Name end
        end
        return nil
    end

    local function getFloorCFrame(floorName)
        local floors = workspace:FindFirstChild("Floors")
        if not floors then return nil end
        local obj = floors:FindFirstChild(floorName)
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

    -- ================================================================
    -- KICKREADY HELPER
    -- ================================================================
    local kickRemote = nil

    local function getKickRemote()
        if kickRemote and kickRemote.Parent then return kickRemote end
        local ok, remote = pcall(function()
            return ReplicatedStorage
                :WaitForChild("Shared",        10)
                :WaitForChild("Packages",      10)
                :WaitForChild("Network",       10)
                :WaitForChild("rev_KickEvent", 10)
        end)
        if ok and remote then kickRemote = remote end
        return kickRemote
    end

    local function fireKick()
        local remote = getKickRemote()
        if not remote then return false end
        pcall(function() remote:FireServer(1, 1) end)
        return true
    end

    local function findKickReady()
        local areas = workspace:FindFirstChild("Areas")
        local obj   = areas and areas:FindFirstChild("KickReady")
        if not obj then obj = workspace:FindFirstChild("KickReady", true) end
        return obj
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

    local function tpToKickReady()
        local char = LocalPlayer.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return false end
        local cf = getObjCFrame(findKickReady())
        if not cf then return false end
        hrp.CFrame = cf + Vector3.new(0, 3, 0)
        return true
    end

    local function walkToPos(targetPos, maxTime, checkFn)
        maxTime = maxTime or 60
        local start = tick()
        while (tick() - start) < maxTime do
            if checkFn and not checkFn() then return false end
            local char     = LocalPlayer.Character
            local hrp      = char and char:FindFirstChild("HumanoidRootPart")
            local humanoid = char and char:FindFirstChildOfClass("Humanoid")
            if not hrp or not humanoid then task.wait(0.3) continue end
            if (hrp.Position - targetPos).Magnitude < 12 then return true end
            humanoid:MoveTo(targetPos)
            task.wait(0.8)
        end
        return false
    end

    local function walkToKickReady(maxTime, checkFn)
        local cf = getObjCFrame(findKickReady())
        if not cf then return false end
        return walkToPos(cf.Position, maxTime, checkFn)
    end

    -- ================================================================
    -- COLLECT-KOORDINATION
    -- ================================================================
    local function waitForCollect()
        if not _G.__DJ_CollectBusy then return end
        print("[AUTO KICK] Warte auf Auto Collect...")
        while _G.__DJ_CollectBusy do task.wait(0.5) end
    end

    -- ================================================================
    -- AUTO KICK STATE
    -- ================================================================
    local autoKickEnabled = false
    local kickLegitMode   = false

    -- ================================================================
    -- MUTATION FILTER HANDLER
    -- ================================================================
    local function handleMutationFilter()
        if acceptAll then return true end

        local waveStart = tick()
        while (tick() - waveStart) < 15 do
            if not autoKickEnabled then return true end
            if getActiveWaveFloor() then break end
            task.wait(0.3)
        end

        local waveFloor = getActiveWaveFloor()
        if not waveFloor then return true end

        local debrisStart = tick()
        local mut = nil
        while (tick() - debrisStart) < 5 do
            if not autoKickEnabled then return true end
            mut = getDebrisMutation()
            if mut then break end
            task.wait(0.3)
        end

        if not mut then return true end
        if acceptedMutations[mut] then return true end

        -- Notify ist OK — wird nur einmal pro Skip aufgerufen
        Rayfield:Notify({
            Title    = "Mutation Filter",
            Content  = "Skipping " .. mut .. " — walking into wave.",
            Duration = 3,
        })

        godmodeWasActive = godmodeEnabled
        if godmodeEnabled then
            disableGodmode()
            task.wait(0.3)
        end

        local waveCF = getFloorCFrame(waveFloor)
        if waveCF then
            walkToPos(waveCF.Position, 30, function()
                if not autoKickEnabled then return false end
                local c = LocalPlayer.Character
                local h = c and c:FindFirstChildOfClass("Humanoid")
                if not c or not h or h.Health <= 0 then return false end
                return true
            end)
        end

        local deathStart = tick()
        while (tick() - deathStart) < 10 do
            local c = LocalPlayer.Character
            local h = c and c:FindFirstChildOfClass("Humanoid")
            if not c or not h or h.Health <= 0 then break end
            task.wait(0.05)
        end

        local respawnStart = tick()
        while (tick() - respawnStart) < 15 do
            local c = LocalPlayer.Character
            local h = c and c:FindFirstChildOfClass("Humanoid")
            if c and h and h.Health > 0 then break end
            task.wait(0.05)
        end

        if godmodeWasActive then
            task.wait(0.3)
            enableGodmode()
        end

        task.wait(0.5)
        walkToKickReady(60, function() return autoKickEnabled end)

        return false
    end

    -- ================================================================
    -- HAUPT-LOOP
    -- ================================================================
    local function runKickLoop()
        while autoKickEnabled do
            waitForCollect()
            if not autoKickEnabled then break end

            if kickLegitMode then
                if not walkToKickReady(60, function() return autoKickEnabled end) then
                    print("[AUTO KICK] KickReady nicht gefunden, retry...")
                    task.wait(1)
                    continue
                end
            else
                if not tpToKickReady() then
                    print("[AUTO KICK] KickReady nicht gefunden, retry...")
                    task.wait(2)
                    continue
                end
            end

            task.wait(2)
            if not autoKickEnabled then break end

            fireKick()
            if not autoKickEnabled then break end

            local mutOk = handleMutationFilter()
            if not autoKickEnabled then break end

            if mutOk then
                walkToKickReady(60, function() return autoKickEnabled end)
            end

            waitForCollect()
            task.wait(0.3)
        end
    end

    -- ================================================================
    -- UI — AUTO KICK
    -- ================================================================
    MinigameTab:CreateSection("Auto Kick")

    MinigameTab:CreateParagraph({
        Title   = "How it works",
        Content = "Teleports to KickReady and waits 2 seconds.\n"
                .."Kicks the block, then walks back to KickReady.\n"
                .."Legit Mode: walks the entire route instead of teleporting.\n"
                .."Mutation Filter: walks into the wave to skip unwanted mutations."
    })

    MinigameTab:CreateToggle({
        Name         = "Auto Kick",
        CurrentValue = false,
        Flag         = "MinigameAutoKick",
        Callback     = function(Value)
            autoKickEnabled = Value
            if Value then
                Rayfield:Notify({ Title = "Auto Kick", Content = "Started!", Duration = 3 })
                task.spawn(runKickLoop)
            else
                Rayfield:Notify({ Title = "Auto Kick", Content = "Stopped.", Duration = 3 })
            end
        end,
    })

    MinigameTab:CreateToggle({
        Name         = "Legit Mode (Walk entire route)",
        CurrentValue = false,
        Flag         = "MinigameKickLegit",
        Callback     = function(Value)
            kickLegitMode = Value
            Rayfield:Notify({
                Title   = "Legit Mode",
                Content = Value and "On — walking the entire route." or "Off — teleporting to KickReady.",
                Duration = 2,
            })
        end,
    })

    -- ================================================================
    -- UI — MUTATION FILTER
    -- ================================================================
    MinigameTab:CreateSection("Mutation Filter")

    MinigameTab:CreateDropdown({
        Name            = "Select Mutations",
        Options         = ALL_MUTATIONS,
        CurrentOption   = {"All"},
        MultipleOptions = true,
        Flag            = "MinigameMutationSelect",
        Callback        = function(Options)
            acceptedMutations = {}
            acceptAll         = false

            if type(Options) == "table" then
                for _, mut in ipairs(Options) do
                    if mut == "All" then
                        acceptAll         = true
                        acceptedMutations = {}
                        Rayfield:Notify({ Title = "Mutation Filter", Content = "All mutations accepted.", Duration = 2 })
                        return
                    end
                    acceptedMutations[mut] = true
                end
            end

            if not next(acceptedMutations) then
                acceptAll = true
            else
                local count = 0
                for _ in pairs(acceptedMutations) do count = count + 1 end
                Rayfield:Notify({ Title = "Mutation Filter", Content = count .. " mutation(s) selected.", Duration = 2 })
            end
        end,
    })

    -- ================================================================
    -- UI — GOD MODE
    -- ================================================================
    MinigameTab:CreateSection("God Mode")

    MinigameTab:CreateToggle({
        Name         = "God Mode",
        CurrentValue = false,
        Flag         = "MinigameGodMode",
        Callback     = function(Value)
            if Value then
                enableGodmode()
                Rayfield:Notify({ Title = "God Mode", Content = "Active — you cannot die!", Duration = 4 })
            else
                disableGodmode()
                Rayfield:Notify({ Title = "God Mode", Content = "Disabled.", Duration = 3 })
            end
        end,
    })

    -- ================================================================
    -- UI — LIFTING WEIGHT
    -- ================================================================
    MinigameTab:CreateSection("Lifting Weight")

    MinigameTab:CreateParagraph({
        Title   = "2x Weight Bug",
        Content = "Spams the weight lift remote as fast as possible.\n"
                .."Triggers the 2x weight bug for double progress.\n"
                .."Turn off when done.",
    })

    local weightBugEnabled = false

    local weightRemote = nil
    local function getWeightRemote()
        if weightRemote and weightRemote.Parent then return weightRemote end
        local ok, remote = pcall(function()
            return ReplicatedStorage
                :WaitForChild("Shared",          10)
                :WaitForChild("Packages",        10)
                :WaitForChild("Network",         10)
                :WaitForChild("rev_TaviMishkal", 10)
        end)
        if ok and remote then weightRemote = remote end
        return weightRemote
    end

    local function runWeightBug()
        while weightBugEnabled do
            local remote = getWeightRemote()
            if remote then
                pcall(function() remote:FireServer() end)
            end
            task.wait()
        end
    end

    MinigameTab:CreateToggle({
        Name         = "2x Weight Bug",
        CurrentValue = false,
        Flag         = "MinigameWeightBug",
        Callback     = function(Value)
            weightBugEnabled = Value
            if Value then
                Rayfield:Notify({ Title = "2x Weight Bug", Content = "Active — spamming weight remote!", Duration = 3 })
                task.spawn(runWeightBug)
            else
                Rayfield:Notify({ Title = "2x Weight Bug", Content = "Stopped.", Duration = 3 })
            end
        end,
    })

    -- ================================================================
    -- UI — AUTO CLICK BONUS
    -- Mobile FIX: TouchTap + GuiInset-Korrektur
    -- ================================================================
    MinigameTab:CreateSection("Auto Click Bonus")

    local bonusEnabled = false

    local function runBonusClicker()
        local PlayerGui    = LocalPlayer:WaitForChild("PlayerGui")
        local KickUpgrades = PlayerGui:WaitForChild("KickUpgrades")
        local vim          = game:GetService("VirtualInputManager")
        local GuiService   = game:GetService("GuiService")
        local lastBonusClick = {}

        local function toScreenPos(absPos, absSize)
            local inset = GuiService:GetGuiInset()
            local cx = absPos.X + absSize.X / 2 + inset.X
            local cy = absPos.Y + absSize.Y / 2 + inset.Y
            return cx, cy
        end

        while bonusEnabled do
            for _, obj in ipairs(KickUpgrades:GetChildren()) do
                if not bonusEnabled then break end
                local absSize, absPos
                local ok = pcall(function()
                    if not obj:IsA("ImageButton") then return end
                    if not obj.Visible then return end
                    if not obj.Parent then return end
                    if obj.Name ~= "Bonus" then return end
                    absSize = obj.AbsoluteSize
                    if not absSize then return end
                    if absSize.X < 20 or absSize.Y < 20 then return end
                    local now = tick()
                    if lastBonusClick[obj] and now - lastBonusClick[obj] < 0.5 then return end
                    lastBonusClick[obj] = now
                    absPos = obj.AbsolutePosition
                end)
                if not ok or not absPos or not absSize then continue end
                local cx, cy = toScreenPos(absPos, absSize)
                pcall(function() vim:SendMouseButtonEvent(cx, cy, 0, true,  game, 0) end)
                pcall(function() vim:SendTouchEvent(0, Vector2.new(cx, cy), Enum.UserInputState.Begin, game) end)
                task.wait(0.05)
                pcall(function() vim:SendMouseButtonEvent(cx, cy, 0, false, game, 0) end)
                pcall(function() vim:SendTouchEvent(0, Vector2.new(cx, cy), Enum.UserInputState.End,   game) end)
            end
            task.wait(0.1)
        end
    end

    MinigameTab:CreateToggle({
        Name         = "Auto Click Bonus",
        CurrentValue = false,
        Flag         = "MinigameBonusClicker",
        Callback     = function(Value)
            bonusEnabled = Value
            if Value then
                Rayfield:Notify({ Title = "Auto Click Bonus", Content = "Active — clicking all bonus bubbles!", Duration = 3 })
                task.spawn(runBonusClicker)
            else
                Rayfield:Notify({ Title = "Auto Click Bonus", Content = "Stopped.", Duration = 3 })
            end
        end,
    })

    print("[MINIGAME] Tab loaded")
end
