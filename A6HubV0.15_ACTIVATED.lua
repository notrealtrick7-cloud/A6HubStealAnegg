--[[
    A6 Hub · Steal an Egg v0.15 · Activation Ready
    Patch: Pet Filter cache/throttle + responsive Auto Treadmill ON/OFF
    Discord: https://discord.gg/ZkGwEUGJv

    Tabs: Info · Steal · Filter · Farm · Pets · Event · Player · Visual · Webhook · Server
    Steal style: Select rarity → Steal → TP Lake → Drop → Steal lại (như video CORRA)
    Pet Filter: tên pet + rarity + cấp (Common→Divine) · auto refresh catalog 60s
    14 biomes (+Enchanted Forest 50B) · Wisp/Tree · Treadmill · Plot · Index · Mutation · Scramble · Anti AFK
]]

print("[A6 SAE] Loading A6 Hub · Steal an Egg v0.15 · Activation Ready ...")

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local LP = Players.LocalPlayer
local DISCORD = "https://discord.gg/ZkGwEUGJv"

getgenv().A6SAE = getgenv().A6SAE or {}
local S = getgenv().A6SAE

-- v0.15 compatibility: the uploaded v3 used A6SAEv3.
-- Keep both names pointing to the same state so existing config can activate this build.
getgenv().A6SAEv3 = S

-- defaults
S.AutoSteal = false
S.StealMethod = "LakeDrop" -- LakeDrop | Direct
S.AutoPlace = false
S.AutoHatch = false
S.AutoSell = false
S.AutoMutation = false
S.AutoTreadmill = false
S.AutoUpgradeTreadmill = false
S.AutoUpgradePlot = false
S.AutoIndex = false
S.AutoScramble = false
S.EggESP = false
S.SpeedBoost = false
S.JumpBoost = false
S.InfJump = false
S.AntiRagdoll = false
S.AntiAFK = true
S.WalkSpeed = 28
S.JumpPower = 50
S.StealDelay = 1.2 -- slower loop, less AC flag
S.WebhookURL = S.WebhookURL or ""
S.WebhookOnSteal = false
S.WebhookOnRare = true

-- User-configurable feature priority (1 = highest). These are scheduling priorities,
-- not anti-cheat bypass controls. The user can reorder them from Settings.
S.FeaturePriority = S.FeaturePriority or {
    "Steal Egg Selected",
    "Auto Dr Scramble",
    "Auto Place After Steal",
    "Auto Hatch Egg",
    "Auto Steal Egg Miss In Index",
    "Auto Farm Speed",
}
S.FeaturePriorityKey = {
    ["Steal Egg Selected"] = "AutoSteal",
    ["Auto Dr Scramble"] = "AutoScramble",
    ["Auto Place After Steal"] = "AutoPlace",
    ["Auto Hatch Egg"] = "AutoHatch",
    ["Auto Steal Egg Miss In Index"] = "AutoIndex",
    ["Auto Farm Speed"] = "AutoTreadmill",
}
S.FeaturePriorityInterval = {
    AutoSteal = 1.2,
    AutoScramble = 1.5,
    AutoPlace = 1.5,
    AutoHatch = 1.5,
    AutoIndex = 1.5,
    AutoTreadmill = 0.5,
}

-- rarities Common → Divine (+ tier index)
S.Rarities = {"Common","Uncommon","Rare","Epic","Legendary","Mythic","Cosmic","Secret","Eternal","Divine"}
S.RarityTier = {
    Common=1, Uncommon=2, Rare=3, Epic=4, Legendary=5,
    Mythic=6, Cosmic=7, Secret=8, Eternal=9, Divine=10
}
S.MinTier = 5 -- Legendary+
S.MaxTier = 10
S.WhitelistRarity = {}
S.BlacklistRarity = {}
for _, r in ipairs(S.Rarities) do
    S.WhitelistRarity[r] = (S.RarityTier[r] or 0) >= S.MinTier
    S.BlacklistRarity[r] = false
end
-- Pet name filter (case-insensitive keys)
S.PetWhitelist = {} -- [petNameLower] = true → chỉ cướp pet này
S.PetBlacklist = {} -- [petNameLower] = true → chặn pet này
S.UsePetNameFilter = false -- bật khi có ít nhất 1 WL pet
S.FilterMode = "Rarity" -- Rarity | Pet | Both
S.PetCatalog = {} -- filled below + optional remote refresh
S.PetCatalogUrl = S.PetCatalogUrl or "" -- optional raw JSON url cập nhật 60s
S.LastCatalogRefresh = 0

-- Local catalog (name, rarity, biome) — refreshable
local function seedCatalog()
    local list = {
        -- Forest
        {n="Chicken", r="Common", b="Forest"}, {n="Dog", r="Common", b="Forest"},
        {n="Bird", r="Uncommon", b="Forest"}, {n="Owl", r="Rare", b="Forest"},
        {n="Raccoon", r="Epic", b="Forest"}, {n="Fox", r="Epic", b="Forest"},
        {n="Bear", r="Legendary", b="Forest"}, {n="Brr Brr Patapim", r="Legendary", b="Forest"},
        -- Lake
        {n="Frog", r="Common", b="Lake"}, {n="Duckling", r="Common", b="Lake"},
        {n="Catfish", r="Uncommon", b="Lake"}, {n="Turtle", r="Rare", b="Lake"},
        {n="Trulimero Trulicina", r="Epic", b="Lake"}, {n="Swan", r="Epic", b="Lake"},
        {n="Axolotl", r="Legendary", b="Lake"}, {n="Leviathan", r="Cosmic", b="Lake"},
        -- Desert
        {n="Jerboa", r="Common", b="Desert"}, {n="Fennec", r="Uncommon", b="Desert"},
        {n="Camel", r="Rare", b="Desert"}, {n="Snake", r="Epic", b="Desert"},
        {n="Scorpion", r="Legendary", b="Desert"}, {n="Royal Sphinx", r="Cosmic", b="Desert"},
        -- Jungle
        {n="Toucan", r="Common", b="Jungle"}, {n="Chimpanzee", r="Uncommon", b="Jungle"},
        {n="Crocodile", r="Rare", b="Jungle"}, {n="Tiger", r="Legendary", b="Jungle"},
        {n="King Snake", r="Mythic", b="Jungle"},
        -- Snow
        {n="Penguin", r="Common", b="Snow"}, {n="Walrus", r="Uncommon", b="Snow"},
        {n="Polar Bear", r="Rare", b="Snow"}, {n="Yeti", r="Legendary", b="Snow"},
        {n="Ice Dragon", r="Mythic", b="Snow"},
        -- Volcano
        {n="Lava Gecko", r="Common", b="Volcano"}, {n="Flaming Bull", r="Epic", b="Volcano"},
        {n="Cerberus", r="Mythic", b="Volcano"}, {n="Lava Dragon", r="Cosmic", b="Volcano"},
        -- Abyss
        {n="Moby", r="Legendary", b="Abyss Ocean"}, {n="El Maja", r="Cosmic", b="Abyss Ocean"},
        -- Prehistoric
        {n="T-Rex", r="Mythic", b="Prehistoric"}, {n="Mosasaurus", r="Cosmic", b="Prehistoric"},
        -- Cosmic
        {n="Cosmic Gecko", r="Legendary", b="Cosmic"}, {n="Cosmic Dragon", r="Secret", b="Cosmic"},
        {n="Unicorn", r="Divine", b="Cosmic"},
        -- Cherry
        {n="Kitsune", r="Divine", b="Cherry Blossom"}, {n="Oni Tiger", r="Eternal", b="Cherry Blossom"},
        -- Titan
        {n="Nightflame", r="Divine", b="Titan Temple"}, {n="Gorilla King", r="Eternal", b="Titan Temple"},
        -- Angels/Demons
        {n="ArchAngel", r="Divine", b="Angels vs Demons"}, {n="World Burner", r="Divine", b="Angels vs Demons"},
        {n="Pegasus", r="Eternal", b="Angels vs Demons"},
        -- Enchanted Forest
        {n="Prism Gecko", r="Common", b="Enchanted Forest"},
        {n="Petal Beetle", r="Uncommon", b="Enchanted Forest"},
        {n="Enchanted Bluejay", r="Rare", b="Enchanted Forest"},
        {n="Astral Jackalope", r="Epic", b="Enchanted Forest"},
        {n="Spirit Panda", r="Legendary", b="Enchanted Forest"},
        {n="Starry Fox", r="Mythic", b="Enchanted Forest"},
        {n="Celestial Sunlion", r="Secret", b="Enchanted Forest"},
        {n="Royal Skywhale", r="Divine", b="Enchanted Forest"},
        -- Mythic list (hub filter style)
        {n="Winged Lamb", r="Mythic", b="?"},
        {n="Toro", r="Mythic", b="?"},
        {n="Bladehide", r="Mythic", b="?"},
        {n="Red Panda", r="Mythic", b="?"},
        {n="Cosmic Gorilla", r="Mythic", b="?"},
        {n="Ankylosaurus", r="Mythic", b="Prehistoric"},
        {n="Nightflame", r="Divine", b="Titan Temple"},
        {n="Pegasus", r="Eternal", b="Angels vs Demons"},
        {n="Unicorn", r="Divine", b="Cosmic"},
        {n="Kitsune", r="Divine", b="Cherry Blossom"},
        {n="Leviathan", r="Cosmic", b="Lake"},
        {n="Ice Dragon", r="Mythic", b="Snow"},
        {n="Lava Dragon", r="Cosmic", b="Volcano"},
        {n="King Snake", r="Mythic", b="Jungle"},
        {n="Cerberus", r="Mythic", b="Volcano"},
        {n="Mosasaurus", r="Cosmic", b="Prehistoric"},
        {n="Cosmic Dragon", r="Secret", b="Cosmic"},
        {n="Oni Tiger", r="Eternal", b="Cherry Blossom"},
        {n="Gorilla King", r="Eternal", b="Titan Temple"},
        {n="ArchAngel", r="Divine", b="Angels vs Demons"},
        {n="World Burner", r="Divine", b="Angels vs Demons"},
        {n="Celestial Sunlion", r="Secret", b="Enchanted Forest"},
        {n="Starry Fox", r="Mythic", b="Enchanted Forest"},
        {n="Spirit Panda", r="Legendary", b="Enchanted Forest"},
    }
    S.PetCatalog = list
