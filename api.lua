-- ============================================================
--  CONFIGURATION  (edit these values before running)
-- ============================================================
local ASSET_ID          = 0          -- Replace with your rbxassetid number
local API_CALL_DELAY    = 0.01       -- Seconds between SyncAPI calls (tune to avoid kick)
local DRY_RUN           = false      -- If true, counts parts and prints a preview without building
local PLACEMENT_OFFSET  = CFrame.new(0, 0, 0)  -- World-space offset for the entire build
-- ============================================================

local Players    = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- Safety: wait for character
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

local BuildingTools = character:FindFirstChild("Building Tools")
if not BuildingTools or not BuildingTools:FindFirstChild("SyncAPI") then
    warn("[Builder] Building Tools or SyncAPI not found. Aborting.")
    return
end
local SyncAPI = BuildingTools.SyncAPI.ServerEndpoint

-- Tracks every created part so undoBuild() can remove them all
local createdParts = {}

-- ============================================================
--  RATE-LIMITED INVOKE
--  Wraps all SyncAPI calls with a configurable delay and pcall
-- ============================================================
local function invoke(method, ...)
    task.wait(API_CALL_DELAY)
    local ok, result = pcall(function(...)
        return SyncAPI:InvokeServer(method, ...)
    end, ...)
    if not ok then
        warn("[Builder] SyncAPI call failed (" .. method .. "): " .. tostring(result))
        return nil
    end
    return result
end

-- ============================================================
--  CORE BUILDING FUNCTIONS
-- ============================================================

local function createPart(partType, cf)
    local part = invoke("CreatePart", partType, cf, workspace)
    if not part then return nil end
    -- Wait for replication (with timeout)
    local t = 0
    repeat
        task.wait(0.05)
        t = t + 0.05
    until workspace:FindFirstChild(part.Name) or t > 5
    table.insert(createdParts, part)
    return part
end

local function resize(part, size, cf)
    invoke("SyncResize", {{ Part = part, CFrame = cf, Size = size }})
end

local function color(part, col)
    invoke("SyncColor", {{ Part = part, UnionColoring = true, Color = col }})
end

local function setMaterial(part, mat)
    invoke("SyncMaterial", {{ Part = part, Material = mat }})
end

local function setCollision(part, canCollide)
    invoke("SyncCollision", {{ Part = part, CanCollide = canCollide }})
end

local function setTransparency(part, level)
    invoke("SyncMaterial", {{ Part = part, Transparency = level }})
end

local function setReflectance(part, level)
    invoke("SyncMaterial", {{ Part = part, Reflectance = level }})
end

local function setAnchor(part, anchored)
    invoke("SyncAnchor", {{ Part = part, Anchored = anchored }})
end

local function addMesh(part, meshId, textureId)
    if not meshId or meshId == "" then return end
    invoke("CreateMeshes", {{ Part = part }})
    invoke("SyncMesh", {{
        Part        = part,
        MeshType    = Enum.MeshType.FileMesh,
        MeshId      = meshId,
        TextureId   = textureId or ""
    }})
end

local function addSpecialMesh(part, sourceMesh)
    invoke("CreateMeshes", {{ Part = part }})
    invoke("SyncMesh", {{
        Part      = part,
        MeshType  = sourceMesh.MeshType,
        MeshId    = sourceMesh.MeshId or "",
        TextureId = sourceMesh.TextureId or "",
        Scale     = sourceMesh.Scale,
        Offset    = sourceMesh.Offset,
    }})
end

-- Mirrors all Texture and Decal children from source onto newPart
local function copyTextures(newPart, sourcePart)
    for _, child in ipairs(sourcePart:GetChildren()) do
        if child:IsA("Texture") or child:IsA("Decal") then
            invoke("CreateTextures", {{
                Part        = newPart,
                Face        = child.Face,
                TextureType = child.ClassName,   -- "Texture" or "Decal"
            }})
        end
    end
end

-- Mirrors all light children from source onto newPart
local function copyLights(newPart, sourcePart)
    for _, child in ipairs(sourcePart:GetChildren()) do
        local lightType = nil
        if child:IsA("PointLight")   then lightType = "PointLight"   end
        if child:IsA("SpotLight")    then lightType = "SpotLight"    end
        if child:IsA("SurfaceLight") then lightType = "SurfaceLight" end
        if lightType then
            invoke("CreateLights", {{ Part = newPart, LightType = lightType }})
        end
    end
end

-- ============================================================
--  PART TYPE DETECTION
-- ============================================================
local function determinePartType(part)
    if part:IsA("TrussPart")       then return "Truss"
    elseif part:IsA("WedgePart")   then return "Wedge"
    elseif part:IsA("CornerWedgePart") then return "Corner"
    elseif part:IsA("Seat")        then return "Seat"
    elseif part:IsA("VehicleSeat") then return "VehicleSeat"
    elseif part:IsA("SpawnLocation") then return "Spawn"
    -- Note: Cylinder and Ball are shapes of a normal Part in modern Roblox
    else return "Normal"
    end
