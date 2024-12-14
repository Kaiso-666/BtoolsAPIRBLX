local function createPart(CFrame)
game:GetService("Players").LocalPlayer.Character:FindFirstChild("Building Tools").SyncAPI.ServerEndpoint:InvokeServer(
    "CreatePart",
    "Normal",
    CFrame,
    workspace
)
end

local function resize(Part, Size)
game:GetService("Players").LocalPlayer.Character:FindFirstChild("Building Tools").SyncAPI.ServerEndpoint:InvokeServer(
    "SyncResize",
    {
        {
            ["Part"] = Part,
            ["CFrame"] = Part.CFrame,
            ["Size"] = Size
        }
    }
)
end

local function color(Part, Color)
game:GetService("Players").LocalPlayer.Character:FindFirstChild("Building Tools").SyncAPI.ServerEndpoint:InvokeServer(
    "SyncColor",
    {
        {
            ["Part"] = Part,
            ["UnionColoring"] = true,
            ["Color"] = Color
        }
    }
)
end

local function material(Part, Material)
game:GetService("Players").LocalPlayer.Character:FindFirstChild("Building Tools").SyncAPI.ServerEndpoint:InvokeServer(
    "SyncMaterial",
    {
        {
            ["Part"] = Part,
            ["Material"] = Material
        }
    }
)
end

local function Collision(Part, bool)
game:GetService("Players").LocalPlayer.Character:FindFirstChild("Building Tools").SyncAPI.ServerEndpoint:InvokeServer(
    "SyncCollision",
    {
        {
            ["Part"] = Part,
            ["CanCollide"] = bool
        }
    }
)
end

local function addMesh(Part, MeshId, TextureId)
    -- CreateMeshes (if necessary)
    game:GetService("Players").LocalPlayer.Character:FindFirstChild("Building Tools").SyncAPI.ServerEndpoint:InvokeServer(
        "CreateMeshes",
        {
            {
                ["Part"] = Part
            }
        }
    )

    -- SyncMesh for MeshType, MeshId, and TextureId
    game:GetService("Players").LocalPlayer.Character:FindFirstChild("Building Tools").SyncAPI.ServerEndpoint:InvokeServer(
        "SyncMesh",
        {
            {
                ["MeshType"] = Enum.MeshType.FileMesh,
                ["Part"] = Part,
                ["MeshId"] = "rbxassetid://" .. MeshId,
                ["TextureId"] = "rbxassetid://" .. TextureId
            }
        }
    )
end