end
seedCatalog()

-- 13 biomes (order)
S.Biomes = {
    {name="Forest", speed=0, guardian="Chicken"},
    {name="Lake", speed=900, guardian="Swan"},
    {name="Desert", speed=10000, guardian="Scorpion"},
    {name="Jungle", speed=40000, guardian="Tiger"},
    {name="Snow", speed=170000, guardian="Yeti"},
    {name="Volcano", speed=700000, guardian="Cerberus"},
    {name="Abyss Ocean", speed=2500000, guardian="Moby"},
    {name="Prehistoric", speed=18000000, guardian="T-Rex"},
    {name="Cosmic", speed=700000000, guardian="Cosmic Skeleton"},
    {name="Cherry Blossom", speed=2500000000, guardian="Oni Tiger"},
    {name="Titan Temple", speed=7000000000, guardian="Gorilla King"},
    {name="Angels vs Demons", speed=20000000000, guardian="ArchAngel / World Burner"},
    {name="Enchanted Forest", speed=50000000000, guardian="Celestial Sunlion"}, -- Update 7 · 50B
}

local function notify(t)
    pcall(function()
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title = "A6 Hub · SAE",
            Text = tostring(t),
            Duration = 3,
        })
    end)
end

local function hrp()
    local c = LP.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

local function humanoid()
    local c = LP.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end

local function firePrompt(prompt)
    if not prompt then return end
    pcall(function()
        if fireproximityprompt then
            fireproximityprompt(prompt)
        else
            prompt:InputHoldBegin()
            task.wait(0.05)
            prompt:InputHoldEnd()
        end
    end)
end

-- Movement: natural run (anti-cheat safe). No hard CFrame spam.
S.MoveStyle = S.MoveStyle or "SoftTween" -- SoftTween (tele nhe) | Walk
S.StealWalkSpeed = S.StealWalkSpeed or 32
S.TweenSpeed = S.TweenSpeed or 55 -- tele nhe, khong spam 100+

local function stopMove()
    local hum = humanoid()
    if hum then
        pcall(function() hum:Move(Vector3.zero) end)
        pcall(function() hum:MoveTo(hrp() and hrp().Position or Vector3.zero) end)
    end
end

local function walkTo(pos, timeout)
    local root = hrp()
    local hum = humanoid()
    if not root or not hum then return false end
    timeout = timeout or 12
    local goal = typeof(pos) == "CFrame" and pos.Position or pos
    goal = Vector3.new(goal.X, root.Position.Y, goal.Z) -- keep Y stable (no fly)
    pcall(function()
        hum.WalkSpeed = math.clamp(S.StealWalkSpeed or 28, 16, 80)
        hum:MoveTo(goal)
    end)
    local t0 = tick()
    while tick() - t0 < timeout do
        root = hrp()
        if not root then return false end
        local d = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(goal.X, 0, goal.Z)).Magnitude
        if d < 6 then
            stopMove()
            return true
        end
        -- re-issue MoveTo if stuck
        if tick() - t0 > 2 and d > 12 then
            pcall(function() hum:MoveTo(goal) end)
        end
        task.wait(0.15)
    end
    stopMove()
    return false
end

local function softTweenTo(cf, speed)
    local root = hrp()
    if not root then return end
    speed = math.clamp(speed or (S.TweenSpeed or 55), 30, 85)
    local targetPos
    if typeof(cf) == "CFrame" then
        targetPos = Vector3.new(cf.X, root.Position.Y + 1.5, cf.Z)
    else
        targetPos = Vector3.new(cf.X, root.Position.Y + 1.5, cf.Z)
    end
    local dist = (root.Position - targetPos).Magnitude
    if dist < 4 then return end
    local t = math.clamp(dist / speed, 0.25, 6)
    local goal = CFrame.new(targetPos.X, targetPos.Y, targetPos.Z)
    local tw = TweenService:Create(root, TweenInfo.new(t, Enum.EasingStyle.Linear), {CFrame = goal})
    tw:Play()
    local done = false
    tw.Completed:Connect(function() done = true end)
    local t0 = tick()
    while not done and tick() - t0 < t + 0.5 do
        task.wait(0.05)
        if not hrp() then break end
    end
end

local function tweenTo(cf, speed)
    if S.MoveStyle == "Walk" then
        local pos = typeof(cf) == "CFrame" and cf.Position or cf
        walkTo(pos, 14)
    else
        softTweenTo(cf, speed or S.TweenSpeed or 55)
    end
end

