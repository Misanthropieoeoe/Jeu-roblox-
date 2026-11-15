-- Money toasts: transient feedback when a stack is picked up, banked, or
-- denied. The cash amount itself lives in the StandStatHUD money box.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local localPlayer = Players.LocalPlayer

local remotes = ReplicatedStorage:WaitForChild("Remotes")
local moneyEvent = remotes:WaitForChild("MoneyEvent")

local CASH_PER_STACK = 500

local gui = Instance.new("ScreenGui")
gui.Name = "MoneyToasts"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = localPlayer:WaitForChild("PlayerGui")

local toast = Instance.new("TextLabel")
toast.Name = "Toast"
toast.AnchorPoint = Vector2.new(0.5, 1)
toast.Position = UDim2.new(0.5, 0, 1, -110)
toast.Size = UDim2.new(0, 320, 0, 30)
toast.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
toast.BackgroundTransparency = 0.2
toast.BorderSizePixel = 0
toast.Font = Enum.Font.SourceSansBold
toast.Text = ""
toast.TextColor3 = Color3.fromRGB(235, 235, 235)
toast.TextSize = 18
toast.Visible = false
toast.Parent = gui
local toastCorner = Instance.new("UICorner")
toastCorner.CornerRadius = UDim.new(0, 8)
toastCorner.Parent = toast

local toastToken = 0
local function showToast(text, color)
	toastToken += 1
	local myToken = toastToken
	toast.Text = text
	toast.TextColor3 = color or Color3.fromRGB(235, 235, 235)
	toast.Visible = true
	toast.BackgroundTransparency = 0.2
	task.delay(2.5, function()
		if toastToken == myToken then
			TweenService:Create(toast, TweenInfo.new(0.4), { BackgroundTransparency = 1 }):Play()
			task.delay(0.4, function()
				if toastToken == myToken then
					toast.Visible = false
					toast.BackgroundTransparency = 0.2
				end
			end)
		end
	end)
end

moneyEvent.OnClientEvent:Connect(function(actionName, amount, total)
	-- "Gained" (argent ramassé, +30) est affiché par le HUD (HUD.client.luau)
	if actionName == "PickedUp" then
		showToast("Picked up a Stack of Money - use it to bank $" .. tostring(amount), Color3.fromRGB(140, 255, 150))
	elseif actionName == "Used" then
		showToast("+$" .. tostring(amount) .. " (total $" .. tostring(total) .. ")", Color3.fromRGB(255, 235, 150))
	elseif actionName == "Denied" then
		showToast(tostring(amount), Color3.fromRGB(255, 120, 110))
	end
end)

print("[MoneyToasts] Ready")