end

-- ============================================================
--  MAIN BUILD FUNCTION  (called per BasePart)
-- ============================================================
local function buildPart(sourcePart, modelOriginCF)
    if not sourcePart:IsA("BasePart") then return end

    -- Apply placement offset: shift the part relative to the model's origin
    local relativeCF = modelOriginCF:ToObjectSpace(sourcePart.CFrame)
    local targetCF   = PLACEMENT_OFFSET * relativeCF

    local partType = determinePartType(sourcePart)
    local newPart  = createPart(partType, targetCF)
    if not newPart then
        warn("[Builder] Could not create part for: " .. sourcePart.Name)
        return
    end

    -- Core properties
    color(newPart,           sourcePart.Color)
    resize(newPart,          sourcePart.Size, targetCF)
    setMaterial(newPart,     sourcePart.Material)
    setCollision(newPart,    sourcePart.CanCollide)
    setTransparency(newPart, sourcePart.Transparency)
    setReflectance(newPart,  sourcePart.Reflectance)

    if sourcePart.Anchored then
        setAnchor(newPart, true)
    end

    -- Mesh: MeshPart
    if sourcePart:IsA("MeshPart") then
        addMesh(newPart, sourcePart.MeshId, sourcePart.TextureID)
    end

    -- Mesh: SpecialMesh child
    local specialMesh = sourcePart:FindFirstChildOfClass("SpecialMesh")
    if specialMesh then
        addSpecialMesh(newPart, specialMesh)
    end

    -- Only copy textures/decals/lights that actually exist on the source
    copyTextures(newPart, sourcePart)
    copyLights(newPart,   sourcePart)
end

-- ============================================================
--  UNDO  — removes every part created during this session
-- ============================================================
local function undoBuild()
    if #createdParts == 0 then
        warn("[Builder] Nothing to undo.")
        return
    end
    for _, part in ipairs(createdParts) do
        if part and part.Parent then
            invoke("DeleteParts", {{ Part = part }})
        end
    end
    createdParts = {}
    print("[Builder] Undo complete — all built parts removed.")
end

-- ============================================================
--  LOAD & BUILD
-- ============================================================

if ASSET_ID == 0 then
    warn("[Builder] ASSET_ID is not set. Please edit the configuration block at the top.")
    return
end

local model = game:GetObjects("rbxassetid://" .. ASSET_ID)[1]
if not model then
    warn("[Builder] Failed to load model from asset ID: " .. ASSET_ID)
    return
end

model.Parent = workspace

-- Collect all BaseParts for counting and iteration
local parts = {}
for _, descendant in ipairs(model:GetDescendants()) do
    if descendant:IsA("BasePart") then
        table.insert(parts, descendant)
    end
end

local totalParts = #parts
print(("[Builder] Model loaded — %d parts found."):format(totalParts))

if DRY_RUN then
    print("[Builder] DRY RUN — no parts will be placed. Set DRY_RUN = false to build.")
    model:Destroy()
    return
end

-- Use the model's primary CFrame as the origin for relative placement,
-- falling back to the first part if no PrimaryPart is set.
local modelOriginCF
if model:IsA("Model") and model.PrimaryPart then
    modelOriginCF = model:GetPrimaryPartCFrame()
elseif #parts > 0 then
    modelOriginCF = parts[1].CFrame
else
    modelOriginCF = CFrame.new()
end

local built   = 0
local failed  = 0

for i, sourcePart in ipairs(parts) do
    local ok, err = pcall(buildPart, sourcePart, modelOriginCF)
    if ok then
        built = built + 1
    else
        failed = failed + 1
        warn(("[Builder] Failed on part %d (%s): %s"):format(i, sourcePart.Name, tostring(err)))
    end

    -- Progress update every 10 parts
    if i % 10 == 0 or i == totalParts then
        print(("[Builder] Progress: %d / %d"):format(i, totalParts))
        game:GetService("StarterGui"):SetCore("SendNotification", {
            Title    = "Building...",
            Text     = ("Part %d of %d"):format(i, totalParts),
            Duration = 2,
        })
    end
end

model:Destroy()

-- Final summary
local summary = ("Built %d / %d parts. Failed: %d"):format(built, totalParts, failed)
print("[Builder] " .. summary)
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title    = "Build complete!",
    Text     = summary,
    Icon     = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=180&h=180",
    Duration = 7,
})

-- Expose undoBuild globally for manual undo in the console
_G.undoBuild = undoBuild
print("[Builder] Run _G.undoBuild() in the console to undo the entire build.")