local function webhook(title, desc, color)
    if not S.WebhookURL or S.WebhookURL == "" then return end
    pcall(function()
        local payload = HttpService:JSONEncode({
            embeds = {{
                title = title,
                description = desc,
                color = color or 65280,
                footer = {text = "A6 Hub · Steal an Egg"},
                timestamp = os.date("!%Y-%m-%dT%H:%M:%SZ"),
            }}
        })
        if syn and syn.request then
            syn.request({Url=S.WebhookURL, Method="POST", Headers={["Content-Type"]="application/json"}, Body=payload})
        elseif request then
            request({Url=S.WebhookURL, Method="POST", Headers={["Content-Type"]="application/json"}, Body=payload})
        elseif http_request then
            http_request({Url=S.WebhookURL, Method="POST", Headers={["Content-Type"]="application/json"}, Body=payload})
        else
            -- fallback HttpService may block
            pcall(function() HttpService:PostAsync(S.WebhookURL, payload) end)
        end
    end)
end

-- rarity detect from name/attributes
local PetDetectCache = setmetatable({}, {__mode = "k"})
local PET_CACHE_TTL = 2.0

local function detectRarity(inst)
    if not inst then return "Common" end
    local now = tick()
    local cached = PetDetectCache[inst]
    if cached and now - cached.t < PET_CACHE_TTL and cached.r then return cached.r end
    local text = (inst.Name or "")
    local a = inst:GetAttribute("Rarity") or inst:GetAttribute("rarity")
    if a then text = text .. " " .. tostring(a) end
    for _, d in ipairs(inst:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("StringValue") then text = text .. " " .. tostring(d.Text or d.Value or "") end
    end
    text = text:lower()
    local order = {"divine","eternal","secret","cosmic","mythic","legendary","epic","rare","uncommon","common"}
    local map = {divine="Divine",eternal="Eternal",secret="Secret",cosmic="Cosmic",mythic="Mythic",legendary="Legendary",epic="Epic",rare="Rare",uncommon="Uncommon",common="Common"}
    local result = "Common"
    for _, k in ipairs(order) do if text:find(k,1,true) then result=map[k]; break end end
    cached = cached or {}; cached.t=now; cached.r=result; PetDetectCache[inst]=cached
    return result
end

local function detectPetName(inst)
    if not inst then return nil end
    local now = tick()
    local cached = PetDetectCache[inst]
    if cached and now - cached.t < PET_CACHE_TTL and cached.pet ~= nil then return cached.pet or nil end
    local text = tostring(inst.Name or "")
    local a,b = inst:GetAttribute("PetName"), inst:GetAttribute("Name")
    if a then text=text.." "..tostring(a) end
    if b then text=text.." "..tostring(b) end
    for _, d in ipairs(inst:GetDescendants()) do
        if d:IsA("TextLabel") or d:IsA("StringValue") then text=text.." "..tostring(d.Text or d.Value or "") end
    end
    text=text:lower()
    local best,bestLen=nil,0
    for _, pet in ipairs(S.PetCatalog) do
        local key=pet.n:lower()
        if #key>bestLen and text:find(key,1,true) then best,bestLen=pet.n,#key end
    end
    cached=cached or {}; cached.t=now; cached.pet=best or false; PetDetectCache[inst]=cached
    return best
end

local function isAllowed(rarity, petName)
    rarity = rarity or "Common"
    local tier = S.RarityTier[rarity] or 1
    -- blacklist rarity always wins
    if S.BlacklistRarity[rarity] then return false end
    -- pet name blacklist
    if petName and S.PetBlacklist[petName:lower()] then return false end
    local mode = S.FilterMode or "Rarity"
    if mode == "Pet" or mode == "Both" then
        local anyPet = false
        for _, v in pairs(S.PetWhitelist) do if v then anyPet = true break end end
        if anyPet then
            if not petName or not S.PetWhitelist[petName:lower()] then
                if mode == "Pet" then return false end
            else
                return true
            end
        end
    end
    if mode == "Rarity" or mode == "Both" then
        if S.WhitelistRarity[rarity] then return true end
        if tier >= (S.MinTier or 1) and tier <= (S.MaxTier or 10) then
            local anyR = false
            for _, v in pairs(S.WhitelistRarity) do if v then anyR = true break end end
            if not anyR then return true end
        end
        return S.WhitelistRarity[rarity] == true
    end
    return true
end

local EggPromptCache = {t=0, list={}}
local EGG_SCAN_TTL = 0.8
local function collectEggPrompts(force)
    local now=tick()
    if not force and now-EggPromptCache.t<EGG_SCAN_TTL then return EggPromptCache.list end
    local list={}
    for _,v in ipairs(workspace:GetDescendants()) do
        if v:IsA("ProximityPrompt") then
            local n=(v.Name.." "..(v.Parent and v.Parent.Name or "")):lower()
            if n:find("egg",1,true) or n:find("steal",1,true) or n:find("grab",1,true) or n:find("pick",1,true) or n:find("take",1,true) then
                local obj=v.Parent or v
                table.insert(list,{prompt=v,rarity=detectRarity(obj),parent=v.Parent,pet=detectPetName(obj)})
            end
        end
    end
    EggPromptCache.t=now; EggPromptCache.list=list
    return list
end

local function nearestAllowedEgg()
    local root = hrp()
    if not root then return nil end
    local best, dist = nil, math.huge
    for _, e in ipairs(collectEggPrompts()) do
        if isAllowed(e.rarity, e.pet) then
            local part = e.parent
            local pos
            if part and part:IsA("BasePart") then pos = part.Position
            elseif part and part:IsA("Model") then
                local pp = part.PrimaryPart or part:FindFirstChildWhichIsA("BasePart")
                if pp then pos = pp.Position end
            end
            if pos then
                local d = (pos - root.Position).Magnitude
                if d < dist then best, dist = e, d end
            end
        end
    end
    return best, dist
end

local function findBiomePart(name)
    for _, v in ipairs(workspace:GetDescendants()) do
        if v.Name:lower():find(name:lower()) and (v:IsA("BasePart") or v:IsA("Model")) then
            if v:IsA("BasePart") then return v end
            local p = v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart")
            if p then return p end
        end
    end
    return nil
end

local function tpLake()
    local lake = findBiomePart("Lake") or findBiomePart("lake") or findBiomePart("SAFE")
    local root = hrp()
    if lake and root then
        tweenTo(CFrame.new(lake.Position.X, root.Position.Y, lake.Position.Z), S.TweenSpeed or 55)
        return true
    end
    if root then
        tweenTo(root.CFrame * CFrame.new(0, 0, -80), S.TweenSpeed or 55)
    end
    return false
end

local function tpBase()
    for _, name in ipairs({"Base","Plot","Home","Pen","Spawn","BasePlot","SafeZone","SAFE"}) do
        local o = workspace:FindFirstChild(name, true)
        if o then
            local part = o:IsA("BasePart") and o or o:FindFirstChildWhichIsA("BasePart", true)
            if part then
                local root = hrp()
                if root then
                    tweenTo(CFrame.new(part.Position.X, root.Position.Y, part.Position.Z), S.TweenSpeed or 55)
                end
                return
            end
        end
    end
end

local function dropEgg()
    -- try drop key / remote / tool deactivate
    pcall(function()
        local hum = humanoid()
        if hum then hum:UnequipTools() end
    end)
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true, Enum.KeyCode.Q, false, game)
        task.wait(0.05)
        vim:SendKeyEvent(false, Enum.KeyCode.Q, false, game)
        vim:SendKeyEvent(true, Enum.KeyCode.Backspace, false, game)
        task.wait(0.05)
        vim:SendKeyEvent(false, Enum.KeyCode.Backspace, false, game)
    end)
    for _, r in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
        if r:IsA("RemoteEvent") then
            local n = r.Name:lower()
            if n:find("drop") or n:find("unequip") or n:find("throw") then
                pcall(function() r:FireServer() end)
            end
        end
    end
end

