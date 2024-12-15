local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local BuildingTools = LocalPlayer.Character:FindFirstChild("Building Tools")
if not BuildingTools or not BuildingTools:FindFirstChild("SyncAPI") then
    warn("Building Tools or SyncAPI not found!")
    return
end
local SyncAPI = BuildingTools.SyncAPI.ServerEndpoint

-- Function to create a part of a specific type
local function createPart(PartType, CFrame)
    local part = SyncAPI:InvokeServer("CreatePart", PartType, CFrame, workspace)
    repeat wait() until workspace:FindFirstChild(part.Name)
    return part
end

-- Function to resize a part
local function resize(Part, Size, CFrame)
    SyncAPI:InvokeServer("SyncResize", {
        {
            ["Part"] = Part,
            ["CFrame"] = CFrame,
            ["Size"] = Size
        }
    })
end

-- Function to change part color
local function color(Part, Color)
    SyncAPI:InvokeServer("SyncColor", {
        {
            ["Part"] = Part,
            ["UnionColoring"] = true,
            ["Color"] = Color
        }
    })
end

-- Function to change part material
local function material(Part, Material)
    SyncAPI:InvokeServer("SyncMaterial", {
        {
            ["Part"] = Part,
            ["Material"] = Material
        }
    })
end

-- Function to set collision
local function collision(Part, bool)
    SyncAPI:InvokeServer("SyncCollision", {
        {
            ["Part"] = Part,
            ["CanCollide"] = bool
        }
    })
end

-- Function to add a mesh
local function addMesh(Part, MeshId, TextureId)
    if not MeshId or MeshId == "" then return end
    SyncAPI:InvokeServer("CreateMeshes", {
        {
            ["Part"] = Part
        }
    })
    SyncAPI:InvokeServer("SyncMesh", {
        {
            ["MeshType"] = Enum.MeshType.FileMesh,
            ["Part"] = Part,
            ["MeshId"] = MeshId,
            ["TextureId"] = TextureId
        }
    })
end

-- Function to set transparency
local function setTransparency(Part, TransparencyLevel)
    SyncAPI:InvokeServer("SyncMaterial", {
        {
            ["Part"] = Part,
            ["Transparency"] = TransparencyLevel
        }
    })
end

-- Function to set reflectance
local function setReflectance(Part, ReflectanceLevel)
    SyncAPI:InvokeServer("SyncMaterial", {
        {
            ["Part"] = Part,
            ["Reflectance"] = ReflectanceLevel
        }
    })
end

-- Function to add a texture or decal
local function addTexture(Part, Face, TextureType)
    SyncAPI:InvokeServer("CreateTextures", {
        {
            ["Part"] = Part,
            ["Face"] = Face,
            ["TextureType"] = TextureType
        }
    })
end

-- Function to add a light
local function addLight(Part, LightType)
    SyncAPI:InvokeServer("CreateLights", {
        {
            ["Part"] = Part,
            ["LightType"] = LightType
        }
    })
end

-- Function to determine part type
local function determinePartType(part)
    if part:IsA("TrussPart") then
        return "Truss"
    elseif part:IsA("WedgePart") then
        return "Wedge"
    elseif part:IsA("CornerWedgePart") then
        return "Corner"
    elseif part:IsA("Cylinder") then
        return "Cylinder"
    elseif part:IsA("Ball") then
        return "Ball"
    elseif part:IsA("Seat") then
        return "Seat"
    elseif part:IsA("VehicleSeat") then
        return "VehicleSeat"
    elseif part:IsA("SpawnLocation") then
        return "Spawn"
    else
        return "Normal"
    end
end

-- Function to process and build parts
local function buildPart(part)
    if not part:IsA("BasePart") then return end

    local partType = determinePartType(part)
    local newPart = createPart(partType, part.CFrame)

    color(newPart, part.Color)
    resize(newPart, part.Size, part.CFrame)
    material(newPart, part.Material)
    collision(newPart, part.CanCollide)
    setTransparency(newPart, part.Transparency) -- Apply transparency
    setReflectance(newPart, part.Reflectance)   -- Apply reflectance

    -- Add textures and decals (Example: Front face as placeholder)
    addTexture(newPart, Enum.NormalId.Front, "Texture")
    addTexture(newPart, Enum.NormalId.Front, "Decal")

    -- Add lights to the part (Example: Adding PointLight)
    addLight(newPart, SpotLight) -- Replace with "SpotLight" or "SurfaceLight" if needed

    if part.Anchored then
        SyncAPI:InvokeServer("SyncAnchor", {
            {
                ["Part"] = newPart,
                ["Anchored"] = true
            }
        })
    end

    if part:IsA("MeshPart") then
        addMesh(newPart, part.MeshId, part.TextureId)
    end
end

-- Load the model
-- assetId = nil -- Replace with the rbxassetid of the model
local model = game:GetObjects("rbxassetid://" .. assetId)[1]
if not model then
    warn("Failed to load model from asset ID.")
    return
end

model.Parent = workspace

-- Process parts in parallel
local threads = {}
for _, descendant in ipairs(model:GetDescendants()) do
    table.insert(threads, coroutine.create(function()
        buildPart(descendant)
    end))
end

-- Start all threads
for _, thread in ipairs(threads) do
    coroutine.resume(thread)
end

model:Destroy()

-- Notify the user
print("Model built and original model removed successfully!")
game:GetService("StarterGui"):SetCore("SendNotification", {
    Title = "Built!",
    Text = "Model built and original model removed successfully!",
    Icon = "rbxthumb://type=AvatarHeadShot&id=" .. LocalPlayer.UserId .. "&w=180&h=180 true",
    Duration = 5
})