local function doStealOnce()
    if S._Stealing then return false end
    S._Stealing = true
    local ok, err = pcall(function()
        local egg, dist = nearestAllowedEgg()
        if not egg then
            notify("No whitelist egg nearby")
            return
        end
        local part = egg.parent
        local cf
        if part:IsA("BasePart") then cf = part.CFrame
        elseif part:IsA("Model") then
            local pp = part.PrimaryPart or part:FindFirstChildWhichIsA("BasePart")
            if pp then cf = pp.CFrame end
        end
        if not cf then return end

        -- Soft tele toi egg (toc do vua, giong video hub)
        local root = hrp()
        local stand = CFrame.new(cf.X, (root and root.Position.Y or cf.Y), cf.Z)
        tweenTo(stand, S.TweenSpeed or 55)
        task.wait(0.2 + math.random() * 0.15)
        firePrompt(egg.prompt)
        notify("Steal " .. (egg.pet or egg.rarity))
        if S.WebhookOnSteal or (S.WebhookOnRare and (egg.rarity == "Secret" or egg.rarity == "Eternal" or egg.rarity == "Divine")) then
            webhook("Egg Stolen", "**Rarity:** " .. egg.rarity .. "\n**Player:** " .. LP.Name, 3066993)
        end
        task.wait(0.3)

        if S.StealMethod == "LakeDrop" then
            -- tele nhe ve huong Lake / SAFE roi Drop, roi cuop lai
            local lake = findBiomePart("Lake") or findBiomePart("lake") or findBiomePart("SAFE")
            if lake then
                tweenTo(CFrame.new(lake.Position.X, (hrp() and hrp().Position.Y or lake.Position.Y), lake.Position.Z), S.TweenSpeed or 55)
            else
                local r = hrp()
                if r then
                    tweenTo(r.CFrame * CFrame.new(0, 0, -60), S.TweenSpeed or 55)
                end
            end
            task.wait(0.25)
            dropEgg()
            task.wait(0.35)
            -- cuop lai egg gan nhat (video style)
            local egg2 = nearestAllowedEgg()
            if egg2 and egg2.parent then
                local p2 = egg2.parent
                local cf2 = p2:IsA("BasePart") and p2.CFrame or (p2.PrimaryPart and p2.PrimaryPart.CFrame)
                if not cf2 then
                    local bp = p2:FindFirstChildWhichIsA("BasePart")
                    if bp then cf2 = bp.CFrame end
                end
                if cf2 then
                    local r2 = hrp()
                    tweenTo(CFrame.new(cf2.X, r2 and r2.Position.Y or cf2.Y, cf2.Z), S.TweenSpeed or 55)
                    task.wait(0.2)
                    firePrompt(egg2.prompt)
                    notify("Steal lai " .. (egg2.pet or egg2.rarity))
                end
            end
        elseif S.StealMethod == "Direct" then
            if S.AutoPlace then
                for _, name in ipairs({"Base","Plot","Home","Pen","Spawn","BasePlot","SafeZone","SAFE"}) do
                    local o = workspace:FindFirstChild(name, true)
                    if o then
                        local part = o:IsA("BasePart") and o or o:FindFirstChildWhichIsA("BasePart", true)
                        if part then
                            local r = hrp()
                            tweenTo(CFrame.new(part.Position.X, r and r.Position.Y or part.Position.Y, part.Position.Z), S.TweenSpeed or 55)
                            break
                        end
                    end
                end
                task.wait(0.25)
                tryPlace()
            end
        end

        if S.AutoPlace and S.StealMethod == "LakeDrop" then
            task.wait(0.2)
            for _, name in ipairs({"Base","Plot","Home","Pen","Spawn","BasePlot","SafeZone","SAFE"}) do
                local o = workspace:FindFirstChild(name, true)
                if o then
                    local part = o:IsA("BasePart") and o or o:FindFirstChildWhichIsA("BasePart", true)
                    if part then
                        local r = hrp()
                        tweenTo(CFrame.new(part.Position.X, r and r.Position.Y or part.Position.Y, part.Position.Z), S.TweenSpeed or 55)
                        break
                    end
                end
            end
            task.wait(0.25)
            tryPlace()
        end
    end)
    S._Stealing = false
    if not ok then warn("[A6 SAE] steal err:", err) end
    return true
end

function tryPlace()
    for _, p in ipairs(workspace:GetDescendants()) do
        if p:IsA("ProximityPrompt") then
            local n = (p.Name .. " " .. (p.Parent and p.Parent.Name or "")):lower()
            if n:find("place") or n:find("pen") or n:find("insert") or n:find("put") then
                firePrompt(p)
            end
        end
    end
end

function tryHatch()
    for _, p in ipairs(workspace:GetDescendants()) do
        if p:IsA("ProximityPrompt") then
            local n = (p.Name .. " " .. (p.Parent and p.Parent.Name or "")):lower()
            if n:find("hatch") or n:find("open") then
                firePrompt(p)
            end
        end
    end
end

function trySell()
    for _, p in ipairs(workspace:GetDescendants()) do
        if p:IsA("ProximityPrompt") then
            local n = (p.Name .. " " .. (p.Parent and p.Parent.Name or "")):lower()
            if n:find("sell") then firePrompt(p) end
        end
    end
    pcall(function()
        for _, r in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
            if (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) and r.Name:lower():find("sell") then
                pcall(function()
                    if r:IsA("RemoteEvent") then r:FireServer() else r:InvokeServer() end
                end)
            end
        end
    end)
end

function tryMutation()
    -- Scrambled / mutation consumables
    for _, t in ipairs(LP.Backpack:GetChildren()) do
        local n = t.Name:lower()
        if n:find("scramble") or n:find("mutation") or n:find("mutate") or n:find("serum") or n:find("enchant") then
            pcall(function()
                humanoid():EquipTool(t)
                task.wait(0.1)
                t:Activate()
            end)
        end
    end
    for _, p in ipairs(workspace:GetDescendants()) do
        if p:IsA("ProximityPrompt") then
            local n = (p.Name .. " " .. (p.Parent and p.Parent.Name or "")):lower()
            if n:find("mutat") or n:find("scramble") or n:find("apply") then
                firePrompt(p)
            end
        end
    end
end

function farmTreadmill()
    if not S.AutoTreadmill or S._Stealing then stopMove(); return false end
    local root,hum=hrp(),humanoid(); if not root or not hum then return false end
    local tm,bestDist=nil,math.huge
    for _,v in ipairs(workspace:GetDescendants()) do
        local n=v.Name:lower()
        if n:find("treadmill",1,true) or n:find("tread",1,true) or n:find("runner",1,true) then
            local part=v:IsA("BasePart") and v or (v:IsA("Model") and (v.PrimaryPart or v:FindFirstChildWhichIsA("BasePart")))
            if part then local d=(part.Position-root.Position).Magnitude; if d<bestDist then tm,bestDist=part,d end end
        end
    end
    if not tm then return false end
    if bestDist>10 then
        pcall(function() hum.WalkSpeed=math.clamp(S.StealWalkSpeed or 28,16,60); hum:MoveTo(tm.Position) end)
    elseif S.AutoTreadmill and not S._Stealing then
        pcall(function() hum.WalkSpeed=math.max(hum.WalkSpeed,20); hum:Move(Vector3.new(1,0,0),true) end)
    end
    return true
end

function upgradeTreadmill()
    for _, p in ipairs(workspace:GetDescendants()) do
        if p:IsA("ProximityPrompt") then
            local n = (p.Name .. " " .. (p.Parent and p.Parent.Name or "")):lower()
            if (n:find("treadmill") or n:find("tread")) and (n:find("upgrade") or n:find("buy") or n:find("level")) then
                firePrompt(p)
            end
        end
    end
    pcall(function()
        for _, r in ipairs(game:GetService("ReplicatedStorage"):GetDescendants()) do
            if (r:IsA("RemoteEvent") or r:IsA("RemoteFunction")) then
                local n = r.Name:lower()
                if n:find("treadmill") and (n:find("upgrade") or n:find("buy")) then
                    pcall(function()
                        if r:IsA("RemoteEvent") then r:FireServer() else r:InvokeServer() end
                    end)
                end
            end
        end
    end)
end

function upgradePlot()
    for _, p in ipairs(workspace:GetDescendants()) do
        if p:IsA("ProximityPrompt") then
            local n = (p.Name .. " " .. (p.Parent and p.Parent.Name or "")):lower()
            if (n:find("plot") or n:find("pen") or n:find("base")) and (n:find("upgrade") or n:find("buy")) then
                firePrompt(p)
            end
        end
    end
end

function farmIndexMissing()
    -- steal any allowed egg to fill index — same as auto steal with broad whitelist tip
    notify("Index farm: dang steal egg whitelist de fill pet thieu")
    doStealOnce()
end

function doScrambleEvent()
    -- hit drones / bat
    for _, m in ipairs(workspace:GetDescendants()) do
        local n = m.Name:lower()
        if n:find("drone") or n:find("scramble") or n:find("sample") then
            local part = m:IsA("BasePart") and m or m:FindFirstChildWhichIsA("BasePart")
            if part then
                tweenTo(part.CFrame + Vector3.new(0, 2, 0), 120)
                -- click / bat
                pcall(function()
                    local vu = VirtualUser
                    vu:CaptureController()
                    vu:ClickButton1(Vector2.new(0,0))
                end)
                for _, p in ipairs(m:GetDescendants()) do
                    if p:IsA("ProximityPrompt") then firePrompt(p) end
                end
            end
        end
    end
    notify("Scramble pass done")
end

-- loops
task.spawn(function()
    while task.wait(S.StealDelay or 1.2) do
        if S.AutoSteal and not S._Stealing then
            pcall(doStealOnce)
        end
    end
end)

-- Priority scheduler for the six user-configurable features.
-- Uses weighted waiting time so a high-priority feature gets serviced first,
-- while enabled lower-priority features are still given turns (no starvation).
local _prioLastRun = {}
local function _priorityIndex(label)
    for i, v in ipairs(S.FeaturePriority or {}) do
        if v == label then return i end
    end
    return 99
end

local function _priorityEnabled(label)
    local key = S.FeaturePriorityKey[label]
    return key and S[key] == true
end

local function _runPriorityFeature(label)
    local key = S.FeaturePriorityKey[label]
    if not key then return end
    if key == "AutoSteal" then
        if not S._Stealing then pcall(doStealOnce) end
    elseif key == "AutoScramble" then
        pcall(doScrambleEvent)
    elseif key == "AutoPlace" then
        pcall(tryPlace)
    elseif key == "AutoHatch" then
        pcall(tryHatch)
    elseif key == "AutoIndex" then
        pcall(farmIndexMissing)
    elseif key == "AutoTreadmill" then
        if S.AutoTreadmill and not S._Stealing then
            pcall(farmTreadmill)
        else
            stopMove()
        end
    end
    _prioLastRun[key] = os.clock()
end

task.spawn(function()
    while task.wait(0.2) do
        local now = os.clock()
        local bestLabel, bestScore = nil, -math.huge
        for _, label in ipairs(S.FeaturePriority or {}) do
            local key = S.FeaturePriorityKey[label]
            if key and _priorityEnabled(label) then
                local interval = S.FeaturePriorityInterval[key] or 1.5
                local last = _prioLastRun[key] or 0
                local age = now - last
                if age >= interval then
                    -- Smaller rank = higher priority; waiting time prevents starvation.
                    local rank = _priorityIndex(label)
                    local score = age * 10 - rank
                    if score > bestScore then
                        bestScore, bestLabel = score, label
                    end
                end
            end
        end
        if bestLabel then
            _runPriorityFeature(bestLabel)
        end

        -- Other independent automations keep their existing loop.
        if S.AutoSell then pcall(trySell) end
        if S.AutoMutation then pcall(tryMutation) end
        if S.AutoUpgradeTreadmill then pcall(upgradeTreadmill) end
        if S.AutoUpgradePlot then pcall(upgradePlot) end
    end
end)

task.spawn(function()
    while task.wait(0.2) do
        local hum = humanoid()
        if hum then
            if S.SpeedBoost then pcall(function() hum.WalkSpeed = S.WalkSpeed end) end
            if S.JumpBoost then pcall(function() hum.JumpPower = S.JumpPower; hum.UseJumpPower = true end) end
        end
        if S.AntiRagdoll then
            pcall(function()
                local c = LP.Character
                if not c then return end
                local h = c:FindFirstChildOfClass("Humanoid")
                if h and h:GetState() == Enum.HumanoidStateType.Physics then
                    h:ChangeState(Enum.HumanoidStateType.Running)
                end
            end)
        end
    end
end)

-- Anti AFK
task.spawn(function()
    while task.wait(30) do
        if S.AntiAFK then
            pcall(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end
end)

UIS.JumpRequest:Connect(function()
    if S.InfJump then
        local hum = humanoid()
        if hum then hum:ChangeState(Enum.HumanoidStateType.Jumping) end
    end
end)

-- ESP
local espFolder = Instance.new("Folder")
espFolder.Name = "A6SAE_ESP"
espFolder.Parent = game.CoreGui

task.spawn(function()
    while task.wait(1.5) do
        for _, c in ipairs(espFolder:GetChildren()) do c:Destroy() end
        if not S.EggESP then continue end
        for _, e in ipairs(collectEggPrompts()) do
            local part = e.parent and (e.parent:IsA("BasePart") and e.parent or e.parent:FindFirstChildWhichIsA("BasePart"))
            if part then
                local bb = Instance.new("BillboardGui")
                bb.Size = UDim2.new(0, 140, 0, 32)
                bb.AlwaysOnTop = true
                bb.Adornee = part
                bb.Parent = espFolder
                local tl = Instance.new("TextLabel", bb)
                tl.Size = UDim2.new(1,0,1,0)
                tl.BackgroundTransparency = 1
                local ok = isAllowed(e.rarity, e.pet)
                local label = (e.pet and (e.pet .. " · ") or "") .. e.rarity
                tl.Text = label .. (ok and " ✓" or " ✗")
                tl.TextColor3 = ok and Color3.fromRGB(80,255,120) or Color3.fromRGB(255,100,100)
                tl.Font = Enum.Font.GothamBold
                tl.TextSize = 12
                tl.TextStrokeTransparency = 0.4
            end
        end
    end
end)

-- UI
local function build()
    local sg = Instance.new("ScreenGui")
    sg.Name = "A6HubSAE"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    pcall(function() sg.Parent = game:GetService("CoreGui") end)
    if not sg.Parent then sg.Parent = LP:WaitForChild("PlayerGui") end

    -- floating open button (small)
    local openBtn = Instance.new("TextButton")
    openBtn.Name = "A6Open"
    openBtn.Parent = sg
    openBtn.Size = UDim2.new(0, 44, 0, 44)
    openBtn.Position = UDim2.new(0, 12, 0.4, 0)
    openBtn.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
    openBtn.Text = "A6"
    openBtn.Font = Enum.Font.GothamBold
    openBtn.TextSize = 14
    openBtn.TextColor3 = Color3.fromRGB(0, 220, 180)
    openBtn.AutoButtonColor = true
    Instance.new("UICorner", openBtn).CornerRadius = UDim.new(0, 10)
    local os2 = Instance.new("UIStroke", openBtn)
    os2.Color = Color3.fromRGB(0, 180, 150)
    os2.Thickness = 1.2

    -- main panel (compact like screenshot ~320x380)
    local main = Instance.new("Frame")
    main.Name = "Main"
    main.Parent = sg
    main.Size = UDim2.new(0, 320, 0, 390)
    main.Position = UDim2.new(0.5, -160, 0.5, -195)
    main.BackgroundColor3 = Color3.fromRGB(22, 24, 28)
    main.BackgroundTransparency = 0.08
    main.Visible = true
    main.Active = true
    main.Draggable = true
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)
    local stroke = Instance.new("UIStroke", main)
    stroke.Color = Color3.fromRGB(40, 44, 52)
    stroke.Thickness = 1

    local title = Instance.new("TextLabel")
    title.Parent = main
    title.BackgroundTransparency = 1
    title.Size = UDim2.new(1, -50, 0, 22)
    title.Position = UDim2.new(0, 12, 0, 6)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 13
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.TextColor3 = Color3.fromRGB(230, 230, 235)
    title.Text = "A6 Hub · SAE"

    local closeBtn = Instance.new("TextButton")
    closeBtn.Parent = main
    closeBtn.Size = UDim2.new(0, 28, 0, 22)
    closeBtn.Position = UDim2.new(1, -34, 0, 6)
    closeBtn.BackgroundColor3 = Color3.fromRGB(40, 42, 48)
    closeBtn.Text = "×"
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 16
    closeBtn.TextColor3 = Color3.fromRGB(200, 200, 210)
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
    closeBtn.MouseButton1Click:Connect(function() main.Visible = false end)
    openBtn.MouseButton1Click:Connect(function() main.Visible = not main.Visible end)

    -- tab bar
    local tabBar = Instance.new("Frame")
    tabBar.Parent = main
    tabBar.BackgroundTransparency = 1
    tabBar.Size = UDim2.new(1, -16, 0, 28)
    tabBar.Position = UDim2.new(0, 8, 0, 30)
    local tabLay = Instance.new("UIListLayout", tabBar)
    tabLay.FillDirection = Enum.FillDirection.Horizontal
    tabLay.Padding = UDim.new(0, 4)

    local pages, tabBtns = {}, {}
    local function show(name)
        for n, p in pairs(pages) do p.Visible = (n == name) end
        for n, b in pairs(tabBtns) do
            if n == name then
                b.BackgroundColor3 = Color3.fromRGB(0, 140, 110)
                b.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                b.BackgroundColor3 = Color3.fromRGB(32, 34, 40)
                b.TextColor3 = Color3.fromRGB(180, 180, 190)
            end
        end
    end

    local tabs = {"Steals", "Pet Filter", "Settings", "Webhooks"}
    for _, name in ipairs(tabs) do
        local b = Instance.new("TextButton")
        b.Parent = tabBar
        b.Size = UDim2.new(0, 72, 0, 26)
        b.BackgroundColor3 = Color3.fromRGB(32, 34, 40)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 11
        b.TextColor3 = Color3.fromRGB(180, 180, 190)
        b.Text = name
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
        tabBtns[name] = b
        b.MouseButton1Click:Connect(function() show(name) end)

        local page = Instance.new("ScrollingFrame")
        page.Parent = main
        page.BackgroundTransparency = 1
        page.Size = UDim2.new(1, -16, 1, -68)
        page.Position = UDim2.new(0, 8, 0, 62)
        page.ScrollBarThickness = 3
        page.ScrollBarImageColor3 = Color3.fromRGB(0, 140, 110)
        page.BorderSizePixel = 0
        page.Visible = false
        page.CanvasSize = UDim2.new(0, 0, 0, 0)
        local lay = Instance.new("UIListLayout", page)
        lay.Padding = UDim.new(0, 6)
        lay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            page.CanvasSize = UDim2.new(0, 0, 0, lay.AbsoluteContentSize.Y + 10)
        end)
        pages[name] = page
    end

    local function section(page, text)
        local l = Instance.new("TextLabel")
        l.Parent = page
        l.BackgroundTransparency = 1
        l.Size = UDim2.new(1, 0, 0, 16)
        l.Font = Enum.Font.GothamBold
        l.TextSize = 11
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextColor3 = Color3.fromRGB(0, 200, 160)
        l.Text = text
        return l
    end

    local function tip(page, text)
        local l = Instance.new("TextLabel")
        l.Parent = page
        l.BackgroundTransparency = 1
        l.Size = UDim2.new(1, 0, 0, 28)
        l.Font = Enum.Font.Gotham
        l.TextSize = 10
        l.TextXAlignment = Enum.TextXAlignment.Left
        l.TextColor3 = Color3.fromRGB(140, 140, 150)
        l.TextWrapped = true
        l.Text = text
        return l
    end

    -- row toggle like screenshot (label left, switch right)
    local function toggleRow(page, label, key, defaultOn)
        if defaultOn ~= nil and S[key] == nil then S[key] = defaultOn end
        local row = Instance.new("Frame")
        row.Parent = page
        row.Size = UDim2.new(1, 0, 0, 32)
        row.BackgroundColor3 = Color3.fromRGB(28, 30, 36)
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)
        local lab = Instance.new("TextLabel")
        lab.Parent = row
        lab.BackgroundTransparency = 1
        lab.Size = UDim2.new(1, -56, 1, 0)
        lab.Position = UDim2.new(0, 10, 0, 0)
        lab.Font = Enum.Font.Gotham
        lab.TextSize = 12
        lab.TextXAlignment = Enum.TextXAlignment.Left
        lab.TextColor3 = Color3.fromRGB(220, 220, 230)
        lab.Text = label
        local sw = Instance.new("TextButton")
        sw.Parent = row
        sw.Size = UDim2.new(0, 40, 0, 22)
        sw.Position = UDim2.new(1, -46, 0.5, -11)
        sw.Text = ""
        Instance.new("UICorner", sw).CornerRadius = UDim.new(1, 0)
        local knob = Instance.new("Frame")
        knob.Parent = sw
        knob.Size = UDim2.new(0, 18, 0, 18)
        knob.Position = UDim2.new(0, 2, 0.5, -9)
        Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
        local function paint()
            if S[key] then
                sw.BackgroundColor3 = Color3.fromRGB(0, 160, 120)
                knob.Position = UDim2.new(1, -20, 0.5, -9)
                knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
            else
                sw.BackgroundColor3 = Color3.fromRGB(50, 52, 60)
                knob.Position = UDim2.new(0, 2, 0.5, -9)
                knob.BackgroundColor3 = Color3.fromRGB(180, 180, 190)
            end
        end
        paint()
        sw.MouseButton1Click:Connect(function()
            S[key] = not S[key]
            if key == "AutoTreadmill" and not S[key] then stopMove() end
            paint()
            notify(label .. (S[key] and " ON" or " OFF"))
        end)
        return row
    end

    local function actionBtn(page, text, color, cb)
        local b = Instance.new("TextButton")
        b.Parent = page
        b.Size = UDim2.new(1, 0, 0, 30)
        b.BackgroundColor3 = color or Color3.fromRGB(0, 120, 100)
        b.Font = Enum.Font.GothamBold
        b.TextSize = 12
        b.TextColor3 = Color3.fromRGB(255, 255, 255)
        b.Text = text
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 8)
        b.MouseButton1Click:Connect(cb)
        return b
    end

    -- ===== STEALS =====
    section(pages["Steals"], "Steals")
    toggleRow(pages["Steals"], "Steal Egg Selected", "AutoSteal")
    toggleRow(pages["Steals"], "Auto Place After Steal", "AutoPlace")
    tip(pages["Steals"], "LakeDrop = soft tele → steal → Lake → Drop → steal again")
    actionBtn(pages["Steals"], "Method: " .. (S.StealMethod or "LakeDrop"), Color3.fromRGB(40, 44, 52), function()
        S.StealMethod = (S.StealMethod == "LakeDrop") and "Direct" or "LakeDrop"
        notify("Method " .. S.StealMethod)
    end)
    actionBtn(pages["Steals"], "Steal once", Color3.fromRGB(0, 110, 95), function() doStealOnce() end)
    actionBtn(pages["Steals"], "TP Lake / Drop", Color3.fromRGB(40, 44, 52), function()
        tpLake(); task.wait(0.2); dropEgg(); notify("Lake + Drop")
    end)
    actionBtn(pages["Steals"], "TP Base", Color3.fromRGB(40, 44, 52), function() tpBase(); notify("Base") end)

    -- ===== PET FILTER (like screenshot) =====
    section(pages["Pet Filter"], "Pet Filter")
    tip(pages["Pet Filter"], "Blacklisted = không cướp. Bỏ blacklist = cho phép. Search tên pet.")

    local search = Instance.new("TextBox")
    search.Parent = pages["Pet Filter"]
    search.Size = UDim2.new(1, 0, 0, 28)
    search.BackgroundColor3 = Color3.fromRGB(32, 34, 40)
    search.Font = Enum.Font.Gotham
    search.TextSize = 12
    search.TextColor3 = Color3.fromRGB(220, 220, 230)
    search.PlaceholderText = "Search Pets..."
    search.PlaceholderColor3 = Color3.fromRGB(100, 100, 110)
    search.Text = ""
    search.ClearTextOnFocus = false
    Instance.new("UICorner", search).CornerRadius = UDim.new(0, 8)

    local listHost = Instance.new("Frame")
    listHost.Parent = pages["Pet Filter"]
    listHost.BackgroundTransparency = 1
    listHost.Size = UDim2.new(1, 0, 0, 1)
    local listLay = Instance.new("UIListLayout", listHost)
    listLay.Padding = UDim.new(0, 5)
    listLay:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        listHost.Size = UDim2.new(1, 0, 0, math.max(1, listLay.AbsoluteContentSize.Y))
    end)

    local rarityColor = {
        Common = Color3.fromRGB(160,160,160), Uncommon = Color3.fromRGB(80,200,120),
        Rare = Color3.fromRGB(80,140,255), Epic = Color3.fromRGB(180,80,255),
        Legendary = Color3.fromRGB(255,180,40), Mythic = Color3.fromRGB(255,80,100),
        Cosmic = Color3.fromRGB(100,200,255), Secret = Color3.fromRGB(255,100,200),
        Eternal = Color3.fromRGB(255,220,100), Divine = Color3.fromRGB(255,255,200),
    }

    local function rebuildPetList(q)
        for _, c in ipairs(listHost:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        q = (q or ""):lower()
        local n = 0
        for _, pet in ipairs(S.PetCatalog) do
            if q == "" or pet.n:lower():find(q, 1, true) or pet.r:lower():find(q, 1, true) then
                n = n + 1
                if n > 50 then break end
                local key = pet.n:lower()
                local row = Instance.new("Frame")
                row.Parent = listHost
                row.Size = UDim2.new(1, 0, 0, 36)
                row.BackgroundColor3 = Color3.fromRGB(32, 28, 34)
                Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

                local nameL = Instance.new("TextLabel")
                nameL.Parent = row
                nameL.BackgroundTransparency = 1
                nameL.Size = UDim2.new(0.55, 0, 0, 18)
                nameL.Position = UDim2.new(0, 10, 0, 2)
                nameL.Font = Enum.Font.GothamBold
                nameL.TextSize = 12
                nameL.TextXAlignment = Enum.TextXAlignment.Left
                nameL.TextColor3 = Color3.fromRGB(235, 235, 240)
                nameL.Text = pet.n

                local rarL = Instance.new("TextLabel")
                rarL.Parent = row
                rarL.BackgroundTransparency = 1
                rarL.Size = UDim2.new(0.55, 0, 0, 14)
                rarL.Position = UDim2.new(0, 10, 0, 18)
                rarL.Font = Enum.Font.Gotham
                rarL.TextSize = 10
                rarL.TextXAlignment = Enum.TextXAlignment.Left
                rarL.TextColor3 = rarityColor[pet.r] or Color3.fromRGB(180, 180, 190)
                rarL.Text = pet.r

                local bl = Instance.new("TextButton")
                bl.Parent = row
                bl.Size = UDim2.new(0, 88, 0, 24)
                bl.Position = UDim2.new(1, -96, 0.5, -12)
                bl.Font = Enum.Font.GothamBold
                bl.TextSize = 11
                Instance.new("UICorner", bl).CornerRadius = UDim.new(0, 6)
                local function paintBL()
                    if S.PetBlacklist[key] then
                        bl.BackgroundColor3 = Color3.fromRGB(140, 40, 50)
                        bl.TextColor3 = Color3.fromRGB(255, 200, 200)
                        bl.Text = "Blacklisted ✕"
                    else
                        bl.BackgroundColor3 = Color3.fromRGB(40, 48, 44)
                        bl.TextColor3 = Color3.fromRGB(160, 220, 180)
                        bl.Text = "Allow ✓"
                    end
                end
                paintBL()
                bl.MouseButton1Click:Connect(function()
                    S.PetBlacklist[key] = not S.PetBlacklist[key]
                    -- if blacklisted, ensure not on whitelist-only path
                    if S.PetBlacklist[key] then S.PetWhitelist[key] = false end
                    paintBL()
                    notify(pet.n .. (S.PetBlacklist[key] and " blacklisted" or " allowed"))
                end)
            end
        end
    end
    rebuildPetList("")
    local petSearchToken = 0
    search:GetPropertyChangedSignal("Text"):Connect(function()
        petSearchToken = petSearchToken + 1
        local token = petSearchToken
        task.delay(0.15, function()
            if token == petSearchToken and search.Parent then rebuildPetList(search.Text) end
        end)
    end)

    actionBtn(pages["Pet Filter"], "Blacklist all Mythic", Color3.fromRGB(120, 40, 50), function()
        for _, pet in ipairs(S.PetCatalog) do
            if pet.r == "Mythic" then S.PetBlacklist[pet.n:lower()] = true end
        end
        rebuildPetList(search.Text)
        notify("All Mythic blacklisted")
    end)
    actionBtn(pages["Pet Filter"], "Clear all blacklist", Color3.fromRGB(40, 80, 60), function()
        S.PetBlacklist = {}
        rebuildPetList(search.Text)
        notify("Blacklist cleared")
    end)
    actionBtn(pages["Pet Filter"], "Refresh pet list", Color3.fromRGB(40, 44, 52), function()
        seedCatalog()
        PetDetectCache = setmetatable({}, {__mode = "k"})
        EggPromptCache.t = 0
        rebuildPetList(search.Text)
        notify(#S.PetCatalog .. " pets")
    end)

    -- force filter mode to respect blacklist
    S.FilterMode = "Both"

    -- ===== PRIORITY SETTINGS =====
    section(pages["Settings"], "Feature Priority")
    tip(pages["Settings"], "1 = ưu tiên cao nhất. Dùng ↑/↓ để đổi thứ tự. Chỉ các tính năng đang ON mới được scheduler chạy.")

    local priorityHost = Instance.new("Frame")
    priorityHost.Parent = pages["Settings"]
    priorityHost.BackgroundTransparency = 1
    priorityHost.Size = UDim2.new(1, 0, 0, 1)
    local priorityLayout = Instance.new("UIListLayout", priorityHost)
    priorityLayout.Padding = UDim.new(0, 5)
    priorityLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        priorityHost.Size = UDim2.new(1, 0, 0, math.max(1, priorityLayout.AbsoluteContentSize.Y))
    end)

    local function rebuildPriorityUI()
        for _, c in ipairs(priorityHost:GetChildren()) do
            if c:IsA("Frame") then c:Destroy() end
        end
        for i, label in ipairs(S.FeaturePriority) do
            local row = Instance.new("Frame")
            row.Parent = priorityHost
            row.Size = UDim2.new(1, 0, 0, 34)
            row.BackgroundColor3 = Color3.fromRGB(32, 34, 40)
            Instance.new("UICorner", row).CornerRadius = UDim.new(0, 8)

            local rank = Instance.new("TextLabel")
            rank.Parent = row
            rank.BackgroundTransparency = 1
            rank.Size = UDim2.new(0, 32, 1, 0)
            rank.Font = Enum.Font.GothamBold
            rank.TextSize = 12
            rank.TextColor3 = Color3.fromRGB(255, 200, 80)
            rank.Text = tostring(i)

            local nameL = Instance.new("TextLabel")
            nameL.Parent = row
            nameL.BackgroundTransparency = 1
            nameL.Position = UDim2.new(0, 34, 0, 0)
            nameL.Size = UDim2.new(1, -108, 1, 0)
            nameL.Font = Enum.Font.GothamBold
            nameL.TextSize = 11
            nameL.TextXAlignment = Enum.TextXAlignment.Left
            nameL.TextColor3 = Color3.fromRGB(235, 235, 240)
            nameL.Text = label

            local up = Instance.new("TextButton")
            up.Parent = row
            up.Size = UDim2.new(0, 28, 0, 24)
            up.Position = UDim2.new(1, -68, 0.5, -12)
            up.Font = Enum.Font.GothamBold
            up.TextSize = 13
            up.Text = "↑"
            up.BackgroundColor3 = Color3.fromRGB(45, 80, 110)
            up.TextColor3 = Color3.fromRGB(255,255,255)
            Instance.new("UICorner", up).CornerRadius = UDim.new(0, 6)

            local down = Instance.new("TextButton")
            down.Parent = row
            down.Size = UDim2.new(0, 28, 0, 24)
            down.Position = UDim2.new(1, -34, 0.5, -12)
            down.Font = Enum.Font.GothamBold
            down.TextSize = 13
            down.Text = "↓"
            down.BackgroundColor3 = Color3.fromRGB(45, 80, 110)
            down.TextColor3 = Color3.fromRGB(255,255,255)
            Instance.new("UICorner", down).CornerRadius = UDim.new(0, 6)

            up.MouseButton1Click:Connect(function()
                if i > 1 then
                    S.FeaturePriority[i], S.FeaturePriority[i-1] =
                        S.FeaturePriority[i-1], S.FeaturePriority[i]
                    rebuildPriorityUI()
                    notify("Priority #" .. i .. " → #" .. (i-1))
                end
            end)
            down.MouseButton1Click:Connect(function()
                if i < #S.FeaturePriority then
                    S.FeaturePriority[i], S.FeaturePriority[i+1] =
                        S.FeaturePriority[i+1], S.FeaturePriority[i]
                    rebuildPriorityUI()
                    notify("Priority #" .. i .. " → #" .. (i+1))
                end
            end)
        end
    end
    rebuildPriorityUI()

    -- ===== SETTINGS (like screenshot toggles) =====
    section(pages["Settings"], "Auto Farm Settings")
    toggleRow(pages["Settings"], "Auto Farm Speed", "AutoTreadmill")
    toggleRow(pages["Settings"], "Auto Place After Steal", "AutoPlace")
    toggleRow(pages["Settings"], "Auto Steal Egg Miss In Index", "AutoIndex")
    toggleRow(pages["Settings"], "Auto Hatch Egg", "AutoHatch")
    toggleRow(pages["Settings"], "Auto Upgrade Treadmill", "AutoUpgradeTreadmill")
    toggleRow(pages["Settings"], "Auto Upgrade Plot", "AutoUpgradePlot")
    toggleRow(pages["Settings"], "Auto Dr Scramble", "AutoScramble")
    toggleRow(pages["Settings"], "Auto Mutation Items", "AutoMutation")
    toggleRow(pages["Settings"], "Auto Sell", "AutoSell")
    toggleRow(pages["Settings"], "Egg ESP", "EggESP")
    toggleRow(pages["Settings"], "Anti AFK", "AntiAFK", true)
    tip(pages["Settings"], "TweenSpeed: tele nhe. Neu kick → giam.")
    actionBtn(pages["Settings"], "TweenSpeed +10", Color3.fromRGB(40, 44, 52), function()
        S.TweenSpeed = math.min(90, (S.TweenSpeed or 55) + 10)
        notify("Tween " .. S.TweenSpeed)
    end)
    actionBtn(pages["Settings"], "TweenSpeed -10", Color3.fromRGB(40, 44, 52), function()
        S.TweenSpeed = math.max(30, (S.TweenSpeed or 55) - 10)
        notify("Tween " .. S.TweenSpeed)
    end)
    actionBtn(pages["Settings"], "Rejoin", Color3.fromRGB(100, 40, 40), function()
        TeleportService:Teleport(game.PlaceId, LP)
    end)
    actionBtn(pages["Settings"], "Server Hop", Color3.fromRGB(100, 40, 40), function()
        pcall(function()
            local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=50"
            local data = HttpService:JSONDecode(game:HttpGet(url))
            for _, s in ipairs(data.data or {}) do
                if s.id ~= game.JobId and s.playing < (s.maxPlayers or 30) then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LP)
                    return
                end
            end
        end)
    end)
    actionBtn(pages["Settings"], "Copy Discord", Color3.fromRGB(88, 101, 242), function()
        pcall(setclipboard, DISCORD)
        notify("Copied discord")
    end)

    -- ===== WEBHOOKS =====
    section(pages["Webhooks"], "Discord Webhook")
    local box = Instance.new("TextBox")
    box.Parent = pages["Webhooks"]
    box.Size = UDim2.new(1, 0, 0, 54)
    box.BackgroundColor3 = Color3.fromRGB(32, 34, 40)
    box.Font = Enum.Font.Code
    box.TextSize = 11
    box.TextColor3 = Color3.fromRGB(220, 220, 230)
    box.PlaceholderText = "https://discord.com/api/webhooks/..."
    box.Text = S.WebhookURL or ""
    box.TextWrapped = true
    box.MultiLine = true
    box.ClearTextOnFocus = false
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 8)
    box.FocusLost:Connect(function() S.WebhookURL = box.Text end)
    toggleRow(pages["Webhooks"], "Webhook every steal", "WebhookOnSteal")
    toggleRow(pages["Webhooks"], "Webhook rare only (Secret+)", "WebhookOnRare", true)
    actionBtn(pages["Webhooks"], "Test Webhook", Color3.fromRGB(0, 120, 100), function()
        S.WebhookURL = box.Text
        webhook("A6 Test", "OK · " .. LP.Name, 3447003)
        notify("Sent")
    end)

    show("Steals")
end

pcall(build)
notify("A6 Hub · SAE v2 ready")
print("[A6 SAE] v2 ready · " .. DISCORD)
