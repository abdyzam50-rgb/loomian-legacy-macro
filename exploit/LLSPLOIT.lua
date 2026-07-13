_G.OrionLib = (function()


local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local LocalPlayer = game:GetService("Players").LocalPlayer
local Mouse = LocalPlayer:GetMouse()
local HttpService = game:GetService("HttpService")

local OrionLib = {
	Elements = {},
	ThemeObjects = {},
	Connections = {},
	Flags = {},
	Themes = {
		Default = {
			Main = Color3.fromRGB(12, 14, 20),
			Second = Color3.fromRGB(18, 22, 32),
			Stroke = Color3.fromRGB(42, 52, 78),
			Divider = Color3.fromRGB(28, 34, 50),
			Text = Color3.fromRGB(236, 241, 255),
			TextDark = Color3.fromRGB(126, 138, 168)
		}
	},
	SelectedTheme = "Default",
	Folder = nil,
	SaveCfg = false
}

--Feather Icons https://github.com/evoincorp/lucideblox/tree/master/src/modules/util - Created by 7kayoh
local Icons = {}

local Success, Response = pcall(function()
	Icons = HttpService:JSONDecode(game:HttpGetAsync("https://raw.githubusercontent.com/evoincorp/lucideblox/master/src/modules/util/icons.json")).icons
end)

if not Success then
	Icons = {}
end	

local function GetIcon(IconName)
	if type(Icons) == "table" and Icons[IconName] ~= nil then
		return Icons[IconName]
	else
		return nil
	end
end   

local function IsImageAsset(ImageID)
	ImageID = tostring(ImageID or "")
	return string.find(ImageID, "rbxasset", 1, true) == 1 or string.find(ImageID, "http", 1, true) == 1
end

local Orion = Instance.new("ScreenGui")
Orion.Name = "Orion"
if syn then
	syn.protect_gui(Orion)
	Orion.Parent = game.CoreGui
else
	Orion.Parent = gethui() or game.CoreGui
end

if gethui then
	for _, Interface in ipairs(gethui():GetChildren()) do
		if Interface.Name == Orion.Name and Interface ~= Orion then
			Interface:Destroy()
		end
	end
else
	for _, Interface in ipairs(game.CoreGui:GetChildren()) do
		if Interface.Name == Orion.Name and Interface ~= Orion then
			Interface:Destroy()
		end
	end
end

function OrionLib:IsRunning()
	if gethui then
		return Orion.Parent == gethui()
	else
		return Orion.Parent == game:GetService("CoreGui")
	end

end

local function AddConnection(Signal, Function)
	if (not OrionLib:IsRunning()) then
		return
	end
	local SignalConnect = Signal:Connect(function(...)
		local ok, err = pcall(Function, ...)
		if not ok then
			-- Roblox can fire UI signals from restricted threads in some executors.
			-- Keep Orion responsive without spamming the developer console.
		end
	end)
	table.insert(OrionLib.Connections, SignalConnect)
	return SignalConnect
end

task.spawn(function()
	while (OrionLib:IsRunning()) do
		wait()
	end

	for _, Connection in next, OrionLib.Connections do
		Connection:Disconnect()
	end
end)

local function MakeDraggable(DragPoint, Main)
	pcall(function()
		local Dragging, DragInput, MousePos, FramePos = false
		AddConnection(DragPoint.InputBegan, function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseButton1 then
				Dragging = true
				MousePos = Input.Position
				pcall(function()
					FramePos = Main.Position
				end)

				Input.Changed:Connect(function()
					local ok, state = pcall(function()
						return Input.UserInputState
					end)
					if ok and state == Enum.UserInputState.End then
						Dragging = false
					end
				end)
			end
		end)
		AddConnection(DragPoint.InputChanged, function(Input)
			if Input.UserInputType == Enum.UserInputType.MouseMovement then
				DragInput = Input
			end
		end)
		AddConnection(UserInputService.InputChanged, function(Input)
			if Input == DragInput and Dragging and MousePos and FramePos and Main then
				pcall(function()
					if not Main.Parent then
						return
					end
					local Delta = Input.Position - MousePos
					--TweenService:Create(Main, TweenInfo.new(0.05, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Position  = UDim2.new(FramePos.X.Scale,FramePos.X.Offset + Delta.X, FramePos.Y.Scale, FramePos.Y.Offset + Delta.Y)}):Play()
					Main.Position  = UDim2.new(FramePos.X.Scale,FramePos.X.Offset + Delta.X, FramePos.Y.Scale, FramePos.Y.Offset + Delta.Y)
				end)
			end
		end)
	end)
end    

local function Create(Name, Properties, Children)
	local Object = Instance.new(Name)
	for i, v in next, Properties or {} do
		Object[i] = v
	end
	for i, v in next, Children or {} do
		v.Parent = Object
	end
	return Object
end

local function CreateElement(ElementName, ElementFunction)
	OrionLib.Elements[ElementName] = function(...)
		return ElementFunction(...)
	end
end

local function MakeElement(ElementName, ...)
	local NewElement = OrionLib.Elements[ElementName](...)
	return NewElement
end

local function SetProps(Element, Props)
	table.foreach(Props, function(Property, Value)
		Element[Property] = Value
	end)
	return Element
end

local function SetChildren(Element, Children)
	table.foreach(Children, function(_, Child)
		Child.Parent = Element
	end)
	return Element
end

local function Round(Number, Factor)
	local Result = math.floor(Number/Factor + (math.sign(Number) * 0.5)) * Factor
	if Result < 0 then Result = Result + Factor end
	return Result
end

local function ReturnProperty(Object)
	if Object:IsA("Frame") or Object:IsA("TextButton") then
		return "BackgroundColor3"
	end 
	if Object:IsA("ScrollingFrame") then
		return "ScrollBarImageColor3"
	end 
	if Object:IsA("UIStroke") then
		return "Color"
	end 
	if Object:IsA("TextLabel") or Object:IsA("TextBox") then
		return "TextColor3"
	end   
	if Object:IsA("ImageLabel") or Object:IsA("ImageButton") then
		return "ImageColor3"
	end   
end

local function AddThemeObject(Object, Type)
	if not OrionLib.ThemeObjects[Type] then
		OrionLib.ThemeObjects[Type] = {}
	end    
	table.insert(OrionLib.ThemeObjects[Type], Object)
	Object[ReturnProperty(Object)] = OrionLib.Themes[OrionLib.SelectedTheme][Type]
	return Object
end    

local function SetTheme()
	for Name, Type in pairs(OrionLib.ThemeObjects) do
		for _, Object in pairs(Type) do
			Object[ReturnProperty(Object)] = OrionLib.Themes[OrionLib.SelectedTheme][Name]
		end    
	end    
end

local function PackColor(Color)
	return {R = Color.R * 255, G = Color.G * 255, B = Color.B * 255}
end    

local function UnpackColor(Color)
	return Color3.fromRGB(Color.R, Color.G, Color.B)
end

local function LoadCfg(Config)
	local Data = HttpService:JSONDecode(Config)
	table.foreach(Data, function(a,b)
		if OrionLib.Flags[a] then
			spawn(function() 
				if OrionLib.Flags[a].Type == "Colorpicker" then
					OrionLib.Flags[a]:Set(UnpackColor(b))
				else
					OrionLib.Flags[a]:Set(b)
				end    
			end)
		else
			warn("Orion Library Config Loader - Could not find ", a ,b)
		end
	end)
end

local function SaveCfg(Name)
	if not OrionLib.SaveCfg then
		return
	end

	local Data = {}
	for i,v in pairs(OrionLib.Flags) do
		if v.Save then
			if v.Type == "Colorpicker" then
				Data[i] = PackColor(v.Value)
			else
				Data[i] = v.Value
			end
		end	
	end
	writefile(OrionLib.Folder .. "/" .. Name .. ".txt", tostring(HttpService:JSONEncode(Data)))
end

local WhitelistedMouse = {Enum.UserInputType.MouseButton1, Enum.UserInputType.MouseButton2,Enum.UserInputType.MouseButton3}
local BlacklistedKeys = {Enum.KeyCode.Unknown,Enum.KeyCode.W,Enum.KeyCode.A,Enum.KeyCode.S,Enum.KeyCode.D,Enum.KeyCode.Up,Enum.KeyCode.Left,Enum.KeyCode.Down,Enum.KeyCode.Right,Enum.KeyCode.Slash,Enum.KeyCode.Tab,Enum.KeyCode.Backspace,Enum.KeyCode.Escape}

local function CheckKey(Table, Key)
	for _, v in next, Table do
		if v == Key then
			return true
		end
	end
end

CreateElement("Corner", function(Scale, Offset)
	local Corner = Create("UICorner", {
		CornerRadius = UDim.new(Scale or 0, Offset or 10)
	})
	return Corner
end)

CreateElement("Stroke", function(Color, Thickness)
	local Stroke = Create("UIStroke", {
		Color = Color or Color3.fromRGB(255, 255, 255),
		Thickness = Thickness or 1
	})
	return Stroke
end)

CreateElement("List", function(Scale, Offset)
	local List = Create("UIListLayout", {
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(Scale or 0, Offset or 0)
	})
	return List
end)

CreateElement("Padding", function(Bottom, Left, Right, Top)
	local Padding = Create("UIPadding", {
		PaddingBottom = UDim.new(0, Bottom or 4),
		PaddingLeft = UDim.new(0, Left or 4),
		PaddingRight = UDim.new(0, Right or 4),
		PaddingTop = UDim.new(0, Top or 4)
	})
	return Padding
end)

CreateElement("TFrame", function()
	local TFrame = Create("Frame", {
		BackgroundTransparency = 1
	})
	return TFrame
end)

CreateElement("Frame", function(Color)
	local Frame = Create("Frame", {
		BackgroundColor3 = Color or Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0
	})
	return Frame
end)

CreateElement("RoundFrame", function(Color, Scale, Offset)
	local Frame = Create("Frame", {
		BackgroundColor3 = Color or Color3.fromRGB(255, 255, 255),
		BorderSizePixel = 0
	}, {
		Create("UICorner", {
			CornerRadius = UDim.new(Scale, Offset)
		})
	})
	return Frame
end)

CreateElement("Button", function()
	local Button = Create("TextButton", {
		Text = "",
		AutoButtonColor = false,
		BackgroundTransparency = 1,
		BorderSizePixel = 0
	})
	return Button
end)

CreateElement("ScrollFrame", function(Color, Width)
	local ScrollFrame = Create("ScrollingFrame", {
		BackgroundTransparency = 1,
		MidImage = "rbxassetid://7445543667",
		BottomImage = "rbxassetid://7445543667",
		TopImage = "rbxassetid://7445543667",
		ScrollBarImageColor3 = Color,
		BorderSizePixel = 0,
		ScrollBarThickness = Width,
		CanvasSize = UDim2.new(0, 0, 0, 0)
	})
	return ScrollFrame
end)

CreateElement("Image", function(ImageID)
	local IconImage = GetIcon(ImageID)
	local ImageNew = Create("ImageLabel", {
		Image = IconImage or (IsImageAsset(ImageID) and ImageID or ""),
		BackgroundTransparency = 1
	})

	return ImageNew
end)

CreateElement("ImageButton", function(ImageID)
	local IconImage = GetIcon(ImageID)
	local Image = Create("ImageButton", {
		Image = IconImage or (IsImageAsset(ImageID) and ImageID or ""),
		BackgroundTransparency = 1
	})
	return Image
end)

CreateElement("Label", function(Text, TextSize, Transparency)
	local Label = Create("TextLabel", {
		Text = Text or "",
		TextColor3 = Color3.fromRGB(240, 240, 240),
		TextTransparency = Transparency or 0,
		TextSize = TextSize or 15,
		Font = Enum.Font.Gotham,
		RichText = true,
		BackgroundTransparency = 1,
		TextXAlignment = Enum.TextXAlignment.Left
	})
	return Label
end)

local NotificationHolder = SetProps(SetChildren(MakeElement("TFrame"), {
	SetProps(MakeElement("List"), {
		HorizontalAlignment = Enum.HorizontalAlignment.Center,
		SortOrder = Enum.SortOrder.LayoutOrder,
		VerticalAlignment = Enum.VerticalAlignment.Bottom,
		Padding = UDim.new(0, 5)
	})
}), {
	Position = UDim2.new(1, -25, 1, -25),
	Size = UDim2.new(0, 300, 1, -25),
	AnchorPoint = Vector2.new(1, 1),
	Parent = Orion
})

function OrionLib:MakeNotification(NotificationConfig)
	spawn(function()
		NotificationConfig.Name = NotificationConfig.Name or "Notification"
		NotificationConfig.Content = NotificationConfig.Content or "Test"
		NotificationConfig.Image = NotificationConfig.Image or "rbxassetid://4384403532"
		NotificationConfig.Time = NotificationConfig.Time or 15

		local NotificationParent = SetProps(MakeElement("TFrame"), {
			Size = UDim2.new(1, 0, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			Parent = NotificationHolder
		})

		local NotificationFrame = SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(18, 22, 32), 0, 10), {
			Parent = NotificationParent, 
			Size = UDim2.new(1, 0, 0, 0),
			Position = UDim2.new(1, -55, 0, 0),
			BackgroundTransparency = 0,
			AutomaticSize = Enum.AutomaticSize.Y
		}), {
			MakeElement("Stroke", Color3.fromRGB(48, 58, 82), 1.2),
			MakeElement("Padding", 12, 12, 12, 12),
			SetProps(MakeElement("Image", NotificationConfig.Image), {
				Size = UDim2.new(0, 20, 0, 20),
				ImageColor3 = Color3.fromRGB(240, 240, 240),
				Name = "Icon"
			}),
			SetProps(MakeElement("Label", NotificationConfig.Name, 15), {
				Size = UDim2.new(1, -30, 0, 20),
				Position = UDim2.new(0, 30, 0, 0),
				Font = Enum.Font.GothamBold,
				Name = "Title"
			}),
			SetProps(MakeElement("Label", NotificationConfig.Content, 14), {
				Size = UDim2.new(1, 0, 0, 0),
				Position = UDim2.new(0, 0, 0, 25),
				Font = Enum.Font.GothamSemibold,
				Name = "Content",
				AutomaticSize = Enum.AutomaticSize.Y,
				TextColor3 = Color3.fromRGB(170, 180, 205),
				TextWrapped = true
			})
		})

		TweenService:Create(NotificationFrame, TweenInfo.new(0.5, Enum.EasingStyle.Quint), {Position = UDim2.new(0, 0, 0, 0)}):Play()

		wait(NotificationConfig.Time - 0.88)
		TweenService:Create(NotificationFrame.Icon, TweenInfo.new(0.4, Enum.EasingStyle.Quint), {ImageTransparency = 1}):Play()
		TweenService:Create(NotificationFrame, TweenInfo.new(0.8, Enum.EasingStyle.Quint), {BackgroundTransparency = 0.6}):Play()
		wait(0.3)
		TweenService:Create(NotificationFrame.UIStroke, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {Transparency = 0.9}):Play()
		TweenService:Create(NotificationFrame.Title, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 0.4}):Play()
		TweenService:Create(NotificationFrame.Content, TweenInfo.new(0.6, Enum.EasingStyle.Quint), {TextTransparency = 0.5}):Play()
		wait(0.05)

		NotificationFrame:TweenPosition(UDim2.new(1, 20, 0, 0),'In','Quint',0.8,true)
		wait(1.35)
		NotificationFrame:Destroy()
	end)
end    

function OrionLib:Init()
	if OrionLib.SaveCfg then	
		pcall(function()
			if isfile(OrionLib.Folder .. "/" .. game.GameId .. ".txt") then
				LoadCfg(readfile(OrionLib.Folder .. "/" .. game.GameId .. ".txt"))
				OrionLib:MakeNotification({
					Name = "Configuration",
					Content = "Auto-loaded configuration for the game " .. game.GameId .. ".",
					Time = 5
				})
			end
		end)		
	end	
end	

function OrionLib:MakeWindow(WindowConfig)
	local FirstTab = true
	local Minimized = false
	local Loaded = false
	local UIHidden = false

	WindowConfig = WindowConfig or {}
	WindowConfig.Name = WindowConfig.Name or "Orion Library"
	WindowConfig.ConfigFolder = WindowConfig.ConfigFolder or WindowConfig.Name
	WindowConfig.SaveConfig = WindowConfig.SaveConfig or false
	WindowConfig.HidePremium = WindowConfig.HidePremium or false
	if WindowConfig.IntroEnabled == nil then
		WindowConfig.IntroEnabled = true
	end
	WindowConfig.IntroText = WindowConfig.IntroText or "Orion Library"
	WindowConfig.CloseCallback = WindowConfig.CloseCallback or function() end
	WindowConfig.ShowIcon = WindowConfig.ShowIcon or false
	WindowConfig.Icon = WindowConfig.Icon or "rbxassetid://8834748103"
	WindowConfig.IntroIcon = WindowConfig.IntroIcon or "rbxassetid://8834748103"
	OrionLib.Folder = WindowConfig.ConfigFolder
	OrionLib.SaveCfg = WindowConfig.SaveConfig

	if WindowConfig.SaveConfig then
		if not isfolder(WindowConfig.ConfigFolder) then
			makefolder(WindowConfig.ConfigFolder)
		end	
	end

	local TabHolder = AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame", Color3.fromRGB(255, 255, 255), 4), {
		Size = UDim2.new(1, 0, 1, -50)
	}), {
		MakeElement("List"),
		MakeElement("Padding", 8, 0, 0, 8)
	}), "Divider")

	AddConnection(TabHolder.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
		pcall(function()
			TabHolder.CanvasSize = UDim2.new(0, 0, 0, TabHolder.UIListLayout.AbsoluteContentSize.Y + 16)
		end)
	end)

	local CloseBtn = SetChildren(SetProps(MakeElement("Button"), {
		Size = UDim2.new(0.5, 0, 1, 0),
		Position = UDim2.new(0.5, 0, 0, 0),
		BackgroundTransparency = 1
	}), {
		AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://7072725342"), {
			Position = UDim2.new(0, 9, 0, 6),
			Size = UDim2.new(0, 18, 0, 18)
		}), "Text")
	})

	local MinimizeBtn = SetChildren(SetProps(MakeElement("Button"), {
		Size = UDim2.new(0.5, 0, 1, 0),
		BackgroundTransparency = 1
	}), {
		AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://7072719338"), {
			Position = UDim2.new(0, 9, 0, 6),
			Size = UDim2.new(0, 18, 0, 18),
			Name = "Ico"
		}), "Text")
	})

	local DragPoint = SetProps(MakeElement("TFrame"), {
		Size = UDim2.new(1, 0, 0, 50)
	})

	local WindowStuff = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 10), {
		Size = UDim2.new(0, 150, 1, -50),
		Position = UDim2.new(0, 0, 0, 50)
	}), {
		AddThemeObject(SetProps(MakeElement("Frame"), {
			Size = UDim2.new(1, 0, 0, 10),
			Position = UDim2.new(0, 0, 0, 0)
		}), "Second"), 
		AddThemeObject(SetProps(MakeElement("Frame"), {
			Size = UDim2.new(0, 10, 1, 0),
			Position = UDim2.new(1, -10, 0, 0)
		}), "Second"), 
		AddThemeObject(SetProps(MakeElement("Frame"), {
			Size = UDim2.new(0, 1, 1, 0),
			Position = UDim2.new(1, -1, 0, 0)
		}), "Stroke"), 
		TabHolder,
		SetChildren(SetProps(MakeElement("TFrame"), {
			Size = UDim2.new(1, 0, 0, 50),
			Position = UDim2.new(0, 0, 1, -50)
		}), {
			AddThemeObject(SetProps(MakeElement("Frame"), {
				Size = UDim2.new(1, 0, 0, 1)
			}), "Stroke"), 
			AddThemeObject(SetChildren(SetProps(MakeElement("Frame"), {
				AnchorPoint = Vector2.new(0, 0.5),
				Size = UDim2.new(0, 32, 0, 32),
				Position = UDim2.new(0, 10, 0.5, 0)
			}), {
				SetProps(MakeElement("Image", "https://www.roblox.com/headshot-thumbnail/image?userId=".. LocalPlayer.UserId .."&width=420&height=420&format=png"), {
					Size = UDim2.new(1, 0, 1, 0)
				}),
				AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://4031889928"), {
					Size = UDim2.new(1, 0, 1, 0),
				}), "Second"),
				MakeElement("Corner", 1)
			}), "Divider"),
			SetChildren(SetProps(MakeElement("TFrame"), {
				AnchorPoint = Vector2.new(0, 0.5),
				Size = UDim2.new(0, 32, 0, 32),
				Position = UDim2.new(0, 10, 0.5, 0)
			}), {
				AddThemeObject(MakeElement("Stroke"), "Stroke"),
				MakeElement("Corner", 1)
			}),
			AddThemeObject(SetProps(MakeElement("Label", LocalPlayer.DisplayName, WindowConfig.HidePremium and 14 or 13), {
				Size = UDim2.new(1, -60, 0, 13),
				Position = WindowConfig.HidePremium and UDim2.new(0, 50, 0, 19) or UDim2.new(0, 50, 0, 12),
				Font = Enum.Font.GothamBold,
				ClipsDescendants = true
			}), "Text"),
			AddThemeObject(SetProps(MakeElement("Label", "", 12), {
				Size = UDim2.new(1, -60, 0, 12),
				Position = UDim2.new(0, 50, 1, -25),
				Visible = not WindowConfig.HidePremium
			}), "TextDark")
		}),
	}), "Second")

	local WindowName = AddThemeObject(SetProps(MakeElement("Label", WindowConfig.Name, 14), {
		Size = UDim2.new(1, -30, 2, 0),
		Position = UDim2.new(0, 25, 0, -24),
		Font = Enum.Font.GothamBlack,
		TextSize = 22
	}), "Text")

	local WindowNameGradient = Create("UIGradient", {
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 96)),
			ColorSequenceKeypoint.new(0.55, Color3.fromRGB(255, 255, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(72, 220, 255)),
		}),
		Rotation = 12,
	})
	WindowNameGradient.Parent = WindowName

	local WindowTopBarLine = AddThemeObject(SetProps(MakeElement("Frame"), {
		Size = UDim2.new(1, 0, 0, 1),
		Position = UDim2.new(0, 0, 1, -1)
	}), "Stroke")

	local MainWindow = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 12), {
		Parent = Orion,
		Position = UDim2.new(0.5, -325, 0.5, -196),
		Size = UDim2.new(0, 650, 0, 392),
		ClipsDescendants = true
	}), {
		--SetProps(MakeElement("Image", "rbxassetid://3523728077"), {
		--	AnchorPoint = Vector2.new(0.5, 0.5),
		--	Position = UDim2.new(0.5, 0, 0.5, 0),
		--	Size = UDim2.new(1, 80, 1, 320),
		--	ImageColor3 = Color3.fromRGB(33, 33, 33),
		--	ImageTransparency = 0.7
		--}),
		SetChildren(SetProps(MakeElement("TFrame"), {
			Size = UDim2.new(1, 0, 0, 50),
			Name = "TopBar"
		}), {
			WindowName,
			WindowTopBarLine,
			AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 7), {
				Size = UDim2.new(0, 70, 0, 30),
				Position = UDim2.new(1, -90, 0, 10)
			}), {
				AddThemeObject(MakeElement("Stroke"), "Stroke"),
				AddThemeObject(SetProps(MakeElement("Frame"), {
					Size = UDim2.new(0, 1, 1, 0),
					Position = UDim2.new(0.5, 0, 0, 0)
				}), "Stroke"), 
				CloseBtn,
				MinimizeBtn
			}), "Second"), 
		}),
		DragPoint,
		WindowStuff
	}), "Main")

	if WindowConfig.ShowIcon then
		WindowName.Position = UDim2.new(0, 50, 0, -24)
		local WindowIcon = SetProps(MakeElement("Image", WindowConfig.Icon), {
			Size = UDim2.new(0, 20, 0, 20),
			Position = UDim2.new(0, 25, 0, 15)
		})
		WindowIcon.Parent = MainWindow.TopBar
	end	

	MakeDraggable(DragPoint, MainWindow)

	AddConnection(CloseBtn.MouseButton1Up, function()
		MainWindow.Visible = false
		UIHidden = true
		OrionLib:MakeNotification({
			Name = "Interface Hidden",
			Content = "Tap RightShift to reopen the interface",
			Time = 5
		})
		WindowConfig.CloseCallback()
	end)

	AddConnection(UserInputService.InputBegan, function(Input)
		if Input.KeyCode == Enum.KeyCode.RightShift and UIHidden then
			MainWindow.Visible = true
		end
	end)

	AddConnection(MinimizeBtn.MouseButton1Up, function()
		if Minimized then
			TweenService:Create(MainWindow, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, 650, 0, 392)}):Play()
			MinimizeBtn.Ico.Image = "rbxassetid://7072719338"
			wait(.02)
			MainWindow.ClipsDescendants = false
			WindowStuff.Visible = true
			WindowTopBarLine.Visible = true
		else
			MainWindow.ClipsDescendants = true
			WindowTopBarLine.Visible = false
			MinimizeBtn.Ico.Image = "rbxassetid://7072720870"

			TweenService:Create(MainWindow, TweenInfo.new(0.5, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, WindowName.TextBounds.X + 140, 0, 50)}):Play()
			wait(0.1)
			WindowStuff.Visible = false	
		end
		Minimized = not Minimized    
	end)

	local function LoadSequence()
		MainWindow.Visible = false
		local LoadSequenceLogo = SetProps(MakeElement("Image", WindowConfig.IntroIcon), {
			Parent = Orion,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 0, 0.4, 0),
			Size = UDim2.new(0, 28, 0, 28),
			ImageColor3 = Color3.fromRGB(255, 255, 255),
			ImageTransparency = 1
		})

		local LoadSequenceText = SetProps(MakeElement("Label", WindowConfig.IntroText, 14), {
			Parent = Orion,
			Size = UDim2.new(1, 0, 1, 0),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.new(0.5, 19, 0.5, 0),
			TextXAlignment = Enum.TextXAlignment.Center,
			Font = Enum.Font.GothamBold,
			TextTransparency = 1
		})

		TweenService:Create(LoadSequenceLogo, TweenInfo.new(.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {ImageTransparency = 0, Position = UDim2.new(0.5, 0, 0.5, 0)}):Play()
		wait(0.8)
		TweenService:Create(LoadSequenceLogo, TweenInfo.new(.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Position = UDim2.new(0.5, -(LoadSequenceText.TextBounds.X/2), 0.5, 0)}):Play()
		wait(0.3)
		TweenService:Create(LoadSequenceText, TweenInfo.new(.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
		wait(2)
		TweenService:Create(LoadSequenceText, TweenInfo.new(.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {TextTransparency = 1}):Play()
		MainWindow.Visible = true
		LoadSequenceLogo:Destroy()
		LoadSequenceText:Destroy()
	end 

	if WindowConfig.IntroEnabled then
		LoadSequence()
	end	

	local TabFunction = {}
	function TabFunction:MakeTab(TabConfig)
		TabConfig = TabConfig or {}
		TabConfig.Name = TabConfig.Name or "Tab"
		TabConfig.Icon = TabConfig.Icon or ""
		TabConfig.PremiumOnly = TabConfig.PremiumOnly or false

		local TabFrame = SetChildren(SetProps(MakeElement("Button"), {
			Size = UDim2.new(1, 0, 0, 30),
			Parent = TabHolder
		}), {
			AddThemeObject(SetProps(MakeElement("Image", TabConfig.Icon), {
				AnchorPoint = Vector2.new(0, 0.5),
				Size = UDim2.new(0, 18, 0, 18),
				Position = UDim2.new(0, 10, 0.5, 0),
				ImageTransparency = 0.4,
				Name = "Ico"
			}), "Text"),
			AddThemeObject(SetProps(MakeElement("Label", TabConfig.Name, 14), {
				Size = UDim2.new(1, -35, 1, 0),
				Position = UDim2.new(0, 35, 0, 0),
				Font = Enum.Font.GothamSemibold,
				TextTransparency = 0.4,
				Name = "Title"
			}), "Text")
		})

		if GetIcon(TabConfig.Icon) ~= nil then
			TabFrame.Ico.Image = GetIcon(TabConfig.Icon)
		end	

		local Container = AddThemeObject(SetChildren(SetProps(MakeElement("ScrollFrame", Color3.fromRGB(255, 255, 255), 5), {
			Size = UDim2.new(1, -150, 1, -50),
			Position = UDim2.new(0, 150, 0, 50),
			Parent = MainWindow,
			Visible = false,
			Name = "ItemContainer"
		}), {
			MakeElement("List", 0, 6),
			MakeElement("Padding", 15, 10, 10, 15)
		}), "Divider")

		AddConnection(Container.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
			pcall(function()
				Container.CanvasSize = UDim2.new(0, 0, 0, Container.UIListLayout.AbsoluteContentSize.Y + 30)
			end)
		end)

		if FirstTab then
			FirstTab = false
			TabFrame.Ico.ImageTransparency = 0
			TabFrame.Title.TextTransparency = 0
			TabFrame.Title.Font = Enum.Font.GothamBlack
			Container.Visible = true
		end    

		AddConnection(TabFrame.MouseButton1Click, function()
			for _, Tab in next, TabHolder:GetChildren() do
				if Tab:IsA("TextButton") then
					Tab.Title.Font = Enum.Font.GothamSemibold
					TweenService:Create(Tab.Ico, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {ImageTransparency = 0.4}):Play()
					TweenService:Create(Tab.Title, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextTransparency = 0.4}):Play()
				end    
			end
			for _, ItemContainer in next, MainWindow:GetChildren() do
				if ItemContainer.Name == "ItemContainer" then
					ItemContainer.Visible = false
				end    
			end  
			TweenService:Create(TabFrame.Ico, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {ImageTransparency = 0}):Play()
			TweenService:Create(TabFrame.Title, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {TextTransparency = 0}):Play()
			TabFrame.Title.Font = Enum.Font.GothamBlack
			Container.Visible = true   
		end)

		local function GetElements(ItemParent)
			local ElementFunction = {}
			function ElementFunction:AddLabel(Text)
				local LabelFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size = UDim2.new(1, 0, 0, 30),
					BackgroundTransparency = 0.7,
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", Text, 15), {
						Size = UDim2.new(1, -12, 1, 0),
						Position = UDim2.new(0, 12, 0, 0),
						Font = Enum.Font.GothamBold,
						Name = "Content"
					}), "Text"),
					AddThemeObject(MakeElement("Stroke"), "Stroke")
				}), "Second")

				local LabelFunction = {}
				function LabelFunction:Set(ToChange)
					LabelFrame.Content.Text = ToChange
				end
				return LabelFunction
			end
			function ElementFunction:AddParagraph(Text, Content)
				Text = Text or "Text"
				Content = Content or "Content"

				local ParagraphFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size = UDim2.new(1, 0, 0, 30),
					BackgroundTransparency = 0.7,
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", Text, 15), {
						Size = UDim2.new(1, -12, 0, 14),
						Position = UDim2.new(0, 12, 0, 10),
						Font = Enum.Font.GothamBold,
						Name = "Title"
					}), "Text"),
					AddThemeObject(SetProps(MakeElement("Label", "", 13), {
						Size = UDim2.new(1, -24, 0, 0),
						Position = UDim2.new(0, 12, 0, 26),
						Font = Enum.Font.GothamSemibold,
						Name = "Content",
						TextWrapped = true
					}), "TextDark"),
					AddThemeObject(MakeElement("Stroke"), "Stroke")
				}), "Second")

				AddConnection(ParagraphFrame.Content:GetPropertyChangedSignal("Text"), function()
					ParagraphFrame.Content.Size = UDim2.new(1, -24, 0, ParagraphFrame.Content.TextBounds.Y)
					ParagraphFrame.Size = UDim2.new(1, 0, 0, ParagraphFrame.Content.TextBounds.Y + 35)
				end)

				ParagraphFrame.Content.Text = Content

				local ParagraphFunction = {}
				function ParagraphFunction:Set(ToChange)
					ParagraphFrame.Content.Text = ToChange
				end
				return ParagraphFunction
			end    
			function ElementFunction:AddButton(ButtonConfig)
				ButtonConfig = ButtonConfig or {}
				ButtonConfig.Name = ButtonConfig.Name or "Button"
				ButtonConfig.Callback = ButtonConfig.Callback or function() end
				ButtonConfig.Icon = ButtonConfig.Icon or "rbxassetid://3944703587"

				local Button = {}

				local Click = SetProps(MakeElement("Button"), {
					Size = UDim2.new(1, 0, 1, 0)
				})

				local ButtonFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size = UDim2.new(1, 0, 0, 33),
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", ButtonConfig.Name, 15), {
						Size = UDim2.new(1, -12, 1, 0),
						Position = UDim2.new(0, 12, 0, 0),
						Font = Enum.Font.GothamBold,
						Name = "Content"
					}), "Text"),
					AddThemeObject(SetProps(MakeElement("Image", ButtonConfig.Icon), {
						Size = UDim2.new(0, 20, 0, 20),
						Position = UDim2.new(1, -30, 0, 7),
					}), "TextDark"),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					Click
				}), "Second")

				AddConnection(Click.MouseEnter, function()
					pcall(function()
						TweenService:Create(ButtonFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(OrionLib.Themes[OrionLib.SelectedTheme].Second.R * 255 + 3, OrionLib.Themes[OrionLib.SelectedTheme].Second.G * 255 + 3, OrionLib.Themes[OrionLib.SelectedTheme].Second.B * 255 + 3)}):Play()
					end)
				end)

				AddConnection(Click.MouseLeave, function()
					pcall(function()
						TweenService:Create(ButtonFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = OrionLib.Themes[OrionLib.SelectedTheme].Second}):Play()
					end)
				end)

				AddConnection(Click.MouseButton1Up, function()
					pcall(function()
						TweenService:Create(ButtonFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(OrionLib.Themes[OrionLib.SelectedTheme].Second.R * 255 + 3, OrionLib.Themes[OrionLib.SelectedTheme].Second.G * 255 + 3, OrionLib.Themes[OrionLib.SelectedTheme].Second.B * 255 + 3)}):Play()
					end)
					spawn(function()
						ButtonConfig.Callback()
					end)
				end)

				AddConnection(Click.MouseButton1Down, function()
					pcall(function()
						TweenService:Create(ButtonFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(OrionLib.Themes[OrionLib.SelectedTheme].Second.R * 255 + 6, OrionLib.Themes[OrionLib.SelectedTheme].Second.G * 255 + 6, OrionLib.Themes[OrionLib.SelectedTheme].Second.B * 255 + 6)}):Play()
					end)
				end)

				function Button:Set(ButtonText)
					ButtonFrame.Content.Text = ButtonText
				end	

				return Button
			end    
			function ElementFunction:AddToggle(ToggleConfig)
				ToggleConfig = ToggleConfig or {}
				ToggleConfig.Name = ToggleConfig.Name or "Toggle"
				ToggleConfig.Default = ToggleConfig.Default or false
				ToggleConfig.Callback = ToggleConfig.Callback or function() end
				ToggleConfig.Color = ToggleConfig.Color or Color3.fromRGB(9, 99, 195)
				ToggleConfig.Flag = ToggleConfig.Flag or nil
				ToggleConfig.Save = ToggleConfig.Save or false

				local Toggle = {Value = ToggleConfig.Default, Save = ToggleConfig.Save}

				local Click = SetProps(MakeElement("Button"), {
					Size = UDim2.new(1, 0, 1, 0)
				})

				local ToggleBox = SetChildren(SetProps(MakeElement("RoundFrame", ToggleConfig.Color, 0, 4), {
					Size = UDim2.new(0, 24, 0, 24),
					Position = UDim2.new(1, -24, 0.5, 0),
					AnchorPoint = Vector2.new(0.5, 0.5)
				}), {
					SetProps(MakeElement("Stroke"), {
						Color = ToggleConfig.Color,
						Name = "Stroke",
						Transparency = 0.5
					}),
					SetProps(MakeElement("Image", "rbxassetid://3944680095"), {
						Size = UDim2.new(0, 20, 0, 20),
						AnchorPoint = Vector2.new(0.5, 0.5),
						Position = UDim2.new(0.5, 0, 0.5, 0),
						ImageColor3 = Color3.fromRGB(255, 255, 255),
						Name = "Ico"
					}),
				})

				local ToggleFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size = UDim2.new(1, 0, 0, 38),
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", ToggleConfig.Name, 15), {
						Size = UDim2.new(1, -12, 1, 0),
						Position = UDim2.new(0, 12, 0, 0),
						Font = Enum.Font.GothamBold,
						Name = "Content"
					}), "Text"),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					ToggleBox,
					Click
				}), "Second")

				function Toggle:Set(Value)
					Toggle.Value = Value
					TweenService:Create(ToggleBox, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Toggle.Value and ToggleConfig.Color or OrionLib.Themes.Default.Divider}):Play()
					TweenService:Create(ToggleBox.Stroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Color = Toggle.Value and ToggleConfig.Color or OrionLib.Themes.Default.Stroke}):Play()
					TweenService:Create(ToggleBox.Ico, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {ImageTransparency = Toggle.Value and 0 or 1, Size = Toggle.Value and UDim2.new(0, 20, 0, 20) or UDim2.new(0, 8, 0, 8)}):Play()
					if not _G.applyingConfig then
						ToggleConfig.Callback(Toggle.Value)
					end
				end    

				Toggle:Set(Toggle.Value)

				AddConnection(Click.MouseEnter, function()
					TweenService:Create(ToggleFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(OrionLib.Themes[OrionLib.SelectedTheme].Second.R * 255 + 3, OrionLib.Themes[OrionLib.SelectedTheme].Second.G * 255 + 3, OrionLib.Themes[OrionLib.SelectedTheme].Second.B * 255 + 3)}):Play()
				end)

				AddConnection(Click.MouseLeave, function()
					TweenService:Create(ToggleFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = OrionLib.Themes[OrionLib.SelectedTheme].Second}):Play()
				end)

				AddConnection(Click.MouseButton1Up, function()
					TweenService:Create(ToggleFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(OrionLib.Themes[OrionLib.SelectedTheme].Second.R * 255 + 3, OrionLib.Themes[OrionLib.SelectedTheme].Second.G * 255 + 3, OrionLib.Themes[OrionLib.SelectedTheme].Second.B * 255 + 3)}):Play()
					SaveCfg(game.GameId)
					Toggle:Set(not Toggle.Value)
				end)

				AddConnection(Click.MouseButton1Down, function()
					TweenService:Create(ToggleFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(OrionLib.Themes[OrionLib.SelectedTheme].Second.R * 255 + 6, OrionLib.Themes[OrionLib.SelectedTheme].Second.G * 255 + 6, OrionLib.Themes[OrionLib.SelectedTheme].Second.B * 255 + 6)}):Play()
				end)

				if ToggleConfig.Flag then
					OrionLib.Flags[ToggleConfig.Flag] = Toggle
				end	
				return Toggle
			end  
			function ElementFunction:AddSlider(SliderConfig)
				SliderConfig = SliderConfig or {}
				SliderConfig.Name = SliderConfig.Name or "Slider"
				SliderConfig.Min = SliderConfig.Min or 0
				SliderConfig.Max = SliderConfig.Max or 100
				SliderConfig.Increment = SliderConfig.Increment or 1
				SliderConfig.Default = SliderConfig.Default or 50
				SliderConfig.Callback = SliderConfig.Callback or function() end
				SliderConfig.ValueName = SliderConfig.ValueName or ""
				SliderConfig.Color = SliderConfig.Color or Color3.fromRGB(9, 149, 98)
				SliderConfig.Flag = SliderConfig.Flag or nil
				SliderConfig.Save = SliderConfig.Save or false

				local Slider = {Value = SliderConfig.Default, Save = SliderConfig.Save}
				local Dragging = false

				local SliderDrag = SetChildren(SetProps(MakeElement("RoundFrame", SliderConfig.Color, 0, 5), {
					Size = UDim2.new(0, 0, 1, 0),
					BackgroundTransparency = 0.3,
					ClipsDescendants = true
				}), {
					AddThemeObject(SetProps(MakeElement("Label", "value", 13), {
						Size = UDim2.new(1, -12, 0, 14),
						Position = UDim2.new(0, 12, 0, 6),
						Font = Enum.Font.GothamBold,
						Name = "Value",
						TextTransparency = 0
					}), "Text")
				})

				local SliderBar = SetChildren(SetProps(MakeElement("RoundFrame", SliderConfig.Color, 0, 5), {
					Size = UDim2.new(1, -24, 0, 26),
					Position = UDim2.new(0, 12, 0, 30),
					BackgroundTransparency = 0.9
				}), {
					SetProps(MakeElement("Stroke"), {
						Color = SliderConfig.Color
					}),
					AddThemeObject(SetProps(MakeElement("Label", "value", 13), {
						Size = UDim2.new(1, -12, 0, 14),
						Position = UDim2.new(0, 12, 0, 6),
						Font = Enum.Font.GothamBold,
						Name = "Value",
						TextTransparency = 0.8
					}), "Text"),
					SliderDrag
				})

				local SliderFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 4), {
					Size = UDim2.new(1, 0, 0, 65),
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", SliderConfig.Name, 15), {
						Size = UDim2.new(1, -12, 0, 14),
						Position = UDim2.new(0, 12, 0, 10),
						Font = Enum.Font.GothamBold,
						Name = "Content"
					}), "Text"),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					SliderBar
				}), "Second")

				SliderBar.InputBegan:Connect(function(Input)
					if Input.UserInputType == Enum.UserInputType.MouseButton1 then 
						Dragging = true 
					end 
				end)
				SliderBar.InputEnded:Connect(function(Input) 
					if Input.UserInputType == Enum.UserInputType.MouseButton1 then 
						Dragging = false 
					end 
				end)

				UserInputService.InputChanged:Connect(function(Input)
					if Dragging and Input.UserInputType == Enum.UserInputType.MouseMovement then 
						local SizeScale = math.clamp((Input.Position.X - SliderBar.AbsolutePosition.X) / SliderBar.AbsoluteSize.X, 0, 1)
						Slider:Set(SliderConfig.Min + ((SliderConfig.Max - SliderConfig.Min) * SizeScale)) 
						SaveCfg(game.GameId)
					end
				end)

				function Slider:Set(Value)
					self.Value = math.clamp(Round(Value, SliderConfig.Increment), SliderConfig.Min, SliderConfig.Max)
					TweenService:Create(SliderDrag,TweenInfo.new(.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),{Size = UDim2.fromScale((self.Value - SliderConfig.Min) / (SliderConfig.Max - SliderConfig.Min), 1)}):Play()
					SliderBar.Value.Text = tostring(self.Value) .. " " .. SliderConfig.ValueName
					SliderDrag.Value.Text = tostring(self.Value) .. " " .. SliderConfig.ValueName
					if not _G.applyingConfig then
						SliderConfig.Callback(self.Value)
					end
				end      

				Slider:Set(Slider.Value)
				if SliderConfig.Flag then				
					OrionLib.Flags[SliderConfig.Flag] = Slider
				end
				return Slider
			end  
			function ElementFunction:AddDropdown(DropdownConfig)
				DropdownConfig = DropdownConfig or {}
				DropdownConfig.Name = DropdownConfig.Name or "Dropdown"
				DropdownConfig.Options = DropdownConfig.Options or {}
				DropdownConfig.Default = DropdownConfig.Default or ""
				DropdownConfig.Callback = DropdownConfig.Callback or function() end
				DropdownConfig.Flag = DropdownConfig.Flag or nil
				DropdownConfig.Save = DropdownConfig.Save or false

				local Dropdown = {Value = DropdownConfig.Default, Options = DropdownConfig.Options, Buttons = {}, Toggled = false, Type = "Dropdown", Save = DropdownConfig.Save}
				local MaxElements = 5

				if not table.find(Dropdown.Options, Dropdown.Value) then
					Dropdown.Value = "..."
				end

				local DropdownList = MakeElement("List")

				local DropdownContainer = AddThemeObject(SetProps(SetChildren(MakeElement("ScrollFrame", Color3.fromRGB(40, 40, 40), 4), {
					DropdownList
				}), {
					Parent = ItemParent,
					Position = UDim2.new(0, 0, 0, 38),
					Size = UDim2.new(1, 0, 1, -38),
					ClipsDescendants = true
				}), "Divider")

				local Click = SetProps(MakeElement("Button"), {
					Size = UDim2.new(1, 0, 1, 0)
				})

				local DropdownFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size = UDim2.new(1, 0, 0, 38),
					Parent = ItemParent,
					ClipsDescendants = true
				}), {
					DropdownContainer,
					SetProps(SetChildren(MakeElement("TFrame"), {
						AddThemeObject(SetProps(MakeElement("Label", DropdownConfig.Name, 15), {
							Size = UDim2.new(1, -12, 1, 0),
							Position = UDim2.new(0, 12, 0, 0),
							Font = Enum.Font.GothamBold,
							Name = "Content"
						}), "Text"),
						AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://7072706796"), {
							Size = UDim2.new(0, 20, 0, 20),
							AnchorPoint = Vector2.new(0, 0.5),
							Position = UDim2.new(1, -30, 0.5, 0),
							ImageColor3 = Color3.fromRGB(240, 240, 240),
							Name = "Ico"
						}), "TextDark"),
						AddThemeObject(SetProps(MakeElement("Label", "Selected", 13), {
							Size = UDim2.new(1, -40, 1, 0),
							Font = Enum.Font.Gotham,
							Name = "Selected",
							TextXAlignment = Enum.TextXAlignment.Right
						}), "TextDark"),
						AddThemeObject(SetProps(MakeElement("Frame"), {
							Size = UDim2.new(1, 0, 0, 1),
							Position = UDim2.new(0, 0, 1, -1),
							Name = "Line",
							Visible = false
						}), "Stroke"), 
						Click
					}), {
						Size = UDim2.new(1, 0, 0, 38),
						ClipsDescendants = true,
						Name = "F"
					}),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					MakeElement("Corner")
				}), "Second")

				AddConnection(DropdownList:GetPropertyChangedSignal("AbsoluteContentSize"), function()
					DropdownContainer.CanvasSize = UDim2.new(0, 0, 0, DropdownList.AbsoluteContentSize.Y)
				end)  

				local function AddOptions(Options)
					for _, Option in pairs(Options) do
						local OptionBtn = AddThemeObject(SetProps(SetChildren(MakeElement("Button", Color3.fromRGB(40, 40, 40)), {
							MakeElement("Corner", 0, 6),
							AddThemeObject(SetProps(MakeElement("Label", Option, 13, 0.4), {
								Position = UDim2.new(0, 8, 0, 0),
								Size = UDim2.new(1, -8, 1, 0),
								Name = "Title"
							}), "Text")
						}), {
							Parent = DropdownContainer,
							Size = UDim2.new(1, 0, 0, 28),
							BackgroundTransparency = 1,
							ClipsDescendants = true
						}), "Divider")

						AddConnection(OptionBtn.MouseButton1Click, function()
							Dropdown:Set(Option)
							SaveCfg(game.GameId)
						end)

						Dropdown.Buttons[Option] = OptionBtn
					end
				end	

				function Dropdown:Refresh(Options, Delete)
					if Delete then
						for _,v in pairs(Dropdown.Buttons) do
							v:Destroy()
						end    
						table.clear(Dropdown.Options)
						table.clear(Dropdown.Buttons)
					end
					Dropdown.Options = Options
					AddOptions(Dropdown.Options)
				end  

				function Dropdown:Set(Value)
					if not table.find(Dropdown.Options, Value) then
						Dropdown.Value = "..."
						DropdownFrame.F.Selected.Text = Dropdown.Value
						for _, v in pairs(Dropdown.Buttons) do
							TweenService:Create(v,TweenInfo.new(.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),{BackgroundTransparency = 1}):Play()
							TweenService:Create(v.Title,TweenInfo.new(.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),{TextTransparency = 0.4}):Play()
						end	
						return
					end

					Dropdown.Value = Value
					DropdownFrame.F.Selected.Text = Dropdown.Value

					for _, v in pairs(Dropdown.Buttons) do
						TweenService:Create(v,TweenInfo.new(.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),{BackgroundTransparency = 1}):Play()
						TweenService:Create(v.Title,TweenInfo.new(.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),{TextTransparency = 0.4}):Play()
					end	
					TweenService:Create(Dropdown.Buttons[Value],TweenInfo.new(.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),{BackgroundTransparency = 0}):Play()
					TweenService:Create(Dropdown.Buttons[Value].Title,TweenInfo.new(.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),{TextTransparency = 0}):Play()
					return DropdownConfig.Callback(Dropdown.Value)
				end

				AddConnection(Click.MouseButton1Click, function()
					Dropdown.Toggled = not Dropdown.Toggled
					DropdownFrame.F.Line.Visible = Dropdown.Toggled
					TweenService:Create(DropdownFrame.F.Ico,TweenInfo.new(.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),{Rotation = Dropdown.Toggled and 180 or 0}):Play()
					if #Dropdown.Options > MaxElements then
						TweenService:Create(DropdownFrame,TweenInfo.new(.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),{Size = Dropdown.Toggled and UDim2.new(1, 0, 0, 38 + (MaxElements * 28)) or UDim2.new(1, 0, 0, 38)}):Play()
					else
						TweenService:Create(DropdownFrame,TweenInfo.new(.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),{Size = Dropdown.Toggled and UDim2.new(1, 0, 0, DropdownList.AbsoluteContentSize.Y + 38) or UDim2.new(1, 0, 0, 38)}):Play()
					end
				end)

				Dropdown:Refresh(Dropdown.Options, false)
				Dropdown:Set(Dropdown.Value)
				if DropdownConfig.Flag then				
					OrionLib.Flags[DropdownConfig.Flag] = Dropdown
				end
				return Dropdown
			end
			function ElementFunction:AddBind(BindConfig)
				BindConfig.Name = BindConfig.Name or "Bind"
				BindConfig.Default = BindConfig.Default or Enum.KeyCode.Unknown
				BindConfig.Hold = BindConfig.Hold or false
				BindConfig.Callback = BindConfig.Callback or function() end
				BindConfig.Flag = BindConfig.Flag or nil
				BindConfig.Save = BindConfig.Save or false

				local Bind = {Value, Binding = false, Type = "Bind", Save = BindConfig.Save}
				local Holding = false

				local Click = SetProps(MakeElement("Button"), {
					Size = UDim2.new(1, 0, 1, 0)
				})

				local BindBox = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 4), {
					Size = UDim2.new(0, 24, 0, 24),
					Position = UDim2.new(1, -12, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5)
				}), {
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					AddThemeObject(SetProps(MakeElement("Label", BindConfig.Name, 14), {
						Size = UDim2.new(1, 0, 1, 0),
						Font = Enum.Font.GothamBold,
						TextXAlignment = Enum.TextXAlignment.Center,
						Name = "Value"
					}), "Text")
				}), "Main")

				local BindFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size = UDim2.new(1, 0, 0, 38),
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", BindConfig.Name, 15), {
						Size = UDim2.new(1, -12, 1, 0),
						Position = UDim2.new(0, 12, 0, 0),
						Font = Enum.Font.GothamBold,
						Name = "Content"
					}), "Text"),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					BindBox,
					Click
				}), "Second")

				AddConnection(BindBox.Value:GetPropertyChangedSignal("Text"), function()
					--BindBox.Size = UDim2.new(0, BindBox.Value.TextBounds.X + 16, 0, 24)
					TweenService:Create(BindBox, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, BindBox.Value.TextBounds.X + 16, 0, 24)}):Play()
				end)

				AddConnection(Click.InputEnded, function(Input)
					if Input.UserInputType == Enum.UserInputType.MouseButton1 then
						if Bind.Binding then return end
						Bind.Binding = true
						BindBox.Value.Text = ""
					end
				end)

				AddConnection(UserInputService.InputBegan, function(Input)
					if UserInputService:GetFocusedTextBox() then return end
					if (Input.KeyCode.Name == Bind.Value or Input.UserInputType.Name == Bind.Value) and not Bind.Binding then
						if BindConfig.Hold then
							Holding = true
							BindConfig.Callback(Holding)
						else
							BindConfig.Callback()
						end
					elseif Bind.Binding then
						local Key
						pcall(function()
							if not CheckKey(BlacklistedKeys, Input.KeyCode) then
								Key = Input.KeyCode
							end
						end)
						pcall(function()
							if CheckKey(WhitelistedMouse, Input.UserInputType) and not Key then
								Key = Input.UserInputType
							end
						end)
						Key = Key or Bind.Value
						Bind:Set(Key)
						SaveCfg(game.GameId)
					end
				end)

				AddConnection(UserInputService.InputEnded, function(Input)
					if Input.KeyCode.Name == Bind.Value or Input.UserInputType.Name == Bind.Value then
						if BindConfig.Hold and Holding then
							Holding = false
							BindConfig.Callback(Holding)
						end
					end
				end)

				AddConnection(Click.MouseEnter, function()
					TweenService:Create(BindFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(OrionLib.Themes[OrionLib.SelectedTheme].Second.R * 255 + 3, OrionLib.Themes[OrionLib.SelectedTheme].Second.G * 255 + 3, OrionLib.Themes[OrionLib.SelectedTheme].Second.B * 255 + 3)}):Play()
				end)

				AddConnection(Click.MouseLeave, function()
					TweenService:Create(BindFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = OrionLib.Themes[OrionLib.SelectedTheme].Second}):Play()
				end)

				AddConnection(Click.MouseButton1Up, function()
					TweenService:Create(BindFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(OrionLib.Themes[OrionLib.SelectedTheme].Second.R * 255 + 3, OrionLib.Themes[OrionLib.SelectedTheme].Second.G * 255 + 3, OrionLib.Themes[OrionLib.SelectedTheme].Second.B * 255 + 3)}):Play()
				end)

				AddConnection(Click.MouseButton1Down, function()
					TweenService:Create(BindFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(OrionLib.Themes[OrionLib.SelectedTheme].Second.R * 255 + 6, OrionLib.Themes[OrionLib.SelectedTheme].Second.G * 255 + 6, OrionLib.Themes[OrionLib.SelectedTheme].Second.B * 255 + 6)}):Play()
				end)

				function Bind:Set(Key)
					Bind.Binding = false
					Bind.Value = Key or Bind.Value
					Bind.Value = Bind.Value.Name or Bind.Value
					BindBox.Value.Text = Bind.Value
				end

				Bind:Set(BindConfig.Default)
				if BindConfig.Flag then				
					OrionLib.Flags[BindConfig.Flag] = Bind
				end
				return Bind
			end  
			function ElementFunction:AddTextbox(TextboxConfig)
				TextboxConfig = TextboxConfig or {}
				TextboxConfig.Name = TextboxConfig.Name or "Textbox"
				TextboxConfig.Default = TextboxConfig.Default or ""
				TextboxConfig.TextDisappear = TextboxConfig.TextDisappear or false
				TextboxConfig.Callback = TextboxConfig.Callback or function() end

				local Click = SetProps(MakeElement("Button"), {
					Size = UDim2.new(1, 0, 1, 0)
				})

				local TextboxActual = AddThemeObject(Create("TextBox", {
					Size = UDim2.new(1, 0, 1, 0),
					BackgroundTransparency = 1,
					TextColor3 = Color3.fromRGB(255, 255, 255),
					PlaceholderColor3 = Color3.fromRGB(210,210,210),
					PlaceholderText = "Input",
					Font = Enum.Font.GothamSemibold,
					TextXAlignment = Enum.TextXAlignment.Center,
					TextSize = 14,
					ClearTextOnFocus = false
				}), "Text")

				local TextContainer = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 4), {
					Size = UDim2.new(0, 24, 0, 24),
					Position = UDim2.new(1, -12, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5)
				}), {
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					TextboxActual
				}), "Main")


				local TextboxFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size = UDim2.new(1, 0, 0, 38),
					Parent = ItemParent
				}), {
					AddThemeObject(SetProps(MakeElement("Label", TextboxConfig.Name, 15), {
						Size = UDim2.new(1, -12, 1, 0),
						Position = UDim2.new(0, 12, 0, 0),
						Font = Enum.Font.GothamBold,
						Name = "Content"
					}), "Text"),
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
					TextContainer,
					Click
				}), "Second")

				AddConnection(TextboxActual:GetPropertyChangedSignal("Text"), function()
					--TextContainer.Size = UDim2.new(0, TextboxActual.TextBounds.X + 16, 0, 24)
					TweenService:Create(TextContainer, TweenInfo.new(0.45, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {Size = UDim2.new(0, TextboxActual.TextBounds.X + 16, 0, 24)}):Play()
				end)

				AddConnection(TextboxActual.FocusLost, function()
					TextboxConfig.Callback(TextboxActual.Text)
					if TextboxConfig.TextDisappear then
						TextboxActual.Text = ""
					end	
				end)

				TextboxActual.Text = TextboxConfig.Default

				AddConnection(Click.MouseEnter, function()
					TweenService:Create(TextboxFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(OrionLib.Themes[OrionLib.SelectedTheme].Second.R * 255 + 3, OrionLib.Themes[OrionLib.SelectedTheme].Second.G * 255 + 3, OrionLib.Themes[OrionLib.SelectedTheme].Second.B * 255 + 3)}):Play()
				end)

				AddConnection(Click.MouseLeave, function()
					TweenService:Create(TextboxFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = OrionLib.Themes[OrionLib.SelectedTheme].Second}):Play()
				end)

				AddConnection(Click.MouseButton1Up, function()
					TweenService:Create(TextboxFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(OrionLib.Themes[OrionLib.SelectedTheme].Second.R * 255 + 3, OrionLib.Themes[OrionLib.SelectedTheme].Second.G * 255 + 3, OrionLib.Themes[OrionLib.SelectedTheme].Second.B * 255 + 3)}):Play()
					TextboxActual:CaptureFocus()
				end)

				AddConnection(Click.MouseButton1Down, function()
					TweenService:Create(TextboxFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {BackgroundColor3 = Color3.fromRGB(OrionLib.Themes[OrionLib.SelectedTheme].Second.R * 255 + 6, OrionLib.Themes[OrionLib.SelectedTheme].Second.G * 255 + 6, OrionLib.Themes[OrionLib.SelectedTheme].Second.B * 255 + 6)}):Play()
				end)
			end 
			function ElementFunction:AddColorpicker(ColorpickerConfig)
				ColorpickerConfig = ColorpickerConfig or {}
				ColorpickerConfig.Name = ColorpickerConfig.Name or "Colorpicker"
				ColorpickerConfig.Default = ColorpickerConfig.Default or Color3.fromRGB(255,255,255)
				ColorpickerConfig.Callback = ColorpickerConfig.Callback or function() end
				ColorpickerConfig.Flag = ColorpickerConfig.Flag or nil
				ColorpickerConfig.Save = ColorpickerConfig.Save or false

				local ColorH, ColorS, ColorV = 1, 1, 1
				local Colorpicker = {Value = ColorpickerConfig.Default, Toggled = false, Type = "Colorpicker", Save = ColorpickerConfig.Save}

				local ColorSelection = Create("ImageLabel", {
					Size = UDim2.new(0, 18, 0, 18),
					Position = UDim2.new(select(3, Color3.toHSV(Colorpicker.Value))),
					ScaleType = Enum.ScaleType.Fit,
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "http://www.roblox.com/asset/?id=4805639000"
				})

				local HueSelection = Create("ImageLabel", {
					Size = UDim2.new(0, 18, 0, 18),
					Position = UDim2.new(0.5, 0, 1 - select(1, Color3.toHSV(Colorpicker.Value))),
					ScaleType = Enum.ScaleType.Fit,
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundTransparency = 1,
					Image = "http://www.roblox.com/asset/?id=4805639000"
				})

				local Color = Create("ImageLabel", {
					Size = UDim2.new(1, -25, 1, 0),
					Visible = false,
					Image = "rbxassetid://4155801252"
				}, {
					Create("UICorner", {CornerRadius = UDim.new(0, 5)}),
					ColorSelection
				})

				local Hue = Create("Frame", {
					Size = UDim2.new(0, 20, 1, 0),
					Position = UDim2.new(1, -20, 0, 0),
					Visible = false
				}, {
					Create("UIGradient", {Rotation = 270, Color = ColorSequence.new{ColorSequenceKeypoint.new(0.00, Color3.fromRGB(255, 0, 4)), ColorSequenceKeypoint.new(0.20, Color3.fromRGB(234, 255, 0)), ColorSequenceKeypoint.new(0.40, Color3.fromRGB(21, 255, 0)), ColorSequenceKeypoint.new(0.60, Color3.fromRGB(0, 255, 255)), ColorSequenceKeypoint.new(0.80, Color3.fromRGB(0, 17, 255)), ColorSequenceKeypoint.new(0.90, Color3.fromRGB(255, 0, 251)), ColorSequenceKeypoint.new(1.00, Color3.fromRGB(255, 0, 4))},}),
					Create("UICorner", {CornerRadius = UDim.new(0, 5)}),
					HueSelection
				})

				local ColorpickerContainer = Create("Frame", {
					Position = UDim2.new(0, 0, 0, 32),
					Size = UDim2.new(1, 0, 1, -32),
					BackgroundTransparency = 1,
					ClipsDescendants = true
				}, {
					Hue,
					Color,
					Create("UIPadding", {
						PaddingLeft = UDim.new(0, 35),
						PaddingRight = UDim.new(0, 35),
						PaddingBottom = UDim.new(0, 10),
						PaddingTop = UDim.new(0, 17)
					})
				})

				local Click = SetProps(MakeElement("Button"), {
					Size = UDim2.new(1, 0, 1, 0)
				})

				local ColorpickerBox = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 4), {
					Size = UDim2.new(0, 24, 0, 24),
					Position = UDim2.new(1, -12, 0.5, 0),
					AnchorPoint = Vector2.new(1, 0.5)
				}), {
					AddThemeObject(MakeElement("Stroke"), "Stroke")
				}), "Main")

				local ColorpickerFrame = AddThemeObject(SetChildren(SetProps(MakeElement("RoundFrame", Color3.fromRGB(255, 255, 255), 0, 5), {
					Size = UDim2.new(1, 0, 0, 38),
					Parent = ItemParent
				}), {
					SetProps(SetChildren(MakeElement("TFrame"), {
						AddThemeObject(SetProps(MakeElement("Label", ColorpickerConfig.Name, 15), {
							Size = UDim2.new(1, -12, 1, 0),
							Position = UDim2.new(0, 12, 0, 0),
							Font = Enum.Font.GothamBold,
							Name = "Content"
						}), "Text"),
						ColorpickerBox,
						Click,
						AddThemeObject(SetProps(MakeElement("Frame"), {
							Size = UDim2.new(1, 0, 0, 1),
							Position = UDim2.new(0, 0, 1, -1),
							Name = "Line",
							Visible = false
						}), "Stroke"), 
					}), {
						Size = UDim2.new(1, 0, 0, 38),
						ClipsDescendants = true,
						Name = "F"
					}),
					ColorpickerContainer,
					AddThemeObject(MakeElement("Stroke"), "Stroke"),
				}), "Second")

				AddConnection(Click.MouseButton1Click, function()
					Colorpicker.Toggled = not Colorpicker.Toggled
					TweenService:Create(ColorpickerFrame,TweenInfo.new(.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),{Size = Colorpicker.Toggled and UDim2.new(1, 0, 0, 148) or UDim2.new(1, 0, 0, 38)}):Play()
					Color.Visible = Colorpicker.Toggled
					Hue.Visible = Colorpicker.Toggled
					ColorpickerFrame.F.Line.Visible = Colorpicker.Toggled
				end)

				local function UpdateColorPicker()
					ColorpickerBox.BackgroundColor3 = Color3.fromHSV(ColorH, ColorS, ColorV)
					Color.BackgroundColor3 = Color3.fromHSV(ColorH, 1, 1)
					Colorpicker:Set(ColorpickerBox.BackgroundColor3)
					ColorpickerConfig.Callback(ColorpickerBox.BackgroundColor3)
					SaveCfg(game.GameId)
				end

				ColorH = 1 - (math.clamp(HueSelection.AbsolutePosition.Y - Hue.AbsolutePosition.Y, 0, Hue.AbsoluteSize.Y) / Hue.AbsoluteSize.Y)
				ColorS = (math.clamp(ColorSelection.AbsolutePosition.X - Color.AbsolutePosition.X, 0, Color.AbsoluteSize.X) / Color.AbsoluteSize.X)
				ColorV = 1 - (math.clamp(ColorSelection.AbsolutePosition.Y - Color.AbsolutePosition.Y, 0, Color.AbsoluteSize.Y) / Color.AbsoluteSize.Y)

				AddConnection(Color.InputBegan, function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						if ColorInput then
							ColorInput:Disconnect()
						end
						ColorInput = AddConnection(RunService.RenderStepped, function()
							local ColorX = (math.clamp(Mouse.X - Color.AbsolutePosition.X, 0, Color.AbsoluteSize.X) / Color.AbsoluteSize.X)
							local ColorY = (math.clamp(Mouse.Y - Color.AbsolutePosition.Y, 0, Color.AbsoluteSize.Y) / Color.AbsoluteSize.Y)
							ColorSelection.Position = UDim2.new(ColorX, 0, ColorY, 0)
							ColorS = ColorX
							ColorV = 1 - ColorY
							UpdateColorPicker()
						end)
					end
				end)

				AddConnection(Color.InputEnded, function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						if ColorInput then
							ColorInput:Disconnect()
						end
					end
				end)

				AddConnection(Hue.InputBegan, function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						if HueInput then
							HueInput:Disconnect()
						end;

						HueInput = AddConnection(RunService.RenderStepped, function()
							local HueY = (math.clamp(Mouse.Y - Hue.AbsolutePosition.Y, 0, Hue.AbsoluteSize.Y) / Hue.AbsoluteSize.Y)

							HueSelection.Position = UDim2.new(0.5, 0, HueY, 0)
							ColorH = 1 - HueY

							UpdateColorPicker()
						end)
					end
				end)

				AddConnection(Hue.InputEnded, function(input)
					if input.UserInputType == Enum.UserInputType.MouseButton1 then
						if HueInput then
							HueInput:Disconnect()
						end
					end
				end)

				function Colorpicker:Set(Value)
					Colorpicker.Value = Value
					ColorpickerBox.BackgroundColor3 = Colorpicker.Value
					ColorpickerConfig.Callback(Colorpicker.Value)
				end

				Colorpicker:Set(Colorpicker.Value)
				if ColorpickerConfig.Flag then				
					OrionLib.Flags[ColorpickerConfig.Flag] = Colorpicker
				end
				return Colorpicker
			end  
			return ElementFunction   
		end	

		local ElementFunction = {}

		function ElementFunction:AddSection(SectionConfig)
			SectionConfig.Name = SectionConfig.Name or "Section"

			local SectionFrame = SetChildren(SetProps(MakeElement("TFrame"), {
				Size = UDim2.new(1, 0, 0, 26),
				Parent = Container
			}), {
				SetChildren(SetProps(MakeElement("Frame"), {
					Size = UDim2.new(0, 3, 0, 14),
					Position = UDim2.new(0, 0, 0, 5),
					BackgroundColor3 = Color3.fromRGB(255, 211, 67),
					BorderSizePixel = 0,
				}), {
					MakeElement("Corner", 1),
				}),
				AddThemeObject(SetProps(MakeElement("Label", SectionConfig.Name, 14), {
					Size = UDim2.new(1, -12, 0, 16),
					Position = UDim2.new(0, 10, 0, 3),
					Font = Enum.Font.GothamBold
				}), "Text"),
				SetChildren(SetProps(MakeElement("TFrame"), {
					AnchorPoint = Vector2.new(0, 0),
					Size = UDim2.new(1, 0, 1, -24),
					Position = UDim2.new(0, 0, 0, 23),
					Name = "Holder"
				}), {
					MakeElement("List", 0, 6)
				}),
			})

			AddConnection(SectionFrame.Holder.UIListLayout:GetPropertyChangedSignal("AbsoluteContentSize"), function()
				pcall(function()
					SectionFrame.Size = UDim2.new(1, 0, 0, SectionFrame.Holder.UIListLayout.AbsoluteContentSize.Y + 31)
					SectionFrame.Holder.Size = UDim2.new(1, 0, 0, SectionFrame.Holder.UIListLayout.AbsoluteContentSize.Y)
				end)
			end)

			local SectionFunction = {}
			for i, v in next, GetElements(SectionFrame.Holder) do
				SectionFunction[i] = v 
			end
			return SectionFunction
		end	

		for i, v in next, GetElements(Container) do
			ElementFunction[i] = v 
		end

		if TabConfig.PremiumOnly then
			for i, v in next, ElementFunction do
				ElementFunction[i] = function() end
			end    
			Container:FindFirstChild("UIListLayout"):Destroy()
			Container:FindFirstChild("UIPadding"):Destroy()
			SetChildren(SetProps(MakeElement("TFrame"), {
				Size = UDim2.new(1, 0, 1, 0),
				Parent = ItemParent
			}), {
				AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://3610239960"), {
					Size = UDim2.new(0, 18, 0, 18),
					Position = UDim2.new(0, 15, 0, 15),
					ImageTransparency = 0.4
				}), "Text"),
				AddThemeObject(SetProps(MakeElement("Label", "Unauthorised Access", 14), {
					Size = UDim2.new(1, -38, 0, 14),
					Position = UDim2.new(0, 38, 0, 18),
					TextTransparency = 0.4
				}), "Text"),
				AddThemeObject(SetProps(MakeElement("Image", "rbxassetid://4483345875"), {
					Size = UDim2.new(0, 56, 0, 56),
					Position = UDim2.new(0, 84, 0, 110),
				}), "Text"),
				AddThemeObject(SetProps(MakeElement("Label", "Premium Features", 14), {
					Size = UDim2.new(1, -150, 0, 14),
					Position = UDim2.new(0, 150, 0, 112),
					Font = Enum.Font.GothamBold
				}), "Text"),
				AddThemeObject(SetProps(MakeElement("Label", "This part of the script is locked to Sirius Premium users. Purchase Premium in the Discord server (discord.gg/sirius)", 12), {
					Size = UDim2.new(1, -200, 0, 14),
					Position = UDim2.new(0, 150, 0, 138),
					TextWrapped = true,
					TextTransparency = 0.4
				}), "Text")
			})
		end
		return ElementFunction   
	end  
	
	--if writefile and isfile then
	--	if not isfile("NewLibraryNotification1.txt") then
	--		local http_req = (syn and syn.request) or (http and http.request) or http_request
	--		if http_req then
	--			http_req({
	--				Url = 'http://127.0.0.1:6463/rpc?v=1',
	--				Method = 'POST',
	--				Headers = {
	--					['Content-Type'] = 'application/json',
	--					Origin = 'https://discord.com'
	--				},
	--				Body = HttpService:JSONEncode({
	--					cmd = 'INVITE_BROWSER',
	--					nonce = HttpService:GenerateGUID(false),
	--					args = {code = 'sirius'}
	--				})
	--			})
	--		end
	--		OrionLib:MakeNotification({
	--			Name = "UI Library Available",
	--			Content = "New UI Library Available - Joining Discord (#announcements)",
	--			Time = 8
	--		})
	--		spawn(function()
	--			local UI = game:GetObjects("rbxassetid://11403719739")[1]

	--			if gethui then
	--				UI.Parent = gethui()
	--			elseif syn.protect_gui then
	--				syn.protect_gui(UI)
	--				UI.Parent = game.CoreGui
	--			else
	--				UI.Parent = game.CoreGui
	--			end

	--			wait(11)

	--			UI:Destroy()
	--		end)
	--		writefile("NewLibraryNotification1.txt","The value for the notification having been sent to you.")
	--	end
	--end
	

	
	return TabFunction
end   

function OrionLib:Destroy()
	Orion:Destroy()
end

return OrionLib

end)()

_G.Players = game:GetService("Players")
_G.UserInputService = game:GetService("UserInputService")
_G.RunService = game:GetService("RunService")
_G.HttpService = game:GetService("HttpService")

_G.Player = _G.Players.LocalPlayer

_G.F = {}

-- Static
_G.staticInteractTarget = ""
_G.arcerosAutoEnabled = false
_G.beastTarget = "Arceros"

-- Beasts of Judgement soft-reset hunts. The trigger names are search
-- candidates for children of SoftResetTriggers; if none match, the first
-- unclaimed BasePart trigger is used, so new/renamed triggers still work.
_G.BEAST_HUNTS = {
	Arceros = { triggerNames = { "Lava" } },
	Glacadia = { triggerNames = { "Ice", "Glacier", "Frost", "Snow", "Glacadia" } },
}
_G.arcerosStatsLabel = nil
_G.fastForwardEnabled = false
_G.windowFocused = true

-- Movement
_G.ctrlClickTpEnabled = false
_G.ctrlClickTpConnection = nil

-- General
_G.savingDisabled = false

_G.antiAfkEnabled = false
_G.antiAfkIdleConnection = nil

-- Trainer
_G.trainerId = 69
_G.autoTrainerEnabled = false
_G.trainerSwitchPromptFirstSeenAt = 0
_G.trainerSwitchPromptLastText = nil
_G.trainerSwitchPromptLastClickAt = 0
_G.trainerSwitchPromptClickedInstance = nil
_G.autoTrainerDelay = 1.5
_G.autoMoveSlot = 1
_G.autoMoveOneEnabled = false
_G.autoMoveOneDelay = 0.2

-- Rally
_G.autoRallyEnabled = false
_G.rallyDelay = 1
_G.rallyKept = 0
_G.rallyReleased = 0
_G.lastRallyActionText = "Idle"
_G.keepGleaming = true
_G.keepSecretAbility = true
_G.keepAll = false
_G.alwaysKeepText = ""
_G.alwaysKeepList = {}
_G.MARK_RELEASE = 1
_G.MARK_KEEP = 2

-- Encounter
_G.autoEncounterEnabled = false
_G.encounterTargetLoomian = ""
_G.autoEncounterDelay = 1.25
_G.focusedRunDelay = 0.12
_G.backgroundRunDelay = 0.35
_G.encounterReleaseDelay = 0.75
_G.focusedEndDelay = 0.15
_G.backgroundEndDelay = 1.25
_G.fastForwardStuckDelay = 4
_G.naturalRunPausedSpecialBattle = nil
_G.encounterTargetStopBattle = nil
_G.autoEncounterPausedBattle = nil
_G.autoEncounterPausedDisplayName = nil
_G.autoEncounterPausedReason = nil

_G.autoCatchEnabled = false
_G.autoCatchDisc = "Adv. Disc"
_G.autoBringEnabled = false
_G.stopOnGleaming = true
_G.stopOnGamma = true
_G.stopOnWisp = true

-- Fishing
_G.autoFishingEnabled = false
_G.autoFishingDelay = 1.75
_G.lastAutoFishingGoppieForme = nil
_G.lastAutoFishingGoppieFormeAt = 0
_G.lastAutoFishingGoppieNotice = nil
_G.goppieCaptureNetworkHooked = false
_G.goppieFormesTextbox = nil

_G.ROAMING_LEGENDARY_STOPS = {
	duskit = true,
	ikazune = true,
	protogon = true,
	mutagon = true,
	cephalops = true,
	wabalisc = true,
	metronette = true,
	nevermare = true,
	akhalos = true,
	gargolem = true,
	elephage = true,
	odoyaga = true,
	arceros = true,
	dakuda = true,
	glacadia = true,
	cosmeleon = true,
}

-- Fossil
_G.TARGET_PETROLITH_INTERACT = "PetrolithTable"
_G.autoFossilEnabled = false
_G.autoFossilDelay = 5
_G.totalFossilBatches = 0
_G.totalFossilRevived = 0
_G.lastFossilQueuedCount = 0
_G.lastFossilBatchText = "Idle"
_G.fossilBusy = false
_G.nextAutoFossilAt = 0
_G.fossilStatusLabel = nil
_G.fossilStatsLabel = nil
_G.fossilMachineLabel = nil

-- Arcade
_G.autoDiscDropEnabled = false
_G.discDropStatusLabel = nil
_G.discDropLiveLabel = nil
_G.discDropRecordsLabel = nil
_G.discDropLastScore = 0
_G.discDropHighScore = 0

-- Information / Tix Boonary automation
_G.autoBoonaryEnabled = false
_G.autoBoonaryTixThreshold = 999999
_G.autoBoonaryGroup = 49
_G.autoBoonaryBusy = false
_G.autoBoonaryTriggered = false
_G.autoBoonaryStatusLabel = nil
_G.autoBoonaryScanNodeLimit = 5000

-- Egg Rain
_G.autoEggRainEnabled = false
_G.autoEggRainDelay = 0.25
_G.eggRainStatusLabel = nil
_G.EGG_RAIN_TARGET_NAME = "Part"
_G.EGG_RAIN_TARGET_SIZE = Vector3.new(15, 1, 1)
_G.EGG_RAIN_SIZE_TOLERANCE = 0.05

-- UMV (WallSparkle through-walls visibility)
_G.wallSparkleUmvEnabled = false
_G.wallSparkleUmvCount = 0
_G.wallSparkleUmvStatusLabel = nil
_G.wallSparkleUmvCountLabel = nil
_G.wallSparkleUmvDescendantConnection = nil
_G.WALL_SPARKLE_ORIGINALS = setmetatable({}, { __mode = "k" })
_G.WALL_SPARKLE_CONFIG = {
	TARGET_NAME = "WallSparkle",
	HIGHLIGHT_NAME = "WallSparkle_ThroughWalls_Highlight",
	BILLBOARD_NAME = "WallSparkle_ThroughWalls_Marker",
	TAG_NAME = "WallSparkleThroughWalls",
	FILL_COLOR = Color3.fromRGB(255, 211, 67),
	OUTLINE_COLOR = Color3.fromRGB(0, 255, 255),
	PART_COLOR = Color3.fromRGB(255, 223, 92),
}

-- UMV mining hidden item reveal
_G.umvMiningRevealEnabled = false
_G.umvMiningRevealedCount = 0
_G.umvMiningRevealedCountLabel = nil
_G.umvMiningRevealLoopAlive = false
_G.umvMiningPlayerGuiWatchConnection = nil
_G.umvMiningRevealOriginals = setmetatable({}, { __mode = "k" })
_G.UMV_MINING_ATLAS_ID = "17203205985"

-- UMV remote sparkle miner (see runRemoteSparkleMine below)

-- Shops
_G.SHOP_DEFINITIONS = {
	{ Id = "battle", Label = "Battle Shop" },
	{ Id = "LoomianVoucher", Label = "Loomian Vouchers" },
	{ Id = "mount", Label = "Sawyer's Saddles" },
	{ Id = "halloween", Label = "Dr. Haloine" },
	{ Id = "typediscs", Label = "Disc Crafting" },
	{ Id = "holiday2022", Label = "Mr. Jolly" },
	{ Id = "cake", Label = "Head Chef's Goodies" },
	{ Id = "meteor", Label = "???" },
	{ Id = "fishtrash", Label = "Junk 4 Junk" },
	{ Id = "arcade", Label = "Arcade Prizes" },
	{ Id = "egg", Label = "Cool Colleggtibles" },
	{ Id = "frxSub", Label = "Supplies" },
	{ Id = "jolly3", Label = "Peppermint Swap" },
	{ Id = "tennistag", Label = "Redeem Tickets" },
}

_G.EXCLUDED_FORMES = {
	"pattern",
	'f',
	'm'
}
_G.GOPPIE_FORMES = {}
_G.GOPPIE_FORMES_FILE = "GOPPIE-FORMES.json"
_G.excludedFormes = {}

_G.uiAlive = true
_G.fastForwardBattles = setmetatable({}, { __mode = "k" })
_G.updateStatus = nil
_G.rallyStatsLabel = nil
_G.rallyStatusLabel = nil
_G.fishingStatusLabel = nil
_G.informationLabels = {}

_G.F.findP = function()
	-- Every call site retries this when _G._p is missing, and a registry
	-- sweep can take hundreds of ms; don't hammer it when the hook can't
	-- be found.
	if _G._findPFailedAt and os.clock() - _G._findPFailedAt < 5 then
		return nil
	end

	for _, fn in pairs(debug.getregistry()) do
		if type(fn) == "function" then
			for _, upvalue in pairs(debug.getupvalues(fn)) do
				local ok, result = pcall(function()
					return upvalue.NPCChat
				end)

				if ok and type(result) == "table" then
					_G._findPFailedAt = nil
					return upvalue
				end
			end
		end
	end

	_G._findPFailedAt = os.clock()
	return nil
end

_G._p = _G.F.findP()

_G.F.safeTableGet = function(object, key)
	if type(object) ~= "table" then
		return nil
	end

	local ok, value = pcall(function()
		return object[key]
	end)

	if ok then
		return value
	end

	return nil
end

_G.F.safeTableSet = function(object, key, value)
	if type(object) ~= "table" then
		return false
	end

	return pcall(function()
		object[key] = value
	end)
end

_G.F.normalizeInfoKey = function(value)
	return string.gsub(string.lower(tostring(value or "")), "[^%w]", "")
end

_G.F.formatInfoValue = function(value)
	if value == nil then
		return "N/A"
	end

	if type(value) == "number" then
		local sign = value < 0 and "-" or ""
		local integer, fraction = tostring(math.abs(value)):match("^(%d+)(%.%d+)$")
		integer = integer or tostring(math.floor(math.abs(value)))
		local formatted = string.reverse(integer):gsub("(%d%d%d)", "%1,")
		formatted = string.reverse(formatted):gsub("^,", "")
		return sign .. formatted .. (fraction or "")
	end

	if type(value) == "boolean" then
		return value and "Yes" or "No"
	end

	return tostring(value)
end

_G.F.getLeaderstatValue = function(aliases)
	local player = _G.Player
	local leaderstats = player and player:FindFirstChild("leaderstats")
	if not leaderstats then
		return nil
	end

	local aliasLookup = {}
	for _, alias in ipairs(aliases) do
		aliasLookup[_G.F.normalizeInfoKey(alias)] = true
	end

	for _, child in ipairs(leaderstats:GetChildren()) do
		if aliasLookup[_G.F.normalizeInfoKey(child.Name)] then
			local ok, value = pcall(function()
				return child.Value
			end)
			if ok and value ~= nil then
				return value
			end
		end
	end

	return nil
end

_G.F.parseInfoNumberText = function(text)
	local match = tostring(text or ""):match("[-+]?%d[%d,]*")
	if not match then
		return nil
	end

	local parsed = tonumber((match:gsub(",", "")))
	return parsed
end

_G.F.getNearbyGuiNumber = function(guiObject)
	if not guiObject then
		return nil
	end

	local containers = { guiObject.Parent }
	if guiObject.Parent and guiObject.Parent.Parent then
		table.insert(containers, guiObject.Parent.Parent)
	end

	for _, container in ipairs(containers) do
		if container then
			for _, descendant in ipairs(container:GetDescendants()) do
				if descendant ~= guiObject and (descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox")) then
					local value = _G.F.parseInfoNumberText(descendant.Text)
					if value ~= nil then
						return value
					end
				end
			end
		end
	end

	return nil
end

_G.F.getPlayerGuiInfoValue = function(aliases)
	local playerGui = _G.Player and _G.Player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return nil
	end

	local aliasLookup = {}
	for _, alias in ipairs(aliases) do
		aliasLookup[_G.F.normalizeInfoKey(alias)] = true
	end

	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if descendant:IsA("TextLabel") or descendant:IsA("TextButton") or descendant:IsA("TextBox") then
			local text = tostring(descendant.Text or "")
			local normalizedText = _G.F.normalizeInfoKey(text)
			local guiName = _G.F.normalizeInfoKey(descendant.Name)

			for aliasKey in pairs(aliasLookup) do
				if normalizedText == aliasKey or guiName == aliasKey or string.find(normalizedText, aliasKey, 1, true) or string.find(guiName, aliasKey, 1, true) then
					local directValue = _G.F.parseInfoNumberText(text)
					if directValue ~= nil then
						return directValue
					end

					local nearbyValue = _G.F.getNearbyGuiNumber(descendant)
					if nearbyValue ~= nil then
						return nearbyValue
					end
				end
			end
		end
	end

	return nil
end

_G.F.findInfoValueInTable = function(root, aliases, maxDepth)
	if type(root) ~= "table" then
		return nil
	end

	local aliasLookup = {}
	for _, alias in ipairs(aliases) do
		aliasLookup[_G.F.normalizeInfoKey(alias)] = true
	end

	local visited = {}
	local function scan(value, depth)
		if type(value) ~= "table" or visited[value] or depth > maxDepth then
			return nil
		end

		visited[value] = true

		local ok, found = pcall(function()
			for key, child in pairs(value) do
				if aliasLookup[_G.F.normalizeInfoKey(key)] and type(child) ~= "table" and type(child) ~= "function" then
					return child
				end
			end

			for _, child in pairs(value) do
				local nested = scan(child, depth + 1)
				if nested ~= nil then
					return nested
				end
			end
		end)

		if ok then
			return found
		end

		return nil
	end

	return scan(root, 0)
end

_G.F.getInformationRoots = function()
	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end

	local roots = {}
	local function add(root)
		if type(root) == "table" then
			table.insert(roots, root)
		end
	end

	add(_G._p)

	if type(_G._p) == "table" then
		for _, key in ipairs({ "PlayerData", "playerData", "Data", "data", "SaveData", "saveData", "PDS", "pds", "Menu", "DataManager" }) do
			add(_G.F.safeTableGet(_G._p, key))
		end

		local dataManager = _G.F.safeTableGet(_G._p, "DataManager")
		if type(dataManager) == "table" then
			for _, key in ipairs({ "currentSave", "currentData", "playerData", "data", "saveData", "currentChunk" }) do
				add(_G.F.safeTableGet(dataManager, key))
			end
		end
	end

	return roots
end

_G.F.getInformationValue = function(aliases)
	local leaderstatValue = _G.F.getLeaderstatValue(aliases)
	if leaderstatValue ~= nil then
		return leaderstatValue
	end

	for _, root in ipairs(_G.F.getInformationRoots()) do
		local value = _G.F.findInfoValueInTable(root, aliases, 5)
		if value ~= nil then
			return value
		end
	end

	return nil
end

_G.F.getInformationSnapshot = function()
	local definitions = {
		{ key = "money", label = "Money", aliases = { "money", "cash", "dollars", "lumidollars", "loomidollars", "lumiDollars" } },
		{ key = "tix", label = "Tix", aliases = { "tix", "ticket", "tickets", "eventtickets", "eventTix" } },
		{ key = "bp", label = "BP", aliases = { "bp", "battlepoints", "battlePoints", "battle_points", "battlepoint" } },
	}

	local snapshot = {}
	for _, definition in ipairs(definitions) do
		table.insert(snapshot, {
			key = definition.key,
			label = definition.label,
			value = _G.F.getInformationValue(definition.aliases),
		})
	end

	return snapshot
end

_G.F.refreshInformationLabels = function()
	if type(_G.informationLabels) ~= "table" then
		return
	end

	local loadedCount = 0
	for _, item in ipairs(_G.F.getInformationSnapshot()) do
		local label = _G.informationLabels[item.key]
		if label and type(label.Set) == "function" then
			if item.value ~= nil then
				loadedCount = loadedCount + 1
			end

			pcall(function()
				label:Set(item.label .. ": " .. _G.F.formatInfoValue(item.value))
			end)
		end
	end

	if _G.informationLabels.status and type(_G.informationLabels.status.Set) == "function" then
		pcall(function()
			_G.informationLabels.status:Set("Loaded: " .. tostring(loadedCount) .. "/3")
		end)
	end
end

_G.isActiveFlag = function(value)
	return value ~= nil and value ~= false and value ~= 0
end

_G.F.isBattleEnded = function(battle)
	return type(battle) == "table" and _G.F.safeTableGet(battle, "ended") == true
end

_G.F.isRealBattle = function(battle)
	return type(battle) == "table"
		and battle.ended ~= true
		and (battle.kind ~= nil or battle.state ~= nil or battle.battleId ~= nil)
end

_G.F.isBattleSetupPending = function(battle)
	if type(battle) ~= "table" or battle.ended then
		return true
	end

	return battle.setupComplete ~= true
end

_G.F.isFishingBattleStarting = function(battle)
	return type(battle) == "table"
		and battle.fshPct ~= nil
		and battle.setupComplete ~= true
end

_G.F.getContainerCurrentBattle = function(container)
	local battle = _G.F.safeTableGet(container, "currentBattle")
	if _G.F.isBattleEnded(battle) then
		_G.F.safeTableSet(container, "currentBattle", nil)
		_G.fastForwardBattles[battle] = nil
		return nil
	end

	if type(battle) ~= "table" then
		return nil
	end

	return battle
end

_G.F.normalizeFormeKey = function(value)
	if value == nil then
		return nil
	end

	local text = tostring(value):lower():gsub("^%s+", ""):gsub("%s+$", "")
	if text == "" then
		return nil
	end

	return text
end

_G.F.rebuildExcludedFormes = function()
	_G.excludedFormes = {}

	for _, entry in pairs(_G.EXCLUDED_FORMES) do
		local key = _G.F.normalizeFormeKey(entry)
		if key then
			_G.excludedFormes[key] = true
		end
	end

	for _, entry in pairs(_G.GOPPIE_FORMES) do
		local key = _G.F.normalizeFormeKey(entry)
		if key then
			_G.excludedFormes[key] = true
		end
	end
end

_G.F.rebuildExcludedFormes()

_G.F.getFormeMatchCandidates = function(value)
	local key = _G.F.normalizeFormeKey(value)
	if key == nil then
		return {}
	end

	local candidates = { key }

	local suffix = string.match(key, "%-([^%-]+)$")
	if suffix and suffix ~= key then
		table.insert(candidates, suffix)
	end

	local barePattern = string.match(key, "%-pattern(%d+)$")
	if barePattern then
		table.insert(candidates, "pattern" .. barePattern)
	end

	return candidates
end

_G.F.isMeaningfulFormeValue = function(value)
	if value == nil or value == false then
		return false
	end

	return _G.F.normalizeFormeKey(value) ~= nil
end

_G.F.isExcludedForme = function(value)
	for _, key in ipairs(_G.F.getFormeMatchCandidates(value)) do
		if _G.excludedFormes[key] then
			return true
		end

		for excludedKey in pairs(_G.excludedFormes) do
			if #excludedKey <= 2 then
				if key == excludedKey or string.sub(key, -(#excludedKey + 1)) == "-" .. excludedKey then
					return true
				end
			elseif string.find(key, excludedKey, 1, true) or string.find(excludedKey, key, 1, true) then
				return true
			end
		end
	end

	return false
end

_G.F.addExcludedForme = function(value)
	if not _G.F.isMeaningfulFormeValue(value) then
		return false
	end

	local key = _G.F.normalizeFormeKey(value)
	for _, entry in ipairs(_G.EXCLUDED_FORMES) do
		if _G.F.normalizeFormeKey(entry) == key then
			return false
		end
	end

	table.insert(_G.EXCLUDED_FORMES, tostring(value))
	_G.F.rebuildExcludedFormes()
	return true
end

_G.F.isGoppieMonster = function(monster)
	if type(monster) ~= "table" then
		return false
	end

	local function valueMatches(value)
		local name = _G.F.normalizeLoomianSearchName(value)
		return name == "goppie" or string.find(name, "goppie", 1, true) ~= nil
	end

	local modelData = _G.F.safeTableGet(monster, "modelData")
	local sprite = _G.F.safeTableGet(monster, "sprite")
	local spriteModelData = type(sprite) == "table" and _G.F.safeTableGet(sprite, "modelData") or nil

	return valueMatches(monster.name)
		or valueMatches(monster.species)
		or valueMatches(monster.nickname)
		or valueMatches(type(modelData) == "table" and _G.F.safeTableGet(modelData, "name") or nil)
		or valueMatches(type(sprite) == "table" and _G.F.safeTableGet(sprite, "name") or nil)
		or valueMatches(type(spriteModelData) == "table" and _G.F.safeTableGet(spriteModelData, "name") or nil)
end

_G.F.getGoppieVariantName = function(value)
	if not _G.F.isMeaningfulFormeValue(value) then
		return nil
	end

	local text = tostring(value)
	local key = _G.F.normalizeLoomianSearchName(text)
	if string.find(key, "goppie", 1, true) and key ~= "goppie" then
		return text
	end

	return nil
end

_G.F.getMonsterGoppieVariantName = function(monster)
	if type(monster) ~= "table" then
		return nil
	end

	local modelData = _G.F.safeTableGet(monster, "modelData")
	local sprite = _G.F.safeTableGet(monster, "sprite")
	local spriteModelData = type(sprite) == "table" and _G.F.safeTableGet(sprite, "modelData") or nil

	for _, value in pairs({
		name = monster.name,
		species = monster.species,
		nickname = monster.nickname,
		modelName = type(modelData) == "table" and _G.F.safeTableGet(modelData, "name") or nil,
		spriteName = type(sprite) == "table" and _G.F.safeTableGet(sprite, "name") or nil,
		spriteModelName = type(spriteModelData) == "table" and _G.F.safeTableGet(spriteModelData, "name") or nil
	}) do
		local variantName = _G.F.getGoppieVariantName(value)
		if variantName then
			return variantName
		end
	end

	return nil
end

_G.F.findGoppieNameDeep = function(root)
	if type(root) ~= "table" then
		return nil
	end

	local seen = {}

	local function scan(value, depth)
		if depth > 6 then
			return nil
		end

		if type(value) == "string" and string.find(_G.F.normalizeLoomianSearchName(value), "goppie", 1, true) then
			return value
		elseif type(value) == "table" and not seen[value] then
			seen[value] = true

			for _, childValue in pairs(value) do
				local found = scan(childValue, depth + 1)
				if found then
					return found
				end
			end
		end

		return nil
	end

	return scan(root, 0)
end

_G.F.normalizeGoppieFormeFromCaptureValue = function(value)
	if type(value) == "string" then
		return _G.F.getGoppieVariantName(value)
	elseif type(value) == "table" then
		local goppieName = _G.F.findGoppieNameDeep(value)
		if _G.F.isMeaningfulFormeValue(_G.F.getGoppieVariantName(goppieName)) then
			return goppieName
		end

		local directForme = _G.F.getMonsterGoppieVariantName(value) or _G.F.getMonsterFormeValue(value)
		if _G.F.isMeaningfulFormeValue(directForme) and _G.F.isGoppieMonster(value) then
			return directForme
		end

		local deepForme = _G.F.findGoppieFormeValueDeep(value)
		if _G.F.isMeaningfulFormeValue(deepForme) then
			return deepForme
		end
	end

	return nil
end

_G.F.addCapturedGoppieFormeFromArgs = function(...)
	local battle = _G.F.getCurrentBattle()
	if battle and _G.F.registerCaughtGoppieFormeFromBattle(battle) then
		return true
	end

	local args = { ... }

	for _, value in ipairs(args) do
		local formeValue = _G.F.normalizeGoppieFormeFromCaptureValue(value)
		if _G.F.isMeaningfulFormeValue(formeValue) then
			_G.lastAutoFishingGoppieForme = formeValue
			_G.lastAutoFishingGoppieFormeAt = os.clock()

			local added = _G.F.addGoppieForme(formeValue)
			pcall(function()
				_G.OrionLib:MakeNotification({
					Name = "Goppie Formes",
					Content = (added and "Saved caught forme: " or "Forme already saved: ") .. tostring(formeValue),
					Time = 4
				})
			end)
			return true
		end
	end

	return false
end

_G.F.isGoppieCaptureNetworkEvent = function(eventName)
	return eventName == "OnCaptureDCGoppie" or eventName == "OnCaptureT5Goppie"
end

_G.F.makeGoppieCaptureCallback = function(eventName, callback)
	return function(...)
		_G.F.addCapturedGoppieFormeFromArgs(...)

		if type(callback) == "function" then
			return callback(...)
		end
	end
end

_G.F.installGoppieCaptureNetworkHook = function()
	if _G.goppieCaptureNetworkHooked then
		return
	end

	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end

	local network = type(_G._p) == "table" and _G.F.safeTableGet(_G._p, "Network") or nil
	if type(network) ~= "table" then
		return
	end

	local bindEvent = _G.F.safeTableGet(network, "bindEvent")
	if type(bindEvent) == "function" then
		local originalBindEvent = bindEvent
		_G.F.safeTableSet(network, "bindEvent", function(self, eventName, callback, ...)
			if _G.F.isGoppieCaptureNetworkEvent(eventName) and type(callback) == "function" then
				callback = _G.F.makeGoppieCaptureCallback(eventName, callback)
			end

			return originalBindEvent(self, eventName, callback, ...)
		end)
		_G.goppieCaptureNetworkHooked = true
	end

	if type(debug) == "table" and type(debug.getupvalues) == "function" then
		pcall(function()
			local upvalues = { debug.getupvalues(bindEvent) }
			for _, upvalue in ipairs(upvalues) do
				if type(upvalue) == "table" then
					for eventName, callback in pairs(upvalue) do
						if _G.F.isGoppieCaptureNetworkEvent(eventName) and type(callback) == "function" then
							upvalue[eventName] = _G.F.makeGoppieCaptureCallback(eventName, callback)
						end
					end
				end
			end
		end)
	end
end

_G.F.findGoppieFormeValueDeep = function(root)
	if type(root) ~= "table" then
		return nil
	end

	local seen = {}
	local foundGoppie = false
	local formeValue = nil

	local function scan(value, key, depth)
		if depth > 6 or (formeValue and foundGoppie) then
			return
		end

		if type(value) == "string" or type(value) == "number" then
			local loweredValue = _G.F.normalizeLoomianSearchName(value)
			if string.find(loweredValue, "goppie", 1, true) then
				foundGoppie = true
			end

			local loweredKey = _G.F.normalizeLoomianSearchName(key)
			local keyLooksLikeForme = string.find(loweredKey, "forme", 1, true)
				or string.find(loweredKey, "form", 1, true)
				or string.find(loweredKey, "variant", 1, true)
				or string.find(loweredKey, "pattern", 1, true)
				or string.find(loweredKey, "color", 1, true)
				or string.find(loweredKey, "colour", 1, true)

			if keyLooksLikeForme
				and _G.F.isMeaningfulFormeValue(value)
				and loweredValue ~= "goppie"
				and loweredValue ~= "m"
				and loweredValue ~= "f" then
				formeValue = formeValue or tostring(value)
			end
		elseif type(value) == "table" and not seen[value] then
			seen[value] = true

			for childKey, childValue in pairs(value) do
				scan(childValue, childKey, depth + 1)
			end
		end
	end

	scan(root, nil, 0)

	if foundGoppie and _G.F.isMeaningfulFormeValue(formeValue) then
		return formeValue
	end

	return nil
end

_G.F.rememberAutoFishingGoppieFormeFromBattle = function(battle)
	if not _G.autoFishingEnabled or type(battle) ~= "table" then
		return nil
	end

	local foe = _G.F.getBattleFoeMonster(battle)
	local deepFormeValue = _G.F.findGoppieFormeValueDeep(battle)
	if not _G.F.isGoppieMonster(foe) and not _G.F.isMeaningfulFormeValue(deepFormeValue) then
		_G.lastAutoFishingGoppieForme = nil
		_G.lastAutoFishingGoppieFormeAt = 0
		return nil
	end

	local formeValue = _G.F.getMonsterGoppieVariantName(foe) or _G.F.getMonsterFormeValue(foe) or deepFormeValue
	if _G.F.isMeaningfulFormeValue(formeValue) then
		_G.lastAutoFishingGoppieForme = formeValue
		_G.lastAutoFishingGoppieFormeAt = os.clock()
		if _G.lastAutoFishingGoppieNotice ~= tostring(formeValue) then
			_G.lastAutoFishingGoppieNotice = tostring(formeValue)
			pcall(function()
				_G.OrionLib:MakeNotification({
					Name = "Auto Fishing",
					Content = "Detected Goppie forme: " .. tostring(formeValue),
					Time = 2
				})
			end)
		end
		return formeValue
	end

	return nil
end

_G.F.getFishingGoppieFormeValue = function(battle)
	if type(battle) ~= "table" then
		return nil
	end

	local foe = _G.F.getBattleFoeMonster(battle)
	return _G.F.getMonsterGoppieVariantName(foe)
		or _G.F.getMonsterFormeValue(foe)
		or _G.F.findGoppieFormeValueDeep(battle)
end

_G.F.isGoppieFormeSaved = function(value)
	if not _G.F.isMeaningfulFormeValue(value) then
		return false
	end

	for _, candidate in ipairs(_G.F.getFormeMatchCandidates(value)) do
		for _, entry in ipairs(_G.GOPPIE_FORMES) do
			local savedKey = _G.F.normalizeFormeKey(entry)
			if savedKey == candidate then
				return true
			end

			for _, savedCandidate in ipairs(_G.F.getFormeMatchCandidates(entry)) do
				if savedCandidate == candidate then
					return true
				end
			end
		end
	end

	return false
end

_G.F.isFishingGoppieBattle = function(battle)
	return type(battle) == "table"
		and battle.kind == "wild"
		and battle.fshPct ~= nil
end

_G.F.isAutoFishingExcludedGoppieBattle = function(battle)
	if not _G.autoFishingEnabled or type(battle) ~= "table" then
		return false
	end

	local foe = _G.F.getBattleFoeMonster(battle)
	local formeValue = _G.F.getFishingGoppieFormeValue(battle)
	if not _G.F.isMeaningfulFormeValue(formeValue) then
		return false
	end

	return (_G.F.isGoppieMonster(foe) or _G.F.isMeaningfulFormeValue(formeValue))
		and _G.F.isGoppieFormeSaved(formeValue)
end

_G.F.shouldCatchFishingGoppieBattle = function(battle)
	if not _G.F.isFishingGoppieBattle(battle) or not _G.F.hasWildFoeLoaded(battle) then
		return false
	end

	local foe = _G.F.getBattleFoeMonster(battle)
	local formeValue = _G.F.getFishingGoppieFormeValue(battle)
	if not _G.F.isGoppieMonster(foe) and not _G.F.isMeaningfulFormeValue(formeValue) then
		return false
	end

	if not _G.F.isMeaningfulFormeValue(formeValue) then
		return false
	end

	return not _G.F.isGoppieFormeSaved(formeValue)
end

_G.F.setFastForwardEnabled = function(value)
	_G.fastForwardEnabled = value and true or false

	if _G.fastForwardEnabled then
		local battle = _G.F.getCurrentBattle()
		_G.F.setBattleFastForward(true, battle)
		_G.F.applyBattleAnimationFastForward(battle, false)
	else
		_G.F.clearAllBattleFastForward()
	end
end

_G.F.setAutoFishingEnabled = function(value)
	_G.autoFishingEnabled = value and true or false

	if FishingAutomation then
		FishingAutomation:setEnabled(_G.autoFishingEnabled)
	end
end

_G.F.safeSetParagraph = function(paragraph, text)
	pcall(function()
		if paragraph and type(paragraph.Set) == "function" then
			paragraph:Set(text)
		end
	end)
end

FishingAutomation = (function()
	local api = {}
	local statusParagraph = nil
	local lastCastAt = 0
	local casting = false
	local originalFishMiniGame = nil
	local fishMiniGameHook = nil
	local hookedFishingModule = nil
	local originalSetupScene = nil
	local hookedSetupSceneOwner = nil

	local function restoreSetupSceneHook()
		if hookedSetupSceneOwner and originalSetupScene then
			if _G.F.safeTableGet(hookedSetupSceneOwner, "setupScene") ~= originalSetupScene then
				_G.F.safeTableSet(hookedSetupSceneOwner, "setupScene", originalSetupScene)
			end
		end

		originalSetupScene = nil
		hookedSetupSceneOwner = nil
	end

	local function installFishingSetupSceneHook()
		if type(_G._p) ~= "table" then
			_G._p = _G.F.findP()
		end

		for _, containerName in ipairs({ "BattleClient", "Battle" }) do
			local battleClient = type(_G._p) == "table" and _G.F.safeTableGet(_G._p, containerName) or nil
			if type(battleClient) == "table" then
				if hookedSetupSceneOwner == battleClient and originalSetupScene then
					return true
				end

				local original = _G.F.safeTableGet(battleClient, "setupScene")
				if type(original) == "function" and original ~= originalSetupScene then
					if not originalSetupScene then
						originalSetupScene = original
					end

					hookedSetupSceneOwner = battleClient
					_G.F.safeTableSet(battleClient, "setupScene", function(self, ...)
						return originalSetupScene(self, ...)
					end)

					return true
				end
			end
		end

		return false
	end

	local function setStatus(text)
		_G.F.safeSetParagraph(statusParagraph, text)
	end

	local function getFishingModule()
		if type(_G._p) ~= "table" then
			_G._p = _G.F.findP()
		end

		local fishing = type(_G._p) == "table" and _G.F.safeTableGet(_G._p, "Fishing") or nil
		if type(fishing) ~= "table" then
			return nil, "Fishing is not ready."
		end

		return fishing
	end

	local function getFishingPool()
		if type(_G._p) ~= "table" then
			_G._p = _G.F.findP()
		end

		local currentChunk = type(_G._p) == "table" and _G._p.DataManager and _G._p.DataManager.currentChunk or nil
		local regionData = type(currentChunk) == "table" and currentChunk.regionData or nil
		local pool = type(regionData) == "table" and regionData.Fishing or nil
		if not pool then
			return nil, "This chunk has no fishing encounters."
		end

		return pool
	end

	local function restoreMiniGameHook()
		if hookedFishingModule and fishMiniGameHook and _G.F.safeTableGet(hookedFishingModule, "FishMiniGame") == fishMiniGameHook then
			_G.F.safeTableSet(hookedFishingModule, "FishMiniGame", originalFishMiniGame)
		end

		originalFishMiniGame = nil
		fishMiniGameHook = nil
		hookedFishingModule = nil
	end

	local function cleanupAutoReelState(animations)
		pcall(function()
			if type(animations) == "table" then
				if animations.pullUp then
					animations.pullUp:Stop(0.5)
				end
				if animations.pullDown then
					animations.pullDown:Stop(0.5)
				end
			end
		end)

		pcall(function()
			_G.RunService:UnbindFromRenderStep("loomFishingGame")
		end)

		pcall(function()
			local mouseManager = type(_G._p) == "table" and _G.F.safeTableGet(_G._p, "MouseManager") or nil
			local setMouseIconEnabled = type(mouseManager) == "table" and _G.F.safeTableGet(mouseManager, "SetMouseIconEnabled") or nil
			if type(setMouseIconEnabled) == "function" then
				setMouseIconEnabled(mouseManager, true)
			end
		end)

		pcall(function()
			game:GetService("GuiService").SelectedObject = nil
		end)
	end

	local function waitForFishCatchResult(fishId)
		local catchResult = nil

		if fishId == nil then
			return true
		end

		if type(_G._p) ~= "table" then
			_G._p = _G.F.findP()
		end

		local network = type(_G._p) == "table" and _G.F.safeTableGet(_G._p, "Network") or nil
		if type(network) ~= "table" or type(_G.F.safeTableGet(network, "get")) ~= "function" then
			return true
		end

		task.spawn(function()
			local ok, value = pcall(function()
				return network:get("PDS", "fshchi", fishId)
			end)

			if ok then
				catchResult = value
			end
		end)

		local deadline = os.clock() + 3
		while catchResult == nil and os.clock() < deadline do
			task.wait()
		end

		if catchResult == nil then
			return true
		end

		return catchResult
	end

	local function installMiniGameHook(fishing)
		if hookedFishingModule == fishing and fishMiniGameHook then
			return true
		end

		restoreMiniGameHook()

		local original = _G.F.safeTableGet(fishing, "FishMiniGame")
		if type(original) ~= "function" then
			return false, "Fishing minigame is not ready."
		end

		originalFishMiniGame = original
		hookedFishingModule = fishing
		fishMiniGameHook = function(self, animations, rod, fishId)
			if not _G.autoFishingEnabled then
				return originalFishMiniGame(self, animations, rod, fishId)
			end

			local catchResult = waitForFishCatchResult(fishId)
			cleanupAutoReelState(animations)
			task.wait(0.2)

			return 0.85, catchResult
		end

		if not _G.F.safeTableSet(fishing, "FishMiniGame", fishMiniGameHook) then
			restoreMiniGameHook()
			return false, "Could not hook fishing minigame."
		end

		return true
	end

	local function getWaterRaycastParams()
		local params = RaycastParams.new()
		params.FilterDescendantsInstances = { workspace.Terrain }
		params.FilterType = Enum.RaycastFilterType.Include
		params.IgnoreWater = false
		return params
	end

	local function findFishableWaterPosition()
		local root = _G.F.getRoot()
		if not root then
			return nil, "Character root is not ready."
		end

		local look = root.CFrame.LookVector * Vector3.new(1, 0, 1)
		if look.Magnitude < 0.01 then
			look = Vector3.new(0, 0, -1)
		else
			look = look.Unit
		end

		local right = root.CFrame.RightVector * Vector3.new(1, 0, 1)
		if right.Magnitude < 0.01 then
			right = Vector3.new(1, 0, 0)
		else
			right = right.Unit
		end

		local params = getWaterRaycastParams()
		for _, distance in ipairs({ 5, 7.5, 10, 13, 16, 20 }) do
			for _, sideOffset in ipairs({ 0, -3, 3, -6, 6 }) do
				local origin = root.Position + look * distance + right * sideOffset + Vector3.new(0, 8, 0)
				local result = workspace:Raycast(origin, Vector3.new(0.001, -60, 0.001), params)
				if result and result.Material == Enum.Material.Water then
					return result.Position
				end
			end
		end

		return nil, "Face fishable water and stand closer."
	end

	local function isNpcChatLocked()
		local chat = type(_G._p) == "table" and _G.F.safeTableGet(_G._p, "NPCChat") or nil
		if type(chat) ~= "table" then
			return false
		end

		for _, methodName in ipairs({ "isChatting", "isAwaitingManualAdvance", "isAwaitingChoice", "isChoosing", "isBusy" }) do
			local method = _G.F.safeTableGet(chat, methodName)
			if type(method) == "function" then
				local ok, result = pcall(function()
					return method(chat)
				end)

				if ok and result then
					return true
				end
			end
		end

		return false
	end

	function api:setEnabled(value)
		_G.autoFishingEnabled = value and true or false

		if not _G.autoFishingEnabled then
			restoreMiniGameHook()
			restoreSetupSceneHook()
			casting = false
			setStatus("Auto Fishing is off.")
		else
			installFishingSetupSceneHook()
			setStatus("Face water to start fishing.")
		end
	end

	function api:isEnabled()
		return _G.autoFishingEnabled
	end

	function api:castOnce()
		if type(_G._p) ~= "table" then
			_G._p = _G.F.findP()
		end

		if _G.F.getCurrentBattle() then
			return false, "Battle already active."
		end

		if casting then
			return false, "Fishing already in progress."
		end

		if isNpcChatLocked() then
			return false, "NPC chat is busy."
		end

		local fishing, fishingReason = getFishingModule()
		if not fishing then
			return false, fishingReason
		end

		if not getFishingPool() then
			return false, "This chunk has no fishing encounters."
		end

		local hooked, hookReason = installMiniGameHook(fishing)
		if not hooked then
			return false, hookReason
		end

		if not installFishingSetupSceneHook() then
			return false, "Battle setup hook is not ready."
		end

		local waterPosition, waterReason = findFishableWaterPosition()
		if not waterPosition then
			return false, waterReason
		end

		local masterControl = type(_G._p) == "table" and _G.F.safeTableGet(_G._p, "MasterControl") or nil
		if type(masterControl) == "table" and masterControl.WalkEnabled == false then
			masterControl.WalkEnabled = true
		end

		_G.F.setFastForwardEnabled(false)
		casting = true
		lastCastAt = os.clock()

		task.spawn(function()
			local ok, err = pcall(function()
				if type(_G.F.safeTableGet(fishing, "OnWaterClicked")) == "function" then
					fishing:OnWaterClicked(waterPosition)
				else
					fishing:Fish(waterPosition)
				end
			end)

			casting = false
			if not ok then
				warn("[Auto Fishing] " .. tostring(err))
				setStatus(tostring(err))
			elseif _G.F.getCurrentBattle() then
				setStatus("Fishing battle started.")
			else
				setStatus("Waiting for next cast.")
			end
		end)

		setStatus("Casting...")
		return true
	end

	function api:runCycle()
		if not _G.autoFishingEnabled then
			return false
		end

		if casting or _G.F.getCurrentBattle() then
			return false
		end

		if os.clock() - lastCastAt < _G.autoFishingDelay then
			return false
		end

		return self:castOnce()
	end

	function api:attachUi(tab)
		statusParagraph = tab:AddLabel("Idle")
		_G.fishingStatusLabel = statusParagraph

		_G.configUi.autoFishingToggle = tab:AddToggle({
			Name = "Auto Fishing",
			Default = _G.autoFishingEnabled,
			Color = Color3.fromRGB(70, 170, 255),
			Callback = function(value)
				_G.F.setAutoFishingEnabled(value)
			end
		})

		tab:AddButton({
			Name = "Cast Now",
			Icon = "waves",
			Callback = function()
				local started, reason = api:castOnce()
				if not started and reason then
					_G.OrionLib:MakeNotification({
						Name = "Auto Fishing",
						Content = reason,
						Time = 4
					})
				end
			end
		})

		tab:AddSlider({
			Name = "Cast Delay",
			Min = 0.75,
			Max = 6,
			Default = _G.autoFishingDelay,
			Increment = 0.25,
			ValueName = "s",
			Callback = function(value)
				_G.autoFishingDelay = value
			end
		})

	end

	function api:restoreMiniGameHook()
		restoreMiniGameHook()
	end

	return api
end)()


_G.F.getCurrentBattle = function()
	if type(_G._p) ~= "table" then
		return nil
	end

	local battle = _G.F.getContainerCurrentBattle(_G.F.safeTableGet(_G._p, "Battle"))
	if battle then
		return battle
	end

	battle = _G.F.getContainerCurrentBattle(_G.F.safeTableGet(_G._p, "BattleClient"))
	if battle then
		return battle
	end

	return nil
end


-- Fast forward, rewritten to use the game's own mechanism and nothing else.
--
-- Every battle animation, statbar tween, and inter-action wait in the game is
-- gated on ONE field: battle.fastForward (checked all over BattleClientActions,
-- BattleClientSide, BattleGui). The game's own turbo-replay path does nothing
-- more than set that field. The old implementation deep-scanned battle tables
-- every tick, writing/nil-ing guessed keys and force-clearing "animating" locks
-- on live game state (scene, sides, gui...), which corrupted battles and the
-- camera. Now we only ever touch the one field the game actually reads.
_G.F.applyFastForwardFlagsToTable = function(object, enabled)
	if type(object) ~= "table" then
		return
	end

	_G.F.safeTableSet(object, "fastForward", enabled and true or false)
end

_G.F.setBattleFastForward = function(enabled, battle)
	_G.F.installBattleCameraSafetyHooks()

	battle = battle or _G.F.getCurrentBattle()

	if not battle then
		return
	end

	if enabled then
		_G.fastForwardBattles[battle] = true

		if _G.F.safeTableGet(battle, "fastForward") ~= true then
			_G.F.safeTableSet(battle, "fastForward", true)
		end
	elseif _G.fastForwardBattles[battle] then
		_G.fastForwardBattles[battle] = nil

		if not _G.F.isBattleEnded(battle) then
			_G.F.safeTableSet(battle, "fastForward", false)
		end
	end
end

_G.F.clearBattleFastForward = function()
	for battle in pairs(_G.fastForwardBattles) do
		_G.fastForwardBattles[battle] = nil

		if not _G.F.isBattleEnded(battle) then
			_G.F.safeTableSet(battle, "fastForward", false)
		end
	end
end

_G.F.callMethodsIfPresent = function(object, methodNames)
	if type(object) ~= "table" then
		return
	end

	for _, methodName in ipairs(methodNames) do
		local method = _G.F.safeTableGet(object, methodName)
		if type(method) == "function" then
			pcall(function()
				method(object)
			end)
		end
	end
end

-- Kept as a thin compatibility wrapper: many call sites pass (battle, clearLocks,
-- enabled). All the deep scanning, animator speeding and lock clearing is gone --
-- battle.fastForward is the entire mechanism.
_G.F.applyBattleAnimationFastForward = function(battle, _clearLocks, enabled)
	if type(battle) ~= "table" then
		return
	end

	if enabled == false then
		-- Force-off must work even for battles we never tracked (e.g. cleanup
		-- of leftover state from a previous script run, or pausing automation
		-- on a gleaming encounter so the player can watch it normally).
		_G.fastForwardBattles[battle] = nil

		if not _G.F.isBattleEnded(battle) then
			_G.F.safeTableSet(battle, "fastForward", false)
		end
	else
		_G.F.setBattleFastForward(true, battle)
	end
end

_G.F.clearAllBattleFastForward = function()
	_G.F.clearBattleFastForward()
end

task.defer(function()
	local battle = _G.F.getCurrentBattle()
	if battle then
		_G.F.applyBattleAnimationFastForward(battle, false, false)
	end
end)

_G.F.getBattleProgressSignature = function(battle)
	if type(battle) ~= "table" then
		return "none"
	end

	return table.concat({
		tostring(_G.F.safeTableGet(battle, "state")),
		tostring(_G.F.safeTableGet(battle, "turn")),
		tostring(_G.F.safeTableGet(battle, "request")),
		tostring(_G.F.safeTableGet(battle, "fulfillingRequest")),
		tostring(_G.F.safeTableGet(battle, "done"))
	}, "|")
end

-- "Nudging" a stuck battle is now just re-asserting battle.fastForward. Any
-- wait the game entered before the flag was set finishes on its own; forcing
-- scene/animation locks from outside only corrupted live battle state.
_G.F.nudgeFastForwardBattle = function(battle)
	if type(battle) ~= "table" or _G.F.safeTableGet(battle, "state") == "input" or _G.F.safeTableGet(battle, "done") then
		return
	end

	_G.F.setBattleFastForward(true, battle)
end

-- EventLoomian Legacy stores a Loomian's gleam tier as `shiny` (a number) and
-- mirrors it into the compact `icon` array (element 3). The PC/Party slot icons
-- are built directly from monster.icon via IconUtil.createMonsterIcon, so the
-- `icon` array is the authoritative source when the full data isn't present.
--   tier 1 = Gleaming, tier 2 = Gamma, tier >= 3 = Corrupt / special gleam.
-- Wisp color lives on `wisp` (number) / icon array element 4.
_G.F.getMonsterIconArray = function(monster)
	if type(monster) ~= "table" then
		return nil
	end

	local icon = _G.F.safeTableGet(monster, "icon")
	if type(icon) == "table" then
		return icon
	end

	for _, key in ipairs({ "summ", "summary", "data", "modelData", "sprite" }) do
		local container = _G.F.safeTableGet(monster, key)
		if type(container) == "table" then
			local nested = _G.F.safeTableGet(container, "icon")
			if type(nested) == "table" then
				return nested
			end
		end
	end

	return nil
end

_G.F.normalizeGleamTier = function(value)
	if value == true then
		return 1
	end
	if type(value) == "number" and value ~= 0 then
		return value
	end
	return nil
end

-- Instance-safe numeric index read. Some game tables carry a metatable whose
-- __index points at a Roblox Instance (e.g. Workspace.Camera), so a missing
-- numeric key like value[2] falls through and throws "2 is not a valid member
-- of Camera". Route every array read through pcall to stay resilient.
_G.F.safeArrayGet = function(value, index)
	if type(value) ~= "table" then
		return nil
	end

	if typeof and typeof(value) == "Instance" then
		return nil
	end

	local ok, result = pcall(function()
		return value[index]
	end)

	if ok then
		return result
	end

	return nil
end

-- PC box slots store { labelIndex, iconArray } where iconArray is the compact
-- { speciesId, sheetType, gleamTier, wispColor } tuple passed to Monster:getIcon.
_G.F.isMonsterIconArray = function(value)
	if type(value) ~= "table" then
		return false
	end

	local speciesId = _G.F.safeArrayGet(value, 1)
	if type(speciesId) ~= "number" then
		return false
	end

	local sheetType = _G.F.safeArrayGet(value, 2)
	if sheetType ~= nil and type(sheetType) ~= "number" and sheetType ~= true then
		return false
	end

	return true
end

_G.F.unwrapPcSlotData = function(slotData)
	if type(slotData) ~= "table" then
		return nil
	end

	local secondEntry = _G.F.safeArrayGet(slotData, 2)
	if _G.F.isMonsterIconArray(secondEntry) then
		return {
			raw = slotData,
			icon = secondEntry,
			labelIndex = _G.F.safeArrayGet(slotData, 1),
			isPcSlot = true,
		}
	end

	if _G.F.isMonsterIconArray(slotData) then
		return {
			raw = slotData,
			icon = slotData,
			isPcSlot = false,
		}
	end

	local icon = _G.F.getMonsterIconArray(slotData)
	if icon then
		return {
			raw = slotData,
			icon = icon,
			isPcSlot = false,
		}
	end

	return {
		raw = slotData,
		icon = nil,
		isPcSlot = false,
	}
end

_G.F.getSpeciesNameFromId = function(speciesId)
	speciesId = tonumber(speciesId)
	if not speciesId then
		return nil
	end

	_G.F.speciesNameCache = _G.F.speciesNameCache or {}
	if _G.F.speciesNameCache[speciesId] then
		return _G.F.speciesNameCache[speciesId]
	end

	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end

	if type(_G._p) == "table" then
		local constants = _G.F.safeTableGet(_G._p, "Constants")
		if type(constants) == "table" then
			for _, key in ipairs({ "MONSTERS", "monsters", "Loomians", "loomians", "DEX", "dex" }) do
				local monsterTable = _G.F.safeTableGet(constants, key)
				if type(monsterTable) == "table" then
					local entry = monsterTable[speciesId]
					if entry ~= nil then
						local name = type(entry) == "table" and (entry.name or entry.n or entry.species) or entry
						if name ~= nil and tostring(name) ~= "" then
							_G.F.speciesNameCache[speciesId] = tostring(name)
							return _G.F.speciesNameCache[speciesId]
						end
					end
				end
			end
		end

		local monsterModule = _G.F.safeTableGet(_G._p, "Monster")
		if type(monsterModule) == "table" then
			for _, methodName in ipairs({ "getName", "getNameFromId", "idToName", "getDexName" }) do
				local method = monsterModule[methodName]
				if type(method) == "function" then
					local ok, name = pcall(method, monsterModule, speciesId)
					if ok and name ~= nil and tostring(name) ~= "" then
						_G.F.speciesNameCache[speciesId] = tostring(name)
						return _G.F.speciesNameCache[speciesId]
					end
				end
			end
		end
	end

	return nil
end

_G.F.getMonsterGleamTier = function(monster)
	if type(monster) ~= "table" then
		return nil
	end

	if _G.F.isMonsterIconArray(monster) then
		return _G.F.normalizeGleamTier(_G.F.safeArrayGet(monster, 3))
	end

	local unwrapped = _G.F.unwrapPcSlotData(monster)
	if unwrapped and unwrapped.icon then
		local tier = _G.F.normalizeGleamTier(_G.F.safeArrayGet(unwrapped.icon, 3))
		if tier then
			return tier
		end
	end

	for _, key in ipairs({ "shiny", "gleam", "gl", "gleaming" }) do
		local tier = _G.F.normalizeGleamTier(_G.F.safeTableGet(monster, key))
		if tier then
			return tier
		end
	end

	for _, containerKey in ipairs({ "summ", "summary", "data", "modelData", "sprite" }) do
		local container = _G.F.safeTableGet(monster, containerKey)
		if type(container) == "table" then
			for _, key in ipairs({ "shiny", "gleam", "gl", "gleaming" }) do
				local tier = _G.F.normalizeGleamTier(_G.F.safeTableGet(container, key))
				if tier then
					return tier
				end
			end

			local nestedSprite = _G.F.safeTableGet(container, "modelData")
			if type(nestedSprite) == "table" then
				local tier = _G.F.normalizeGleamTier(_G.F.safeTableGet(nestedSprite, "gleam"))
				if tier then
					return tier
				end
			end
		end
	end

	local icon = _G.F.getMonsterIconArray(monster)
	if type(icon) == "table" then
		local tier = _G.F.normalizeGleamTier(_G.F.safeArrayGet(icon, 3))
		if tier then
			return tier
		end
	end

	return nil
end

_G.F.getMonsterGleamValue = function(monster)
	if type(monster) ~= "table" then
		return nil
	end

	local tier = _G.F.getMonsterGleamTier(monster)
	if tier then
		return tier
	end

	local shiny = _G.F.safeTableGet(monster, "shiny")
	if _G.isActiveFlag(shiny) then
		return shiny
	end

	local gamma = _G.F.safeTableGet(monster, "gamma")
	if _G.isActiveFlag(gamma) then
		return gamma
	end

	local isGamma = _G.F.safeTableGet(monster, "isGamma")
	if _G.isActiveFlag(isGamma) then
		return isGamma
	end

	local gleam = _G.F.safeTableGet(monster, "gleam")
	if _G.isActiveFlag(gleam) then
		return gleam
	end

	local gleaming = _G.F.safeTableGet(monster, "gleaming")
	if _G.isActiveFlag(gleaming) then
		return gleaming
	end

	local gl = _G.F.safeTableGet(monster, "gl")
	if _G.isActiveFlag(gl) then
		return gl
	end

	local summary = _G.F.safeTableGet(monster, "summ")
	if type(summary) == "table" then
		for _, key in ipairs({ "gl", "gleam", "gleaming", "gamma", "shiny" }) do
			local summaryValue = _G.F.safeTableGet(summary, key)
			if _G.isActiveFlag(summaryValue) then
				return summaryValue
			end
		end
	end

	local modelData = _G.F.safeTableGet(monster, "modelData")
	if type(modelData) == "table" then
		local modelGleam = _G.F.safeTableGet(modelData, "gleam")
		if _G.isActiveFlag(modelGleam) then
			return modelGleam
		end

		local modelGamma = _G.F.safeTableGet(modelData, "gamma")
		if _G.isActiveFlag(modelGamma) then
			return modelGamma
		end
	end

	-- Some flags only land on the sprite's model data (wisp detection
	-- below relies on the same spot); check it for gleam too.
	local sprite = _G.F.safeTableGet(monster, "sprite")
	local spriteModelData = type(sprite) == "table" and _G.F.safeTableGet(sprite, "modelData") or nil
	if type(spriteModelData) == "table" then
		for _, key in ipairs({ "gleam", "gleaming", "gl", "gamma", "shiny" }) do
			local spriteValue = _G.F.safeTableGet(spriteModelData, key)
			if _G.isActiveFlag(spriteValue) then
				return spriteValue
			end
		end
	end

	return nil
end

_G.F.getMonsterWispValue = function(monster)
	if type(monster) ~= "table" then
		return nil
	end

	if _G.F.isMonsterIconArray(monster) then
		return _G.F.normalizeGleamTier(_G.F.safeArrayGet(monster, 4))
	end

	local unwrapped = _G.F.unwrapPcSlotData(monster)
	local unwrappedWisp = unwrapped and unwrapped.icon and _G.F.safeArrayGet(unwrapped.icon, 4) or nil
	if unwrappedWisp ~= nil then
		local wisp = _G.F.normalizeGleamTier(unwrappedWisp)
		if wisp then
			return wisp
		end
	end

	local wisp = _G.F.safeTableGet(monster, "wisp")
	if _G.isActiveFlag(wisp) then
		return wisp
	end

	local modelData = _G.F.safeTableGet(monster, "modelData")
	local modelWisp = type(modelData) == "table" and _G.F.safeTableGet(modelData, "wisp") or nil
	if _G.isActiveFlag(modelWisp) then
		return modelWisp
	end

	local sprite = _G.F.safeTableGet(monster, "sprite")
	local spriteModelData = type(sprite) == "table" and _G.F.safeTableGet(sprite, "modelData") or nil
	local spriteWisp = type(spriteModelData) == "table" and _G.F.safeTableGet(spriteModelData, "wisp") or nil
	if _G.isActiveFlag(spriteWisp) then
		return spriteWisp
	end

	local icon = _G.F.getMonsterIconArray(monster)
	local iconWisp = type(icon) == "table" and _G.F.safeArrayGet(icon, 4) or nil
	if _G.isActiveFlag(iconWisp) then
		return iconWisp
	end

	return nil
end
_G.F.getMonsterFormeValue = function(monster)
	if type(monster) ~= "table" then
		return nil
	end

	local forme = _G.F.safeTableGet(monster, "Forme")
	if _G.F.isMeaningfulFormeValue(forme) then
		return forme
	end

	forme = _G.F.safeTableGet(monster, "forme")
	if _G.F.isMeaningfulFormeValue(forme) then
		return forme
	end

	local modelData = _G.F.safeTableGet(monster, "modelData")
	local species = _G.F.safeTableGet(monster, "species")
	if type(modelData) == "table" then
		local modelForme = _G.F.safeTableGet(modelData, "Forme")
		if _G.F.isMeaningfulFormeValue(modelForme) then
			return modelForme
		end

		modelForme = _G.F.safeTableGet(modelData, "forme")
		if _G.F.isMeaningfulFormeValue(modelForme) then
			return modelForme
		end

		local modelName = _G.F.safeTableGet(modelData, "name")
		if _G.F.isMeaningfulFormeValue(modelName) and species and _G.F.normalizeFormeKey(modelName) ~= _G.F.normalizeFormeKey(species) then
			return modelName
		end
	end

	local sprite = _G.F.safeTableGet(monster, "sprite")
	local spriteModelData = type(sprite) == "table" and _G.F.safeTableGet(sprite, "modelData") or nil
	if type(spriteModelData) == "table" then
		local spriteForme = _G.F.safeTableGet(spriteModelData, "Forme")
		if _G.F.isMeaningfulFormeValue(spriteForme) then
			return spriteForme
		end

		spriteForme = _G.F.safeTableGet(spriteModelData, "forme")
		if _G.F.isMeaningfulFormeValue(spriteForme) then
			return spriteForme
		end

		local spriteName = _G.F.safeTableGet(spriteModelData, "name")
		if _G.F.isMeaningfulFormeValue(spriteName) and species and _G.F.normalizeFormeKey(spriteName) ~= _G.F.normalizeFormeKey(species) then
			return spriteName
		end
	end

	return nil
end

_G.F.getMonsterTrackedFormeValue = function(monster)
	local formeValue = _G.F.getMonsterFormeValue(monster)
	if not _G.F.isMeaningfulFormeValue(formeValue) then
		return nil
	end

	if _G.F.isExcludedForme(formeValue) then
		return nil
	end

	return formeValue
end

_G.F.getMonsterSpecialValue = function(monster)
	if type(monster) ~= "table" then
		return nil
	end

	local gleamValue = _G.F.getMonsterGleamValue(monster)
	if gleamValue then
		return "Gleaming/Gamma", gleamValue
	end

	local wispValue = _G.F.getMonsterWispValue(monster)
	if wispValue then
		return "Wisp", wispValue
	end

	local formeValue = _G.F.getMonsterTrackedFormeValue(monster)
	if formeValue ~= nil then
		return "Forme", formeValue
	end

	return nil
end

_G.F.getBattleFoeMonster = function(battle)
	if type(battle) ~= "table" then
		return nil
	end

	return battle.p2 and battle.p2.monsters and battle.p2.monsters[1]
end

_G.F.normalizeLoomianSearchName = function(value)
	return string.lower(string.gsub(tostring(value or ""), "^%s*(.-)%s*$", "%1"))
end

_G.F.getMonsterDisplayName = function(monster)
	if type(monster) ~= "table" then
		return ""
	end

	return tostring(monster.name or monster.species or monster.nickname or "")
end

_G.F.getEncounterFoeSpeciesName = function(monster)
	if type(monster) ~= "table" then
		return ""
	end

	local summary = _G.F.safeTableGet(monster, "summ")
	if type(summary) == "table" then
		local speciesName = _G.F.safeTableGet(summary, "name")
		if type(speciesName) == "string" and speciesName ~= "" then
			return speciesName
		end
	end

	return tostring(monster.name or monster.species or "")
end

_G.F.monsterMatchesSearchTarget = function(monster, searchTarget)
	local wanted = _G.F.normalizeLoomianSearchName(searchTarget)
	if wanted == "" then
		return true
	end

	local name = _G.F.normalizeLoomianSearchName(_G.F.getEncounterFoeSpeciesName(monster))
	if name == "" then
		return false
	end

	return name == wanted or string.find(name, wanted, 1, true) ~= nil
end

_G.F.roamingLegendaryStopLookup = nil

_G.F.rebuildRoamingLegendaryStopLookup = function()
	local lookup = {}

	for name, enabled in pairs(_G.ROAMING_LEGENDARY_STOPS or {}) do
		if enabled then
			local key = _G.F.normalizeLoomianSearchName(name)
			if key ~= "" then
				lookup[key] = tostring(name)
			end
		end
	end

	_G.F.roamingLegendaryStopLookup = lookup
end

_G.F.getRoamingLegendaryMatchName = function(monster)
	if type(monster) ~= "table" then
		return nil
	end

	local lookup = _G.F.roamingLegendaryStopLookup
	if not lookup then
		_G.F.rebuildRoamingLegendaryStopLookup()
		lookup = _G.F.roamingLegendaryStopLookup
	end

	local name = _G.F.normalizeLoomianSearchName(_G.F.getEncounterFoeSpeciesName(monster))
	if name == "" then
		return nil
	end

	if lookup[name] then
		return lookup[name]
	end

	for key, displayName in pairs(lookup) do
		if string.find(name, key, 1, true) or string.find(key, name, 1, true) then
			return displayName
		end
	end

	return nil
end

_G.F.isMatchingRoamingLegendaryFoe = function(battle)
	if not _G.F.hasWildFoeLoaded(battle) then
		return false
	end

	return _G.F.getRoamingLegendaryMatchName(_G.F.getBattleFoeMonster(battle)) ~= nil
end

_G.F.handleRoamingLegendaryFound = function(battle)
	if type(battle) ~= "table" then
		return
	end

	local foe = _G.F.getBattleFoeMonster(battle)
	local matchName = _G.F.getRoamingLegendaryMatchName(foe)
	if not matchName then
		return
	end

	local displayName = _G.F.getEncounterFoeSpeciesName(foe)
	if displayName == "" then
		displayName = matchName
	end

	_G.F.pauseAutoEncounterForBattle(battle, displayName, "Roaming Legendary", "Roaming Legendary Found")
end

_G.F.rebuildRoamingLegendaryStopLookup()
_G.F.getMonsterGammaValue = function(monster)
	if type(monster) ~= "table" then
		return nil
	end

	if _G.F.getMonsterGleamTier(monster) == 2 then
		return 2
	end

	local gamma = _G.F.safeTableGet(monster, "gamma")
	if _G.isActiveFlag(gamma) then
		return gamma
	end

	local isGamma = _G.F.safeTableGet(monster, "isGamma")
	if _G.isActiveFlag(isGamma) then
		return isGamma
	end

	local summary = _G.F.safeTableGet(monster, "summ")
	if type(summary) == "table" then
		local summaryGamma = _G.F.safeTableGet(summary, "gamma")
		if _G.isActiveFlag(summaryGamma) then
			return summaryGamma
		end
	end

	local modelData = _G.F.safeTableGet(monster, "modelData")
	if type(modelData) == "table" then
		local modelGamma = _G.F.safeTableGet(modelData, "gamma")
		if _G.isActiveFlag(modelGamma) then
			return modelGamma
		end
	end

	return nil
end

_G.F.getMonsterGleamingOnlyValue = function(monster)
	if type(monster) ~= "table" or _G.F.getMonsterGammaValue(monster) then
		return nil
	end

	local tier = _G.F.getMonsterGleamTier(monster)
	if tier == 1 then
		return 1
	end

	local shiny = _G.F.safeTableGet(monster, "shiny")
	if _G.isActiveFlag(shiny) then
		return shiny
	end

	local gleam = _G.F.safeTableGet(monster, "gleam")
	if _G.isActiveFlag(gleam) then
		return gleam
	end

	local gleaming = _G.F.safeTableGet(monster, "gleaming")
	if _G.isActiveFlag(gleaming) then
		return gleaming
	end

	local gl = _G.F.safeTableGet(monster, "gl")
	if _G.isActiveFlag(gl) then
		return gl
	end

	local summary = _G.F.safeTableGet(monster, "summ")
	if type(summary) == "table" then
		for _, key in ipairs({ "gl", "gleam", "gleaming", "shiny" }) do
			local summaryValue = _G.F.safeTableGet(summary, key)
			if _G.isActiveFlag(summaryValue) then
				return summaryValue
			end
		end
	end

	local modelData = _G.F.safeTableGet(monster, "modelData")
	if type(modelData) == "table" then
		local modelGleam = _G.F.safeTableGet(modelData, "gleam")
		if _G.isActiveFlag(modelGleam) then
			return modelGleam
		end
	end

	return nil
end

_G.F.getWildSpecialFoeForStop = function(battle)
	local foe = _G.F.getBattleFoeMonster(battle)
	if type(foe) ~= "table" then
		return nil
	end

	if _G.stopOnWisp then
		local wispValue = _G.F.getMonsterWispValue(foe)
		if _G.isActiveFlag(wispValue) then
			return foe, wispValue, "Wisp"
		end
	end

	if _G.stopOnGamma then
		local gammaValue = _G.F.getMonsterGammaValue(foe)
		if _G.isActiveFlag(gammaValue) then
			return foe, gammaValue, "Gamma"
		end
	end

	if _G.stopOnGleaming then
		local gleamValue = _G.F.getMonsterGleamingOnlyValue(foe)
		if _G.isActiveFlag(gleamValue) then
			return foe, gleamValue, "Gleaming"
		end
	end

	return nil
end


_G.F.getStaticHuntSpecialFoe = function(battle)
	local foe = battle and battle.p2 and battle.p2.monsters and battle.p2.monsters[1]
	if type(foe) ~= "table" then
		return nil
	end

	local gleamValue = _G.F.getMonsterGleamValue(foe)
	if _G.isActiveFlag(gleamValue) then
		return foe, gleamValue, "Gleaming/Gamma"
	end

	local wispValue = _G.F.getMonsterWispValue(foe)
	if _G.isActiveFlag(wispValue) then
		return foe, wispValue, "Wisp"
	end

	return nil
end

_G.F.hasWildFoeLoaded = function(battle)
	return type(battle) == "table"
		and type(battle.p2) == "table"
		and type(battle.p2.monsters) == "table"
		and type(battle.p2.monsters[1]) == "table"
end

_G.F.isStaticBattleReadyToEnd = function(battle)
	if type(battle) ~= "table" or battle.ended then
		return false
	end

	if battle.setupComplete ~= true then
		return false
	end

	return _G.F.hasWildFoeLoaded(battle)
end

_G.F.advanceSoftResetNpcChat = function()
	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end

	local chat = type(_G._p) == "table" and _G._p.NPCChat or nil
	if type(chat) ~= "table" then
		return false
	end

	local chatting = false
	pcall(function()
		if type(chat.isChatting) == "function" then
			chatting = chat:isChatting()
		end
	end)

	if not chatting then
		return false
	end

	pcall(function()
		chat.fastForward = true
		chat.skipping = true
		chat.TextSpeedMultiplier = 100
	end)

	local advanced = false

	pcall(function()
		if type(chat.isAwaitingManualAdvance) == "function" and chat:isAwaitingManualAdvance()
			and type(chat.manualAdvance) == "function" then
			chat:manualAdvance()
			advanced = true
		end
	end)

	if not advanced then
		pcall(function()
			if type(chat.manualAdvance) == "function" then
				chat:manualAdvance()
			end
		end)

		local utilities = type(_G._p) == "table" and _G._p.Utilities or nil
		local frontGui = utilities and utilities.frontGui
		if frontGui then
			for _, name in ipairs({ "ChatBox", "ChatArrowPointer" }) do
				local item = frontGui:FindFirstChild(name, true)
				if item and _G.F.isGuiChainVisible(item) then
					if _G.F.activateGuiButton(item) or _G.F.clickGuiButtonOnce(item) then
						advanced = true
						break
					end

					local okVim, vim = pcall(function()
						return game:GetService("VirtualInputManager")
					end)

					if okVim and vim and item:IsA("GuiObject") then
						pcall(function()
							local center = item.AbsolutePosition + (item.AbsoluteSize / 2)
							vim:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
							task.wait(0.025)
							vim:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0)
						end)
						advanced = true
						break
					end
				end
			end
		end

		if not advanced then
			local okVim, vim = pcall(function()
				return game:GetService("VirtualInputManager")
			end)

			if okVim and vim then
				pcall(function()
					local camera = workspace.CurrentCamera
					local viewport = camera and camera.ViewportSize or Vector2.new(1280, 720)
					vim:SendMouseButtonEvent(viewport.X * 0.5, viewport.Y * 0.72, 0, true, game, 0)
					task.wait(0.025)
					vim:SendMouseButtonEvent(viewport.X * 0.5, viewport.Y * 0.72, 0, false, game, 0)
				end)
				advanced = true
			end
		end
	end

	return advanced
end

_G.F.clickGuiButtonOnce = function(button)
	if not button then
		return false
	end

	if type(firesignal) == "function" then
		local okSignal, signal = pcall(function()
			return button.Activated
		end)

		if okSignal and signal then
			local okFire = pcall(function()
				firesignal(signal)
			end)

			if okFire then
				return true
			end
		end
	end

	local okActivate = pcall(function()
		button:Activate()
	end)

	return okActivate
end

_G.F.activateGuiButton = function(button)
	if not button then
		return false
	end

	local clicked = false

	if type(firesignal) == "function" then
		for _, signalName in ipairs({ "Activated", "MouseButton1Click", "MouseButton1Up" }) do
			local okSignal, signal = pcall(function()
				return button[signalName]
			end)

			if okSignal and signal then
				local okFire = pcall(function()
					firesignal(signal)
				end)

				clicked = clicked or okFire
			end
		end
	end

	local okActivate = pcall(function()
		button:Activate()
	end)
	clicked = clicked or okActivate

	local okVim, vim = pcall(function()
		return game:GetService("VirtualInputManager")
	end)

	if okVim and vim then
		local okMouse = pcall(function()
			local center = button.AbsolutePosition + (button.AbsoluteSize / 2)
			vim:SendMouseButtonEvent(center.X, center.Y, 0, true, game, 0)
			task.wait(0.025)
			vim:SendMouseButtonEvent(center.X, center.Y, 0, false, game, 0)
		end)

		clicked = clicked or okMouse
	end

	return clicked
end

_G.F.canUseRealMouse = function()
	-- Real clicks land wherever the OS cursor is; never move/click the
	-- user's mouse while the game window isn't focused.
	if _G.windowFocused == false then
		return false
	end

	return type(mousemoveabs) == "function"
		and (type(mouse1click) == "function"
			or (type(mouse1press) == "function" and type(mouse1release) == "function"))
end

_G.F.realMouseClickGuiObject = function(guiObject)
	if typeof(guiObject) ~= "Instance" or not guiObject:IsA("GuiObject") then
		return false
	end

	if not _G.F.canUseRealMouse() then
		return false
	end

	local ok = pcall(function()
		local inset = game:GetService("GuiService"):GetGuiInset()
		local center = guiObject.AbsolutePosition + (guiObject.AbsoluteSize / 2)
		local x = center.X + inset.X
		local y = center.Y + inset.Y

		local camera = workspace.CurrentCamera
		if camera then
			local viewport = camera.ViewportSize
			if x < 0 or y < 0 or x > viewport.X or y > viewport.Y then
				error("click target is off screen")
			end
		end

		local restoreTo = nil
		pcall(function()
			restoreTo = game:GetService("UserInputService"):GetMouseLocation()
		end)

		mousemoveabs(x, y)
		task.wait(0.03)

		if type(mouse1click) == "function" then
			mouse1click()
		else
			mouse1press()
			task.wait(0.03)
			mouse1release()
		end

		if restoreTo then
			task.wait(0.05)
			mousemoveabs(restoreTo.X, restoreTo.Y)
		end
	end)

	return ok
end

_G.F.isGuiChainVisible = function(item)
	local current = item

	while current do
		if current:IsA("GuiObject") and current.Visible == false then
			return false
		end

		if current:IsA("ScreenGui") and current.Enabled == false then
			return false
		end

		current = current.Parent
	end

	return true
end

_G.F.getBattleGuiModule = function()
	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end

	local battleGui = type(_G._p) == "table" and _G._p.BattleGui or nil
	if type(battleGui) ~= "table" then
		return nil
	end

	_G.F.installBattleGuiSafetyHooks(battleGui)
	return battleGui
end

_G.F.installBattleGuiSafetyHooks = function(battleGui)
	if type(battleGui) ~= "table" then
		if type(_G._p) ~= "table" then
			_G._p = _G.F.findP()
		end
		battleGui = type(_G._p) == "table" and _G._p.BattleGui or nil
	end
	if type(battleGui) ~= "table" or battleGui.__llsploitMainChoicesGuard then
		return
	end

	local originalMainChoices = _G.F.safeTableGet(battleGui, "mainChoices")
	if type(originalMainChoices) == "function" then
		_G.F.safeTableSet(battleGui, "mainChoices", function(self, ...)
			if type(_G._p) ~= "table" then
				_G._p = _G.F.findP()
			end

			local linkedBattle = type(_G._p) == "table" and _G._p.Battle and _G._p.Battle.currentBattle or nil
			if type(linkedBattle) ~= "table" or linkedBattle.battleId == nil or linkedBattle.ended then
				return
			end

			return originalMainChoices(self, ...)
		end)
	end

	battleGui.__llsploitMainChoicesGuard = true
end

task.defer(function()
	_G.F.installBattleGuiSafetyHooks()
end)

task.defer(function()
	_G.F.installBattleCameraSafetyHooks()
end)

_G.F.findBattleRunButtonInGui = function()
	local okPlayer, player = pcall(function()
		return game:GetService("Players").LocalPlayer
	end)

	if not okPlayer or not player then
		return nil
	end

	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return nil
	end

	-- This gets polled every tick for the whole battle; once the Run item is
	-- known and visible, answer from it directly instead of sweeping
	-- PlayerGui again. A hidden cached item usually means the menu is just
	-- closed, but the game may also have swapped in a different Run item,
	-- so let the rate-limited rescan below keep running rather than pinning
	-- to this instance forever.
	local cachedItem = _G._battleRunItemCache
	if typeof(cachedItem) == "Instance" and cachedItem:IsDescendantOf(playerGui) then
		if _G.F.isGuiChainVisible(cachedItem) then
			local button = cachedItem:FindFirstChild("Button")
			if button and button:IsA("GuiButton") then
				return button
			end
		end
	else
		_G._battleRunItemCache = nil
	end

	local now = os.clock()
	if _G._battleRunScanAt and now - _G._battleRunScanAt < 0.25 then
		return nil
	end
	_G._battleRunScanAt = now

	local ok, descendants = pcall(function()
		return playerGui:GetDescendants()
	end)

	if not ok then
		return nil
	end

	for _, item in ipairs(descendants) do
		if item.Name == "Run" and item:IsA("GuiObject") and _G.F.isGuiChainVisible(item) then
			local button = item:FindFirstChild("Button")
			if button and button:IsA("GuiButton") then
				_G._battleRunItemCache = item
				return button
			end
		end
	end

	return nil
end

_G.F.getBattleRunButton = function()
	local battleGui = _G.F.getBattleGuiModule()
	if battleGui then
		local buttonData = _G.F.safeTableGet(battleGui, "buttonData")
		local runEntry = type(buttonData) == "table" and buttonData.run or nil
		local runUi = type(runEntry) == "table" and runEntry.ui or nil
		if runUi then
			local button = runUi:FindFirstChild("Button")
			if button then
				return button
			end
		end

		local main = _G.F.safeTableGet(battleGui, "main")
		local mainRun = type(main) == "table" and main.run or nil
		if mainRun then
			local button = mainRun:FindFirstChild("Button")
			if button then
				return button
			end
		end
	end

	return _G.F.findBattleRunButtonInGui()
end

_G.F.isBattleMainMenuOpen = function()
	local battleGui = _G.F.getBattleGuiModule()
	if not battleGui then
		return false
	end

	local contexts = _G.F.safeTableGet(battleGui, "currentMenuContexts")
	if type(contexts) == "table" then
		for _, contextName in ipairs(contexts) do
			if contextName == "main"
				or contextName == "mainFirst"
				or contextName == "mainOther"
				or contextName == "mainBagEnabled" then
				return true
			end
		end
	end

	local buttonData = _G.F.safeTableGet(battleGui, "buttonData")
	local runEntry = type(buttonData) == "table" and buttonData.run or nil
	local runUi = type(runEntry) == "table" and runEntry.ui or nil
	if runUi and runUi.Visible == true and _G.F.isGuiChainVisible(runUi) then
		return true
	end

	local main = _G.F.safeTableGet(battleGui, "main")
	local container = type(main) == "table" and main.container or nil
	if container and container.Visible == true and _G.F.isGuiChainVisible(container) then
		return true
	end

	return _G.F.findBattleRunButtonInGui() ~= nil
end

_G.battleRunEarliestAt = {}

_G.F.getBattleRunEarliestAt = function(battle)
	local battleId = battle and battle.battleId
	if not battleId then
		return os.clock()
	end

	if not _G.battleRunEarliestAt[battleId] then
		_G.battleRunEarliestAt[battleId] = os.clock() + 0.65
	end

	return _G.battleRunEarliestAt[battleId]
end

_G.F.clearBattleRunTiming = function(battle)
	local battleId = battle and battle.battleId
	if battleId then
		_G.battleRunEarliestAt[battleId] = nil
	end
end

_G.F.isBattleRunMenuReady = function(battle, allowTimedFallback)
	if not _G.F.isStaticBattleReadyToEnd(battle) then
		return false
	end

	local earliestAt = _G.F.getBattleRunEarliestAt(battle)
	if os.clock() < earliestAt then
		return false
	end

	-- Never try to run before the battle is awaiting input AND the
	-- BattleGui has taken the battle over. setupComplete flips before the
	-- camera pan / GUI load, and the previous battle's menu state can still
	-- read as "open" during the intro — running that early corrupts the
	-- battle client. (For fishing this also makes takeOver's mainChoices
	-- run before tryRun ends the battle.)
	if battle.state ~= "input" or not _G.F.isBattleLinkedToBattleGui(battle) then
		return false
	end

	if _G.F.isBattleMainMenuOpen() then
		return true
	end

	if allowTimedFallback then
		return os.clock() >= earliestAt + 0.6
	end

	return false
end

_G.F.finishNaturalBattleRun = function(battle, escaped, masteryUpdate, queueActions)
	if escaped == "partial" or escaped == false or escaped == nil then
		return false
	end

	if type(masteryUpdate) == "table" then
		battle.masteryProgressUpdate = masteryUpdate
	end

	if type(queueActions) == "table" then
		battle.actionQueue = battle.actionQueue or {}
		for _, action in ipairs(queueActions) do
			table.insert(battle.actionQueue, action)
		end
	end

	pcall(function()
		if type(_G._p) == "table" and type(_G._p.BattleCamera) == "table" and type(_G._p.BattleCamera.stopIdleCamera) == "function" then
			_G._p.BattleCamera.stopIdleCamera(battle)
		end
	end)

	pcall(function()
		battle.ended = true
		if battle.BattleEnded then
			battle.BattleEnded:Fire()
		end
	end)

	return true
end

_G.F.isBattleLinkedToBattleGui = function(battle)
	if type(battle) ~= "table" or battle.battleId == nil or type(_G._p) ~= "table" then
		return false
	end

	local linkedBattle = _G._p.Battle and _G._p.Battle.currentBattle
	if type(linkedBattle) ~= "table" or linkedBattle.battleId == nil then
		linkedBattle = _G._p.BattleClient and _G._p.BattleClient.currentBattle
	end

	return linkedBattle == battle
end

_G.F.naturalRunFromBattle = function(battle, allowTimedFallback)
	if type(battle) ~= "table" or battle.CanRun == false or battle.ended then
		return false
	end

	if not _G.F.isBattleRunMenuReady(battle, allowTimedFallback) then
		return false
	end

	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end

	local isFishingBattle = battle.fshPct ~= nil

	-- Fishing: skip BattleGui run clicks; they call mainChoices before Battle.currentBattle is set.
	if not isFishingBattle then
		local canClickBattleGui = _G.F.isBattleLinkedToBattleGui(battle)
		local runButton = _G.F.getBattleRunButton()

		-- Prefer clicking Run with the real mouse; fall back to the
		-- module/virtual paths only when that isn't possible.
		if canClickBattleGui and runButton and _G.F.realMouseClickGuiObject(runButton) then
			task.wait(0.2)

			if battle.ended then
				return true
			end
		end

		local battleGui = _G.F.getBattleGuiModule()
		local mainButtonClicked = battleGui and _G.F.safeTableGet(battleGui, "mainButtonClicked") or nil

		if canClickBattleGui and type(mainButtonClicked) == "function" then
			pcall(function()
				mainButtonClicked(battleGui, {}, 4)
			end)

			if battle.ended then
				return true
			end
		end

		if runButton and canClickBattleGui then
			_G.F.clickGuiButtonOnce(runButton)

			if battle.ended then
				return true
			end

			_G.F.activateGuiButton(runButton)

			if battle.ended then
				return true
			end
		end
	end

	local network = type(_G._p) == "table" and _G._p.Network or nil
	local battleId = battle.battleId
	if type(network) ~= "table" or type(network.get) ~= "function" or not battleId then
		return false
	end

	local ok, escaped, masteryUpdate, queueActions = pcall(function()
		return network:get("BattleFunction", battleId, "tryRun")
	end)

	if not ok then
		return false
	end

	return _G.F.finishNaturalBattleRun(battle, escaped, masteryUpdate, queueActions)
end
_G.naturalCatchFromBattle = nil
_G.normalizeCaptureDiscId = nil
_G.isCatchUiActive = nil
_G.resetCatchUiTiming = nil

do
	local CAPTURE_DISC_ALIASES = {
		capture = "capturedisc",
		basic = "basicdisc",
		advanced = "advanceddisc",
		expert = "expertdisc",
		hyper = "hyperdisc",
		ace = "acedisc",
		golden = "goldendisc",
	}

	local catchBagOpenedAt = 0
	local catchDiscSelectedAt = 0
	local catchOpenedBagForRequest = false
	local BAG_ITEMS_READY_DELAY = 0.55
	local DISC_DETAIL_READY_DELAY = 0.4

	local function normalizeCaptureDiscIdImpl(text)
		local trimmed = string.lower(string.gsub(tostring(text or ""), "^%s*(.-)%s*$", "%1"))
		if trimmed == "" then
			return nil
		end

		local compact = string.gsub(trimmed, "[^a-z0-9]", "")
		if compact == "" then
			return nil
		end

		if CAPTURE_DISC_ALIASES[compact] then
			return CAPTURE_DISC_ALIASES[compact]
		end

		if string.find(compact, "disc", 1, true) then
			local withoutCapture = string.gsub(compact, "capture", "")
			if withoutCapture ~= "" and string.find(withoutCapture, "disc", 1, true) then
				return withoutCapture
			end

			return compact
		end

		return compact .. "disc"
	end

	_G.normalizeCaptureDiscId = normalizeCaptureDiscIdImpl

	local function compactDiscSearchText(text)
		return string.gsub(string.lower(tostring(text or "")), "[^a-z0-9]", "")
	end

	local function discItemMatchesSearch(item, discId, discLabel)
		if type(item) ~= "table" then
			return false
		end

		local targetId = normalizeCaptureDiscIdImpl(discLabel) or normalizeCaptureDiscIdImpl(discId) or compactDiscSearchText(discId)
		if targetId == "" then
			return false
		end

		local itemId = compactDiscSearchText(item.id)
		if itemId == targetId or string.find(itemId, targetId, 1, true) or string.find(targetId, itemId, 1, true) then
			return true
		end

		local itemName = compactDiscSearchText(item.name)
		if itemName == targetId or string.find(itemName, targetId, 1, true) or string.find(targetId, itemName, 1, true) then
			return true
		end

		return false
	end

	local function getBattleBagModule()
		if type(_G._p) ~= "table" then
			_G._p = _G.F.findP()
		end

		local menu = type(_G._p) == "table" and _G._p.Menu or nil
		return menu and menu.bag or nil
	end

	local function getBattleBagButton()
		local battleGui = _G.F.getBattleGuiModule()
		if battleGui then
			local buttonData = _G.F.safeTableGet(battleGui, "buttonData")
			local bagEntry = type(buttonData) == "table" and buttonData.bag or nil
			local bagUi = type(bagEntry) == "table" and bagEntry.ui or nil
			if bagUi then
				local button = bagUi:FindFirstChild("Button")
				if button and _G.F.isGuiChainVisible(bagUi) then
					return button
				end
			end

			local main = _G.F.safeTableGet(battleGui, "main")
			local mainBag = type(main) == "table" and main.bag or nil
			if mainBag then
				local button = mainBag:FindFirstChild("Button")
				if button and _G.F.isGuiChainVisible(mainBag) then
					return button
				end
			end
		end

		local okPlayer, player = pcall(function()
			return game:GetService("Players").LocalPlayer
		end)

		if not okPlayer or not player then
			return nil
		end

		local playerGui = player:FindFirstChildOfClass("PlayerGui")
		if not playerGui then
			return nil
		end

		local ok, descendants = pcall(function()
			return playerGui:GetDescendants()
		end)

		if not ok then
			return nil
		end

		for _, item in ipairs(descendants) do
			if item:IsA("GuiObject") and _G.F.isGuiChainVisible(item) and (item.Name == "Items" or item.Name == "Bag") then
				local button = item:FindFirstChild("Button")
				if button and button:IsA("GuiButton") then
					return button
				end
			end
		end

		return nil
	end

	local function isBagOpenInBattle()
		local bag = getBattleBagModule()
		if type(bag) ~= "table" or bag.inBattle ~= true then
			return false
		end

		local battleContainer = bag.battleContainer
		return battleContainer and battleContainer.Visible == true and _G.F.isGuiChainVisible(battleContainer)
	end

	local function isBagItemDetailOpen()
		local bag = getBattleBagModule()
		if type(bag) ~= "table" then
			return false
		end

		local details = bag.battleDetailsContainer
		return details and details.Visible == true and _G.F.isGuiChainVisible(details)
	end

	local function findBattleBagDiscItem(discId, discLabel)
		if type(_G._p) ~= "table" then
			_G._p = _G.F.findP()
		end

		local network = type(_G._p) == "table" and _G._p.Network or nil
		if type(network) == "table" and type(network.get) == "function" then
			local ok, bagData = pcall(function()
				return network:get("PDS", "getBattleBag")
			end)

			if ok and type(bagData) == "table" then
				for _, itemList in ipairs(bagData) do
					if type(itemList) == "table" then
						for _, item in ipairs(itemList) do
							if discItemMatchesSearch(item, discId, discLabel) then
								return item
							end
						end
					end
				end
			end
		end

		return nil
	end

	local function getGuiItemDisplayName(guiButton)
		if not guiButton then
			return nil
		end

		local ok, descendants = pcall(function()
			return guiButton:GetDescendants()
		end)

		if not ok then
			return nil
		end

		for _, item in ipairs(descendants) do
			if item:IsA("TextLabel") then
				local okText, text = pcall(function()
					return item.Text
				end)

				if okText and type(text) == "string" and text ~= "" and not string.find(text, "^x%d+$") then
					return text
				end
			end
		end

		return nil
	end

	local function findBagDiscButton(discId, discLabel)
		local bag = getBattleBagModule()
		if type(bag) ~= "table" or not bag.battleContainer then
			return nil
		end

		local discContainer = bag.battleContainer:FindFirstChild("DiscContainer")
		local content = discContainer and discContainer:FindFirstChild("ContentContainer")
		if not content then
			return nil
		end

		local ok, children = pcall(function()
			return content:GetChildren()
		end)

		if not ok then
			return nil
		end

		for _, child in ipairs(children) do
			if child:IsA("GuiButton") and _G.F.isGuiChainVisible(child) then
				local displayName = getGuiItemDisplayName(child)
				if displayName and discItemMatchesSearch({ name = displayName, id = displayName }, discId, discLabel) then
					return child
				end
			end
		end

		return nil
	end

	local function clickBagUseButton(bag)
		if type(bag) ~= "table" then
			return false
		end

		if type(bag.useSelectedItemBattle) == "function" and bag.selection then
			pcall(function()
				bag:useSelectedItemBattle()
			end)
			return true
		end

		local useButton = bag.useButtonBattle
		if useButton and _G.F.isGuiChainVisible(useButton) then
			pcall(function()
				useButton:Activate()
			end)
			return true
		end

		local parent = useButton and useButton.Parent
		if parent and parent:IsA("GuiButton") and _G.F.isGuiChainVisible(parent) then
			pcall(function()
				parent:Activate()
			end)
			return true
		end

		return false
	end

	local function openBattleBagFromMain()
		local clicked = false
		local bagButton = getBattleBagButton()
		if not bagButton then
			return false
		end

		if _G.F.clickGuiButtonOnce(bagButton) then
			clicked = true
			task.wait(0.05)

			if isBagOpenInBattle() or isBagItemDetailOpen() then
				return true
			end
		end

		if _G.F.activateGuiButton(bagButton) then
			clicked = true
			task.wait(0.05)

			if isBagOpenInBattle() or isBagItemDetailOpen() then
				return true
			end
		end

		return clicked
	end

	_G.isCatchUiActive = function()
		return isBagOpenInBattle() or isBagItemDetailOpen()
	end

	_G.resetCatchUiTiming = function()
		catchBagOpenedAt = 0
		catchDiscSelectedAt = 0
		catchOpenedBagForRequest = false
	end

	_G.naturalCatchFromBattle = function(battle, discId, discLabel)
		if type(_G._p) ~= "table" then
			_G._p = _G.F.findP()
		end

		if _G.F.isBattleSetupPending(battle) then
			return false, "Battle setup not ready."
		end

		local bag = getBattleBagModule()

		if isBagItemDetailOpen() and catchOpenedBagForRequest then
			if catchDiscSelectedAt == 0 then
				catchDiscSelectedAt = os.clock()
				return false, "Waiting for disc detail."
			end

			if type(bag) == "table" and not bag.selection then
				return false, "Waiting for disc detail."
			end

			if os.clock() - catchDiscSelectedAt < DISC_DETAIL_READY_DELAY then
				return false, "Waiting for disc detail."
			end

			clickBagUseButton(bag)
			return true
		end

		if isBagOpenInBattle() and catchOpenedBagForRequest then
			if catchBagOpenedAt == 0 then
				catchBagOpenedAt = os.clock()
				return false, "Waiting for bag items."
			end

			if os.clock() - catchBagOpenedAt < BAG_ITEMS_READY_DELAY then
				return false, "Waiting for bag items."
			end

			local itemData = findBattleBagDiscItem(discId, discLabel)
			if itemData and type(bag) == "table" and type(bag.viewItemBattle) == "function" then
				pcall(function()
					bag:viewItemBattle(itemData)
				end)
				catchDiscSelectedAt = os.clock()
				return false, "Disc opened."
			end

			local discButton = findBagDiscButton(discId, discLabel)
			if discButton then
				pcall(function()
					discButton:Activate()
				end)
				catchDiscSelectedAt = os.clock()
				return false, "Disc selected."
			end

			return false, "Waiting for bag items."
		end

		if not _G.F.isBattleRunMenuReady(battle) then
			return false, "Battle menu not ready."
		end

		if openBattleBagFromMain() then
			catchBagOpenedAt = os.clock()
			catchDiscSelectedAt = 0
			catchOpenedBagForRequest = true
			return false, "Opening bag."
		end

		return false, "Bag button not found."
	end
end

_G.F.getRoot = function()
	local ok, root = pcall(function()
		local character = _G.Player.Character or _G.Player.CharacterAdded:Wait()
		return character:FindFirstChild("HumanoidRootPart")
	end)

	if ok then
		return root
	end

	return nil
end

_G.F.setEggRainStatus = function(text)
	local statusText = tostring(text or "Idle")

	if _G.eggRainStatusLabel and type(_G.eggRainStatusLabel.Set) == "function" then
		pcall(function()
			_G.eggRainStatusLabel:Set("Status: " .. statusText)
		end)
	end
end

_G.F.isEggRainPart = function(item)
	if not item or not item:IsA("BasePart") then
		return false
	end

	if item.Name ~= _G.EGG_RAIN_TARGET_NAME then
		return false
	end

	local size = item.Size
	local target = _G.EGG_RAIN_TARGET_SIZE
	local tolerance = _G.EGG_RAIN_SIZE_TOLERANCE

	return math.abs(size.X - target.X) <= tolerance
		and math.abs(size.Y - target.Y) <= tolerance
		and math.abs(size.Z - target.Z) <= tolerance
end

_G.F.getEggRainParts = function()
	local ok, descendants = pcall(function()
		return workspace:GetDescendants()
	end)

	if not ok or type(descendants) ~= "table" then
		return nil, "Could not scan workspace."
	end

	local parts = {}

	for _, item in ipairs(descendants) do
		if _G.F.isEggRainPart(item) then
			table.insert(parts, item)
		end
	end

	if #parts == 0 then
		return nil, "No Egg Rain parts found."
	end

	return parts
end

_G.F.bringEggRainPartsToPlayer = function()
	local root = _G.F.getRoot()
	if not root then
		_G.F.setEggRainStatus("Character root not ready.")
		return false, "Character root not ready."
	end

	local parts, reason = _G.F.getEggRainParts()
	if not parts then
		_G.F.setEggRainStatus(reason)
		return false, reason
	end

	local movedCount = 0
	local firstError = nil
	local zeroVelocity = Vector3.new(0, 0, 0)

	for _, part in ipairs(parts) do
		pcall(function()
			part.AssemblyLinearVelocity = zeroVelocity
			part.AssemblyAngularVelocity = zeroVelocity
		end)

		local moved, moveErr = pcall(function()
			part.CFrame = root.CFrame
		end)

		if moved then
			movedCount = movedCount + 1
		elseif not firstError then
			firstError = tostring(moveErr)
		end
	end

	if movedCount == 0 then
		local reasonText = "Could not move Egg Rain parts: " .. tostring(firstError or "unknown error")
		_G.F.setEggRainStatus(reasonText)
		return false, reasonText
	end

	_G.F.setEggRainStatus(string.format("Brought %d egg part(s) to you.", movedCount))

	return true
end

_G.F.bringNearestEggRainPartToPlayer = _G.F.bringEggRainPartsToPlayer
_G.F.teleportToNearestEggRainPart = _G.F.bringEggRainPartsToPlayer

_G.F.runEggRainBringOnce = function()
	if type(_G.F.setEggRainStatus) ~= "function" then
		_G.F.setEggRainStatus = function() end
	end

	local bringFunction = _G.F.bringEggRainPartsToPlayer
		or _G.F.bringNearestEggRainPartToPlayer
		or _G.F.teleportToNearestEggRainPart

	if type(bringFunction) ~= "function" then
		_G.F.setEggRainStatus("Egg Rain bring function not loaded.")
		return false, "Egg Rain bring function not loaded."
	end

	return bringFunction()
end

local WallSparkleCollectionService = game:GetService("CollectionService")

_G.F.isWallSparklePart = function(instance)
	local cfg = _G.WALL_SPARKLE_CONFIG
	return instance:IsA("BasePart") and string.lower(instance.Name) == string.lower(cfg.TARGET_NAME)
end

_G.F.getOrCreateWallSparkleChild = function(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end

	local created = Instance.new(className)
	created.Name = name
	created.Parent = parent
	return created
end

_G.F.captureWallSparkleOriginal = function(part)
	if _G.WALL_SPARKLE_ORIGINALS[part] then
		return
	end

	_G.WALL_SPARKLE_ORIGINALS[part] = {
		Material = part.Material,
		Color = part.Color,
		CastShadow = part.CastShadow,
	}
end

_G.F.applyWallSparkleMarker = function(part)
	if not _G.F.isWallSparklePart(part) then
		return false
	end

	local cfg = _G.WALL_SPARKLE_CONFIG
	_G.F.captureWallSparkleOriginal(part)

	part:SetAttribute("ThroughWallsVisible", true)
	part.Material = Enum.Material.Neon
	part.Color = cfg.PART_COLOR
	part.CastShadow = false

	local highlight = _G.F.getOrCreateWallSparkleChild(part, "Highlight", cfg.HIGHLIGHT_NAME)
	highlight.Adornee = part
	highlight.Enabled = true
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = cfg.FILL_COLOR
	highlight.OutlineColor = cfg.OUTLINE_COLOR
	highlight.FillTransparency = 0.35
	highlight.OutlineTransparency = 0

	local billboard = _G.F.getOrCreateWallSparkleChild(part, "BillboardGui", cfg.BILLBOARD_NAME)
	billboard.Adornee = part
	billboard.AlwaysOnTop = true
	billboard.Enabled = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 100000
	billboard.Size = UDim2.fromOffset(34, 18)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 1.15, 0)

	local label = _G.F.getOrCreateWallSparkleChild(billboard, "TextLabel", "Label")
	label.BackgroundTransparency = 0.15
	label.BackgroundColor3 = Color3.fromRGB(8, 17, 23)
	label.BorderSizePixel = 0
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBold
	label.Text = "WS"
	label.TextColor3 = Color3.fromRGB(255, 236, 122)
	label.TextScaled = true
	label.TextStrokeTransparency = 0.35
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)

	if not WallSparkleCollectionService:HasTag(part, cfg.TAG_NAME) then
		WallSparkleCollectionService:AddTag(part, cfg.TAG_NAME)
	end

	return true
end

_G.F.removeWallSparkleMarker = function(part)
	if not part or not part:IsA("BasePart") then
		return
	end

	local cfg = _G.WALL_SPARKLE_CONFIG
	local highlight = part:FindFirstChild(cfg.HIGHLIGHT_NAME)
	if highlight then
		highlight:Destroy()
	end

	local billboard = part:FindFirstChild(cfg.BILLBOARD_NAME)
	if billboard then
		billboard:Destroy()
	end

	part:SetAttribute("ThroughWallsVisible", nil)

	if WallSparkleCollectionService:HasTag(part, cfg.TAG_NAME) then
		WallSparkleCollectionService:RemoveTag(part, cfg.TAG_NAME)
	end

	local original = _G.WALL_SPARKLE_ORIGINALS[part]
	if original then
		part.Material = original.Material
		part.Color = original.Color
		part.CastShadow = original.CastShadow
		_G.WALL_SPARKLE_ORIGINALS[part] = nil
	end
end

_G.F.scanWallSparkleParts = function()
	local count = 0

	for _, instance in ipairs(workspace:GetDescendants()) do
		if _G.F.isWallSparklePart(instance) and _G.F.applyWallSparkleMarker(instance) then
			count += 1
		end
	end

	_G.wallSparkleUmvCount = count
	return count
end

_G.F.setWallSparkleUmvStatus = function(text)
	local statusText = tostring(text or "Idle")

	if _G.wallSparkleUmvStatusLabel and type(_G.wallSparkleUmvStatusLabel.Set) == "function" then
		pcall(function()
			_G.wallSparkleUmvStatusLabel:Set("Status: " .. statusText)
		end)
	end
end

_G.F.refreshWallSparkleUmvUi = function()
	if _G.wallSparkleUmvCountLabel and type(_G.wallSparkleUmvCountLabel.Set) == "function" then
		pcall(function()
			_G.wallSparkleUmvCountLabel:Set("Marked: " .. tostring(_G.wallSparkleUmvCount or 0))
		end)
	end
end

_G.F.refreshUmvMiningUi = function()
	if _G.umvMiningRevealedCountLabel and type(_G.umvMiningRevealedCountLabel.Set) == "function" then
		pcall(function()
			_G.umvMiningRevealedCountLabel:Set("Revealed: " .. tostring(_G.umvMiningRevealedCount or 0))
		end)
	end
end

_G.F.clearAllWallSparkleMarkers = function()
	local cfg = _G.WALL_SPARKLE_CONFIG

	for _, part in ipairs(WallSparkleCollectionService:GetTagged(cfg.TAG_NAME)) do
		_G.F.removeWallSparkleMarker(part)
	end

	for _, instance in ipairs(workspace:GetDescendants()) do
		if _G.F.isWallSparklePart(instance) and instance:GetAttribute("ThroughWallsVisible") then
			_G.F.removeWallSparkleMarker(instance)
		end
	end

	_G.wallSparkleUmvCount = 0
	_G.F.refreshWallSparkleUmvUi()
end

_G.F.setWallSparkleUmvEnabled = function(value)
	value = value and true or false
	if _G.wallSparkleUmvEnabled == value then
		return
	end

	_G.wallSparkleUmvEnabled = value

	if value then
		if not _G.wallSparkleUmvDescendantConnection then
			_G.wallSparkleUmvDescendantConnection = workspace.DescendantAdded:Connect(function(instance)
				if _G.wallSparkleUmvEnabled and _G.F.isWallSparklePart(instance) then
					if _G.F.applyWallSparkleMarker(instance) then
						_G.wallSparkleUmvCount += 1
						_G.F.refreshWallSparkleUmvUi()
					end
				end
			end)
		end

		local count = _G.F.scanWallSparkleParts()
		_G.F.setWallSparkleUmvStatus(string.format("Enabled — %d WallSparkle part(s) marked.", count))
	else
		if _G.wallSparkleUmvDescendantConnection then
			_G.wallSparkleUmvDescendantConnection:Disconnect()
			_G.wallSparkleUmvDescendantConnection = nil
		end

		_G.F.clearAllWallSparkleMarkers()
		_G.F.setWallSparkleUmvStatus("Disabled.")
	end

	_G.F.refreshWallSparkleUmvUi()
end

_G.F.umvMiningAssetId = function(value)
	return tostring(value or ""):match("%d+")
end

_G.F.umvMiningSameAtlas = function(guiObject)
	return _G.F.umvMiningAssetId(guiObject.Image) == _G.UMV_MINING_ATLAS_ID
end

_G.F.umvMiningIsMiningGrid = function(candidate)
	if not candidate:IsA("ImageButton") then
		return false
	end

	if not _G.F.umvMiningSameAtlas(candidate) then
		return false
	end

	return candidate.ImageRectSize == Vector2.new(352, 256)
		and candidate.ImageRectOffset == Vector2.new(16, 16)
end

_G.F.isUmvMiningHiddenIcon = function(descendant)
	if not descendant:IsA("ImageLabel") or not _G.F.umvMiningSameAtlas(descendant) then
		return false
	end

	if descendant:GetAttribute("UmvMiningHiddenItem") then
		return true
	end

	return descendant.ZIndex == 3
end

_G.F.umvMiningGetRevealZIndex = function(grid)
	local maxZ = grid.ZIndex or 1

	for _, descendant in ipairs(grid:GetDescendants()) do
		if descendant:IsA("GuiObject") and not _G.F.isUmvMiningHiddenIcon(descendant) then
			maxZ = math.max(maxZ, descendant.ZIndex)
		end
	end

	return maxZ + 10
end

_G.F.applyUmvMiningReveal = function(icon, grid)
	if not _G.F.isUmvMiningHiddenIcon(icon) then
		return false
	end

	if not grid or not _G.F.umvMiningIsMiningGrid(grid) then
		return false
	end

	if not _G.umvMiningRevealOriginals[icon] then
		_G.umvMiningRevealOriginals[icon] = {
			ZIndex = icon.ZIndex,
			ImageTransparency = icon.ImageTransparency,
			BackgroundTransparency = icon.BackgroundTransparency,
			Active = icon.Active,
			Selectable = icon.Selectable,
			Visible = icon.Visible,
		}
	end

	icon:SetAttribute("UmvMiningHiddenItem", true)
	icon.ZIndex = _G.F.umvMiningGetRevealZIndex(grid)
	icon.ImageTransparency = 0
	icon.BackgroundTransparency = 1
	icon.Active = false
	icon.Selectable = false
	icon.Visible = true

	return true
end

_G.F.removeUmvMiningReveal = function(icon)
	if not icon or not icon:IsA("GuiObject") then
		return
	end

	local original = _G.umvMiningRevealOriginals[icon]
	if original then
		icon.ZIndex = original.ZIndex
		icon.ImageTransparency = original.ImageTransparency
		icon.BackgroundTransparency = original.BackgroundTransparency
		icon.Active = original.Active
		icon.Selectable = original.Selectable
		icon.Visible = original.Visible
		_G.umvMiningRevealOriginals[icon] = nil
	end

	icon:SetAttribute("UmvMiningHiddenItem", nil)
end

_G.F.clearUmvMiningReveal = function()
	local icons = {}
	for icon in pairs(_G.umvMiningRevealOriginals) do
		table.insert(icons, icon)
	end

	for _, icon in ipairs(icons) do
		_G.F.removeUmvMiningReveal(icon)
	end

	_G.umvMiningRevealedCount = 0
	_G.F.refreshUmvMiningUi()
end

_G.F.revealUmvMiningHiddenItems = function()
	local player = _G.Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return 0
	end

	local count = 0

	for _, grid in ipairs(_G.F.umvMiningFindGrids(playerGui)) do
		for _, descendant in ipairs(grid:GetDescendants()) do
			if _G.F.isUmvMiningHiddenIcon(descendant) and _G.F.applyUmvMiningReveal(descendant, grid) then
				count += 1
			end
		end
	end

	_G.umvMiningRevealedCount = count
	_G.F.refreshUmvMiningUi()
	return count
end

_G.F.umvMiningFindGrids = function(playerGui)
	local grids = {}

	for _, descendant in ipairs(playerGui:GetDescendants()) do
		if _G.F.umvMiningIsMiningGrid(descendant) then
			table.insert(grids, descendant)
		end
	end

	return grids
end

_G.F.onUmvMiningPlayerGuiDescendant = function(descendant)
	if _G.F.umvMiningIsMiningGrid(descendant) then
		if _G.umvMiningRevealEnabled then
			task.defer(_G.F.revealUmvMiningHiddenItems)
		end
		return
	end

	if not _G.umvMiningRevealEnabled or not _G.F.isUmvMiningHiddenIcon(descendant) then
		return
	end

	local parent = descendant.Parent
	while parent do
		if _G.F.umvMiningIsMiningGrid(parent) then
			if _G.F.applyUmvMiningReveal(descendant, parent) then
				_G.umvMiningRevealedCount += 1
				_G.F.refreshUmvMiningUi()
			end
			break
		end
		parent = parent.Parent
	end
end

_G.F.stopUmvMiningPlayerGuiWatcher = function()
	if _G.umvMiningRevealEnabled then
		return
	end

	if _G.umvMiningPlayerGuiWatchConnection then
		_G.umvMiningPlayerGuiWatchConnection:Disconnect()
		_G.umvMiningPlayerGuiWatchConnection = nil
	end
end

_G.F.ensureUmvMiningPlayerGuiWatcher = function()
	if not _G.umvMiningRevealEnabled or _G.umvMiningPlayerGuiWatchConnection then
		return
	end

	local player = _G.Players.LocalPlayer
	local playerGui = player and player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then
		return
	end

	_G.umvMiningPlayerGuiWatchConnection = playerGui.DescendantAdded:Connect(_G.F.onUmvMiningPlayerGuiDescendant)
end

_G.F.startUmvMiningRevealLoop = function()
	if _G.umvMiningRevealLoopAlive then
		return
	end

	_G.umvMiningRevealLoopAlive = true

	task.spawn(function()
		while _G.umvMiningRevealEnabled and _G.uiAlive do
			_G.F.revealUmvMiningHiddenItems()
			task.wait(0.35)
		end

		_G.umvMiningRevealLoopAlive = false
	end)
end

_G.F.setUmvMiningRevealEnabled = function(value)
	value = value and true or false
	if _G.umvMiningRevealEnabled == value then
		return
	end

	_G.umvMiningRevealEnabled = value

	if value then
		_G.F.ensureUmvMiningPlayerGuiWatcher()

		if not _G.umvMiningPlayerGuiWatchConnection then
			task.spawn(function()
				local player = _G.Players.LocalPlayer
				if not player then
					return
				end

				player:WaitForChild("PlayerGui", 30)
				_G.F.ensureUmvMiningPlayerGuiWatcher()

				if _G.umvMiningRevealEnabled then
					_G.F.revealUmvMiningHiddenItems()
					_G.F.startUmvMiningRevealLoop()
				end
			end)
		else
			_G.F.revealUmvMiningHiddenItems()
			_G.F.startUmvMiningRevealLoop()
		end
	else
		_G.F.clearUmvMiningReveal()
		_G.F.stopUmvMiningPlayerGuiWatcher()
	end
end

-- UMV remote sparkle miner: TP to nearest WS sparkle, sync mine point, fire game click.
_G.remoteSparkleMineEnabled = false
_G.remoteSparkleMineKeyConnection = nil
_G.remoteSparkleMineStatusLabel = nil
_G.REMOTE_SPARKLE_STANDOFF = 10
_G.REMOTE_SPARKLE_FRONT_CLEARANCE = 3
_G.REMOTE_SPARKLE_Y_PADDING_BELOW = 8
_G.REMOTE_SPARKLE_Y_PADDING_ABOVE = 5
_G._remoteSparkleYLimitsCache = nil
_G.cachedMiningModule = nil
_G.cachedMiningModuleAt = 0
_G.MINING_MODULE_CACHE_TTL = 1.5

_G.F.clearRemoteSparkleYLimitsCache = function()
	_G._remoteSparkleYLimitsCache = nil
end

_G.F.clearMiningModuleCache = function()
	_G.cachedMiningModule = nil
	_G.cachedMiningModuleAt = 0
end

_G.F.partIsNamedWall = function(part)
	return typeof(part) == "Instance" and part:IsA("BasePart") and string.lower(part.Name) == "wall"
end

_G.F.getMiningChunk = function()
	for _, chunkName in ipairs({ "chunk17b", "chunk17a", "chunk17c" }) do
		local chunk = workspace:FindFirstChild(chunkName)
		if chunk then
			return chunk
		end
	end

	return nil
end

_G.F.getBeastsChunkMap = function()
	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end

	local currentChunk = type(_G._p) == "table" and _G._p.DataManager and _G._p.DataManager.currentChunk or nil

	if type(currentChunk) == "table" then
		if currentChunk.map then
			return currentChunk.map
		end

		if type(currentChunk.GetMap) == "function" then
			local ok, map = pcall(function()
				return currentChunk:GetMap()
			end)

			if ok and map then
				return map
			end
		end
	end

	-- The chunk map goes nil while a soft reset reloads the chunk, and this
	-- gets polled every tick; reuse the last found map and keep the tree
	-- searches below on a cooldown instead of sweeping workspace each call.
	local cached = _G._beastsChunkMapCache
	if typeof(cached) == "Instance" and cached:IsDescendantOf(game) then
		return cached
	end
	_G._beastsChunkMapCache = nil

	local now = os.clock()
	if _G._beastsChunkScanAt and now - _G._beastsChunkScanAt < 3 then
		return nil
	end
	_G._beastsChunkScanAt = now

	for _, chunkName in ipairs({ "chunk27", "Chunk27" }) do
		local wsChunk = workspace:FindFirstChild(chunkName)
		if wsChunk then
			if wsChunk:FindFirstChild("SoftResetTriggers", true) then
				_G._beastsChunkMapCache = wsChunk
				return wsChunk
			end

			local nestedMap = wsChunk:FindFirstChild("map")
			if nestedMap and nestedMap:FindFirstChild("SoftResetTriggers", true) then
				_G._beastsChunkMapCache = nestedMap
				return nestedMap
			end
		end
	end

	for _, descendant in ipairs(workspace:GetDescendants()) do
		if descendant.Name == "SoftResetTriggers" then
			local lavaTrigger = descendant:FindFirstChild("Lava")
			if lavaTrigger and lavaTrigger:IsA("BasePart") then
				_G._beastsChunkMapCache = descendant.Parent
				return descendant.Parent
			end
		end
	end

	return nil
end

_G.F.getSelectedBeastName = function()
	local name = tostring(_G.beastTarget or "")
	if _G.BEAST_HUNTS[name] then
		return name
	end

	return "Arceros"
end

_G.F.getBeastTrigger = function(beastName)
	if not _G.BEAST_HUNTS[beastName] then
		beastName = _G.F.getSelectedBeastName()
	end

	local map = _G.F.getBeastsChunkMap()
	if not map then
		return nil, nil
	end

	-- Reuse the last resolved trigger while it still belongs to the current
	-- map; this gets polled every tick, so avoid re-walking the map tree.
	_G._beastTriggerCache = _G._beastTriggerCache or {}

	local cached = _G._beastTriggerCache[beastName]
	if typeof(cached) == "Instance" and cached:IsDescendantOf(map) then
		return cached, map
	end
	_G._beastTriggerCache[beastName] = nil

	local triggers = map:FindFirstChild("SoftResetTriggers")
	if not triggers then
		local now = os.clock()
		if _G._beastTriggerScanAt and now - _G._beastTriggerScanAt < 3 then
			return nil, map
		end
		_G._beastTriggerScanAt = now

		for _, descendant in ipairs(map:GetDescendants()) do
			if descendant.Name == "SoftResetTriggers" then
				triggers = descendant
				break
			end
		end
	end

	if not triggers then
		return nil, map
	end

	for _, triggerName in ipairs(_G.BEAST_HUNTS[beastName].triggerNames) do
		local trigger = triggers:FindFirstChild(triggerName)
		if trigger and trigger:IsA("BasePart") then
			_G._beastTriggerCache[beastName] = trigger
			return trigger, map
		end
	end

	-- Trigger names can change between game updates; fall back to any
	-- BasePart trigger that no other beast's name list claims.
	local claimed = {}
	for otherName, otherInfo in pairs(_G.BEAST_HUNTS) do
		if otherName ~= beastName then
			for _, triggerName in ipairs(otherInfo.triggerNames) do
				claimed[string.lower(triggerName)] = true
			end
		end
	end

	for _, child in ipairs(triggers:GetChildren()) do
		if child:IsA("BasePart") and not claimed[string.lower(child.Name)] then
			_G._beastTriggerCache[beastName] = child
			return child, map
		end
	end

	return nil, map
end

_G.F.getSelectedBeastTrigger = function()
	return _G.F.getBeastTrigger(_G.F.getSelectedBeastName())
end

_G.F.getArcerosLavaTrigger = function()
	return _G.F.getBeastTrigger("Arceros")
end

_G.F.getBeastBattleScene = function(beastName)
	if not _G.BEAST_HUNTS[beastName] then
		beastName = _G.F.getSelectedBeastName()
	end

	local map = _G.F.getBeastsChunkMap()
	if not map then
		return nil
	end

	local scenes = map:FindFirstChild("BuiltInBattleScenes")
	if not scenes then
		for _, descendant in ipairs(map:GetDescendants()) do
			if descendant.Name == "BuiltInBattleScenes" then
				scenes = descendant
				break
			end
		end
	end

	if not scenes then
		return nil
	end

	-- Scene children mirror the trigger names (e.g. "Lava").
	for _, sceneName in ipairs(_G.BEAST_HUNTS[beastName].triggerNames) do
		local scene = scenes:FindFirstChild(sceneName)
		if scene then
			return scene
		end
	end

	return nil
end

_G.F.getArcerosBattleScene = function()
	return _G.F.getBeastBattleScene("Arceros")
end

_G.F.getMiningWallsModel = function()
	local chunk = _G.F.getMiningChunk()
	if not chunk then
		return nil
	end

	local walls = chunk:FindFirstChild("Walls")
	if walls then
		return walls
	end

	local map = chunk:FindFirstChild("map")
	if map then
		return map:FindFirstChild("Walls")
	end

	return nil
end

_G.F.getRemoteSparkleYLimits = function()
	if _G._remoteSparkleYLimitsCache then
		return _G._remoteSparkleYLimitsCache[1], _G._remoteSparkleYLimitsCache[2]
	end

	local yMin = math.huge
	local yMax = -math.huge

	local function absorbPart(part)
		if not part:IsA("BasePart") then
			return
		end

		local halfY = part.Size.Y * 0.5
		yMin = math.min(yMin, part.Position.Y - halfY)
		yMax = math.max(yMax, part.Position.Y + halfY)
	end

	local walls = _G.F.getMiningWallsModel()
	if walls then
		for _, descendant in ipairs(walls:GetDescendants()) do
			absorbPart(descendant)
		end
	end

	local chunk = _G.F.getMiningChunk()
	if chunk then
		for _, descendant in ipairs(chunk:GetDescendants()) do
			if _G.F.partIsNamedWall(descendant) then
				absorbPart(descendant)
			end
		end
	end

	if yMin == math.huge then
		yMin, yMax = -500, 500
	else
		yMin -= _G.REMOTE_SPARKLE_Y_PADDING_BELOW
		yMax += _G.REMOTE_SPARKLE_Y_PADDING_ABOVE
	end

	_G._remoteSparkleYLimitsCache = { yMin, yMax }
	return yMin, yMax
end

_G.F.clampRemoteSparkleY = function(y)
	local yMin, yMax = _G.F.getRemoteSparkleYLimits()
	return math.clamp(y, yMin, yMax)
end

_G.F.isSparkleWithinYLimits = function(sparklePart)
	if typeof(sparklePart) ~= "Instance" then
		return false
	end

	local yMin, yMax = _G.F.getRemoteSparkleYLimits()
	local sparkleY = sparklePart.Position.Y
	return sparkleY >= yMin and sparkleY <= yMax
end

_G.F.isSparkleTouchingWall = function(sparklePart)
	if typeof(sparklePart) ~= "Instance" or not sparklePart:IsA("BasePart") then
		return false
	end

	local ok, touchingParts = pcall(function()
		return sparklePart:GetTouchingParts()
	end)

	if ok and type(touchingParts) == "table" then
		for _, part in touchingParts do
			if _G.F.partIsNamedWall(part) then
				return true
			end
		end
	end

	local probeDirections = {
		sparklePart.CFrame.LookVector,
		-sparklePart.CFrame.LookVector,
		sparklePart.CFrame.RightVector,
		-sparklePart.CFrame.RightVector,
		sparklePart.CFrame.UpVector,
		-sparklePart.CFrame.UpVector,
	}

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { sparklePart }

	for _, direction in ipairs(probeDirections) do
		if direction.Magnitude > 0.01 then
			local hit = workspace:Raycast(sparklePart.Position, direction.Unit * 4, params)
			if hit and _G.F.partIsNamedWall(hit.Instance) then
				return true
			end
		end
	end

	local wallsModel = _G.F.getMiningWallsModel()
	if wallsModel then
		for _, descendant in ipairs(wallsModel:GetDescendants()) do
			if _G.F.partIsNamedWall(descendant) then
				local localPosition = descendant.CFrame:PointToObjectSpace(sparklePart.Position)
				local halfSize = descendant.Size * 0.5
				local offsetX = math.max(math.abs(localPosition.X) - halfSize.X, 0)
				local offsetY = math.max(math.abs(localPosition.Y) - halfSize.Y, 0)
				local offsetZ = math.max(math.abs(localPosition.Z) - halfSize.Z, 0)
				if Vector3.new(offsetX, offsetY, offsetZ).Magnitude <= 2.5 then
					return true
				end
			end
		end
	end

	return false
end

_G.F.getSparkleFrontVector = function(sparklePart)
	if typeof(sparklePart) ~= "Instance" or not sparklePart:IsA("BasePart") then
		return nil
	end

	local front = sparklePart.CFrame.LookVector
	front = Vector3.new(front.X, 0, front.Z)
	if front.Magnitude < 0.05 then
		return nil
	end

	return front.Unit
end

_G.F.raycastSparkleWall = function(sparklePart, direction, distance)
	if typeof(sparklePart) ~= "Instance" or not sparklePart:IsA("BasePart") or typeof(direction) ~= "Vector3" then
		return nil
	end

	if direction.Magnitude < 0.01 then
		return nil
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { sparklePart }

	local ok, hit = pcall(function()
		return workspace:Raycast(sparklePart.Position, direction.Unit * (distance or 5), params)
	end)

	if ok and hit and _G.F.partIsNamedWall(hit.Instance) then
		return hit
	end

	return nil
end

_G.F.getSparkleTeleportFrontVector = function(sparklePart)
	local front = _G.F.getSparkleFrontVector(sparklePart)
	if not front then
		return nil
	end

	local frontWall = _G.F.raycastSparkleWall(sparklePart, front, 5)
	local backWall = _G.F.raycastSparkleWall(sparklePart, -front, 5)

	-- Prefer the open side of the sparkle's Front face. If the wall is in
	-- front, stand behind it instead; if the wall is behind, stand in front.
	if frontWall and not backWall then
		return -front
	end

	return front
end

_G.F.isSparkleFrontFaceUsable = function(sparklePart)
	local front = _G.F.getSparkleTeleportFrontVector(sparklePart)
	if not front then
		return false
	end

	local wallBehind = _G.F.raycastSparkleWall(sparklePart, -front, 5)
	local wallAhead = _G.F.raycastSparkleWall(sparklePart, front, _G.REMOTE_SPARKLE_FRONT_CLEARANCE)

	return wallBehind ~= nil and wallAhead == nil
end

_G.F.isValidMiningSparkle = function(sparklePart)
	return _G.F.isWallSparklePart(sparklePart)
		and _G.F.isSparkleWithinYLimits(sparklePart)
		and _G.F.isSparkleTouchingWall(sparklePart)
		and _G.F.isSparkleFrontFaceUsable(sparklePart)
end

_G.F.setRemoteSparkleMineStatus = function(text)
	if _G.remoteSparkleMineStatusLabel and type(_G.remoteSparkleMineStatusLabel.Set) == "function" then
		pcall(function()
			_G.remoteSparkleMineStatusLabel:Set("Remote Mine: " .. tostring(text))
		end)
	end
end

_G.F.getActiveWallSparkles = function()
	local sparkles = {}

	for _, inst in ipairs(workspace:GetDescendants()) do
		if inst.Parent == workspace and _G.F.isValidMiningSparkle(inst) then
			table.insert(sparkles, inst)
		end
	end

	if #sparkles == 0 then
		for _, inst in ipairs(workspace:GetDescendants()) do
			if _G.F.isValidMiningSparkle(inst) then
				table.insert(sparkles, inst)
			end
		end
	end

	return sparkles
end

_G.F.getNearestWallSparkle = function(worldPosition)
	if typeof(worldPosition) ~= "Vector3" then
		return nil
	end

	local ranked = {}

	for _, sparkle in ipairs(_G.F.getActiveWallSparkles()) do
		table.insert(ranked, {
			part = sparkle,
			distance = (worldPosition - sparkle.Position).Magnitude,
		})
	end

	table.sort(ranked, function(a, b)
		return a.distance < b.distance
	end)

	if ranked[1] then
		return ranked[1].part
	end

	return nil
end

_G.F.temporarilyDisableCharacterCollision = function(character, duration)
	if typeof(character) ~= "Instance" then
		return
	end

	local originals = {}
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			originals[descendant] = descendant.CanCollide
			pcall(function()
				descendant.CanCollide = false
			end)
		end
	end

	task.delay(duration or 1.25, function()
		for part, canCollide in pairs(originals) do
			if typeof(part) == "Instance" and part.Parent then
				pcall(function()
					part.CanCollide = canCollide
				end)
			end
		end
	end)
end

_G.F.teleportCharacterToSparkle = function(sparklePart)
	local player = _G.Players.LocalPlayer
	local character = player and player.Character
	local humanoidRootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoidRootPart or typeof(sparklePart) ~= "Instance" then
		return false
	end

	if not _G.F.isValidMiningSparkle(sparklePart) then
		return false
	end

	local sparklePosition = sparklePart.Position
	local front = _G.F.getSparkleTeleportFrontVector(sparklePart)
	if not front then
		return false
	end

	_G.F.temporarilyDisableCharacterCollision(character, 1.5)
	pcall(function()
		humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
		humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
	end)

	local stand = sparklePosition + front * _G.REMOTE_SPARKLE_STANDOFF
	local standY = _G.F.clampRemoteSparkleY(sparklePosition.Y + 2)
	humanoidRootPart.CFrame = CFrame.new(
		Vector3.new(stand.X, standY, stand.Z),
		sparklePosition
	)
	return true
end

_G.F.findMinePointForSparkle = function(sparklePart, mining)
	if typeof(sparklePart) ~= "Instance" then
		return nil
	end

	mining = mining or _G.F.getMiningModule(true)
	if not mining then
		return nil
	end

	local minePoints = _G.F.safeTableGet(mining, "MinePoints")
	if type(minePoints) ~= "table" then
		return nil
	end

	for _, minePoint in pairs(minePoints) do
		if type(minePoint) == "table" and _G.F.safeTableGet(minePoint, "Part") == sparklePart then
			return minePoint
		end
	end

	local nearestPoint = nil
	local nearestDistance = nil

	for _, minePoint in pairs(minePoints) do
		if type(minePoint) == "table" then
			local part = _G.F.safeTableGet(minePoint, "Part")
			if part and part.Parent then
				local distance = (part.Position - sparklePart.Position).Magnitude
				if not nearestDistance or distance < nearestDistance then
					nearestPoint = minePoint
					nearestDistance = distance
				end
			end
		end
	end

	return nearestPoint
end

_G.F.syncMinePointForSparkle = function(sparklePart)
	if typeof(sparklePart) ~= "Instance" then
		return false
	end

	local targetPosition = sparklePart.Position
	local targetCFrame = sparklePart.CFrame

	local function applyToMinePoint(minePoint)
		if type(minePoint) ~= "table" then
			return false
		end

		return pcall(function()
			minePoint.Position = targetPosition
			minePoint.CFrame = targetCFrame
		end)
	end

	local mining = _G.F.getMiningModule(true)
	local minePoint = _G.F.findMinePointForSparkle(sparklePart, mining)
	if minePoint and applyToMinePoint(minePoint) then
		return true
	end

	if type(getconnections) ~= "function" or type(debug) ~= "table" or type(debug.getupvalue) ~= "function" then
		return false
	end

	local player = _G.Players.LocalPlayer
	local mouse = player and player:GetMouse()
	if not mouse then
		return false
	end

	local ok, connections = pcall(getconnections, mouse.Button1Down)
	if not ok or type(connections) ~= "table" then
		return false
	end

	for _, connection in ipairs(connections) do
		local handler = connection.Function
		if type(handler) ~= "function" then
			continue
		end

		for index = 1, 128 do
			local uvOk, value = pcall(debug.getupvalue, handler, index)
			if not uvOk then
				break
			end

			if type(value) == "table" then
				local minePoints = _G.F.safeTableGet(value, "MinePoints")
				if type(minePoints) == "table" then
					local matched = _G.F.findMinePointForSparkle(sparklePart, value)
					if matched and applyToMinePoint(matched) then
						return true
					end
				end
			end
		end
	end

	return false
end

_G.F.isMiningClickHandler = function(handler)
	if type(handler) ~= "function" or type(debug) ~= "table" or type(debug.getupvalue) ~= "function" then
		return false
	end

	for index = 1, 64 do
		local uvOk, value = pcall(debug.getupvalue, handler, index)
		if not uvOk then
			break
		end

		if type(value) == "table" and type(_G.F.safeTableGet(value, "MinePoints")) == "table" then
			return true
		end
	end

	return false
end

_G.F.fireGameMiningClick = function()
	if type(getconnections) ~= "function" then
		return false, "Executor needs getconnections."
	end

	local player = _G.Players.LocalPlayer
	local mouse = player and player:GetMouse()
	if not mouse then
		return false, "No mouse."
	end

	local ok, connections = pcall(getconnections, mouse.Button1Down)
	if not ok or type(connections) ~= "table" or #connections == 0 then
		return false, "No mining click handler. Click a wall once first."
	end

	for _, connection in ipairs(connections) do
		local handler = connection.Function
		if type(handler) == "function" and _G.F.isMiningClickHandler(handler) and pcall(handler) then
			return true
		end
	end

	for _, connection in ipairs(connections) do
		if type(connection.Function) == "function" and pcall(connection.Function) then
			return true
		end
	end

	return false, "Mining click handler failed."
end

_G.F.runRemoteSparkleMine = function()
	local player = _G.Players.LocalPlayer
	local mouse = player and player:GetMouse()
	if not mouse then
		return false, "No mouse."
	end

	local sparkles = _G.F.getActiveWallSparkles()
	if #sparkles == 0 then
		return false, "No valid sparkles (need Wall contact, front face, and Y bounds)."
	end

	local sparkle = _G.F.getNearestWallSparkle(mouse.Hit.Position)
	if not sparkle then
		return false, "No valid sparkle near crosshair."
	end

	return _G.F.runRemoteSparkleMineAt(sparkle)
end

_G.F.setRemoteSparkleMineEnabled = function(value)
	value = value and true or false
	if _G.remoteSparkleMineEnabled == value then
		return
	end

	_G.remoteSparkleMineEnabled = value

	_G.F.clearRemoteSparkleYLimitsCache()

	if _G.remoteSparkleMineKeyConnection then
		_G.remoteSparkleMineKeyConnection:Disconnect()
		_G.remoteSparkleMineKeyConnection = nil
	end

	if not value then
		_G.F.setRemoteSparkleMineStatus("Off")
		return
	end

	_G.remoteSparkleMineKeyConnection = _G.UserInputService.InputBegan:Connect(function(input, processed)
		if processed or not _G.remoteSparkleMineEnabled then
			return
		end
		if input.KeyCode ~= Enum.KeyCode.E then
			return
		end

		_G.F.setRemoteSparkleMineStatus("Mining...")
		task.spawn(function()
			local ok, reason = _G.F.runRemoteSparkleMine()
			if ok then
				_G.F.setRemoteSparkleMineStatus("Done - press E for next.")
			else
				_G.F.setRemoteSparkleMineStatus(reason or "Failed")
			end
		end)
	end)

	_G.F.setRemoteSparkleMineStatus("Ready - " .. tostring(#_G.F.getActiveWallSparkles()) .. " sparkle(s). Press E.")
end

_G.F.isMiningModuleTable = function(candidate)
	if type(candidate) ~= "table" then
		return false
	end

	local minePoints = _G.F.safeTableGet(candidate, "MinePoints")
	local startDive = _G.F.safeTableGet(candidate, "StartDive")
	local createMinePoint = _G.F.safeTableGet(candidate, "CreateMinePoint")
	local batteryLevel = _G.F.safeTableGet(candidate, "BatteryLevel")

	return type(minePoints) == "table"
		and type(startDive) == "function"
		and type(createMinePoint) == "function"
		and type(batteryLevel) == "number"
end

_G.F.scanFunctionUpvaluesForMiningModule = function()
	if type(debug) ~= "table" or type(debug.getregistry) ~= "function" or type(debug.getupvalue) ~= "function" then
		return nil
	end

	local ok, registry = pcall(debug.getregistry)
	if not ok or type(registry) ~= "table" then
		return nil
	end

	for _, fn in pairs(registry) do
		if type(fn) == "function" then
			for index = 1, 160 do
				local uvOk, upvalue = pcall(debug.getupvalue, fn, index)
				if not uvOk then
					break
				end

				if _G.F.isMiningModuleTable(upvalue) then
					return upvalue
				end
			end
		end
	end

	return nil
end

_G.F.scanRegistryForMiningModule = function()
	if type(debug) ~= "table" or type(debug.getregistry) ~= "function" then
		return nil
	end

	local ok, registry = pcall(debug.getregistry)
	if not ok or type(registry) ~= "table" then
		return nil
	end

	for _, value in ipairs(registry) do
		if _G.F.isMiningModuleTable(value) then
			return value
		end
	end

	return nil
end

_G.F.getMiningModule = function(forceRefresh)
	if not forceRefresh
		and _G.cachedMiningModule
		and _G.F.isMiningModuleTable(_G.cachedMiningModule)
		and (os.clock() - _G.cachedMiningModuleAt) < _G.MINING_MODULE_CACHE_TTL then
		return _G.cachedMiningModule
	end

	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end

	local mining = type(_G._p) == "table" and _G.F.safeTableGet(_G._p, "Mining") or nil
	if not _G.F.isMiningModuleTable(mining) then
		mining = _G.F.scanFunctionUpvaluesForMiningModule()
	end
	if not _G.F.isMiningModuleTable(mining) then
		mining = _G.F.scanRegistryForMiningModule()
	end

	if _G.F.isMiningModuleTable(mining) then
		_G.cachedMiningModule = mining
		_G.cachedMiningModuleAt = os.clock()
		return mining
	end

	_G.F.clearMiningModuleCache()
	return nil
end

_G.F.runRemoteSparkleMineAt = function(sparklePart)
	if typeof(sparklePart) ~= "Instance" then
		return false, "Invalid sparkle."
	end

	if not _G.F.teleportCharacterToSparkle(sparklePart) then
		return false, "Teleport failed (invalid sparkle, front face, or Y limit)."
	end

	task.wait(0.35)
	_G.F.syncMinePointForSparkle(sparklePart)

	local clicked, reason = _G.F.fireGameMiningClick()
	if clicked then
		return true
	end

	return false, reason or "Click failed after teleport."
end


_G.F.isCtrlHeld = function()
	return _G.UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
		or _G.UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
end

_G.F.disconnectCtrlClickTp = function()
	if _G.ctrlClickTpConnection then
		_G.ctrlClickTpConnection:Disconnect()
		_G.ctrlClickTpConnection = nil
	end
end

_G.F.tryCtrlClickTeleport = function()
	if not _G.ctrlClickTpEnabled or not _G.F.isCtrlHeld() then
		return
	end

	local player = _G.Players.LocalPlayer
	local mouse = player:GetMouse()
	local target = mouse.Target
	local hit = mouse.Hit

	if not target or not hit then
		return
	end

	local playerGui = player:FindFirstChildOfClass("PlayerGui")
	if playerGui and target:IsDescendantOf(playerGui) then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local destination = hit.Position + Vector3.new(0, 3, 0)

	if humanoidRootPart then
		humanoidRootPart.CFrame = CFrame.new(destination)
	elseif humanoid then
		humanoid:MoveTo(hit.Position)
	end
end

_G.F.setCtrlClickTpEnabled = function(value)
	value = value and true or false
	if _G.ctrlClickTpEnabled == value then
		return
	end

	_G.ctrlClickTpEnabled = value
	_G.F.disconnectCtrlClickTp()

	if not value then
		return
	end

	local player = _G.Players.LocalPlayer
	local mouse = player:GetMouse()

	_G.ctrlClickTpConnection = mouse.Button1Down:Connect(function()
		_G.F.tryCtrlClickTeleport()
	end)
end

_G.F.setAntiAfkEnabled = function(value)
	value = value and true or false
	if _G.antiAfkEnabled == value then
		return
	end

	_G.antiAfkEnabled = value

	if _G.antiAfkIdleConnection then
		_G.antiAfkIdleConnection:Disconnect()
		_G.antiAfkIdleConnection = nil
	end

	if not value then
		return
	end

	local player = _G.Player or _G.Players.LocalPlayer
	local virtualUser = game:GetService("VirtualUser")

	_G.antiAfkIdleConnection = player.Idled:Connect(function()
		pcall(function()
			virtualUser:CaptureController()
			virtualUser:ClickButton2(Vector2.new())
		end)
	end)
end

-- "Disable Saving" rides the game's cutscene state: while a cutscene is marked
-- active the game suppresses saving. Toggle ON = StartCutscene, OFF = EndCutscene.
_G.F.setSavingDisabled = function(value)
	local enabled = value and true or false

	-- Early return matters: OrionLib fires toggle callbacks during AddToggle
	-- (creation), and an error thrown there aborts building the rest of the
	-- tab. With Default=false this makes the creation-time call a no-op.
	if _G.savingDisabled == enabled then
		return true
	end

	if type(_G._p) ~= "table" then
		local ok, found = pcall(_G.F.findP)
		_G._p = ok and found or nil
	end

	local cutsceneManager = type(_G._p) == "table" and _G.F.safeTableGet(_G._p, "CutsceneManager") or nil
	local methodName = enabled and "StartCutscene" or "EndCutscene"
	local method = type(cutsceneManager) == "table" and _G.F.safeTableGet(cutsceneManager, methodName) or nil

	if type(method) ~= "function" then
		return false, "CutsceneManager." .. methodName .. " is not available."
	end

	local ok, err = pcall(function()
		method(cutsceneManager)
	end)

	if not ok then
		return false, tostring(err)
	end

	_G.savingDisabled = enabled
	return true
end

_G.F.callBattleCameraMethod = function(methodName, battle)
	if type(_G._p) ~= "table" then
		return
	end

	local battleCamera = _G.F.safeTableGet(_G._p, "BattleCamera")
	local method = type(battleCamera) == "table" and _G.F.safeTableGet(battleCamera, methodName) or nil
	if type(method) ~= "function" then
		return
	end

	if pcall(function()
		method(battleCamera, battle)
	end) then
		return
	end

	if pcall(function()
		method(battleCamera)
	end) then
		return
	end

	pcall(function()
		method(battle)
	end)
end

-- The game's idle battle camera (BattleCamera.startIdleCamera) pans between the
-- battlers with cinematic tweens that keep reading battle.CoordinateFrame1/2 and
-- the side sprites every frame. Our automations end/tear down battles the instant
-- they're runnable, so those fields go nil underneath the camera and its
-- render-step callbacks spam "attempt to index nil with 'p'/'Position'/'Y'".
--
-- One hook on _p.BattleCamera covers every battle mode (static, encounter,
-- trainer, fishing, catch). We (1) pcall-guard setCamera/setCameraIfLookingAway
-- so a torn-down battle can never error inside a render step, and (2) skip the
-- purely-cosmetic idle camera entirely while automation is active.
_G.battleCameraHooked = false

_G.F.shouldSuppressBattleCameraIdle = function()
	if _G.fastForwardEnabled
		or _G.autoEncounterEnabled
		or _G.autoEncounterPausedBattle ~= nil
		or _G.autoFishingEnabled
		or _G.autoTrainerEnabled
		or _G.autoCatchEnabled then
		return true
	end

	local staticActive = false
	pcall(function()
		staticActive = StaticAutomation and StaticAutomation:isAutomationActive() or false
	end)

	return staticActive
end

_G.F.installBattleCameraSafetyHooks = function()
	if _G.battleCameraHooked then
		return
	end

	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end

	local battleCamera = type(_G._p) == "table" and _G.F.safeTableGet(_G._p, "BattleCamera") or nil
	if type(battleCamera) ~= "table" then
		return
	end

	local originalSetCamera = _G.F.safeTableGet(battleCamera, "setCamera")
	if type(originalSetCamera) == "function" and not battleCamera.__llsploitSetCameraGuard then
		_G.F.safeTableSet(battleCamera, "setCamera", function(...)
			pcall(originalSetCamera, ...)
		end)
		battleCamera.__llsploitSetCameraGuard = true
	end

	local originalLookAway = _G.F.safeTableGet(battleCamera, "setCameraIfLookingAway")
	if type(originalLookAway) == "function" and not battleCamera.__llsploitLookAwayGuard then
		_G.F.safeTableSet(battleCamera, "setCameraIfLookingAway", function(...)
			pcall(originalLookAway, ...)
		end)
		battleCamera.__llsploitLookAwayGuard = true
	end

	local originalStartIdle = _G.F.safeTableGet(battleCamera, "startIdleCamera")
	if type(originalStartIdle) == "function" and not battleCamera.__llsploitStartIdleGuard then
		_G.F.safeTableSet(battleCamera, "startIdleCamera", function(...)
			if _G.F.shouldSuppressBattleCameraIdle() then
				return
			end
			pcall(originalStartIdle, ...)
		end)
		battleCamera.__llsploitStartIdleGuard = true
	end

	_G.battleCameraHooked = true
end

_G.F.clearCurrentBattleReference = function(battle)
	if type(_G._p) ~= "table" or type(battle) ~= "table" then
		return
	end

	for _, containerName in ipairs({ "Battle", "BattleClient" }) do
		local container = _G.F.safeTableGet(_G._p, containerName)
		if type(container) == "table" and _G.F.safeTableGet(container, "currentBattle") == battle then
			_G.F.safeTableSet(container, "currentBattle", nil)
		end
	end
end

_G.F.releaseFinishedBattle = function(battle)
	if type(battle) ~= "table" then
		return
	end

	_G.F.clearBattleRunTiming(battle)
	_G.F.setBattleFastForward(false, battle)

	_G.F.callBattleCameraMethod("stopIdleCamera", battle)
	_G.F.callBattleCameraMethod("StopIdleCamera", battle)

	pcall(function()
		_G.RunService:UnbindFromRenderStep("BattleCamera")
	end)

	_G.F.clearCurrentBattleReference(battle)
end

_G.F.releaseBattleAutomationForCapture = function(battle)
	if type(battle) ~= "table" then
		return
	end

	_G.F.clearBattleRunTiming(battle)
	_G.F.applyBattleAnimationFastForward(battle, false, false)
	_G.F.setBattleFastForward(false, battle)
end

_G.F.setAutoEncounterToggleState = function(value)
	if _G.configUi.autoEncounterToggle and type(_G.configUi.autoEncounterToggle.Set) == "function" then
		pcall(function()
			_G.configUi.autoEncounterToggle:Set(value and true or false)
		end)
	end
end

_G.F.pauseAutoEncounterForBattle = function(battle, displayName, reason, notificationTitle)
	if type(battle) ~= "table" then
		return false
	end

	if _G.autoEncounterPausedBattle == battle then
		return true
	end

	_G.autoEncounterPausedBattle = battle
	_G.autoEncounterPausedDisplayName = displayName
	_G.autoEncounterPausedReason = reason

	_G.F.releaseBattleAutomationForCapture(battle)
	_G.autoEncounterEnabled = false
	_G.F.setAutoEncounterToggleState(false)

	pcall(function()
		local content
		if reason and reason ~= "" and reason ~= "Target" then
			content = string.format(
				"Found %s (%s). Auto Encounter paused until this encounter ends.",
				tostring(displayName),
				tostring(reason)
			)
		else
			content = string.format(
				"Found %s. Auto Encounter paused until this encounter ends.",
				tostring(displayName)
			)
		end

		_G.OrionLib:MakeNotification({
			Name = notificationTitle or "Auto Encounter Paused",
			Content = content,
			Time = 8,
		})
	end)

	return true
end

_G.F.resumeAutoEncounterAfterPausedBattle = function(battle)
	if not _G.autoEncounterPausedBattle then
		return false
	end

	if battle and _G.autoEncounterPausedBattle ~= battle then
		return false
	end

	local displayName = _G.autoEncounterPausedDisplayName or "encounter"
	_G.autoEncounterPausedBattle = nil
	_G.autoEncounterPausedDisplayName = nil
	_G.autoEncounterPausedReason = nil

	_G.autoEncounterEnabled = true
	_G.F.setAutoEncounterToggleState(true)

	pcall(function()
		_G.OrionLib:MakeNotification({
			Name = "Auto Encounter Resumed",
			Content = string.format("Auto Encounter resumed after %s.", tostring(displayName)),
			Time = 4,
		})
	end)

	return true
end

_G.F.pauseNaturalRunForSpecialBattle = function(battle)
	if type(battle) ~= "table" or not _G.F.hasWildFoeLoaded(battle) then
		return false
	end

	if _G.naturalRunPausedSpecialBattle == battle then
		return true
	end

	local foe, specialValue, specialReason = _G.F.getWildSpecialFoeForStop(battle)
	if not foe then
		return false
	end

	_G.naturalRunPausedSpecialBattle = battle

	local displayName = _G.F.getEncounterFoeSpeciesName(foe)
	if displayName == "" then
		displayName = tostring(foe.name or foe.species or "wild Loomian")
	end

	return _G.F.pauseAutoEncounterForBattle(battle, displayName, specialReason, "Auto Encounter Paused")
end

_G.F.clearNaturalRunSpecialPause = function(battle)
	if not battle or _G.naturalRunPausedSpecialBattle == battle then
		_G.naturalRunPausedSpecialBattle = nil
	end

	if not battle or _G.encounterTargetStopBattle == battle then
		_G.encounterTargetStopBattle = nil
	end
end

_G.F.setTemporaryBattleFlag = function(object, key, value, resetDelay)
	if type(object) ~= "table" then
		return
	end

	if not _G.F.safeTableSet(object, key, value) then
		return
	end

	task.delay(resetDelay or 0.35, function()
		if _G.F.safeTableGet(object, key) == value then
			_G.F.safeTableSet(object, key, false)
		end
	end)
end

_G.F.skipEncounterCutscene = function(battle)
	if type(battle) ~= "table" then
		return
	end

	_G.F.applyBattleAnimationFastForward(battle, false)
	_G.F.setTemporaryBattleFlag(battle, "skipping", true, 0.35)
	_G.F.setTemporaryBattleFlag(battle, "skipRequested", true, 0.35)
	_G.F.setTemporaryBattleFlag(battle, "skipIntroRequested", true, 0.35)

	_G.F.callMethodsIfPresent(battle, {
		"skipIntro", "SkipIntro",
		"skipCutscene", "SkipCutscene",
		"skip", "Skip",
		"finishIntro", "FinishIntro"
	})

	local scene = _G.F.safeTableGet(battle, "scene")
	if type(scene) == "table" then
		_G.F.applyFastForwardFlagsToTable(scene, true)
		_G.F.setTemporaryBattleFlag(scene, "skipping", true, 0.35)

		_G.F.callMethodsIfPresent(scene, {
			"skip", "Skip",
			"finish", "Finish",
			"skipIntro", "SkipIntro"
		})
	end

	if type(_G._p) == "table" and type(_G._p.NPCChat) == "table" then
		pcall(function()
			_G._p.NPCChat.fastForward = true
			_G._p.NPCChat.skipping = true
		end)

		_G.F.callMethodsIfPresent(_G._p.NPCChat, {
			"advance", "Advance",
			"next", "Next",
			"skip", "Skip",
			"close", "Close",
			"finish", "Finish"
		})
	end
end

_G.F.skipTrainerText = function()
	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end

	if type(_G._p) ~= "table" or type(_G._p.NPCChat) ~= "table" then
		return
	end

	pcall(function()
		_G._p.NPCChat.fastForward = true
		_G._p.NPCChat.skipping = true
	end)

	pcall(function()
		for _, methodName in ipairs({
			"choose", "Choose",
			"answer", "Answer",
			"respond", "Respond",
			"select", "Select",
			"selectOption", "SelectOption",
			"optionChosen", "OptionChosen"
		}) do
			local method = _G.F.safeTableGet(_G._p.NPCChat, methodName)
			if type(method) == "function" then
				pcall(function()
					method(_G._p.NPCChat, false)
				end)
				pcall(function()
					method(_G._p.NPCChat, "No")
				end)
				pcall(function()
					method(_G._p.NPCChat, 2)
				end)
			end
		end
	end)

	pcall(function()
		if type(_G._p.NPCChat.isChatting) == "function" and _G._p.NPCChat:isChatting() then
			_G._p.NPCChat:clear()
		end
	end)

	pcall(function()
		if type(_G._p.NPCChat.manualAdvance) == "function"
			and (type(_G._p.NPCChat.isAwaitingManualAdvance) ~= "function" or _G._p.NPCChat:isAwaitingManualAdvance()) then
			_G._p.NPCChat:manualAdvance()
		end
	end)

	_G.F.callMethodsIfPresent(_G._p.NPCChat, {
		"manualAdvance", "ManualAdvance",
		"advance", "Advance",
		"next", "Next",
		"skip", "Skip",
		"close", "Close",
		"finish", "Finish",
		"continue", "Continue"
	})
end

_G.F.clickThroughNpcChat = function()
	_G.F.skipTrainerText()

	pcall(function()
		if type(_G._p) ~= "table" then
			_G._p = _G.F.findP()
		end

		if type(_G._p) == "table" and type(_G._p.NPCChat) == "table" then
			_G._p.NPCChat.TextSpeedMultiplier = 100

			if type(_G._p.NPCChat.isChatting) == "function" and _G._p.NPCChat:isChatting() and type(_G._p.NPCChat.clear) == "function" then
				_G._p.NPCChat:clear()
			end
		end
	end)
end

-- Mastery report ("Mastery Progress") appears after a battle grants a mastery
-- level-up. In doTrainerBattle the game calls mastery:showProgressUpdate(...)
-- synchronously and blocks on the report's OK button, so a level-up would
-- otherwise freeze Auto Trainer until the user clicks OK manually.
--
-- The report text is rendered per-glyph (Utilities.Write), so it has no readable
-- .Text to match on. We key off the report's fake-watch ImageButton
-- (rbxassetid://1935359631, created only by Menu:createFakeWatch, which is used
-- only by the mastery report), then look for a visible "OK" label when present
-- and otherwise click the bottom-right actionable button inside the report.
_G.MASTERY_WATCH_IMAGE = "rbxassetid://1935359631"
_G.MASTERY_SCROLL_TOP_IMAGE = "rbxassetid://3763595294"
_G.masteryReportLastClickAt = 0
_G.masteryReportOkFirstSeenAt = 0
_G.masteryReportOkButton = nil

_G.F.normalizeGuiSearchText = function(value)
	local text = string.lower(tostring(value or ""))
	text = string.gsub(text, "%s+", " ")
	text = string.gsub(text, "[^%w%s]", "")
	return string.gsub(text, "^%s*(.-)%s*$", "%1")
end

_G.F.guiTextLooksLikeOk = function(value)
	local normalized = _G.F.normalizeGuiSearchText(value)
	if normalized == "" then
		return false
	end

	if normalized == "ok" or normalized == "buttona ok" then
		return true
	end

	return string.find(normalized, " ok", 1, true) ~= nil
		or string.find(normalized, "ok ", 1, true) ~= nil
		or string.find(normalized, "buttona ok", 1, true) ~= nil
end

_G.F.findAncestorGuiButton = function(item)
	local current = item

	while current do
		if current:IsA("GuiButton") then
			return current
		end

		current = current.Parent
	end

	return nil
end

_G.F.collectGuiTextSnapshot = function(root)
	if typeof(root) ~= "Instance" then
		return ""
	end

	local parts = {}
	local ok, descendants = pcall(function()
		return root:GetDescendants()
	end)

	if not ok then
		return ""
	end

	for _, item in ipairs(descendants) do
		if _G.F.isGuiChainVisible(item) then
			if item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then
				local okText, text = pcall(function()
					return item.Text
				end)

				if okText and type(text) == "string" and text ~= "" then
					table.insert(parts, text)
				end
			end

			local okContent, contentText = pcall(function()
				return item.ContentText
			end)

			if okContent and type(contentText) == "string" and contentText ~= "" then
				table.insert(parts, contentText)
			end
		end
	end

	return table.concat(parts, " ")
end

_G.F.getMasteryGuiContainers = function()
	local containers = {}
	local seen = {}

	local function add(container)
		if typeof(container) == "Instance" and not seen[container] then
			seen[container] = true
			table.insert(containers, container)
		end
	end

	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end

	if type(_G._p) == "table" then
		local utilities = _G.F.safeTableGet(_G._p, "Utilities")
		add(type(utilities) == "table" and _G.F.safeTableGet(utilities, "frontGui") or nil)

		local menu = _G.F.safeTableGet(_G._p, "Menu")
		add(type(menu) == "table" and _G.F.safeTableGet(menu, "frontContainer") or nil)
	end

	pcall(function()
		local playerGui = _G.Player and _G.Player:FindFirstChildOfClass("PlayerGui")
		add(playerGui)
	end)

	return containers
end

_G.F.getMasteryReportRoot = function()
	for _, container in ipairs(_G.F.getMasteryGuiContainers()) do
		local ok, descendants = pcall(function()
			return container:GetDescendants()
		end)

		if ok then
			for _, item in ipairs(descendants) do
				if item:IsA("ImageButton") and item.Image == _G.MASTERY_WATCH_IMAGE and _G.F.isGuiChainVisible(item) then
					return item
				end
			end
		end
	end

	for _, container in ipairs(_G.F.getMasteryGuiContainers()) do
		local ok, descendants = pcall(function()
			return container:GetDescendants()
		end)

		if ok then
			for _, item in ipairs(descendants) do
				if item:IsA("ScrollingFrame")
					and item.TopImage == _G.MASTERY_SCROLL_TOP_IMAGE
					and _G.F.isGuiChainVisible(item) then
					local current = item.Parent

					while current do
						if current:IsA("ImageButton") and current.Image == _G.MASTERY_WATCH_IMAGE then
							return current
						end

						current = current.Parent
					end
				end
			end
		end
	end

	return nil
end

_G.F.findMasteryReportOkButtonByText = function(reportRoot)
	local roots = {}

	if typeof(reportRoot) == "Instance" then
		table.insert(roots, reportRoot)
	else
		for _, container in ipairs(_G.F.getMasteryGuiContainers()) do
			table.insert(roots, container)
		end
	end

	for _, root in ipairs(roots) do
		local ok, descendants = pcall(function()
			return root:GetDescendants()
		end)

		if ok then
			for _, item in ipairs(descendants) do
				if _G.F.isGuiChainVisible(item) then
					local itemText = nil

					if item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then
						local okText, text = pcall(function()
							return item.Text
						end)

						if okText then
							itemText = text
						end
					end

					if not itemText then
						local okContent, contentText = pcall(function()
							return item.ContentText
						end)

						if okContent then
							itemText = contentText
						end
					end

					if _G.F.guiTextLooksLikeOk(itemText) then
						local button = item:IsA("GuiButton") and item or _G.F.findAncestorGuiButton(item)
						if button then
							return button
						end
					end
				end
			end
		end
	end

	return nil
end

_G.F.findMasteryReportOkButton = function(reportRoot)
	if typeof(reportRoot) ~= "Instance" then
		return _G.F.findMasteryReportOkButtonByText(nil)
	end

	local textButton = _G.F.findMasteryReportOkButtonByText(reportRoot)
	if textButton then
		return textButton
	end

	local ok, descendants = pcall(function()
		return reportRoot:GetDescendants()
	end)

	if not ok then
		return nil
	end

	local reportPos = reportRoot.AbsolutePosition
	local reportSize = reportRoot.AbsoluteSize
	local reportBottom = reportPos.Y + reportSize.Y
	local bestButton = nil
	local bestScore = -math.huge

	for _, item in ipairs(descendants) do
		if item ~= reportRoot and item:IsA("GuiButton") and _G.F.isGuiChainVisible(item) then
			local itemText = _G.F.collectGuiTextSnapshot(item)
			if _G.F.guiTextLooksLikeOk(itemText) then
				return item
			end

			local pos = item.AbsolutePosition
			local size = item.AbsoluteSize
			if size.X > 0 and size.Y > 0 then
				local centerX = pos.X + (size.X / 2)
				local centerY = pos.Y + (size.Y / 2)
				local inLowerHalf = centerY >= reportPos.Y + (reportSize.Y * 0.5)
				local inRightSide = centerX >= reportPos.X + (reportSize.X * 0.45)
				local nearReportBottom = pos.Y + size.Y >= reportBottom - math.max(reportSize.Y * 0.2, 24)

				if inLowerHalf and inRightSide and nearReportBottom then
					local score = centerX + (centerY * 0.01)
					if score > bestScore then
						bestScore = score
						bestButton = item
					end
				end
			end
		end
	end

	if bestButton then
		return bestButton
	end

	local fallbackY = -math.huge

	for _, item in ipairs(descendants) do
		if item ~= reportRoot and item:IsA("GuiButton") and _G.F.isGuiChainVisible(item) then
			local y = item.AbsolutePosition.Y
			if y > fallbackY then
				fallbackY = y
				bestButton = item
			end
		end
	end

	return bestButton
end

_G.F.isMasteryReportVisible = function()
	local reportRoot = _G.F.getMasteryReportRoot()
	if reportRoot then
		return true
	end

	for _, container in ipairs(_G.F.getMasteryGuiContainers()) do
		local snapshot = _G.F.collectGuiTextSnapshot(container)
		if string.find(_G.F.normalizeGuiSearchText(snapshot), "mastery progress", 1, true) then
			return true
		end
	end

	return false
end

_G.F.dismissMasteryReport = function()
	if not _G.F.isMasteryReportVisible() then
		_G.masteryReportOkFirstSeenAt = 0
		_G.masteryReportOkButton = nil
		return false
	end

	local reportRoot = _G.F.getMasteryReportRoot()
	local okButton = _G.F.findMasteryReportOkButton(reportRoot)
	if not okButton then
		_G.masteryReportOkFirstSeenAt = 0
		_G.masteryReportOkButton = nil
		return false
	end

	local now = os.clock()
	if okButton ~= _G.masteryReportOkButton then
		_G.masteryReportOkButton = okButton
		_G.masteryReportOkFirstSeenAt = now
		return false
	end

	if now - _G.masteryReportOkFirstSeenAt < 0.2 then
		return false
	end

	if now - _G.masteryReportLastClickAt < 0.4 then
		return false
	end
	_G.masteryReportLastClickAt = now

	return _G.F.activateGuiButton(okButton) and true or false
end

_G.F.isTrainerSwitchPromptText = function(text)
	local lower = string.lower(tostring(text or ""))
	if lower == "" then
		return false
	end

	if string.find(lower, "switch loomian", 1, true) then
		return true
	end

	return string.find(lower, "send in", 1, true) ~= nil
		and string.find(lower, "will you", 1, true) ~= nil
end

_G.F.isCaptureNicknamePromptText = function(text)
	local lower = string.lower(tostring(text or ""))
	if lower == "" then
		return false
	end

	if string.find(lower, "nickname", 1, true)
		or string.find(lower, "give a nickname", 1, true)
		or string.find(lower, "no nickname", 1, true) then
		return true
	end

	return string.find(lower, "captured", 1, true) ~= nil
		and string.find(lower, "nickname", 1, true) ~= nil
end

_G.F.getVisibleBattlePromptTextSnapshot = function()
	local parts = {}
	local seen = {}

	local function addContainer(container)
		if container and not seen[container] then
			seen[container] = true
			table.insert(parts, container)
		end
	end

	pcall(function()
		if type(_G._p) ~= "table" then
			_G._p = _G.F.findP()
		end

		local utilities = type(_G._p) == "table" and _G._p.Utilities or nil
		addContainer(utilities and utilities.frontGui or nil)
	end)

	pcall(function()
		local playerGui = _G.Player and _G.Player:FindFirstChildOfClass("PlayerGui")
		addContainer(playerGui)
	end)

	local texts = {}

	for _, container in ipairs(parts) do
		local ok, descendants = pcall(function()
			return container:GetDescendants()
		end)

		if ok then
			for _, item in ipairs(descendants) do
				if _G.F.isGuiChainVisible(item) then
					if item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then
						local okText, text = pcall(function()
							return item.Text
						end)

						if okText and type(text) == "string" and text ~= "" then
							table.insert(texts, text)
						end
					end

					local okContent, contentText = pcall(function()
						return item.ContentText
					end)

					if okContent and type(contentText) == "string" and contentText ~= "" then
						table.insert(texts, contentText)
					end
				end
			end
		end
	end

	return string.lower(table.concat(texts, " "))
end

_G.F.findVisibleBattleYesOrNoPrompt = function()
	local function findIn(container)
		if not container then
			return nil
		end

		local ok, descendants = pcall(function()
			return container:GetDescendants()
		end)

		if not ok then
			return nil
		end

		for _, item in ipairs(descendants) do
			if item.Name == "YesOrNoPrompt" and _G.F.isGuiChainVisible(item) then
				return item
			end
		end

		return nil
	end

	pcall(function()
		if type(_G._p) ~= "table" then
			_G._p = _G.F.findP()
		end
	end)

	local utilities = type(_G._p) == "table" and _G._p.Utilities or nil
	local promptFrame = findIn(utilities and utilities.frontGui or nil)
	if promptFrame then
		return promptFrame
	end

	local playerGui = _G.Player and _G.Player:FindFirstChildOfClass("PlayerGui")
	promptFrame = findIn(playerGui)
	if promptFrame then
		return promptFrame
	end

	local battleGui = type(_G._p) == "table" and _G._p.BattleGui or nil
	if type(battleGui) == "table" then
		for _, value in pairs(battleGui) do
			if typeof(value) == "Instance" and value.Name == "YesOrNoPrompt" and _G.F.isGuiChainVisible(value) then
				return value
			end
		end
	end

	return nil
end

_G.F.getBattleYesOrNoPromptButtons = function(promptRoot)
	if typeof(promptRoot) ~= "Instance" then
		if type(promptRoot) == "table" and typeof(promptRoot.gui) == "Instance" then
			promptRoot = promptRoot.gui.Parent or promptRoot.gui
		else
			return nil, nil
		end
	end

	if not promptRoot then
		return nil, nil
	end

	local buttons = {}
	local ok, descendants = pcall(function()
		return promptRoot:GetDescendants()
	end)

	if not ok then
		return nil, nil
	end

	for _, item in ipairs(descendants) do
		if item:IsA("ImageButton") and _G.F.isGuiChainVisible(item) then
			table.insert(buttons, item)
		end
	end

	table.sort(buttons, function(left, right)
		local leftY = left.Position.Y.Scale + (left.Position.Y.Offset / math.max(left.AbsoluteSize.Y, 1))
		local rightY = right.Position.Y.Scale + (right.Position.Y.Offset / math.max(right.AbsoluteSize.Y, 1))
		return leftY < rightY
	end)

	return buttons[1], buttons[2]
end

_G.F.getBattleYesOrNoLiveState = function()
	local promptFrame = nil
	local yesNoSignal = nil
	local noButton = nil

	pcall(function()
		if type(_G._p) ~= "table" then
			_G._p = _G.F.findP()
		end

		local battleGui = type(_G._p) == "table" and _G._p.BattleGui or nil
		local promptYesOrNo = battleGui
			and (_G.F.safeTableGet(battleGui, "promptYesOrNo") or _G.F.safeTableGet(battleGui, "PromptYesOrNo"))
			or nil

		if type(promptYesOrNo) == "function" and type(debug) == "table" and type(debug.getupvalues) == "function" then
			local ok, upvalues = pcall(function()
				return { debug.getupvalues(promptYesOrNo) }
			end)

			if ok then
				for _, upvalue in ipairs(upvalues) do
					if type(upvalue) == "table" and type(upvalue.Fire) == "function" and type(upvalue.Wait) == "function" then
						yesNoSignal = upvalue
					end

					if type(upvalue) == "table" and upvalue.Visible == true then
						promptFrame = upvalue
						if typeof(upvalue.gui) == "Instance" then
							local _, foundNo = _G.F.getBattleYesOrNoPromptButtons(upvalue.gui.Parent or upvalue.gui)
							noButton = foundNo or noButton
						end
					end

					if typeof(upvalue) == "Instance" and upvalue:IsA("ImageButton") and _G.F.isGuiChainVisible(upvalue) then
						local y = upvalue.Position.Y.Scale + (upvalue.Position.Y.Offset / math.max(upvalue.AbsoluteSize.Y, 1))
						if y >= 0.5 then
							noButton = upvalue
						end
					end
				end
			end
		end
	end)

	if not promptFrame then
		promptFrame = _G.F.findVisibleBattleYesOrNoPrompt()
	end

	if promptFrame and not noButton then
		local searchRoot = promptFrame
		if type(promptFrame) == "table" and typeof(promptFrame.gui) == "Instance" then
			searchRoot = promptFrame.gui.Parent or promptFrame.gui
		end
		_, noButton = _G.F.getBattleYesOrNoPromptButtons(searchRoot)
	end

	local promptOpen = false
	if type(promptFrame) == "table" and promptFrame.Visible == true then
		promptOpen = true
	elseif typeof(promptFrame) == "Instance" and _G.F.isGuiChainVisible(promptFrame) then
		promptOpen = true
	end

	return promptOpen, yesNoSignal, noButton, promptFrame
end

_G.F.fireBattleYesOrNoAnswer = function(answer, yesNoSignal, noButton)
	local clicked = false

	if yesNoSignal and type(yesNoSignal.Fire) == "function" then
		local okFire = pcall(function()
			yesNoSignal:Fire(answer and true or false)
		end)
		clicked = clicked or okFire

		if type(firesignal) == "function" then
			local okSignal, signal = pcall(function()
				return yesNoSignal
			end)

			if okSignal and signal then
				local okSignalFire = pcall(function()
					firesignal(signal, answer and true or false)
				end)
				clicked = clicked or okSignalFire
			end
		end
	end

	if noButton then
		clicked = _G.F.activateGuiButton(noButton) or clicked
		clicked = _G.F.clickGuiButtonOnce(noButton) or clicked
	end

	return clicked
end

-- Trainer battles ask "Will you switch Loomians?" when the foe sends out a new
-- Loomian. BattleGui.message skips the prompt while battle.fastForward is true,
-- but if fast-forward is off for even one frame the prompt blocks on Wait().
-- Auto-click No so trainer farming never stalls on this dialog.
_G.F.dismissTrainerSwitchPrompt = function()
	if not _G.autoTrainerEnabled then
		return false
	end

	local battle = _G.F.getCurrentBattle()
	if type(battle) ~= "table" or battle.ended or battle.done then
		_G.trainerSwitchPromptFirstSeenAt = 0
		_G.trainerSwitchPromptLastText = nil
		_G.trainerSwitchPromptClickedInstance = nil
		return false
	end

	if battle.kind ~= "trainer" then
		return false
	end

	_G.F.setBattleFastForward(true, battle)

	local promptOpen, yesNoSignal, noButton, promptFrame = _G.F.getBattleYesOrNoLiveState()
	if not promptOpen and not promptFrame then
		_G.trainerSwitchPromptFirstSeenAt = 0
		_G.trainerSwitchPromptLastText = nil
		return false
	end

	local promptText = _G.F.getVisibleBattlePromptTextSnapshot()
	if _G.F.isCaptureNicknamePromptText(promptText) then
		return false
	end

	local now = os.clock()
	if promptText ~= _G.trainerSwitchPromptLastText or _G.trainerSwitchPromptFirstSeenAt == 0 then
		_G.trainerSwitchPromptLastText = promptText
		_G.trainerSwitchPromptFirstSeenAt = now
		return false
	end

	if now - _G.trainerSwitchPromptFirstSeenAt < 0.15 then
		return false
	end

	if _G.trainerSwitchPromptClickedInstance ~= nil
		and _G.trainerSwitchPromptClickedInstance == promptFrame
		and now - _G.trainerSwitchPromptLastClickAt < 0.8 then
		return false
	end

	if now - _G.trainerSwitchPromptLastClickAt < 0.35 then
		return false
	end

	_G.trainerSwitchPromptLastClickAt = now
	_G.trainerSwitchPromptClickedInstance = promptFrame

	return _G.F.fireBattleYesOrNoAnswer(false, yesNoSignal, noButton)
end

_G.F.startAutoTrainer = function()
	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end

	if type(_G._p) ~= "table" or (type(_G._p.BattleClient) ~= "table" and type(_G._p.Battle) ~= "table") then
		return false, "BattleClient is not ready."
	end

	if _G.F.getCurrentBattle() or (_G._p.BattleClient and _G._p.BattleClient.currentBattle) or (_G._p.Battle and _G._p.Battle.currentBattle) then
		return false, "Battle already active."
	end

	local id = tonumber(_G.trainerId)
	if not id then
		return false, "Trainer ID must be a number."
	end

	local currentChunk = _G._p.DataManager and _G._p.DataManager.currentChunk
	if type(currentChunk) ~= "table" then
		return false, "Current chunk is not ready."
	end

	local trainerData = currentChunk.battles and (currentChunk.battles[tostring(id)] or currentChunk.battles[id])
	local opponentBaseNPC = nil

	if type(currentChunk.GetNPCs) == "function" then
		local ok, npcs = pcall(function()
			return currentChunk:GetNPCs()
		end)

		if ok and type(npcs) == "table" then
			for _, npc in ipairs(npcs) do
				local npcTrainer = npc and npc.battle
				local npcId = npcTrainer and tonumber(npcTrainer.num)

				if not npcId and npc and npc.model then
					local battleValue = npc.model:FindFirstChild("#Battle")
					if battleValue then
						npcId = tonumber(battleValue.Value)
					end
				end

				if id and npcId == id then
					opponentBaseNPC = npc
					trainerData = trainerData or npcTrainer
					break
				end
			end
		end
	end

	if type(trainerData) ~= "table" then
		return false, "Trainer data for this ID is not loaded in the current area."
	end

	if type(opponentBaseNPC) ~= "table" or not opponentBaseNPC.model then
		return false, "Trainer NPC for this ID is not loaded nearby."
	end

	local battleClient = _G._p.BattleClient or _G._p.Battle
	local ok, result = pcall(function()
		_G.F.skipTrainerText()

		return battleClient:doTrainerBattle({
			trainer = trainerData,
			opponentBaseNPC = opponentBaseNPC,
			skipStartAnim = true
		})
	end)

	if not ok then
		return false, tostring(result)
	end

	return true
end

_G.lastAutoMoveOneRequest = nil
_G.pendingAutoMoveOneRequest = nil
_G.pendingAutoMoveOneAt = 0
_G.autoMoveSlotToggles = {}
_G.syncingAutoMoveSlotToggles = false

_G.F.setAutoMoveSlot = function(value)
	local parsed = tonumber(value)
	if not parsed then
		return
	end

	_G.autoMoveSlot = math.clamp(math.floor(parsed), 1, 4)
	_G.lastAutoMoveOneRequest = nil
	_G.pendingAutoMoveOneRequest = nil
	_G.pendingAutoMoveOneAt = 0

	_G.syncingAutoMoveSlotToggles = true
	for slot, toggle in pairs(_G.autoMoveSlotToggles) do
		if type(toggle) == "table" and type(toggle.Set) == "function" then
			toggle:Set(slot == _G.autoMoveSlot)
		end
	end
	_G.syncingAutoMoveSlotToggles = false
end

_G.F.useMoveOne = function(battle)
	if not _G.autoMoveOneEnabled then
		_G.lastAutoMoveOneRequest = nil
		_G.pendingAutoMoveOneRequest = nil
		_G.pendingAutoMoveOneAt = 0
		return false, "Auto Use Move is disabled."
	end

	battle = battle or _G.F.getCurrentBattle()
	if type(battle) ~= "table" then
		_G.lastAutoMoveOneRequest = nil
		_G.pendingAutoMoveOneRequest = nil
		return false, "No active battle."
	end

	local request = battle.fulfillingRequest
	if type(request) ~= "table" or request.requestType ~= "move" then
		_G.lastAutoMoveOneRequest = nil
		_G.pendingAutoMoveOneRequest = nil
		return false, "No move request is active."
	end

	if request == _G.lastAutoMoveOneRequest then
		return false, "Move already sent for this request."
	end

	if battle.done then
		_G.lastAutoMoveOneRequest = nil
		_G.pendingAutoMoveOneRequest = nil
		return false, "Battle already ended."
	end

	if battle.state ~= "input" then
		return false, "Battle is not ready for input."
	end

	if _G.pendingAutoMoveOneRequest ~= request then
		_G.pendingAutoMoveOneRequest = request
		_G.pendingAutoMoveOneAt = os.clock()
		return false, "Move queued."
	end

	if os.clock() - _G.pendingAutoMoveOneAt < 0.35 then
		return false, "Waiting for move input listener."
	end

	if type(battle.InputChosen) ~= "table" or type(battle.InputChosen.Fire) ~= "function" then
		return false, "Move input hook is not ready."
	end

	local moveChoice = "move " .. tostring(_G.autoMoveSlot)
	local ok, result = pcall(function()
		battle.InputChosen:Fire(moveChoice)
	end)

	if not ok then
		return false, tostring(result)
	end

	_G.lastAutoMoveOneRequest = request
	_G.pendingAutoMoveOneRequest = nil
	return true
end
StaticAutomation = (function()
	local api = {}
	local enabled = false
	local toggle = nil
	local promptCount = 0
	local softResetCount = 0
	local statsLabel = nil
	local currentBattle = nil
	local battleFirstSeenAt = 0
	local lastRunAttemptAt = 0
	local lastInteractAt = 0
	local lastSpecialNoticeAt = 0

	local interactDelay = 0.45
	local softResetPromptPhase = 0
	local waitingForPromptDismiss = false
	local clickedPromptInstance = nil
	local clickedPromptText = nil
	local lastPromptClickAt = 0
	local promptFirstSeenAt = 0
	local lastSeenPromptText = nil

	local promptClickMinVisible = 0.15
	local promptPhaseAdvanceDelay = 0.6
	local promptClickGap = 0.8
	local clickedPromptButton = nil
	local lastPromptSeenAt = 0
	local promptSequenceGrace = 0.75
	local promptSequenceTimeout = 6
	local arcerosWalkActive = false
	local arcerosWalkStartedAt = 0
	local lastSoftResetChatAdvanceAt = 0
	local softResetChatAdvanceGap = 0.45
	local chatBoxCache = nil
	local runAttemptBattle = nil
	local runAttemptStartedAt = 0
	local chunkNotReadySince = 0
	local chunkStuckNotified = false
	local battleStuckDumped = false
	local battleForceEnded = false
	local foeLoadedAt = 0
	local walkArcerosToLavaTrigger
	local isSoftResetDialogueActive
	local isSoftResetSequenceActive

	-- The chunk unloads while a soft reset teleports the player; anything we
	-- do during that window (walking, advancing chat, interacting) races the
	-- game's own transition and can wedge it, so everything active waits on
	-- this.
	local function isCurrentChunkReady()
		if type(_G._p) ~= "table" then
			_G._p = _G.F.findP()
		end

		local dataManager = type(_G._p) == "table" and _G._p.DataManager or nil
		return type(dataManager) == "table" and type(dataManager.currentChunk) == "table"
	end

	local function refreshStatus()
		if statsLabel then
			pcall(function()
				statsLabel:Set(string.format("Soft Resets: %d", softResetCount))
			end)
		end

		if _G.arcerosStatsLabel then
			pcall(function()
				_G.arcerosStatsLabel:Set(string.format("Soft Resets: %d", softResetCount))
			end)
		end

		if _G.updateStatus then
			_G.updateStatus()
		end
	end

	local function getGuiContainers()
		local containers = {}

		pcall(function()
			local playerGui = _G.Player and _G.Player:FindFirstChildOfClass("PlayerGui")
			if playerGui then
				table.insert(containers, playerGui)
			end
		end)

		pcall(function()
			local coreGui = game:GetService("CoreGui")
			if coreGui then
				table.insert(containers, coreGui)
			end
		end)

		if type(gethui) == "function" then
			local ok, hui = pcall(gethui)
			if ok and hui then
				table.insert(containers, hui)
			end
		end

		pcall(function()
			if type(_G._p) ~= "table" then
				_G._p = _G.F.findP()
			end

			local utilities = type(_G._p) == "table" and _G._p.Utilities or nil
			if utilities and utilities.frontGui then
				table.insert(containers, utilities.frontGui)
			end
		end)

		return containers
	end

	local function isGuiItemVisible(item)
		local current = item

		while current do
			if current:IsA("GuiObject") and current.Visible == false then
				return false
			end

			if current:IsA("ScreenGui") and current.Enabled == false then
				return false
			end

			current = current.Parent
		end

		return true
	end

	local function clickPromptButton(button)
		if not button then
			return false
		end

		-- Prefer the real mouse; fall back to signal/virtual clicks only
		-- when that isn't possible (window unfocused, no executor support).
		if _G.F.realMouseClickGuiObject(button) then
			return true
		end

		if type(firesignal) == "function" then
			local okSignal, signal = pcall(function()
				return button.Activated
			end)

			if okSignal and signal then
				local okFire = pcall(function()
					firesignal(signal)
				end)

				if okFire then
					return true
				end
			end
		end

		local okActivate = pcall(function()
			button:Activate()
		end)

		return okActivate
	end

	local promptCacheValue = nil
	local promptCacheCheckedAt = 0
	local promptCacheScanAt = 0
	local promptCacheHoldFor = 0.05
	local promptRescanGap = 0.2

	local function scanForVisibleYesOrNoPrompt()
		local promptFrame = _G.F.findVisibleBattleYesOrNoPrompt()
		if promptFrame then
			return promptFrame
		end

		for _, container in ipairs(getGuiContainers()) do
			local ok, descendants = pcall(function()
				return container:GetDescendants()
			end)

			if ok then
				for _, item in ipairs(descendants) do
					if item.Name == "YesOrNoPrompt" and isGuiItemVisible(item) then
						return item
					end
				end
			end
		end

		return nil
	end

	local function findVisibleYesOrNoPrompt()
		local now = os.clock()

		-- Several checks per tick funnel through here; serve them all from
		-- one result instead of re-scanning every GUI tree each time.
		if now - promptCacheCheckedAt < promptCacheHoldFor then
			return promptCacheValue
		end

		if promptCacheValue then
			local live = false
			pcall(function()
				live = promptCacheValue.Parent ~= nil
					and promptCacheValue:IsDescendantOf(game)
					and isGuiItemVisible(promptCacheValue)
			end)

			if live then
				promptCacheCheckedAt = now
				return promptCacheValue
			end

			promptCacheValue = nil
		end

		if now - promptCacheScanAt < promptRescanGap then
			promptCacheCheckedAt = now
			return nil
		end

		promptCacheScanAt = now
		promptCacheValue = scanForVisibleYesOrNoPrompt()
		promptCacheCheckedAt = now
		return promptCacheValue
	end

	local function getYesOrNoPromptButtons(promptRoot)
		if not promptRoot then
			return nil, nil
		end

		local buttons = {}
		local ok, descendants = pcall(function()
			return promptRoot:GetDescendants()
		end)

		if not ok then
			return nil, nil
		end

		for _, item in ipairs(descendants) do
			if item:IsA("ImageButton") and isGuiItemVisible(item) then
				table.insert(buttons, item)
			end
		end

		table.sort(buttons, function(left, right)
			local leftY = left.Position.Y.Scale + (left.Position.Y.Offset / math.max(left.AbsoluteSize.Y, 1))
			local rightY = right.Position.Y.Scale + (right.Position.Y.Offset / math.max(right.AbsoluteSize.Y, 1))
			return leftY < rightY
		end)

		return buttons[1], buttons[2]
	end

	local function resetSoftResetPromptState()
		softResetPromptPhase = 0
		waitingForPromptDismiss = false
		clickedPromptInstance = nil
		clickedPromptText = nil
		clickedPromptButton = nil
		lastPromptClickAt = 0
		promptFirstSeenAt = 0
		lastSeenPromptText = nil
		lastPromptSeenAt = 0
	end

	local function getPromptText(promptRoot)
		local texts = {}

		pcall(function()
			for _, item in ipairs(promptRoot:GetDescendants()) do
				if item:IsA("TextLabel") and item.Text ~= "" then
					table.insert(texts, item.Text)
				end
			end
		end)

		return table.concat(texts, "|")
	end

	local function clickCurrentPrompt(promptFrame, promptText)
		local wantYes = softResetPromptPhase == 1
		local yesButton, noButton = getYesOrNoPromptButtons(promptFrame)
		local targetButton = wantYes and yesButton or noButton

		if not targetButton or not clickPromptButton(targetButton) then
			return false
		end

		waitingForPromptDismiss = true
		clickedPromptInstance = promptFrame
		clickedPromptText = promptText
		clickedPromptButton = targetButton
		lastPromptClickAt = os.clock()
		return true
	end

	local function isClickedButtonStillLive()
		if not clickedPromptButton then
			return false
		end

		local live = false
		pcall(function()
			live = clickedPromptButton.Parent ~= nil
				and clickedPromptButton:IsDescendantOf(game)
				and isGuiItemVisible(clickedPromptButton)
		end)

		return live
	end

	local function handleStaticRestartPrompt()
		local promptFrame = findVisibleYesOrNoPrompt()
		local promptText = promptFrame and getPromptText(promptFrame) or nil
		local now = os.clock()

		if promptFrame then
			lastPromptSeenAt = now
		end

		if waitingForPromptDismiss then
			local samePrompt = promptFrame ~= nil
				and promptFrame == clickedPromptInstance
				and promptText == clickedPromptText
				and isClickedButtonStillLive()

			-- The game may reuse the exact same frame, text, and buttons for the
			-- next question. If the prompt still looks identical shortly after a
			-- click, assume the click was consumed and it's now showing the next
			-- question, rather than re-clicking the same answer.
			if samePrompt and now - lastPromptClickAt < promptPhaseAdvanceDelay then
				return false
			end

			waitingForPromptDismiss = false
			clickedPromptInstance = nil
			clickedPromptText = nil
			clickedPromptButton = nil
			local completedSoftReset = softResetPromptPhase == 1
			softResetPromptPhase = softResetPromptPhase + 1
			if softResetPromptPhase >= 2 then
				softResetPromptPhase = 0
			end
			if completedSoftReset then
				softResetCount = softResetCount + 1
			end
			promptCount = promptCount + 1
			refreshStatus()

			if not samePrompt then
				-- The prompt visibly changed, so the next question is already
				-- loaded; no need to keep the inter-click spacing.
				lastPromptClickAt = 0
			end

			if not promptFrame then
				promptFirstSeenAt = 0
				lastSeenPromptText = nil
				return true
			end
			-- Fall through so the new question gets answered once it settles.
		end

		if not promptFrame then
			promptFirstSeenAt = 0
			lastSeenPromptText = nil
			return false
		end

		-- Let the prompt finish appearing (and its text settle) before clicking.
		if lastSeenPromptText ~= promptText or promptFirstSeenAt == 0 then
			lastSeenPromptText = promptText
			promptFirstSeenAt = now
			return false
		end

		if now - promptFirstSeenAt < promptClickMinVisible then
			return false
		end

		-- Keep answers spaced out so the next question has time to load in.
		if lastPromptClickAt > 0 and now - lastPromptClickAt < promptClickGap then
			return false
		end

		return clickCurrentPrompt(promptFrame, promptText)
	end

	local function advanceSoftResetNpcChat()
		if findVisibleYesOrNoPrompt() then
			return false
		end

		if not isCurrentChunkReady() then
			return false
		end

		local now = os.clock()
		if now - lastSoftResetChatAdvanceAt < softResetChatAdvanceGap then
			return false
		end

		if not _G.F.advanceSoftResetNpcChat or type(_G.F.advanceSoftResetNpcChat) ~= "function" then
			return false
		end

		if not _G.F.advanceSoftResetNpcChat() then
			return false
		end

		lastSoftResetChatAdvanceAt = now
		return true
	end

	local function handleSoftResetDialogue()
		advanceSoftResetNpcChat()
		return handleStaticRestartPrompt()
	end

	isSoftResetDialogueActive = function()
		if findVisibleYesOrNoPrompt() then
			return true
		end

		if type(_G._p) ~= "table" then
			_G._p = _G.F.findP()
		end

		local chat = type(_G._p) == "table" and _G._p.NPCChat or nil
		if type(chat) ~= "table" then
			return false
		end

		local awaitingManual = false
		pcall(function()
			if type(chat.isAwaitingManualAdvance) == "function" then
				awaitingManual = chat:isAwaitingManualAdvance()
			end
		end)

		if awaitingManual then
			return true
		end

		if not (_G.arcerosAutoEnabled or enabled) then
			return false
		end

		local chatting = false
		pcall(function()
			if type(chat.isChatting) == "function" then
				chatting = chat:isChatting()
			end
		end)

		if not chatting then
			return false
		end

		local utilities = type(_G._p) == "table" and _G._p.Utilities or nil
		local frontGui = utilities and utilities.frontGui
		if not frontGui then
			return false
		end

		local chatBox = chatBoxCache
		if not (chatBox and chatBox.Parent and chatBox:IsDescendantOf(frontGui)) then
			chatBox = frontGui:FindFirstChild("ChatBox", true)
			chatBoxCache = chatBox
		end

		return chatBox ~= nil and isGuiItemVisible(chatBox)
	end

	isSoftResetSequenceActive = function()
		if findVisibleYesOrNoPrompt() then
			return true
		end

		if isSoftResetDialogueActive() then
			return true
		end

		local now = os.clock()

		if waitingForPromptDismiss or softResetPromptPhase ~= 0 then
			-- The next prompt in the sequence may still be on its way; don't
			-- start a new interaction, which would reset the prompt phase.
			if now - lastPromptSeenAt <= promptSequenceTimeout then
				return true
			end

			-- The sequence appears to have died; recover.
			resetSoftResetPromptState()
			return false
		end

		return lastPromptSeenAt > 0 and now - lastPromptSeenAt < promptSequenceGrace
	end

	local function normalizeInteractKind(value)
		return string.lower(string.gsub(tostring(value or ""), "%s+", ""))
	end

	local function getStaticChunkRoots()
		if type(_G._p) ~= "table" then
			_G._p = _G.F.findP()
		end

		local roots = {}
		local currentChunk = type(_G._p) == "table" and _G._p.DataManager and _G._p.DataManager.currentChunk or nil

		if type(currentChunk) == "table" and currentChunk.map then
			table.insert(roots, currentChunk.map)
		end

		if type(currentChunk) == "table" and type(currentChunk.GetMap) == "function" then
			local ok, map = pcall(function()
				return currentChunk:GetMap()
			end)

			if ok and map and map ~= currentChunk.map then
				table.insert(roots, map)
			end
		end

		return roots
	end

	local function getInanimateInteractPosition(model, tag)
		local main = model and (model:FindFirstChild("Main") or model:FindFirstChild("Base"))
		if main and main:IsA("BasePart") then
			return main.Position
		end

		local parent = tag and tag.Parent
		if parent and parent:IsA("BasePart") then
			return parent.Position
		end

		if model and model:IsA("Model") and model.PrimaryPart then
			return model.PrimaryPart.Position
		end

		return nil
	end

	local function collectChunkInanimateInteracts()
		local entries = {}
		local seen = {}

		for _, root in ipairs(getStaticChunkRoots()) do
			local ok, descendants = pcall(function()
				return root:GetDescendants()
			end)

			if ok then
				for _, item in ipairs(descendants) do
					if item.Name == "#InanimateInteract" and item:IsA("StringValue") and not seen[item] then
						seen[item] = true

						local model = item.Parent
						if model then
							table.insert(entries, {
								tag = item,
								model = model,
								kind = tostring(item.Value or ""),
								position = getInanimateInteractPosition(model, item)
							})
						end
					end
				end
			end
		end

		return entries
	end

	local function listChunkInteractKinds(entries)
		local kinds = {}
		local seen = {}

		for _, entry in ipairs(entries) do
			local kind = entry.kind
			if kind ~= "" and not seen[kind] then
				seen[kind] = true
				table.insert(kinds, kind)
			end
		end

		table.sort(kinds)
		return kinds
	end

	local function findNearestChunkInanimateInteract()
		local root = _G.F.getRoot()
		if not root then
			return nil, "Character root is not ready."
		end

		local entries = collectChunkInanimateInteracts()
		if #entries == 0 then
			return nil, "No #InanimateInteract tags found in the current chunk."
		end

		local wanted = normalizeInteractKind(_G.staticInteractTarget)
		local bestEntry = nil
		local bestDistance = math.huge

		for _, entry in ipairs(entries) do
			local matchesTarget = wanted == "" or normalizeInteractKind(entry.kind) == wanted
			if matchesTarget and entry.position then
				local distance = (root.Position - entry.position).Magnitude
				if distance < bestDistance then
					bestEntry = entry
					bestDistance = distance
				end
			end
		end

		if not bestEntry then
			local kinds = listChunkInteractKinds(entries)
			local available = #kinds > 0 and table.concat(kinds, ", ") or "unknown"

			if wanted ~= "" then
				return nil, string.format("No #InanimateInteract with value '%s' in this chunk. Available: %s", _G.staticInteractTarget, available)
			end

			return nil, "No usable #InanimateInteract tags found in the current chunk."
		end

		return bestEntry
	end

	local function resolveStaticBattleKind()
		if _G.arcerosAutoEnabled then
			return "arceros", nil
		end

		local wanted = normalizeInteractKind(_G.staticInteractTarget)
		if wanted == "arceros" then
			return "arceros", nil
		end

		if wanted ~= "" then
			return _G.staticInteractTarget, nil
		end

		local entries = collectChunkInanimateInteracts()
		if #entries == 0 then
			return nil, "No #InanimateInteract tags found. Set Interact Target (e.g. cephalops)."
		end

		local kinds = listChunkInteractKinds(entries)
		if #kinds == 1 then
			return kinds[1], nil
		end

		local entry, reason = findNearestChunkInanimateInteract()
		if entry then
			return entry.kind, nil
		end

		if #kinds > 1 then
			return nil, string.format("Multiple interacts in chunk (%s). Set Interact Target.", table.concat(kinds, ", "))
		end

		return nil, reason or "Could not resolve a static interact target."
	end

	local STATIC_REGION_KEYS = {
		cephalops = "csq",
		burnslug = "slug",
		spooker21 = "spooker",
	}

	local function buildSoftResetRoamerConfig(monsterName, roamFlag, monsterLookDir, resetCF, roamer)
		return {
			monsterName = monsterName,
			[roamFlag] = true,
			monsterLookDir = monsterLookDir,
			owm = roamer,
			resetCF = resetCF
		}
	end

	local function buildStaticBattleConfig(kind, chunk, gameState)
		local normalizedKind = normalizeInteractKind(kind)
		local regionData = chunk.regionData

		if normalizedKind == "cephalops" then
			local roamer = chunk.roamer
			if not roamer then
				return nil, nil, "Cephalops roamer is not loaded in this chunk."
			end

			local pool = regionData and regionData.csq
			if type(pool) ~= "table" then
				return nil, nil, "regionData.csq is not available in this chunk."
			end

			return pool, {
				musicVolume = 0.7,
				musicId = { 9116975080, 9116943160 },
				softResetInfo = buildSoftResetRoamerConfig(
					"Cephalops",
					"doesRoam",
					Vector3.new(-1, 0, 0),
					CFrame.new(-600, 220.5, 1010, 0, 0, -1, 0, 1, 0, 1, 0, 0),
					roamer
				)
			}
		end

		if normalizedKind == "spooker21" then
			local roamer = chunk.roamer
			if not roamer then
				return nil, nil, "Nevermare roamer is not loaded in this chunk."
			end

			local pool = regionData and regionData.spooker
			if type(pool) ~= "table" then
				return nil, nil, "regionData.spooker is not available in this chunk."
			end

			return pool, {
				musicVolume = 0.6,
				musicId = { 7796745359, 7796747076 },
				softResetInfo = buildSoftResetRoamerConfig(
					"Nevermare",
					"doesRoamUFGraveyard",
					Vector3.new(0, 0, -1),
					CFrame.new(-1432, 32.6, 3067.5, -1, 0, 0, 0, 1, 0, 0, 0, -1),
					roamer
				)
			}
		end

		if normalizedKind == "phage" then
			local phage = gameState._phage
			if not phage then
				return nil, nil, "Elephage overworld model is not loaded."
			end

			local pool = regionData and regionData.phage
			if type(pool) ~= "table" then
				return nil, nil, "regionData.phage is not available in this chunk."
			end

			return pool, {
				musicVolume = 0.34,
				musicId = { 9733031349, 9733032843 },
				softResetInfo = buildSoftResetRoamerConfig(
					"Elephage",
					"doesRoam",
					Vector3.new(0, 0, -1),
					CFrame.new(5.7, 7.25, 107.4, -1, 0, 0, 0, 1, 0, 0, 0, -1),
					phage
				)
			}
		end

		if normalizedKind == "arceros" then
			local pool = regionData and regionData.beastLava
			if type(pool) ~= "table" then
				return nil, nil, "regionData.beastLava is not available. Stand in Beasts of Judgement (chunk27)."
			end

			-- Without the scene, doWildBattle nil-indexes partway through
			-- setup and leaves a half-initialized battle.
			local builtInScene = _G.F.getArcerosBattleScene()
			if not builtInScene then
				return nil, nil, "Arceros battle scene is not loaded."
			end

			return pool, {
				musicVolume = 0.8,
				musicId = { 15235696765, 15235699127 },
				useBuiltInScene = builtInScene,
				softResetInfo = {
					isBeastsOfJudgementRoam = true,
					monsterName = "Arceros",
					resetCF = CFrame.new(6319.5, 10.2, 1466.7, 0.41174382, 0, -0.911299646, 0, 1, 0, 0.911299646, 0, 0.41174382),
				},
			}
		end

		if normalizedKind == "burnslug" then
			local pool = regionData and regionData.slug
			if type(pool) ~= "table" then
				return nil, nil, "regionData.slug is not available in this chunk."
			end

			return pool, {}
		end

		local regionKey = STATIC_REGION_KEYS[normalizedKind] or kind
		local pool = regionData and (regionData[regionKey] or regionData[normalizedKind])

		if type(pool) ~= "table" then
			for key, value in pairs(regionData or {}) do
				if normalizeInteractKind(key) == normalizedKind and type(value) == "table" then
					pool = value
					break
				end
			end
		end

		if type(pool) ~= "table" then
			return nil, nil, string.format("No regionData battle pool found for '%s'.", tostring(kind))
		end

		return pool, {}
	end

	local function findStaticInteractEntry(kind)
		local normalizedKind = normalizeInteractKind(kind)

		for _, entry in ipairs(collectChunkInanimateInteracts()) do
			if normalizeInteractKind(entry.kind) == normalizedKind then
				return entry
			end
		end

		return nil
	end

	walkArcerosToLavaTrigger = function(manualRequest)
		if arcerosWalkActive then
			return true
		end

		if not isCurrentChunkReady() then
			return false, "Waiting for the chunk to load."
		end

		local lavaTrigger = _G.F.getSelectedBeastTrigger()
		if not lavaTrigger or not lavaTrigger:IsA("BasePart") then
			return false
		end

		if type(_G._p) ~= "table" then
			_G._p = _G.F.findP()
		end

		local root = _G.F.getRoot()
		if not root then
			return false, "Character root is not ready."
		end

		local lookDir = -lavaTrigger.CFrame.RightVector
		local standPos = lavaTrigger.Position + lookDir * 5

		arcerosWalkActive = true
		arcerosWalkStartedAt = os.clock()

		task.spawn(function()
			local deadline = os.clock() + 60
			local startedWalk = false

			while os.clock() < deadline do
				if not arcerosWalkActive then
					break
				end

				if not manualRequest and not _G.arcerosAutoEnabled and not enabled then
					break
				end

				if _G.F.getCurrentBattle() then
					break
				end

				local blocked = false
				pcall(function()
					blocked = isSoftResetSequenceActive() or not isCurrentChunkReady()
				end)

				if blocked then
					task.wait(0.2)
				else
					local masterControl = type(_G._p) == "table" and _G._p.MasterControl or nil
					if type(masterControl) == "table" and masterControl.WalkEnabled ~= false then
						if not startedWalk then
							pcall(function()
								masterControl:WalkTo(standPos, 8)
							end)
							startedWalk = true
						end

						local liveRoot = _G.F.getRoot()
						if liveRoot then
							local distance = (liveRoot.Position - standPos).Magnitude
							if distance <= 4 then
								pcall(function()
									masterControl:WalkTo(lavaTrigger.Position + lookDir * 2, 8)
								end)
								task.wait(1.5)
								break
							end
						end
					end

					task.wait(0.2)
				end
			end

			arcerosWalkActive = false
		end)

		return true
	end

	local function startNaturalStaticEncounter(kindOverride)
		if type(_G._p) ~= "table" then
			_G._p = _G.F.findP()
		end

		if type(_G._p) ~= "table" then
			return false, "Hook is not ready."
		end

		if _G.F.getCurrentBattle()
			or (_G._p.BattleClient and _G._p.BattleClient.currentBattle)
			or (_G._p.Battle and _G._p.Battle.currentBattle) then
			return false, "Battle already active."
		end

		local kind, kindReason
		if kindOverride and kindOverride ~= "" then
			kind = kindOverride
		else
			kind, kindReason = resolveStaticBattleKind()
		end

		if not kind then
			return false, kindReason
		end

		local isArcerosKind = normalizeInteractKind(kind) == "arceros"

		if not _G.F.getRoot() then
			return false, "Waiting for the character to load."
		end

		if not isArcerosKind then
			local masterControl = _G._p.MasterControl
			if type(masterControl) == "table" and masterControl.WalkEnabled == false then
				return false, "Cannot interact right now."
			end
		end

		if isArcerosKind then
			if arcerosWalkActive then
				return false
			end

			-- Never fall through to the generic interact/doWildBattle paths
			-- for Arceros: starting the battle any way other than touching
			-- the lava trigger can nil-index inside the game's battle setup
			-- and leave a half-initialized battle (one camera move, no
			-- player side, never completes). Verify every piece and wait
			-- until all of it is loaded.
			if not isCurrentChunkReady() then
				return false, "Waiting for the chunk to load."
			end

			local lavaTrigger = _G.F.getSelectedBeastTrigger()
			if not lavaTrigger then
				return false, "Waiting for the soft reset trigger to load."
			end

			local walked, walkReason = walkArcerosToLavaTrigger()
			if walked then
				return false
			end

			return false, walkReason or "Waiting for the soft reset trigger walk."
		end

		local inanimateInteract = _G._p.InanimateInteract
		local handler = type(inanimateInteract) == "table" and inanimateInteract[kind] or nil
		local entry = findStaticInteractEntry(kind)

		if type(handler) == "function" then
			-- Calling the game's handler with a missing model nil-indexes
			-- partway through its battle setup; wait until it's loaded.
			if not entry or not entry.model or not entry.model.Parent then
				return false, string.format("Overworld model for '%s' is not loaded.", tostring(kind))
			end

			resetSoftResetPromptState()

			local ok, result = pcall(function()
				return handler(entry.model)
			end)

			if not ok then
				return false, tostring(result)
			end

			resetSoftResetPromptState()
			return true
		end

		local chunk = _G._p.DataManager and _G._p.DataManager.currentChunk
		if type(chunk) ~= "table" then
			return false, "Current chunk is not ready."
		end

		local pool, options, buildReason = buildStaticBattleConfig(kind, chunk, _G._p)
		if type(pool) ~= "table" then
			return false, buildReason or string.format("No battle config for '%s'.", tostring(kind))
		end

		local battleClient = _G._p.BattleClient or _G._p.Battle
		if type(battleClient) ~= "table" or type(battleClient.doWildBattle) ~= "function" then
			return false, "BattleClient is not ready."
		end

		local ok, result = pcall(function()
			resetSoftResetPromptState()
			return battleClient:doWildBattle(pool, options or {})
		end)

		if not ok then
			return false, tostring(result)
		end

		resetSoftResetPromptState()
		return true
	end

	local function getPromptWorldPosition(prompt)
		local parent = prompt and prompt.Parent

		if not parent then
			return nil
		end

		if parent:IsA("Attachment") then
			return parent.WorldPosition
		end

		if parent:IsA("BasePart") then
			return parent.Position
		end

		local part = parent:FindFirstAncestorWhichIsA("BasePart")
		return part and part.Position or nil
	end

	local function findNearestEnabledProximityPrompt()
		local root = _G.F.getRoot()
		if not root then
			return nil, "Character root is not ready."
		end

		local ok, descendants = pcall(function()
			return workspace:GetDescendants()
		end)

		if not ok then
			return nil, "Workspace prompts are not available."
		end

		local bestPrompt = nil
		local bestDistance = math.huge

		for _, item in ipairs(descendants) do
			if item:IsA("ProximityPrompt") and item.Enabled then
				local position = getPromptWorldPosition(item)

				if position then
					local distance = (root.Position - position).Magnitude
					local maxDistance = tonumber(item.MaxActivationDistance) or 10

					if distance <= maxDistance + 6 and distance < bestDistance then
						bestPrompt = item
						bestDistance = distance
					end
				end
			end
		end

		if not bestPrompt then
			return nil, "Stand near the static encounter prompt."
		end

		return bestPrompt
	end

	local function findNearestEnabledClickDetector()
		local root = _G.F.getRoot()
		if not root then
			return nil, "Character root is not ready."
		end

		local ok, descendants = pcall(function()
			return workspace:GetDescendants()
		end)

		if not ok then
			return nil, "Workspace click detectors are not available."
		end

		local bestDetector = nil
		local bestDistance = math.huge

		for _, item in ipairs(descendants) do
			if item:IsA("ClickDetector") then
				local parent = item.Parent
				local part = parent and (parent:IsA("BasePart") and parent or parent:FindFirstAncestorWhichIsA("BasePart"))

				if part then
					local distance = (root.Position - part.Position).Magnitude
					local maxDistance = tonumber(item.MaxActivationDistance) or 32

					if distance <= maxDistance + 6 and distance < bestDistance then
						bestDetector = item
						bestDistance = distance
					end
				end
			end
		end

		if not bestDetector then
			return nil, "Stand near the static encounter prompt."
		end

		return bestDetector
	end

	local function triggerProximityPrompt(prompt)
		if not prompt then
			return false
		end

		if type(fireproximityprompt) == "function" then
			local ok = pcall(function()
				fireproximityprompt(prompt)
			end)

			if ok then
				return true
			end
		end

		local ok = pcall(function()
			prompt:InputHoldBegin()
			task.wait((tonumber(prompt.HoldDuration) or 0) + 0.05)
			prompt:InputHoldEnd()
		end)

		return ok
	end

	local function triggerClickDetector(detector)
		if not detector then
			return false
		end

		if type(fireclickdetector) == "function" then
			local ok = pcall(function()
				fireclickdetector(detector)
			end)

			if ok then
				return true
			end
		end

		return false
	end

	local function resetBattleState()
		currentBattle = nil
		battleFirstSeenAt = 0
		lastRunAttemptAt = 0
		battleStuckDumped = false
		battleForceEnded = false
		foeLoadedAt = 0
	end

	local function notifyStaticSpecial(foe, specialValue, specialReason)
		local now = os.clock()
		if now - lastSpecialNoticeAt < 2 then
			return
		end

		lastSpecialNoticeAt = now
		local wasBeastHunt = _G.arcerosAutoEnabled
		enabled = false
		_G.arcerosAutoEnabled = false

		if type(toggle) == "table" and type(toggle.Set) == "function" and toggle.Value ~= false then
			task.defer(function()
				toggle:Set(false)
			end)
		end

		if _G.configUi.autoArcerosToggle and type(_G.configUi.autoArcerosToggle.Set) == "function" then
			task.defer(function()
				_G.configUi.autoArcerosToggle:Set(false)
			end)
		end

		pcall(function()
			_G.OrionLib:MakeNotification({
				Name = wasBeastHunt and (_G.F.getSelectedBeastName() .. " Hunt Paused") or "Static Hunt Paused",
				Content = string.format("Found %s (%s: %s).", tostring(foe and (foe.name or foe.species) or "wild Loomian"), tostring(specialReason), tostring(specialValue)),
				Time = 8
			})
		end)

		refreshStatus()
	end

	function api:isAutomationActive()
		return enabled or _G.arcerosAutoEnabled
	end

	function api:checkBattleFoe(battle)
		if not self:isAutomationActive() or not _G.F.hasWildFoeLoaded(battle) then
			return false
		end

		if _G.arcerosAutoEnabled then
			local foe = _G.F.getBattleFoeMonster(battle)
			local gleamValue = foe and _G.F.getMonsterGleamValue(foe)
			if _G.isActiveFlag(gleamValue) then
				notifyStaticSpecial(foe, gleamValue, "Gleaming/Gamma")
				return true
			end

			return false
		end

		local foe, specialValue, specialReason = _G.F.getStaticHuntSpecialFoe(battle)
		if foe then
			notifyStaticSpecial(foe, specialValue, specialReason)
			return true
		end

		return false
	end

	function api:isArcerosWalking()
		return arcerosWalkActive
	end

	function api:walkToArcerosTrigger()
		return walkArcerosToLavaTrigger(true)
	end

	function api:isEnabled()
		return enabled
	end

	function api:setEnabled(value)
		enabled = value and true or false

		if not enabled and not _G.arcerosAutoEnabled then
			resetBattleState()
			resetSoftResetPromptState()
			arcerosWalkActive = false
		end

		refreshStatus()
	end

	function api:attachToggle(newToggle)
		toggle = newToggle
	end

	function api:getPromptCount()
		return promptCount
	end

	function api:getSoftResetCount()
		return softResetCount
	end

	function api:attachStatsLabel(label)
		statsLabel = label
		refreshStatus()
	end

	function api:resetStats()
		promptCount = 0
		softResetCount = 0
		resetSoftResetPromptState()
		refreshStatus()
	end

	function api:serviceSoftResetDialogue()
		if not self:isAutomationActive() then
			return
		end

		pcall(function()
			if type(_G._p) ~= "table" then
				_G._p = _G.F.findP()
			end

			handleSoftResetDialogue()
		end)

		if not _G.arcerosAutoEnabled or arcerosWalkActive or _G.F.getCurrentBattle() then
			return
		end

		local blocked = false
		pcall(function()
			blocked = isSoftResetSequenceActive()
		end)

		if blocked then
			return
		end

		pcall(function()
			local lavaTrigger = _G.F.getSelectedBeastTrigger()
			if lavaTrigger and walkArcerosToLavaTrigger then
				walkArcerosToLavaTrigger()
			end
		end)
	end

	function api:serviceBattle()
		if not self:isAutomationActive() then
			return
		end

		if type(_G._p) ~= "table" then
			_G._p = _G.F.findP()
		end

		self:serviceSoftResetDialogue()

		local battle = _G.F.getCurrentBattle()
		if type(battle) ~= "table" then
			return
		end

		if self:checkBattleFoe(battle) then
			return
		end

		if _G.fastForwardEnabled or enabled or _G.arcerosAutoEnabled then
			_G.F.setBattleFastForward(true, battle)
			_G.F.applyBattleAnimationFastForward(battle, false)
		end

		if battle.ended then
			_G.F.clearBattleRunTiming(battle)
			return
		end

		local now = os.clock()

		if currentBattle ~= battle then
			currentBattle = battle
			battleFirstSeenAt = now
			battleStuckDumped = false
			battleForceEnded = false
			foeLoadedAt = 0
		end

		local battleAge = now - battleFirstSeenAt

		-- A soft-reset battle should be over within a few seconds. If one
		-- sits around, log its state once so the wedge is visible in the
		-- console instead of hanging silently.
		if battleAge >= 15 and not battleStuckDumped then
			battleStuckDumped = true
			pcall(function()
				warn(string.format(
					"[Auto Static] Battle stuck for %ds: setupComplete=%s state=%s battleId=%s turn=%s CanRun=%s foeLoaded=%s menuOpen=%s linked=%s",
					math.floor(battleAge),
					tostring(_G.F.safeTableGet(battle, "setupComplete")),
					tostring(_G.F.safeTableGet(battle, "state")),
					tostring(_G.F.safeTableGet(battle, "battleId")),
					tostring(_G.F.safeTableGet(battle, "turn")),
					tostring(_G.F.safeTableGet(battle, "CanRun")),
					tostring(_G.F.hasWildFoeLoaded(battle)),
					tostring(_G.F.isBattleMainMenuOpen()),
					tostring(_G.F.isBattleLinkedToBattleGui(battle))
				))
			end)
		end

		-- Last resort: force the battle closed so the hunt can't wedge on a
		-- battle that never becomes runnable. The next soft reset restores
		-- clean state either way.
		if battleAge >= 25 and not battleForceEnded then
			battleForceEnded = true
			warn("[Auto Static] Battle stuck for 25s; force-ending it.")

			task.spawn(function()
				pcall(function()
					local network = type(_G._p) == "table" and _G._p.Network or nil
					local battleId = _G.F.safeTableGet(battle, "battleId")
					if type(network) == "table" and type(network.get) == "function" and battleId then
						network:get("BattleFunction", battleId, "tryRun")
					end
				end)
			end)

			task.spawn(function()
				task.wait(3)

				pcall(function()
					if not _G.F.isBattleEnded(battle) then
						_G.F.finishNaturalBattleRun(battle, true)
					end
				end)

				pcall(function()
					_G.F.releaseFinishedBattle(battle)
				end)
			end)

			return
		end

		if not _G.F.isStaticBattleReadyToEnd(battle) then
			return
		end

		if foeLoadedAt == 0 then
			foeLoadedAt = now
		end

		-- The foe's special flags (gleam/wisp) can replicate a beat after
		-- the monster entry itself appears; hold every run attempt long
		-- enough for checkBattleFoe to see the settled flags first, so a
		-- Gleaming pauses the hunt instead of being run from.
		if now - foeLoadedAt < 1 then
			return
		end

		-- The built-in-scene battle sometimes never shows a detectable run
		-- menu; after waiting on it for a while, use the timed run path so
		-- the battle still gets ended instead of wedging the hunt.
		local allowTimedFallback = battleAge >= 6

		if not _G.F.isBattleRunMenuReady(battle, allowTimedFallback) then
			return
		end

		if now - lastRunAttemptAt < 0.35 then
			return
		end

		lastRunAttemptAt = now

		-- tryRun invokes the server and can yield forever if the battle is
		-- not ready server-side; run the attempt on its own thread so a
		-- stuck invoke can't kill this service loop, and don't stack a new
		-- attempt on the same battle until the old one finishes or times out.
		if runAttemptBattle == battle and now - runAttemptStartedAt < 8 then
			return
		end

		runAttemptBattle = battle
		runAttemptStartedAt = now

		task.spawn(function()
			pcall(function()
				_G.F.naturalRunFromBattle(battle, allowTimedFallback)
			end)

			if runAttemptBattle == battle then
				runAttemptBattle = nil
			end
		end)
	end

	function api:runCycle()
		if not self:isAutomationActive() then
			return false
		end

		if _G.F.getCurrentBattle() then
			return false
		end

		if arcerosWalkActive then
			return false
		end

		if isSoftResetSequenceActive() then
			pcall(handleSoftResetDialogue)
			return false, "Waiting for the static prompt."
		end

		local now = os.clock()

		if not isCurrentChunkReady() then
			if chunkNotReadySince == 0 then
				chunkNotReadySince = now
			elseif now - chunkNotReadySince >= 30 and not chunkStuckNotified then
				chunkStuckNotified = true
				warn("[Auto Static] Chunk has not reloaded for 30s; the soft reset looks stuck. A rejoin may be needed.")

				pcall(function()
					_G.OrionLib:MakeNotification({
						Name = "Arceros",
						Content = "Chunk has not reloaded for 30s. The soft reset looks stuck; a rejoin may be needed.",
						Time = 10,
					})
				end)
			end

			return false, "Waiting for the chunk to load."
		end

		chunkNotReadySince = 0
		chunkStuckNotified = false

		if now - lastInteractAt < interactDelay then
			return false
		end

		lastInteractAt = now
		return startNaturalStaticEncounter()
	end

	function api:startInteraction(kind)
		if _G.F.getCurrentBattle() then
			return false, "Battle already active."
		end

		return startNaturalStaticEncounter(kind)
	end

	return api
end)()
_G.F.truthy = function(value)
	return value ~= nil and value ~= false and value ~= 0
end

_G.F.refreshRallyUI = function()
	if _G.rallyStatsLabel then
		pcall(function()
			_G.rallyStatsLabel:Set(string.format("Kept: %d | Released: %d", _G.rallyKept, _G.rallyReleased))
		end)
	end
	if _G.rallyStatusLabel then
		pcall(function()
			_G.rallyStatusLabel:Set(_G.lastRallyActionText)
		end)
	end
end

_G.F.setAlwaysKeepList = function(text)
	_G.alwaysKeepText = tostring(text or "")
	_G.alwaysKeepList = {}
	for entry in string.gmatch(_G.alwaysKeepText, "[^,]+") do
		local key = string.lower(string.gsub(entry, "^%s*(.-)%s*$", "%1"))
		if key ~= "" then
			table.insert(_G.alwaysKeepList, key)
		end
	end
end

-- Rally PDS API (from game Rally module):
--   ranchStatus  -> { rallied = number, full = boolean }
--   getRallied   -> { monsters = {...}, max = number, mastery = ... }
--   handleRallied(marks) -> new rallied count
-- Marks: 0 = unmarked, 1 = release, 2 = keep
_G.F.rallyPdsGet = function(actionName, ...)
	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end

	local args = { ... }

	for _, remoteKey in ipairs({ "Network", "Connection" }) do
		local remote = type(_G._p) == "table" and _G._p[remoteKey] or nil
		if type(remote) == "table" and type(remote.get) == "function" then
			local ok, result = pcall(function()
				return remote:get("PDS", actionName, unpack(args))
			end)
			if ok then
				return true, result
			end
		end
	end

	local ok, result = pcall(function()
		local remoteFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Remote")
		local getRemote = remoteFolder and remoteFolder:FindFirstChild("GET")
		if not getRemote then
			error("GET remote not found")
		end
		return getRemote:InvokeServer("PDS", actionName, unpack(args))
	end)

	if ok then
		return true, result
	end

	return false
end

-- PDS shop flow for Arcade Boonary: maxBuy -> quantity, then buyItem(id, qty).
-- At 999,999 tix and 2,000 tix each, that is 499 Boonarys.
_G.BOONARY_PDS_REQ_KEY = "qYMeR25bQnq/OmfJpFX7Hg"
_G.BOONARY_SHOP_ITEM_ID = "_loom_Boonary"
_G.BOONARY_TIX_PRICE = 2000

_G.F.pdsGetAction = function(actionName, ...)
	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end

	local args = { ... }
	local network = type(_G._p) == "table" and _G._p.Network or nil
	if type(network) == "table" and type(network.get) == "function" then
		local ok, value = pcall(function()
			return network:get("PDS", actionName, unpack(args))
		end)
		if ok then
			return true, value
		end
	end

	return _G.F.rallyPdsGet(actionName, unpack(args))
end

_G.F.getBoonaryBuyQuantityFromTix = function(tix)
	tix = tonumber(tix)
	if not tix or tix <= 0 then
		return nil
	end

	local price = tonumber(_G.BOONARY_TIX_PRICE) or 2000
	if price <= 0 then
		return nil
	end

	return math.floor(tix / price)
end

_G.F.getBoonaryMaxBuyErrorMessage = function(code)
	local errorMessages = {
		fb = "Already at max carry for Boonary.",
		nc = "Not enough Battle Tokens.",
		np = "Not enough Cake Points.",
		nt = "Not enough Tickets/Tix.",
		nr = "Not enough resources/vouchers for Boonary.",
		nm = "Not enough Loomicoin.",
		ao = "You already own this item.",
		lc = "Loomian Care is full.",
		dl = "Daily Boonary purchase limit reached.",
	}

	return errorMessages[code] or ("Shop purchase failed: " .. tostring(code))
end

_G.F.rallyPdsReq = function(actionName, ...)
	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end

	local args = { ... }

	for _, remoteKey in ipairs({ "Network", "Connection" }) do
		local remote = type(_G._p) == "table" and _G._p[remoteKey] or nil
		for _, methodName in ipairs({ "post", "request" }) do
			local method = type(remote) == "table" and remote[methodName] or nil
			if type(method) == "function" then
				local ok, result = pcall(function()
					return method(remote, "PDS", actionName, unpack(args))
				end)
				if ok then
					return true, result
				end
			end
		end
	end

	local ok, result = pcall(function()
		local remoteFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Remote")
		local reqRemote = remoteFolder and remoteFolder:FindFirstChild("REQ")
		if not reqRemote then
			error("REQ remote not found")
		end
		return reqRemote:InvokeServer(_G.BOONARY_PDS_REQ_KEY, "PDS", actionName, unpack(args))
	end)

	if ok then
		return true, result
	end

	return false, result
end

_G.F.getRallyModule = function()
	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end
	if type(_G._p) ~= "table" then
		return nil
	end

	if type(_G._p.Menu) == "table" and type(_G._p.Menu.rally) == "table" then
		return _G._p.Menu.rally
	end
	if type(_G._p.Rally) == "table" then
		return _G._p.Rally
	end
	if type(_G._p.DataManager) == "table" and type(_G._p.DataManager.loadModule) == "function" then
		local ok, result = pcall(function()
			return _G._p.DataManager:loadModule("Rally")
		end)
		if ok and type(result) == "table" then
			return result
		end
	end

	return nil
end

_G.F.ensureRallyModule = function()
	local rally = _G.F.getRallyModule()
	if rally then
		return rally
	end

	if type(_G._p) ~= "table" or type(_G._p.DataManager) ~= "table" then
		return nil
	end

	local ok, result = pcall(function()
		if type(_G._p.DataManager.loadModule) == "function" then
			return _G._p.DataManager:loadModule("Rally")
		end
	end)

	if ok and type(result) == "table" then
		if type(_G._p.Menu) == "table" then
			pcall(function()
				_G._p.Menu.rally = result
			end)
		end
		return result
	end

	return nil
end

_G.F.syncRallyBubble = function(newCount)
	local rally = _G.F.ensureRallyModule()
	if not rally or newCount == nil then
		return
	end

	pcall(function()
		rally.ralliedCount = newCount
	end)

	if type(rally.updateNPCBubble) == "function" then
		pcall(function()
			rally:updateNPCBubble(newCount)
		end)
	end
end

_G.F.openRallyMenu = function()
	local rally = _G.F.ensureRallyModule()
	if not rally then
		return false, "Rally module is not loaded."
	end

	if type(rally.openRalliedMonstersMenu) == "function" then
		local ok, err = pcall(function()
			if type(_G._p.Menu) == "table" and type(_G._p.Menu.disable) == "function" then
				_G._p.Menu:disable()
			end
			rally:openRalliedMonstersMenu()
		end)

		pcall(function()
			if type(_G._p.Menu) == "table" and type(_G._p.Menu.enable) == "function" then
				_G._p.Menu:enable()
			end
		end)

		if ok then
			return true
		end
		return false, tostring(err)
	end

	if type(rally.openRallyTeamMenu) == "function" then
		local ok, err = pcall(function()
			if type(_G._p.Menu) == "table" and type(_G._p.Menu.disable) == "function" then
				_G._p.Menu:disable()
			end
			rally:openRallyTeamMenu()
		end)

		pcall(function()
			if type(_G._p.Menu) == "table" and type(_G._p.Menu.enable) == "function" then
				_G._p.Menu:enable()
			end
		end)

		if ok then
			return true
		end
		return false, tostring(err)
	end

	return false, "Rally module has no menu opener."
end

_G.F.getShopModule = function()
	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end

	if type(_G._p) ~= "table" then
		return nil
	end

	local menu = type(_G._p.Menu) == "table" and _G._p.Menu or nil
	local parents = {}
	if type(menu) == "table" then
		table.insert(parents, menu)
	end
	table.insert(parents, _G._p)

	for _, parent in ipairs(parents) do
		for _, key in ipairs({ "shop", "Shop", "shops", "Shops", "mart", "Mart" }) do
			local candidate = _G.F.safeTableGet(parent, key)
			if type(candidate) == "table" or type(candidate) == "function" then
				return candidate
			end
		end
	end

	for _, parent in ipairs(parents) do
		for _, methodName in ipairs({ "openShop", "OpenShop", "openShopMenu", "OpenShopMenu", "openMart", "OpenMart" }) do
			if type(_G.F.safeTableGet(parent, methodName)) == "function" then
				return parent
			end
		end
	end

	local dataManager = type(_G._p.DataManager) == "table" and _G._p.DataManager or nil
	if type(dataManager) == "table" and type(_G.F.safeTableGet(dataManager, "loadModule")) == "function" then
		for _, moduleName in ipairs({ "Shop", "shop", "Shops", "shops", "Mart", "ShopMenu" }) do
			local ok, result = pcall(function()
				return dataManager:loadModule(moduleName)
			end)

			if ok and (type(result) == "table" or type(result) == "function") then
				if type(menu) == "table" and _G.F.safeTableGet(menu, "shop") == nil then
					pcall(function()
						menu.shop = result
					end)
				end

				return result
			end
		end
	end

	return nil
end

_G.F.tryOpenShopWithMethod = function(shopModule, method, shopId, displayName)
	local lastErr = nil
	local attempts = {
		function()
			return method(shopModule, shopId)
		end,
		function()
			return method(shopModule, shopId, displayName)
		end,
		function()
			return method(shopModule, { id = shopId, name = displayName })
		end,
		function()
			return method(shopModule, displayName)
		end,
		function()
			return method(shopId)
		end,
	}

	for _, attempt in ipairs(attempts) do
		local ok, result, extra = pcall(attempt)
		if ok and result ~= false then
			return true
		end

		if ok then
			lastErr = tostring(extra or result or "Shop opener returned false.")
		else
			lastErr = tostring(result)
		end
	end

	return false, lastErr
end

_G.F.openShop = function(shopId, displayName)
	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end

	if type(_G._p) ~= "table" then
		return false, "Hook is not ready."
	end

	local shopModule = _G.F.getShopModule()
	if not shopModule then
		return false, "Shop module is not loaded."
	end

	if type(shopModule) == "function" then
		local ok, result = pcall(function()
			return shopModule(shopId)
		end)

		if ok and result ~= false then
			return true
		end

		return false, ok and "Shop opener returned false." or tostring(result)
	end

	local lastErr = nil
	for _, methodName in ipairs({
		"open", "Open",
		"openShop", "OpenShop",
		"openShopMenu", "OpenShopMenu",
		"openMart", "OpenMart",
		"show", "Show",
	}) do
		local method = _G.F.safeTableGet(shopModule, methodName)
		if type(method) == "function" then
			local opened, reason = _G.F.tryOpenShopWithMethod(shopModule, method, shopId, displayName)
			if opened then
				return true
			end

			lastErr = reason
		end
	end

	return false, lastErr or "Shop module has no known opener."
end

_G.F.setAutoBoonaryStatus = function(text)
	local message = tostring(text or "")
	if message == "" then
		message = "Idle"
	end

	if _G.autoBoonaryStatusLabel and type(_G.autoBoonaryStatusLabel.Set) == "function" then
		pcall(function()
			_G.autoBoonaryStatusLabel:Set(message)
		end)
	end
end

_G.F.getCurrentTixCount = function()
	return tonumber(_G.F.getInformationValue({ "tix", "ticket", "tickets", "eventtickets", "eventTix" }))
end

_G.F.pdsPost = function(actionName, ...)
	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end

	local args = { ... }
	for _, remoteKey in ipairs({ "Network", "Connection" }) do
		local remote = type(_G._p) == "table" and _G._p[remoteKey] or nil
		if type(remote) == "table" and type(remote.post) == "function" then
			local ok, result = pcall(function()
				return remote:post("PDS", actionName, unpack(args))
			end)
			if ok and result ~= nil and result ~= false then
				return true, result
			end
		end
	end

	return false, "No acknowledged PDS post path found."
end

_G.F.tryBoonaryPdsAction = function(actionNames, argumentSets)
	local lastReason = nil

	for _, actionName in ipairs(actionNames) do
		for _, args in ipairs(argumentSets) do
			local ok, result = _G.F.rallyPdsGet(actionName, unpack(args))
			if ok and result ~= nil and result ~= false then
				return true, result, actionName
			end

			ok, result = _G.F.pdsPost(actionName, unpack(args))
			if ok then
				return true, result, actionName
			end

			lastReason = tostring(result or actionName)
			task.wait(0.05)
		end
	end

	return false, lastReason or "No candidate action succeeded."
end

-- Real boost API (confirmed working in the pity-boost variant of this script):
--   boostStatus -> { ["1"] = { remaining, paused }, ..., p = { activePity, ... } }
--   useBoost(boostId, count) consumes Ro-Power tokens and starts/extends the boost.
-- Boost id 1 = Gleaming, 2 = Roaming.
_G.GLEAMING_BOOST_ID = 1

_G.F.isBoostRunning = function(boostStatus, boostId)
	local entry = type(boostStatus) == "table" and (boostStatus[tostring(boostId)] or boostStatus[boostId]) or nil
	if type(entry) ~= "table" then
		return false
	end

	local remaining = tonumber(entry[1])
	if remaining == nil or remaining <= 0 then
		return false
	end

	return entry[2] ~= true
end

_G.F.activateGleamingRoPowers = function(count)
	count = math.max(1, math.floor(tonumber(count) or 2))

	local okStatus, boostStatus = _G.F.rallyPdsGet("boostStatus")
	if not okStatus or type(boostStatus) ~= "table" then
		return false, "Could not read boost status from the server."
	end

	local alreadyRunning = _G.F.isBoostRunning(boostStatus, _G.GLEAMING_BOOST_ID)

	local activated = 0
	for _ = 1, count do
		local okUse, tokenCount = _G.F.rallyPdsGet("useBoost", _G.GLEAMING_BOOST_ID, 1)
		if not okUse or not tokenCount then
			-- Out of tokens (or refused); stop here and judge by what's running.
			break
		end
		activated = activated + 1
		task.wait(0.25)
	end

	local okVerify, verifyStatus = _G.F.rallyPdsGet("boostStatus")
	local running = okVerify and _G.F.isBoostRunning(verifyStatus, _G.GLEAMING_BOOST_ID)

	if not running then
		if activated == 0 then
			return false, "Could not start the Gleaming boost (no Ro-Power tokens?)."
		end
		return false, "Used " .. activated .. " Ro-Power token(s) but the Gleaming boost is not running."
	end

	return true, string.format("Gleaming boost running (%d token(s) used%s).",
		activated, alreadyRunning and ", was already active" or "")
end

_G.F.purchaseMaxArcadeBoonarys = function()
	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end

	local itemId = _G.BOONARY_SHOP_ITEM_ID
	local ok, maxResult = _G.F.pdsGetAction("maxBuy", itemId)

	if not ok and maxResult == nil then
		local reqOk, reqValue = _G.F.rallyPdsReq("maxBuy", itemId)
		if reqOk then
			ok = true
			maxResult = reqValue
		end
	end

	if type(maxResult) == "string" then
		return false, _G.F.getBoonaryMaxBuyErrorMessage(maxResult)
	end

	if maxResult == true then
		_G.F.setAutoBoonaryStatus("Purchased Boonary(s).")
		return true, 1
	end

	local quantity = nil
	if type(maxResult) == "number" and maxResult > 0 then
		quantity = math.floor(maxResult)
	else
		quantity = _G.F.getBoonaryBuyQuantityFromTix(_G.F.getCurrentTixCount())
	end

	if not quantity or quantity <= 0 then
		return false, tostring(maxResult or "Could not determine Boonary purchase quantity.")
	end

	local buyOk, buyResult = _G.F.pdsGetAction("buyItem", itemId, quantity)
	if buyOk and buyResult then
		_G.F.setAutoBoonaryStatus("Purchased " .. tostring(quantity) .. " Boonary(s).")
		return true, quantity
	end

	if not buyOk then
		local reqOk, reqValue = _G.F.rallyPdsReq("buyItem", itemId, quantity)
		if reqOk and reqValue then
			_G.F.setAutoBoonaryStatus("Purchased " .. tostring(quantity) .. " Boonary(s).")
			return true, quantity
		end
	end

	return false, tostring(buyResult or maxResult or "buyItem failed.")
end

_G.F.getBoonaryMonsterName = function(monster)
	if type(monster) ~= "table" then
		return ""
	end

	local unwrapped = _G.F.unwrapPcSlotData(monster)
	if unwrapped and unwrapped.icon then
		local speciesId = _G.F.safeArrayGet(unwrapped.icon, 1)
		local speciesName = _G.F.getSpeciesNameFromId(speciesId)
		if speciesName then
			return speciesName
		end
		return "Loomian #" .. tostring(speciesId)
	end

	for _, containerKey in ipairs({ "summ", "summary", "modelData", "data" }) do
		local container = _G.F.safeTableGet(monster, containerKey)
		if type(container) == "table" then
			for _, key in ipairs({ "name", "species", "nickname", "id", "num", "dex", "monster", "loomian" }) do
				local value = _G.F.safeTableGet(container, key)
				if value ~= nil and tostring(value) ~= "" then
					return tostring(value)
				end
			end
		end
	end

	local sprite = _G.F.safeTableGet(monster, "sprite")
	local spriteModelData = type(sprite) == "table" and _G.F.safeTableGet(sprite, "modelData") or nil
	if type(spriteModelData) == "table" then
		for _, key in ipairs({ "name", "species", "id", "num", "dex" }) do
			local value = _G.F.safeTableGet(spriteModelData, key)
			if value ~= nil and tostring(value) ~= "" then
				return tostring(value)
			end
		end
	end

	for _, key in ipairs({ "name", "species", "nickname", "id", "num", "dex", "monster", "loomian" }) do
		local value = _G.F.safeTableGet(monster, key)
		if value ~= nil and tostring(value) ~= "" then
			return tostring(value)
		end
	end

	return ""
end

-- Reverse-lookup every species id whose dex name contains "boonary" and cache
-- the set, so per-slot Boonary checks are a numeric compare instead of a name
-- resolution. Cached only once found, so an early call before _p.Constants is
-- ready doesn't poison the cache.
_G.F.getBoonarySpeciesIdSet = function()
	if _G.F.boonarySpeciesIdSet then
		return _G.F.boonarySpeciesIdSet
	end

	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end

	local set = {}
	local constants = type(_G._p) == "table" and _G.F.safeTableGet(_G._p, "Constants") or nil
	if type(constants) == "table" then
		for _, key in ipairs({ "MONSTERS", "monsters", "Loomians", "loomians", "DEX", "dex" }) do
			local monsterTable = _G.F.safeTableGet(constants, key)
			if type(monsterTable) == "table" then
				pcall(function()
					for id, entry in pairs(monsterTable) do
						local name = type(entry) == "table" and (entry.name or entry.n or entry.species) or entry
						if type(name) == "string" and string.find(string.lower(name), "boonary", 1, true) then
							set[tonumber(id) or id] = true
						end
					end
				end)
				if next(set) then
					break
				end
			end
		end
	end

	if next(set) then
		_G.F.boonarySpeciesIdSet = set
	end
	return set
end

_G.F.isBoonaryMonster = function(monster)
	-- Priority check: species id from the compact icon array (real PC format),
	-- before falling back to name resolution for other data shapes.
	local unwrapped = _G.F.unwrapPcSlotData(monster)
	if unwrapped and unwrapped.icon then
		local speciesId = tonumber(_G.F.safeArrayGet(unwrapped.icon, 1))
		if speciesId then
			local idSet = _G.F.getBoonarySpeciesIdSet()
			if next(idSet) then
				return idSet[speciesId] == true
			end
		end
	end

	local name = string.lower(_G.F.getBoonaryMonsterName(monster))
	return string.find(name, "boonary", 1, true) ~= nil
end

_G.F.isStorageMonsterLike = function(value)
	if type(value) ~= "table" then
		return false
	end

	-- Real PC slots are positional arrays with no named keys:
	-- { labelIndex, { speciesId, sheetType, gleamTier, wispColor } } — or a bare
	-- icon array. Check the shape directly, same as unwrapPcSlotData.
	if _G.F.isMonsterIconArray(value) or _G.F.isMonsterIconArray(_G.F.safeArrayGet(value, 2)) then
		return true
	end

	for _, key in ipairs({ "summ", "summary", "name", "species", "nickname", "id", "num", "dex", "gl", "gleam", "gamma", "isGamma", "shiny", "wisp", "icon", "sa", "ivs", "evs", "moves", "personality" }) do
		if _G.F.safeTableGet(value, key) ~= nil then
			return true
		end
	end

	return false
end

_G.F.getMonsterDebugText = function(monster)
	if type(monster) ~= "table" then
		return ""
	end

	local parts = {}
	for _, key in ipairs({ "name", "species", "nickname", "id", "num", "dex", "gl", "gleam", "gamma", "isGamma", "sa", "personality" }) do
		local value = _G.F.safeTableGet(monster, key)
		if value ~= nil and type(value) ~= "table" and type(value) ~= "function" then
			table.insert(parts, tostring(key) .. "=" .. tostring(value))
		end
	end

	local summary = _G.F.safeTableGet(monster, "summ") or _G.F.safeTableGet(monster, "summary")
	if type(summary) == "table" then
		for _, key in ipairs({ "name", "species", "nickname", "id", "num", "dex", "gl", "gleam", "gamma" }) do
			local value = _G.F.safeTableGet(summary, key)
			if value ~= nil and type(value) ~= "table" and type(value) ~= "function" then
				table.insert(parts, "summ." .. tostring(key) .. "=" .. tostring(value))
			end
		end
	end

	local modelData = _G.F.safeTableGet(monster, "modelData")
	if type(modelData) == "table" then
		for _, key in ipairs({ "name", "species", "id", "num", "dex", "gleam", "gamma" }) do
			local value = _G.F.safeTableGet(modelData, key)
			if value ~= nil and type(value) ~= "table" and type(value) ~= "function" then
				table.insert(parts, "modelData." .. tostring(key) .. "=" .. tostring(value))
			end
		end
	end

	return table.concat(parts, " ")
end

_G.F.isKeepBoonary = function(monster)
	return _G.isActiveFlag(_G.F.getMonsterGleamValue(monster)) or _G.isActiveFlag(_G.F.getMonsterGammaValue(monster))
end

_G.F.formatBoonaryTableKeys = function(value, limit)
	if type(value) ~= "table" then
		return ""
	end

	local keys = {}
	limit = tonumber(limit) or 12

	local ok = pcall(function()
		for key in pairs(value) do
			table.insert(keys, tostring(key))
			if #keys >= limit then
				break
			end
		end
	end)

	if not ok or #keys == 0 then
		return ""
	end

	return table.concat(keys, ", ")
end

_G.F.addBoonaryStorageCandidate = function(candidates, seen, source, value)
	if type(value) ~= "table" or seen[value] then
		return
	end

	seen[value] = true
	table.insert(candidates, {
		source = tostring(source),
		data = value,
		keys = _G.F.formatBoonaryTableKeys(value, 10),
	})
end

_G.F.getLocalBoonaryStorageCandidates = function()
	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end

	local candidates = {}
	local seen = {}
	local roots = {}
	local scanned = 0
	local maxNodes = math.max(100, tonumber(_G.autoBoonaryScanNodeLimit) or 5000)

	local function addRoot(source, value)
		if type(value) == "table" then
			table.insert(roots, { source = tostring(source), data = value })
		end
	end

	addRoot("_p", _G._p)

	if type(_G._p) == "table" then
		for _, key in ipairs({ "PC", "pc", "Storage", "storage", "Boxes", "boxes", "Box", "box", "PlayerData", "playerData", "Data", "data", "SaveData", "saveData", "Menu", "DataManager" }) do
			addRoot("_p." .. key, _G.F.safeTableGet(_G._p, key))
		end

		local dataManager = _G.F.safeTableGet(_G._p, "DataManager")
		if type(dataManager) == "table" then
			for _, key in ipairs({ "currentSave", "currentData", "playerData", "data", "saveData" }) do
				addRoot("DataManager." .. key, _G.F.safeTableGet(dataManager, key))
			end

			local loadModule = _G.F.safeTableGet(dataManager, "loadModule")
			if type(loadModule) == "function" then
				for _, moduleName in ipairs({ "PC", "Pc", "Storage", "PCStorage", "MonsterStorage", "Boxes", "Box" }) do
					local ok, module = pcall(function()
						return dataManager:loadModule(moduleName)
					end)
					if ok then
						addRoot("DataManager:loadModule(" .. moduleName .. ")", module)
					end
				end
			end
		end
	end

	local interestingKeys = {
		pc = true,
		pcs = true,
		box = true,
		boxes = true,
		storage = true,
		monsterstorage = true,
		monsters = true,
		mons = true,
	}

	local function scan(source, value, depth)
		if type(value) ~= "table" or depth > 4 or scanned >= maxNodes then
			return
		end

		scanned = scanned + 1

		local ok = pcall(function()
			for key, child in pairs(value) do
				if scanned >= maxNodes then
					break
				end
				if type(child) == "table" then
					local normalized = _G.F.normalizeInfoKey(key)
					if interestingKeys[normalized] or string.find(normalized, "storage", 1, true) or string.find(normalized, "box", 1, true) or string.find(normalized, "pc", 1, true) then
						_G.F.addBoonaryStorageCandidate(candidates, seen, source .. "." .. tostring(key), child)
					end

					if depth < 4 then
						scan(source .. "." .. tostring(key), child, depth + 1)
					end
				end
			end
		end)

		if not ok then
			return
		end
	end

	for _, root in ipairs(roots) do
		_G.F.addBoonaryStorageCandidate(candidates, seen, root.source, root.data)
		scan(root.source, root.data, 0)
	end

	return candidates
end

_G.F.getFastBoonaryPreviewCandidates = function()
	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end

	local candidates = {}
	local seen = {}
	local function add(source, value)
		_G.F.addBoonaryStorageCandidate(candidates, seen, source, value)
	end

	add("_p", _G._p)

	if type(_G._p) == "table" then
		for _, key in ipairs({ "PC", "pc", "Storage", "storage", "Boxes", "boxes", "PlayerData", "playerData", "Data", "data", "SaveData", "saveData" }) do
			add("_p." .. key, _G.F.safeTableGet(_G._p, key))
		end

		local dataManager = _G.F.safeTableGet(_G._p, "DataManager")
		add("_p.DataManager", dataManager)

		if type(dataManager) == "table" then
			for _, key in ipairs({ "currentSave", "currentData", "playerData", "data", "saveData" }) do
				add("DataManager." .. key, _G.F.safeTableGet(dataManager, key))
			end
		end

		local menu = _G.F.safeTableGet(_G._p, "Menu")
		add("_p.Menu", menu)
		if type(menu) == "table" then
			for _, key in ipairs({ "pc", "PC", "storage", "Storage", "boxes", "Boxes" }) do
				add("_p.Menu." .. key, _G.F.safeTableGet(menu, key))
			end
		end
	end

	return candidates
end

_G.F.getStorageGroupCandidates = function(groupNumber)
	groupNumber = math.max(1, math.floor(tonumber(groupNumber) or 49))
	local actions = {
		"getPCGroup",
		"getStorageGroup",
		"getBox",
		"getPCBox",
		"getPCData",
		"getStorage",
		"getMonsters",
	}

	local argumentSets = {
		{ groupNumber },
		{ tostring(groupNumber) },
		{ "pc", groupNumber },
		{},
	}

	for _, actionName in ipairs(actions) do
		for _, args in ipairs(argumentSets) do
			local ok, result = _G.F.rallyPdsGet(actionName, unpack(args))
			if ok and type(result) == "table" then
				return result, actionName
			end
			task.wait(0.03)
		end
	end

	local localCandidates = _G.F.getLocalBoonaryStorageCandidates()
	local bestCandidate = nil
	local bestBoonaryCount = 0
	local bestEntryCount = 0

	for _, candidate in ipairs(localCandidates) do
		local allEntries = _G.F.collectStorageGroupEntries(candidate.data, groupNumber)
		local entries = {}
		for _, entry in ipairs(allEntries) do
			if _G.F.isBoonaryMonster(entry.monster) then
				table.insert(entries, entry)
			end
		end

		if #entries > bestBoonaryCount or (#entries == bestBoonaryCount and #allEntries > bestEntryCount) then
			bestCandidate = candidate
			bestBoonaryCount = #entries
			bestEntryCount = #allEntries
		end
	end

	if bestCandidate and bestBoonaryCount > 0 then
		return bestCandidate.data, bestCandidate.source
	end

	if #localCandidates > 0 then
		return {
			__boonaryCandidateList = true,
			candidates = localCandidates,
		}, "local candidates"
	end

	return nil, "No PC storage action succeeded and no local storage candidates were loaded."
end

_G.F.collectStorageGroupEntries = function(data, groupNumber, nodeLimit)
	local entries = {}
	local visited = {}
	local scanned = 0
	local maxNodes = math.max(50, tonumber(nodeLimit) or tonumber(_G.autoBoonaryScanNodeLimit) or 5000)
	groupNumber = math.max(1, math.floor(tonumber(groupNumber) or 49))

	local function add(monster, slot, group)
		if type(monster) ~= "table" or visited[monster] then
			return
		end
		visited[monster] = true
		table.insert(entries, {
			monster = monster,
			slot = slot,
			group = tonumber(group) or groupNumber,
		})
	end

	local function scan(value, depth, currentGroup)
		if type(value) ~= "table" or depth > 6 or scanned >= maxNodes then
			return
		end

		scanned = scanned + 1

		local groupValue = tonumber(_G.F.safeTableGet(value, "group") or _G.F.safeTableGet(value, "box") or currentGroup)
		if groupValue == nil then
			groupValue = currentGroup
		end

		if _G.F.isStorageMonsterLike(value) and (groupValue == nil or tonumber(groupValue) == groupNumber) then
			add(value, _G.F.safeTableGet(value, "slot") or _G.F.safeTableGet(value, "index"), groupValue)
			return
		end

		local directMonsters = _G.F.safeTableGet(value, "monsters") or _G.F.safeTableGet(value, "Mons") or _G.F.safeTableGet(value, "party") or _G.F.safeTableGet(value, "box")
		if type(directMonsters) == "table" then
			for slot, monster in pairs(directMonsters) do
				if type(monster) == "table" and _G.F.isStorageMonsterLike(monster) and (groupValue == nil or tonumber(groupValue) == groupNumber) then
					add(monster, slot, groupValue)
				end
			end
		end

		for key, child in pairs(value) do
			if scanned >= maxNodes then
				break
			end
			local childGroup = groupValue
			local numericKey = tonumber(key)
			if numericKey == groupNumber and type(child) == "table" then
				childGroup = groupNumber
			end
			scan(child, depth + 1, childGroup)
		end
	end

	scan(data, 0, nil)
	return entries
end

_G.F.collectStorageGroupMonsters = function(data, groupNumber)
	local entries = {}

	for _, entry in ipairs(_G.F.collectStorageGroupEntries(data, groupNumber)) do
		if _G.F.isBoonaryMonster(entry.monster) then
			table.insert(entries, entry)
		end
	end

	return entries
end

_G.F.releaseStoredBoonary = function(entry)
	if type(entry) ~= "table" or type(entry.monster) ~= "table" then
		return false, "Invalid storage entry."
	end

	local monster = entry.monster
	local identifiers = {}
	for _, key in ipairs({ "id", "uid", "uuid", "pcid", "pcId", "personality", "ident" }) do
		local value = _G.F.safeTableGet(monster, key)
		if value ~= nil then
			table.insert(identifiers, value)
		end
	end

	local actions = {
		"releaseStoredMonster",
		"releaseFromStorage",
		"releaseFromPC",
		"releaseMonster",
		"deleteStoredMonster",
	}

	local argumentSets = {}
	if entry.group ~= nil and entry.slot ~= nil then
		table.insert(argumentSets, { entry.group, entry.slot })
		if tonumber(entry.group) and tonumber(entry.slot) then
			table.insert(argumentSets, { tonumber(entry.group), tonumber(entry.slot) })
		end
		table.insert(argumentSets, { { group = entry.group, slot = entry.slot } })
	end

	for _, identifier in ipairs(identifiers) do
		table.insert(argumentSets, { identifier })
		table.insert(argumentSets, { entry.group, identifier })
	end

	if #argumentSets == 0 then
		return false, "No safe release identifier for " .. _G.F.getBoonaryMonsterName(monster) .. "."
	end

	return _G.F.tryBoonaryPdsAction(actions, argumentSets)
end

_G.F.cleanBoonaryStorageGroup = function(groupNumber)
	local data, source = _G.F.getStorageGroupCandidates(groupNumber)
	if type(data) ~= "table" then
		return false, tostring(source)
	end
	if data.__boonaryCandidateList then
		return false, "No Boonarys found in loaded local storage candidates."
	end

	local entries = _G.F.collectStorageGroupMonsters(data, groupNumber)
	local kept = 0
	local released = 0
	local failed = 0

	for _, entry in ipairs(entries) do
		if _G.F.isKeepBoonary(entry.monster) then
			kept = kept + 1
		else
			local ok = _G.F.releaseStoredBoonary(entry)
			if ok then
				released = released + 1
			else
				failed = failed + 1
			end
			task.wait(0.2)
		end
	end

	return true, string.format("Group %d via %s: kept %d, released %d, failed %d.", tonumber(groupNumber) or 49, tostring(source), kept, released, failed)
end

-- ============================================================================
-- Direct PC session path (matches the game's real protocol):
--   Session = Network:get("PDS", "openPC")   -> { id, boxes, party, maxBoxes, ... }
--   boxes[boxKey][slotKey] = { labelIndex, { speciesId, sheetType, gleamTier, wispColor } }
--   release: ch.m[tostring(labelIndex)] = { -1, rcount }; boxes[box][slot] = nil
--   commit:  Network:get("PDS", "closePC", Session.id, Session.ch)
-- ============================================================================

_G.F.getPcSession = function()
	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end
	if type(_G._p) ~= "table" then
		return nil, "Game framework (_p) not found."
	end

	-- Prefer the live session if the PC UI is open; the game commits its own
	-- ch journal when the player closes the PC, so we must write into it.
	local pcModule = _G.F.safeTableGet(_G._p, "PC")
	local live = type(pcModule) == "table" and _G.F.safeTableGet(pcModule, "pcData") or nil
	if type(live) == "table" and type(_G.F.safeTableGet(live, "boxes")) == "table" then
		return live, true
	end

	local network = _G.F.safeTableGet(_G._p, "Network")
	if type(network) ~= "table" or type(network.get) ~= "function" then
		return nil, "Network module not found."
	end

	local ok, session = pcall(function()
		return network:get("PDS", "openPC")
	end)
	if not ok or type(session) ~= "table" or type(_G.F.safeTableGet(session, "boxes")) ~= "table" then
		return nil, "openPC failed (server refused or returned no boxes)."
	end

	session.ch = { m = {} }
	session.rcount = 0
	return session, false
end

_G.F.journalPcRelease = function(session, labelIndex, boxKey, slotKey)
	if type(session.ch) ~= "table" then
		session.ch = { m = {} }
	end
	if type(session.ch.m) ~= "table" then
		session.ch.m = {}
	end

	session.rcount = (tonumber(session.rcount) or 0) + 1
	session.ch.m[tostring(labelIndex)] = { -1, session.rcount }

	local box = session.boxes[boxKey]
	if type(box) == "table" then
		box[slotKey] = nil
	end
end

_G.F.closePcSession = function(session)
	local network = _G.F.safeTableGet(_G._p, "Network")
	if type(network) ~= "table" or type(network.get) ~= "function" then
		return false, "Network module not found."
	end

	local ok, result = pcall(function()
		return network:get("PDS", "closePC", session.id, session.ch)
	end)
	if not ok or not result then
		return false, "closePC failed; releases were NOT committed."
	end
	return true, result
end

-- Diagnostic lines go to the console AND a buffer that dry runs flush to
-- BOONARY-DIAG.txt in the config folder, so failures are inspectable even
-- without console access.
_G.F.boonaryDiagPrint = function(line)
	line = tostring(line)
	print(line)
	if type(_G.boonaryDiagLines) == "table" then
		table.insert(_G.boonaryDiagLines, line)
	end
end

-- Dump what the PC session actually contains so detection failures are
-- debuggable from the console instead of guessing at data shapes.
_G.F.printBoonaryPcDiagnostics = function(session, isLiveSession)
	local print = _G.F.boonaryDiagPrint
	local function describeValue(value, depth)
		if type(value) ~= "table" then
			return type(value) .. ":" .. tostring(value)
		end
		if depth <= 0 then
			return "table{...}"
		end
		local parts = {}
		local count = 0
		local ok = pcall(function()
			for key, child in pairs(value) do
				count = count + 1
				if count > 8 then
					table.insert(parts, "...")
					break
				end
				table.insert(parts, tostring(key) .. "=" .. describeValue(child, depth - 1))
			end
		end)
		if not ok then
			return "table{unreadable}"
		end
		return "{" .. table.concat(parts, ", ") .. "}"
	end

	print("[Boonary Diag] session source: " .. (isLiveSession and "live PC UI (pcData)" or "openPC network call"))
	print("[Boonary Diag] session keys: " .. describeValue(session, 1))

	local idSet = _G.F.getBoonarySpeciesIdSet()
	local idList = {}
	for id in pairs(idSet) do
		table.insert(idList, tostring(id))
	end
	print("[Boonary Diag] boonary species ids from Constants: " .. (#idList > 0 and table.concat(idList, ", ") or "NONE FOUND (name fallback will be used)"))

	local boxCount = 0
	local slotsPrinted = 0
	for boxKey, box in pairs(session.boxes) do
		boxCount = boxCount + 1
		if type(box) == "table" then
			local slotCount = 0
			pcall(function()
				for _ in pairs(box) do
					slotCount = slotCount + 1
				end
			end)
			if boxCount <= 6 or slotCount > 0 then
				print(string.format("[Boonary Diag] box key=%s (%s) slots=%d", tostring(boxKey), type(boxKey), slotCount))
			end
			for slotKey, slot in pairs(box) do
				if slotsPrinted >= 8 then
					break
				end
				slotsPrinted = slotsPrinted + 1
				local unwrapped = _G.F.unwrapPcSlotData(slot)
				local icon = unwrapped and unwrapped.icon or nil
				local speciesId = icon and _G.F.safeArrayGet(icon, 1) or nil
				local name = _G.F.getBoonaryMonsterName(slot)
				print(string.format("[Boonary Diag]   slot key=%s (%s) raw=%s | icon=%s species=%s name=%s isBoonary=%s",
					tostring(slotKey), type(slotKey), describeValue(slot, 2),
					icon and describeValue(icon, 1) or "nil",
					tostring(speciesId), tostring(name), tostring(_G.F.isBoonaryMonster(slot))))
			end
		else
			print(string.format("[Boonary Diag] box key=%s is a %s, not a table", tostring(boxKey), type(box)))
		end
	end
	print(string.format("[Boonary Diag] total boxes iterated: %d, sample slots printed: %d", boxCount, slotsPrinted))
	if boxCount == 0 then
		print("[Boonary Diag] session.boxes is EMPTY - the server returned no box data on this path.")
	end

	-- Species histogram across every box: the dominant id in the Boonary dump
	-- box identifies the species numerically even with no name table.
	local histogram = {}
	local boxTallies = {}
	for boxKey, box in pairs(session.boxes) do
		if type(box) == "table" then
			for _, slot in pairs(box) do
				local unwrapped = _G.F.unwrapPcSlotData(slot)
				local speciesId = unwrapped and unwrapped.icon and _G.F.safeArrayGet(unwrapped.icon, 1) or nil
				if speciesId ~= nil then
					local key = tostring(speciesId)
					local entry = histogram[key]
					if not entry then
						entry = { count = 0, gleam = 0, boxes = {} }
						histogram[key] = entry
					end
					entry.count = entry.count + 1
					entry.boxes[tostring(boxKey)] = (entry.boxes[tostring(boxKey)] or 0) + 1
					local tier = _G.F.normalizeGleamTier(_G.F.safeArrayGet(unwrapped.icon, 3))
					if tier and tier >= 1 then
						entry.gleam = entry.gleam + 1
					end
				end
			end
		end
	end

	local sorted = {}
	for speciesKey, entry in pairs(histogram) do
		table.insert(sorted, { species = speciesKey, entry = entry })
	end
	table.sort(sorted, function(a, b)
		return a.entry.count > b.entry.count
	end)

	print("[Boonary Diag] species histogram (top 15):")
	for index = 1, math.min(#sorted, 15) do
		local item = sorted[index]
		local boxParts = {}
		for boxKey, count in pairs(item.entry.boxes) do
			table.insert(boxParts, boxKey .. "x" .. count)
		end
		print(string.format("[Boonary Diag]   species=%s count=%d gleam/gamma=%d boxes: %s",
			item.species, item.entry.count, item.entry.gleam, table.concat(boxParts, ", ")))
	end

	-- Ask the server what a few of these actually are; getSummary is what the
	-- real PC UI uses for the stats screen, so it should carry the name.
	local network = _G.F.safeTableGet(_G._p, "Network")
	if type(network) == "table" and type(network.get) == "function" then
		local sampledSpecies = {}
		local sampled = 0
		for _, item in ipairs(sorted) do
			if sampled >= 5 then
				break
			end
			for boxKey, box in pairs(session.boxes) do
				if sampled >= 5 or sampledSpecies[item.species] then
					break
				end
				if type(box) == "table" then
					for _, slot in pairs(box) do
						local unwrapped = _G.F.unwrapPcSlotData(slot)
						local speciesId = unwrapped and unwrapped.icon and _G.F.safeArrayGet(unwrapped.icon, 1) or nil
						if speciesId ~= nil and tostring(speciesId) == item.species then
							local labelIndex = _G.F.safeArrayGet(slot, 1)
							if labelIndex ~= nil then
								sampledSpecies[item.species] = true
								sampled = sampled + 1
								local ok, summary = pcall(function()
									return network:get("PDS", "cPC", "getSummary", labelIndex)
								end)
								print(string.format("[Boonary Diag] getSummary species=%s label=%s -> %s",
									item.species, tostring(labelIndex),
									ok and describeValue(summary, 3) or ("ERROR: " .. tostring(summary))))
								task.wait(0.1)
							end
							break
						end
					end
				end
			end
		end
	else
		print("[Boonary Diag] Network module unavailable; skipped getSummary sampling.")
	end
end

_G.F.tableContainsString = function(value, needle, depth)
	if type(value) == "string" then
		return string.find(string.lower(value), needle, 1, true) ~= nil
	end
	if type(value) ~= "table" or depth <= 0 then
		return false
	end
	local found = false
	pcall(function()
		for _, child in pairs(value) do
			if _G.F.tableContainsString(child, needle, depth - 1) then
				found = true
				break
			end
		end
	end)
	return found
end

_G.F.tableContainsBoonaryString = function(value, depth)
	return _G.F.tableContainsString(value, "boonary", depth)
end

-- The client has no species-name table (names are server-side), so learn
-- which species ids are Boonarys by asking the server for one summary per
-- unique species in the PC and checking it for the string "boonary".
-- The learned set is cached for the rest of the session.
_G.F.learnBoonarySpeciesIds = function(session)
	if _G.F.boonarySpeciesIdSet and next(_G.F.boonarySpeciesIdSet) then
		return _G.F.boonarySpeciesIdSet
	end

	local set = _G.F.getBoonarySpeciesIdSet()
	if next(set) then
		return set
	end

	local network = _G.F.safeTableGet(_G._p, "Network")
	if type(network) ~= "table" or type(network.get) ~= "function" then
		return set
	end

	set = {}
	local keepSet = {}
	local checkedSpecies = {}
	for _, box in pairs(session.boxes) do
		if type(box) == "table" then
			for _, slot in pairs(box) do
				local unwrapped = _G.F.unwrapPcSlotData(slot)
				local speciesId = unwrapped and unwrapped.icon and tonumber(_G.F.safeArrayGet(unwrapped.icon, 1)) or nil
				local sheetType = unwrapped and unwrapped.icon and _G.F.safeArrayGet(unwrapped.icon, 2) or nil
				local labelIndex = _G.F.safeArrayGet(slot, 1)
				if speciesId and labelIndex ~= nil and not checkedSpecies[speciesId] then
					checkedSpecies[speciesId] = true
					local ok, summary = pcall(function()
						return network:get("PDS", "cPC", "getSummary", labelIndex)
					end)
					if ok and _G.F.tableContainsBoonaryString(summary, 4) then
						set[speciesId] = true
						-- sheetType 8 = direct asset-id icon: the gleam/gamma
						-- variant is baked into the asset id itself, with no
						-- per-individual tier in icon[3]. If the summary says
						-- gleam/gamma, every slot with this id is that variant.
						if sheetType == 8 and (_G.F.tableContainsString(summary, "gleam", 4) or _G.F.tableContainsString(summary, "gamma", 4)) then
							keepSet[speciesId] = true
						end
					end
					task.wait(0.05)
				end
			end
		end
	end

	if next(set) then
		_G.F.boonarySpeciesIdSet = set
		_G.F.boonaryKeepSpeciesIdSet = keepSet
	end
	return set
end

-- Sweep every PC box. Per-slot priority: (1) is it a Boonary? (species-id
-- check) -> if not, never touched; (2) is it Gleam/Gamma (or any special
-- gleam tier)? -> skip/keep; (3) otherwise journal a release. dryRun prints
-- what would happen without journaling or committing anything.
_G.F.cleanBoonaryPcBoxes = function(dryRun)
	local session, liveOrReason = _G.F.getPcSession()
	if not session then
		return false, tostring(liveOrReason)
	end
	local isLiveSession = liveOrReason == true

	local print = print
	if dryRun then
		_G.boonaryDiagLines = {}
		print = _G.F.boonaryDiagPrint
		pcall(function()
			_G.F.printBoonaryPcDiagnostics(session, isLiveSession)
		end)
	end

	_G.F.setAutoBoonaryStatus("Identifying Boonary species from server summaries...")
	local learnedIds = {}
	pcall(function()
		learnedIds = _G.F.learnBoonarySpeciesIds(session)
	end)
	if dryRun then
		local idParts = {}
		for id in pairs(learnedIds) do
			table.insert(idParts, tostring(id))
		end
		print("[Boonary Diag] learned boonary species ids: " .. (#idParts > 0 and table.concat(idParts, ", ") or "NONE - every isBoonary check will fail!"))
		local keepParts = {}
		for id in pairs(_G.F.boonaryKeepSpeciesIdSet or {}) do
			table.insert(keepParts, tostring(id))
		end
		if #keepParts > 0 then
			print("[Boonary Diag] asset-id variants kept wholesale (gleam/gamma baked into icon): " .. table.concat(keepParts, ", "))
		end
	end

	-- Hard guarantee: without a positively identified Boonary species id set
	-- (learned from server summaries), refuse to release anything at all.
	-- No name heuristics, no fallbacks.
	if not next(learnedIds) then
		if not isLiveSession then
			_G.F.closePcSession(session)
		end
		local reason = "Could not positively identify the Boonary species from server summaries; refusing to release anything."
		_G.F.setAutoBoonaryStatus(reason)
		return false, reason
	end

	local keepSpeciesIds = _G.F.boonaryKeepSpeciesIdSet or {}
	local boonarySeen = 0
	local kept = 0
	local released = 0
	local skippedNoId = 0

	for boxKey, box in pairs(session.boxes) do
		if type(box) == "table" then
			for slotKey, slot in pairs(box) do
				local unwrapped = _G.F.unwrapPcSlotData(slot)
				-- Exclusive targeting: the slot's species id must be in the
				-- learned Boonary set. Anything else is never touched.
				local slotSpeciesId = unwrapped and unwrapped.icon and tonumber(_G.F.safeArrayGet(unwrapped.icon, 1)) or nil
				if slotSpeciesId ~= nil and learnedIds[slotSpeciesId] == true then
					boonarySeen = boonarySeen + 1

					local tier = _G.F.normalizeGleamTier(_G.F.safeArrayGet(unwrapped.icon, 3))
					local keepByAssetVariant = slotSpeciesId ~= nil and keepSpeciesIds[slotSpeciesId] == true
					if (tier and tier >= 1) or keepByAssetVariant then
						kept = kept + 1
						if dryRun then
							print(string.format("[Boonary PC] box=%s slot=%s tier=%s -> KEEP (%s)",
								tostring(boxKey), tostring(slotKey), tostring(tier),
								keepByAssetVariant and "asset-id variant" or tier == 1 and "Gleaming" or tier == 2 and "Gamma" or "Special"))
						end
					else
						local labelIndex = _G.F.safeArrayGet(slot, 1)
						if labelIndex == nil then
							skippedNoId = skippedNoId + 1
						elseif dryRun then
							released = released + 1
							print(string.format("[Boonary PC] box=%s slot=%s label=%s -> WOULD RELEASE",
								tostring(boxKey), tostring(slotKey), tostring(labelIndex)))
						else
							_G.F.journalPcRelease(session, labelIndex, boxKey, slotKey)
							released = released + 1
						end
					end
				end
			end
		end
	end

	local commitNote = ""
	if not dryRun and released > 0 and isLiveSession then
		commitNote = " (commits when you close the PC)"
	elseif not isLiveSession then
		-- Always close a session we opened ourselves - including dry runs
		-- (empty journal = no changes) - so no PC session is left dangling.
		local ok, reason = _G.F.closePcSession(session)
		if not dryRun and released > 0 then
			if not ok then
				return false, string.format("Saw %d Boonarys, kept %d, but %s", boonarySeen, kept, tostring(reason))
			end
			commitNote = " (committed)"
		end
	end

	local summary = string.format("%sBoonarys: %d seen, %d kept (Gleam/Gamma), %d %s%s%s.",
		dryRun and "[DRY RUN] " or "",
		boonarySeen, kept, released,
		dryRun and "would release" or "released",
		skippedNoId > 0 and (", " .. skippedNoId .. " skipped (no id)") or "",
		commitNote)

	if dryRun and type(_G.boonaryDiagLines) == "table" and writefile then
		pcall(function()
			table.insert(_G.boonaryDiagLines, summary)
			writefile(_G.F.getConfigFilePath("BOONARY-DIAG.txt"), table.concat(_G.boonaryDiagLines, "\n"))
		end)
	end

	_G.F.setAutoBoonaryStatus(summary)
	return true, summary
end

_G.F.printBoonaryStoragePreview = function(groupNumber)
	groupNumber = math.max(1, math.floor(tonumber(groupNumber) or 49))
	print("[Auto Boonary Preview] Starting scan for PC group " .. tostring(groupNumber) .. "...")
	_G.F.setAutoBoonaryStatus("Preview scanning group " .. tostring(groupNumber) .. "...")

	local candidates = _G.F.getFastBoonaryPreviewCandidates()
	print("[Auto Boonary Preview] Fast candidates found: " .. tostring(#candidates))

	if #candidates == 0 then
		local reason = "No fast local storage candidates found."
		print("[Auto Boonary Preview] " .. reason)
		_G.F.setAutoBoonaryStatus(reason)
		return false, reason
	end

	local maxCandidates = math.min(#candidates, 18)
	local bestSource = nil
	local bestEntries = {}
	local bestBoonaries = {}

	for candidateIndex = 1, maxCandidates do
		local candidate = candidates[candidateIndex]
		print(string.format(
			"[Auto Boonary Preview] scanning candidate #%d/%d source=%s keys={%s}",
			candidateIndex,
			maxCandidates,
			tostring(candidate.source),
			tostring(candidate.keys)
		))
		task.wait()

		local allEntries = _G.F.collectStorageGroupEntries(candidate.data, groupNumber, 120)
		local boonaries = {}
		for _, entry in ipairs(allEntries) do
			if _G.F.isBoonaryMonster(entry.monster) then
				table.insert(boonaries, entry)
			end
		end

		print(string.format(
			"[Auto Boonary Preview] candidate #%d entries=%d boonarys=%d",
			candidateIndex,
			#allEntries,
			#boonaries
		))

		if #boonaries > #bestBoonaries or (#boonaries == #bestBoonaries and #allEntries > #bestEntries) then
			bestSource = candidate.source
			bestEntries = allEntries
			bestBoonaries = boonaries
		end

		task.wait()
	end

	local allEntries = bestEntries
	local entries = bestBoonaries
	local kept = 0
	local wouldDelete = 0

	print("[Auto Boonary Preview] Best source=" .. tostring(bestSource) .. " | Group=" .. tostring(groupNumber) .. " | entries seen=" .. tostring(#allEntries) .. " | Boonarys seen=" .. tostring(#entries))

	for index, entry in ipairs(allEntries) do
		local monster = entry.monster
		local name = _G.F.getBoonaryMonsterName(monster)
		local gleamValue = _G.F.getMonsterGleamValue(monster)
		local gammaValue = _G.F.getMonsterGammaValue(monster)
		local isBoonary = _G.F.isBoonaryMonster(monster)
		local keep = isBoonary and _G.F.isKeepBoonary(monster)
		local action = "OTHER"

		if isBoonary then
			if keep then
				kept = kept + 1
				action = "KEEP"
			else
				wouldDelete = wouldDelete + 1
				action = "WOULD DELETE"
			end
		end

		print(string.format(
			"[Auto Boonary Preview] #%d group=%s slot=%s name=%s gleam=%s gamma=%s action=%s keys={%s} fields={%s}",
			index,
			tostring(entry.group),
			tostring(entry.slot),
			tostring(name),
			tostring(gleamValue),
			tostring(gammaValue),
			action,
			_G.F.formatBoonaryTableKeys(monster, 12),
			_G.F.getMonsterDebugText(monster)
		))
	end

	local summary = string.format("Group %d: saw %d, would keep %d, would delete %d.", groupNumber, #entries, kept, wouldDelete)
	print("[Auto Boonary Preview] " .. summary)
	_G.F.setAutoBoonaryStatus(summary)
	return true, summary
end

_G.F.runAutoBoonaryCycle = function()
	if _G.autoBoonaryBusy then
		return false, "Already running."
	end

	_G.autoBoonaryBusy = true
	_G.F.setAutoBoonaryStatus("Activating Gleaming Ro-Powers...")

	local ok, result = _G.F.activateGleamingRoPowers(2)
	if not ok then
		_G.autoBoonaryBusy = false
		_G.F.setAutoBoonaryStatus(result)
		return false, result
	end

	_G.F.setAutoBoonaryStatus("Buying Boonarys from Arcade Prizes...")
	ok, result = _G.F.purchaseMaxArcadeBoonarys()
	if not ok then
		_G.autoBoonaryBusy = false
		_G.F.setAutoBoonaryStatus(result)
		return false, result
	end

	-- No legacy fallback here: cleanBoonaryPcBoxes is the only release path,
	-- and it refuses to act without positive Boonary identification.
	_G.F.setAutoBoonaryStatus("Sweeping PC boxes for Boonarys...")
	ok, result = _G.F.cleanBoonaryPcBoxes(false)

	_G.autoBoonaryBusy = false
	_G.F.setAutoBoonaryStatus(ok and result or tostring(result))
	return ok, result
end

_G.F.setAutoBoonaryEnabled = function(value)
	_G.autoBoonaryEnabled = value and true or false
	if not _G.autoBoonaryEnabled then
		_G.autoBoonaryTriggered = false
		_G.F.setAutoBoonaryStatus("Idle")
	end
end

_G.F.getRanchStatus = function()
	local ok, status = _G.F.rallyPdsGet("ranchStatus")
	if ok and type(status) == "table" then
		return status
	end
	return nil
end

_G.F.getWaitingCount = function()
	local status = _G.F.getRanchStatus()
	if status then
		local count = tonumber(status.rallied)
		if count then
			return count
		end
	end

	local rally = _G.F.ensureRallyModule()
	if rally then
		return tonumber(rally.ralliedCount)
	end

	return nil
end

_G.F.rallyHandleRallied = function(marks)
	local loadingToken = {}

	pcall(function()
		if type(_G._p.DataManager) == "table" and type(_G._p.DataManager.setLoading) == "function" then
			_G._p.DataManager:setLoading(loadingToken, true)
		end
	end)

	local ok, newCount = _G.F.rallyPdsGet("handleRallied", marks)

	pcall(function()
		if type(_G._p.DataManager) == "table" and type(_G._p.DataManager.setLoading) == "function" then
			_G._p.DataManager:setLoading(loadingToken, false)
		end
	end)

	return ok, newCount
end

_G.F.getRalliedMonsterName = function(monster, index)
	local summary = type(monster) == "table" and _G.F.safeTableGet(monster, "summ") or nil
	if type(summary) == "table" then
		local nickname = _G.F.safeTableGet(summary, "nickname")
		if type(nickname) == "string" and nickname ~= "" then
			return nickname
		end
		local name = _G.F.safeTableGet(summary, "name")
		if type(name) == "string" and name ~= "" then
			return name
		end
	end
	return "Loomian #" .. tostring(index)
end

-- Game Rally UI checks monster.gl == 1 for the gleam icon.
_G.F.isGleaming = function(monster)
	return type(monster) == "table" and monster.gl == 1
end

-- Game Rally UI shows a separate icon when monster.sa is set.
_G.F.isSecretAbility = function(monster)
	if type(monster) ~= "table" then
		return false
	end
	local sa = _G.F.safeTableGet(monster, "sa")
	return sa ~= nil and sa ~= false and sa ~= 0
end

_G.F.isWisp = function(monster)
	if type(monster) ~= "table" then
		return false
	end
	local summary = _G.F.safeTableGet(monster, "summ")
	if type(summary) == "table" and _G.F.truthy(_G.F.safeTableGet(summary, "wisp")) then
		return true
	end
	return _G.F.truthy(_G.F.safeTableGet(monster, "wisp"))
end

_G.F.isAlwaysKeepMatch = function(monster, index)
	if #_G.alwaysKeepList == 0 then
		return false
	end

	local name = string.lower(_G.F.getRalliedMonsterName(monster, index))
	for _, wanted in ipairs(_G.alwaysKeepList) do
		if string.find(name, wanted, 1, true) then
			return true
		end
	end

	return false
end

_G.F.shouldKeepMonster = function(monster, index)
	if _G.keepAll then
		return true, "Keep All"
	end
	if _G.keepGleaming and _G.F.isGleaming(monster) then
		return true, "Gleaming"
	end
	if _G.keepSecretAbility and _G.F.isSecretAbility(monster) then
		return true, "Secret Ability"
	end
	if _G.F.isAlwaysKeepMatch(monster, index) then
		return true, "Always Keep"
	end
	return false
end

_G.F.runAutoRally = function()
	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end
	if type(_G._p) ~= "table" then
		return false, "Game hook is not ready."
	end

	_G.F.ensureRallyModule()

	local ranchStatus = _G.F.getRanchStatus()
	local waitingCount = ranchStatus and tonumber(ranchStatus.rallied) or _G.F.getWaitingCount()

	if waitingCount == 0 then
		if ranchStatus and ranchStatus.full then
			_G.lastRallyActionText = "Ranch is full with no inbox to clear."
			_G.F.refreshRallyUI()
			return false, "Ranch is full. Clear your rallied Loomians at Rally Ranch."
		end
		_G.lastRallyActionText = "No rallied Loomians waiting."
		_G.F.refreshRallyUI()
		return false, "No rallied Loomians waiting."
	end

	local ok, data = _G.F.rallyPdsGet("getRallied")
	if not ok then
		_G.lastRallyActionText = "Could not reach Rally service."
		_G.F.refreshRallyUI()
		return false, "Could not reach the Rally service."
	end

	if type(data) ~= "table" or type(data.monsters) ~= "table" or #data.monsters == 0 then
		if waitingCount and waitingCount > 0 then
			_G.lastRallyActionText = string.format("%d waiting but getRallied returned nothing.", waitingCount)
			_G.F.refreshRallyUI()
			return false, string.format("Rally says %d waiting, but getRallied returned no monsters.", waitingCount)
		end
		_G.lastRallyActionText = "No rallied Loomians waiting."
		_G.F.refreshRallyUI()
		return false, "No rallied Loomians waiting."
	end

	local marks = table.create(#data.monsters, 0)
	local kept = 0
	local released = 0
	local keptNames = {}

	for index, monster in ipairs(data.monsters) do
		local keep, reason = _G.F.shouldKeepMonster(monster, index)
		if keep then
			marks[index] = _G.MARK_KEEP
			kept = kept + 1
			table.insert(keptNames, string.format("%s (%s)", _G.F.getRalliedMonsterName(monster, index), reason))
		else
			marks[index] = _G.MARK_RELEASE
			released = released + 1
		end
	end

	if kept == 0 and released == 0 then
		_G.lastRallyActionText = "Nothing marked to keep or release."
		_G.F.refreshRallyUI()
		return false, "Nothing marked to keep or release."
	end

	local handled, newCount = _G.F.rallyHandleRallied(marks)
	if not handled then
		_G.lastRallyActionText = "handleRallied failed."
		_G.F.refreshRallyUI()
		return false, "handleRallied failed."
	end

	_G.rallyKept = _G.rallyKept + kept
	_G.rallyReleased = _G.rallyReleased + released
	_G.lastRallyActionText = string.format("Handled %d: kept %d, released %d.", #data.monsters, kept, released)
	_G.F.refreshRallyUI()
	_G.F.syncRallyBubble(newCount)

	if kept > 0 then
		pcall(function()
			_G.OrionLib:MakeNotification({
				Name = "Rally Keeper",
				Content = string.format("Kept %d: %s", kept, table.concat(keptNames, ", ")),
				Time = 8
			})
		end)
	end

	return true
end


_G.F.shouldCatchWildBattle = function(battle)
	if not _G.autoCatchEnabled then
		return false
	end

	if type(battle) ~= "table" or battle.kind ~= "wild" then
		return false
	end

	if _G.F.isFishingGoppieBattle(battle) then
		if not _G.F.hasWildFoeLoaded(battle) then
			return true
		end

		return _G.F.shouldCatchFishingGoppieBattle(battle)
	end

	if not _G.F.hasWildFoeLoaded(battle) then
		return false
	end

	local foe = _G.F.getBattleFoeMonster(battle)
	if _G.F.shouldFilterEncounterTarget() and _G.F.monsterMatchesSearchTarget(foe, _G.encounterTargetLoomian) then
		return true
	end

	if _G.F.isMatchingRoamingLegendaryFoe(battle) then
		return true
	end

	return _G.F.getWildSpecialFoeForStop(battle) ~= nil
end

CatchAutomation = (function()
	local api = {}

	local lastCatchDiscRequest = nil
	local pendingCatchDiscRequest = nil
	local pendingCatchDiscAt = 0
	local lastDiscAttemptAt = 0
	local lastBattleObject = nil
	local lastPreparedCatchBattle = nil
	local awaitingCaptureNicknamePrompt = false
	local awaitingCaptureNicknameSince = 0
	local catchAwaitingNickname = false
	local waitingForNicknamePromptDismiss = false
	local clickedNicknamePromptInstance = nil
	local lastNicknamePromptAttemptAt = 0
	local lastNicknamePromptServiceAt = 0
	local NICKNAME_PROMPT_SCAN_INTERVAL = 0.25

	local pendingCapturedGoppieForme = nil
	local registeredCapturedGoppieForme = false

	local function resetCaptureNicknamePromptState()
		awaitingCaptureNicknamePrompt = false
		awaitingCaptureNicknameSince = 0
		catchAwaitingNickname = false
		waitingForNicknamePromptDismiss = false
		clickedNicknamePromptInstance = nil
		lastNicknamePromptAttemptAt = 0
		lastNicknamePromptServiceAt = 0

		pendingCapturedGoppieForme = nil
		registeredCapturedGoppieForme = false
	end


	local function rememberPendingCapturedGoppieForme(battle)
		pendingCapturedGoppieForme = nil

		if type(battle) ~= "table" then
			return
		end

		local foe = _G.F.getBattleFoeMonster(battle)
		local formeValue = _G.F.getFishingGoppieFormeValue(battle)
		if _G.F.isMeaningfulFormeValue(formeValue)
			and (_G.F.isGoppieMonster(foe) or _G.F.isFishingGoppieBattle(battle)) then
			pendingCapturedGoppieForme = formeValue
			_G.lastAutoFishingGoppieForme = formeValue
			_G.lastAutoFishingGoppieFormeAt = os.clock()
		end
	end

	local function registerPendingCapturedGoppieForme()
		if not _G.F.isMeaningfulFormeValue(pendingCapturedGoppieForme) then
			rememberPendingCapturedGoppieForme(_G.F.getCurrentBattle())
		end

		if not _G.F.isMeaningfulFormeValue(pendingCapturedGoppieForme)
			and _G.F.isMeaningfulFormeValue(_G.lastAutoFishingGoppieForme)
			and os.clock() - _G.lastAutoFishingGoppieFormeAt <= 90 then
			pendingCapturedGoppieForme = _G.lastAutoFishingGoppieForme
		end

		if registeredCapturedGoppieForme then
			return
		end

		local battle = _G.F.getCurrentBattle()
		if battle and _G.F.registerCaughtGoppieFormeFromBattle(battle) then
			registeredCapturedGoppieForme = true
			return
		end

		if _G.F.isMeaningfulFormeValue(pendingCapturedGoppieForme)
			and (_G.F.addGoppieForme(pendingCapturedGoppieForme) or _G.F.isGoppieFormeSaved(pendingCapturedGoppieForme)) then
			registeredCapturedGoppieForme = true
		end
	end

	local function resetCatchDiscState()
		lastCatchDiscRequest = nil
		pendingCatchDiscRequest = nil
		pendingCatchDiscAt = 0
		if _G.resetCatchUiTiming then
			_G.resetCatchUiTiming()
		end
	end

	local function normalizePromptText(value)
		local text = string.lower(tostring(value or ""))
		text = string.gsub(text, "%s+", " ")
		return text
	end

	local function findAncestorGuiButton(item)
		local current = item

		while current do
			if current:IsA("GuiButton") then
				return current
			end

			current = current.Parent
		end

		return nil
	end

	local getPromptGuiContainers
	local isPromptGuiVisible
	local getBattleGuiPromptYesOrNoMethod

	local function findGuiButtonByText(text)
		local wanted = normalizePromptText(text)

		for _, container in ipairs(getPromptGuiContainers()) do
			local ok, descendants = pcall(function()
				return container:GetDescendants()
			end)

			if ok then
				for _, item in ipairs(descendants) do
					if (item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox")) and isPromptGuiVisible(item) then
						local okText, itemText = pcall(function()
							return item.Text
						end)

						if okText and normalizePromptText(itemText) == wanted then
							local button = item:IsA("GuiButton") and item or findAncestorGuiButton(item)

							if button then
								return button
							end
						end
					end
				end
			end
		end

		return nil
	end

	local function getVisiblePromptTextSnapshot()
		local parts = {}

		for _, container in ipairs(getPromptGuiContainers()) do
			local ok, descendants = pcall(function()
				return container:GetDescendants()
			end)

			if ok then
				for _, item in ipairs(descendants) do
					local visible = isPromptGuiVisible(item)
					if not visible and item:IsA("GuiObject") then
						visible = item.AbsoluteSize.X > 4 and item.AbsoluteSize.Y > 4
					end

					if visible then
						if item:IsA("TextLabel") or item:IsA("TextButton") or item:IsA("TextBox") then
							local okText, text = pcall(function()
								return item.Text
							end)

							if okText and type(text) == "string" and text ~= "" then
								table.insert(parts, text)
							end
						end

						local okContent, contentText = pcall(function()
							return item.ContentText
						end)

						if okContent and type(contentText) == "string" and contentText ~= "" then
							table.insert(parts, contentText)
						end
					end
				end
			end
		end

		return string.lower(table.concat(parts, " "))
	end

	local function visibleTextContainsCaptureNickname()
		local snapshot = getVisiblePromptTextSnapshot()
		if snapshot == "" then
			return false
		end

		if string.find(snapshot, "nickname", 1, true)
			or string.find(snapshot, "give a nickname", 1, true)
			or string.find(snapshot, "no nickname", 1, true) then
			return true
		end

		return string.find(snapshot, "captured", 1, true) ~= nil
			and string.find(snapshot, "nickname", 1, true) ~= nil
	end

	getPromptGuiContainers = function()
		local containers = {}
		local seen = {}

		local function addContainer(container)
			if container and not seen[container] then
				seen[container] = true
				table.insert(containers, container)
			end
		end

		pcall(function()
			if type(_G._p) ~= "table" then
				_G._p = _G.F.findP()
			end

			local utilities = type(_G._p) == "table" and _G._p.Utilities or nil
			local frontGui = utilities and utilities.frontGui or nil
			addContainer(frontGui)
		end)

		pcall(function()
			local playerGui = _G.Player and _G.Player:FindFirstChildOfClass("PlayerGui")
			addContainer(playerGui)
		end)

		return containers
	end

	isPromptGuiVisible = function(item)
		local current = item

		while current do
			if current:IsA("GuiObject") and current.Visible == false then
				return false
			end

			if current:IsA("ScreenGui") and current.Enabled == false then
				return false
			end

			current = current.Parent
		end

		return true
	end

	local function findVisibleYesOrNoPromptFrame()
		for _, container in ipairs(getPromptGuiContainers()) do
			local ok, descendants = pcall(function()
				return container:GetDescendants()
			end)

			if ok then
				for _, item in ipairs(descendants) do
					if item.Name == "YesOrNoPrompt" and isPromptGuiVisible(item) then
						return item
					end
				end
			end
		end

		local okBattleGui, battlePrompt = pcall(function()
			if type(_G._p) ~= "table" then
				_G._p = _G.F.findP()
			end

			local battleGui = type(_G._p) == "table" and _G._p.BattleGui or nil
			if type(battleGui) ~= "table" then
				return nil
			end

			for _, value in pairs(battleGui) do
				if type(value) == "Instance" and value.Name == "YesOrNoPrompt" and isPromptGuiVisible(value) then
					return value
				end
			end

			return nil
		end)

		if okBattleGui and battlePrompt then
			return battlePrompt
		end

		local promptYesOrNo = getBattleGuiPromptYesOrNoMethod()
		if type(promptYesOrNo) == "function" and type(debug) == "table" and type(debug.getupvalues) == "function" then
			local okUpvalues, upvalues = pcall(function()
				return { debug.getupvalues(promptYesOrNo) }
			end)

			if okUpvalues then
				for _, upvalue in ipairs(upvalues) do
					if type(upvalue) == "table" and upvalue.Visible == true then
						if typeof(upvalue.gui) == "Instance" then
							return upvalue.gui.Parent or upvalue.gui
						end

						return upvalue
					end
				end
			end
		end

		return nil
	end

	local function getPromptSearchRoot(promptRoot)
		if typeof(promptRoot) == "Instance" then
			return promptRoot
		end

		if type(promptRoot) == "table" and typeof(promptRoot.gui) == "Instance" then
			return promptRoot.gui
		end

		return promptRoot
	end

	local getYesOrNoPromptButtons

	local function getYesOrNoNoButton(promptRoot)
		promptRoot = getPromptSearchRoot(promptRoot)
		if not promptRoot then
			return nil
		end

		local _, noButton = getYesOrNoPromptButtons(promptRoot)
		if noButton then
			return noButton
		end

		local ok, descendants = pcall(function()
			return promptRoot:GetDescendants()
		end)

		if not ok then
			return nil
		end

		local bestButton = nil
		local bestY = -math.huge

		for _, item in ipairs(descendants) do
			if item:IsA("ImageButton") and isPromptGuiVisible(item) then
				local y = item.Position.Y.Scale + (item.Position.Y.Offset / math.max(item.AbsoluteSize.Y, 1))
				if y > bestY then
					bestY = y
					bestButton = item
				end
			end
		end

		return bestButton
	end

	local function fireGuiButtonSignals(button)
		if not button then
			return false
		end

		local clicked = false

		if type(_G.F) == "table" and type(_G.F.clickGuiButtonOnce) == "function" then
			clicked = _G.F.clickGuiButtonOnce(button) or clicked
		end

		if type(_G.F) == "table" and type(_G.F.activateGuiButton) == "function" then
			clicked = _G.F.activateGuiButton(button) or clicked
		end

		local okActivate = pcall(function()
			button:Activate()
		end)
		clicked = clicked or okActivate

		return clicked
	end

	getYesOrNoPromptButtons = function(promptRoot)
		promptRoot = getPromptSearchRoot(promptRoot)
		if not promptRoot then
			return nil, nil
		end

		local buttons = {}
		local ok, descendants = pcall(function()
			return promptRoot:GetDescendants()
		end)

		if not ok then
			return nil, nil
		end

		for _, item in ipairs(descendants) do
			if item:IsA("ImageButton") and isPromptGuiVisible(item) then
				table.insert(buttons, item)
			end
		end

		table.sort(buttons, function(left, right)
			local leftY = left.Position.Y.Scale + (left.Position.Y.Offset / math.max(left.AbsoluteSize.Y, 1))
			local rightY = right.Position.Y.Scale + (right.Position.Y.Offset / math.max(right.AbsoluteSize.Y, 1))
			return leftY < rightY
		end)

		return buttons[1], buttons[2]
	end

	getBattleGuiPromptYesOrNoMethod = function()
		if type(_G._p) ~= "table" then
			_G._p = _G.F.findP()
		end

		local battleGui = type(_G._p) == "table" and _G._p.BattleGui or nil
		if type(battleGui) ~= "table" then
			return nil
		end

		local promptYesOrNo = _G.F.safeTableGet(battleGui, "promptYesOrNo") or _G.F.safeTableGet(battleGui, "PromptYesOrNo")
		if type(promptYesOrNo) ~= "function" then
			return nil
		end

		return promptYesOrNo
	end

	local function getBattleGuiYesOrNoLiveState()
		local promptYesOrNo = getBattleGuiPromptYesOrNoMethod()
		local promptFrame = nil
		local yesNoSignal = nil
		local noButton = nil

		if type(promptYesOrNo) == "function" and type(debug) == "table" and type(debug.getupvalues) == "function" then
			local ok, upvalues = pcall(function()
				return { debug.getupvalues(promptYesOrNo) }
			end)

			if ok then
				for _, upvalue in ipairs(upvalues) do
					if type(upvalue) == "table" and type(upvalue.Fire) == "function" and type(upvalue.Wait) == "function" then
						yesNoSignal = upvalue
					end

					if type(upvalue) == "table" and upvalue.Visible == true then
						promptFrame = upvalue
						if typeof(upvalue.gui) == "Instance" then
							noButton = getYesOrNoNoButton(upvalue.gui) or noButton
						end
					end

					if typeof(upvalue) == "Instance" and upvalue:IsA("ImageButton") and isPromptGuiVisible(upvalue) then
						local y = upvalue.Position.Y.Scale + (upvalue.Position.Y.Offset / math.max(upvalue.AbsoluteSize.Y, 1))
						if y >= 0.5 then
							noButton = upvalue
						end
					end
				end
			end
		end

		if not promptFrame then
			promptFrame = findVisibleYesOrNoPromptFrame()
		end

		if promptFrame and not noButton then
			noButton = getYesOrNoNoButton(getPromptSearchRoot(promptFrame))
		end

		local promptOpen = false
		if type(promptFrame) == "table" and promptFrame.Visible == true then
			promptOpen = true
		elseif typeof(promptFrame) == "Instance" and isPromptGuiVisible(promptFrame) then
			promptOpen = true
		elseif yesNoSignal ~= nil then
			promptOpen = true
		end

		if promptOpen and not noButton then
			noButton = findGuiButtonByText("No")
		end

		return promptOpen, yesNoSignal, noButton, promptFrame
	end

	local function clickBattleGuiPromptButton(button)
		if not button then
			return false
		end

		return fireGuiButtonSignals(button)
	end

	local function handleCaptureNicknamePrompt()
		local promptOpen, yesNoSignal, noButton, promptFrame = getBattleGuiYesOrNoLiveState()

		if waitingForNicknamePromptDismiss then
			if promptOpen or promptFrame then
				if os.clock() - lastNicknamePromptAttemptAt > 0.6 then
					waitingForNicknamePromptDismiss = false
					clickedNicknamePromptInstance = nil
				else
					return false
				end
			else

			waitingForNicknamePromptDismiss = false
			clickedNicknamePromptInstance = nil
			awaitingCaptureNicknamePrompt = false
			catchAwaitingNickname = false
			return true
			end
		end

		if not promptOpen and not promptFrame then
			return false
		end

		local hasNicknameText = visibleTextContainsCaptureNickname()

		if hasNicknameText then
			awaitingCaptureNicknamePrompt = true
			awaitingCaptureNicknameSince = os.clock()
			catchAwaitingNickname = true
		end

		if catchAwaitingNickname and awaitingCaptureNicknameSince > 0 and os.clock() - awaitingCaptureNicknameSince > 45 then
			catchAwaitingNickname = false
			awaitingCaptureNicknamePrompt = false
			return false
		end

		if not catchAwaitingNickname and not awaitingCaptureNicknamePrompt and not hasNicknameText then
			return false
		end

		if clickedNicknamePromptInstance ~= nil and clickedNicknamePromptInstance == promptFrame then
			return false
		end

		noButton = noButton or findGuiButtonByText("No")

		if noButton and clickBattleGuiPromptButton(noButton) then
			waitingForNicknamePromptDismiss = true
			clickedNicknamePromptInstance = promptFrame
			lastNicknamePromptAttemptAt = os.clock()
			return true
		end

		return false
	end

	local function isWildBattleCatchable(battle)
		if type(battle) ~= "table" or battle.ended or battle.done or battle.kind ~= "wild" then
			return false
		end

		if battle.isHeavyBag or battle.IsNoliBattle or battle.isRaid2v1 then
			return false
		end

		local request = battle.fulfillingRequest
		if type(request) == "table" and request.requestType ~= nil and request.requestType ~= "move" then
			return false
		end

		if battle.state ~= "input" and not _G.F.isBattleMainMenuOpen() then
			return false
		end

		if not _G.F.hasWildFoeLoaded(battle) then
			return false
		end

		local hasRoom = battle.fulfillingRequest and battle.fulfillingRequest.hasRoom
		if hasRoom == false then
			return false
		end

		return true
	end

	local function getCatchRequestKey(battle)
		local request = type(battle) == "table" and battle.fulfillingRequest or nil
		if type(request) == "table" then
			return request
		end

		if type(battle) ~= "table" then
			return nil
		end

		return table.concat({
			tostring(_G.F.safeTableGet(battle, "battleId")),
			tostring(_G.F.safeTableGet(battle, "turn")),
			tostring(_G.F.safeTableGet(battle, "state")),
		}, "|")
	end

	local function tryThrowCaptureDisc(battle, discId)
		if not isWildBattleCatchable(battle) then
			resetCatchDiscState()
			return false, "Battle is not ready to throw a disc."
		end

		local requestKey = getCatchRequestKey(battle)
		if requestKey == lastCatchDiscRequest then
			if os.clock() - lastDiscAttemptAt > 2.5
				and not catchAwaitingNickname
				and not (_G.isCatchUiActive and _G.isCatchUiActive()) then
				lastCatchDiscRequest = nil
				resetCatchDiscState()
			else
				return false, "Disc already thrown for this turn."
			end
		end

		if requestKey == lastCatchDiscRequest then
			return false, "Disc already thrown for this turn."
		end

		if pendingCatchDiscRequest ~= requestKey then
			pendingCatchDiscRequest = requestKey
			pendingCatchDiscAt = os.clock()
			if _G.resetCatchUiTiming then
				_G.resetCatchUiTiming()
			end
			return false, "Disc throw queued."
		end

		if os.clock() - pendingCatchDiscAt < 0.35 and not (_G.isCatchUiActive and _G.isCatchUiActive()) then
			return false, "Waiting for battle input listener."
		end

		local threw, reason = _G.naturalCatchFromBattle(battle, discId, _G.autoCatchDisc)
		if threw then
			lastCatchDiscRequest = requestKey
			pendingCatchDiscRequest = nil
			catchAwaitingNickname = true
			awaitingCaptureNicknamePrompt = true
			awaitingCaptureNicknameSince = os.clock()
			lastNicknamePromptServiceAt = 0
			rememberPendingCapturedGoppieForme(battle)
			return true
		end

		return false, reason or "Catch UI not ready."
	end

	function api:isEnabled()
		return _G.autoCatchEnabled
	end

	function api:managesBattles()
		return _G.autoCatchEnabled
	end

	function api:shouldCatchBattle(battle)
		return _G.F.shouldCatchWildBattle(battle)
	end

	function api:resetState()
		resetCatchDiscState()
		resetCaptureNicknamePromptState()
		lastDiscAttemptAt = 0
		lastBattleObject = nil
		lastPreparedCatchBattle = nil
	end

	function api:serviceNicknamePrompt()
		_G.F.installGoppieCaptureNetworkHook()

		if visibleTextContainsCaptureNickname() then
			awaitingCaptureNicknamePrompt = true
			awaitingCaptureNicknameSince = os.clock()
			catchAwaitingNickname = true
			registerPendingCapturedGoppieForme()
		end

		if not _G.autoCatchEnabled and not _G.autoFishingEnabled then
			if not catchAwaitingNickname and not awaitingCaptureNicknamePrompt and not waitingForNicknamePromptDismiss then
				return
			end
		elseif _G.autoCatchEnabled then
			if not catchAwaitingNickname and not awaitingCaptureNicknamePrompt and not waitingForNicknamePromptDismiss then
				return
			end
		end

		local now = os.clock()
		if now - lastNicknamePromptServiceAt < NICKNAME_PROMPT_SCAN_INTERVAL then
			return
		end
		lastNicknamePromptServiceAt = now

		local promptOpen = select(1, getBattleGuiYesOrNoLiveState())
		local promptFrame = findVisibleYesOrNoPromptFrame()
		local recentAutoFishingGoppie = _G.autoFishingEnabled
			and _G.F.isMeaningfulFormeValue(_G.lastAutoFishingGoppieForme)
			and os.clock() - _G.lastAutoFishingGoppieFormeAt <= 90
		local looksLikeNicknamePrompt = visibleTextContainsCaptureNickname()
			or ((promptOpen or promptFrame) and recentAutoFishingGoppie)
			or ((promptOpen or promptFrame) and (_G.autoFishingEnabled or _G.autoCatchEnabled))

		if _G.isCatchUiActive and _G.isCatchUiActive() and not promptOpen and not promptFrame and not catchAwaitingNickname and not looksLikeNicknamePrompt then
			return
		end

		handleCaptureNicknamePrompt()
	end

	function api:serviceBattle()
		if not _G.autoCatchEnabled then
			return
		end

		if type(_G._p) ~= "table" then
			_G._p = _G.F.findP()
		end

		local battle = _G.F.getCurrentBattle()
		if type(battle) ~= "table" or battle.ended then
			if lastBattleObject then
				lastBattleObject = nil
				lastPreparedCatchBattle = nil
				resetCatchDiscState()
				resetCaptureNicknamePromptState()
			end
			return
		end

		if battle ~= lastBattleObject then
			lastBattleObject = battle
			lastPreparedCatchBattle = nil
			resetCatchDiscState()
		end

		if battle.kind ~= "wild" then
			return
		end

		if _G.F.isBattleSetupPending(battle) then
			return
		end

		if not _G.F.shouldCatchWildBattle(battle) then
			return
		end

		if _G.autoBringEnabled and lastPreparedCatchBattle ~= battle then
			lastPreparedCatchBattle = battle
			_G.F.releaseBattleAutomationForCapture(battle)
		end

		if not _G.F.hasWildFoeLoaded(battle) then
			return
		end

		local discId = _G.normalizeCaptureDiscId(_G.autoCatchDisc)
		if not discId then
			return
		end

		local now = os.clock()
		local catchUiBusy = _G.isCatchUiActive and _G.isCatchUiActive()
		local minDelay = catchUiBusy and 0.45 or 0.35

		if now - lastDiscAttemptAt < minDelay then
			return
		end

		local threw, reason = tryThrowCaptureDisc(battle, discId)
		if threw
			or reason == "Disc already thrown for this turn."
			or reason == "Disc throw queued."
			or reason == "Disc selected."
			or reason == "Disc opened."
			or reason == "Opening bag."
			or reason == "Waiting for disc detail."
			or reason == "Waiting for requested disc detail."
			or reason == "Waiting for bag items."
			or reason == "Requested disc button not found."
			or reason == "Use button not found." then
			lastDiscAttemptAt = now
		end
	end

	return api
end)()

ArcadeAutomation = (function()
	local api = {}

	local discDropStatusLabel = nil
	local discDropLiveLabel = nil
	local discDropRecordsLabel = nil

	local arcadeRemoteKey = "W8iupZbUTwip9WF0zpAvmA"

	local function setLabelText(label, text)
		if label and type(label.Set) == "function" then
			pcall(function()
				label:Set(tostring(text or ""))
			end)
		end
	end

	local function formatDiscDropNumber(value)
		local number = math.floor(tonumber(value) or 0)
		local text = tostring(number)
		local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
		if formatted:sub(1, 1) == "," then
			formatted = formatted:sub(2)
		end
		return formatted
	end

	local function refreshDiscDropRecordsLabel()
		setLabelText(
			discDropRecordsLabel,
			string.format(
				"Last score: %s | Best score: %s",
				formatDiscDropNumber(_G.discDropLastScore),
				formatDiscDropNumber(_G.discDropHighScore)
			)
		)
	end

	local function updateDiscDropUi(grid, movesMade, message)
		local score = type(grid) == "table" and tonumber(grid.score) or 0
		local combo = type(grid) == "table" and tonumber(grid.combo) or 0

		setLabelText(discDropStatusLabel, tostring(message or "Idle"))
		setLabelText(
			discDropLiveLabel,
			string.format(
				"Score: %s | Moves: %d | Combo: %d",
				formatDiscDropNumber(score),
				movesMade or 0,
				combo or 0
			)
		)
		refreshDiscDropRecordsLabel()
	end

	local function setDiscDropStatus(text)
		setLabelText(discDropStatusLabel, text)
		refreshDiscDropRecordsLabel()
	end

	local function recordDiscDropGameScore(grid)
		local finalScore = type(grid) == "table" and math.floor(tonumber(grid.score) or 0) or 0
		_G.discDropLastScore = finalScore

		if finalScore > _G.discDropHighScore then
			_G.discDropHighScore = finalScore
		end
	end

	local function ensureP()
		if type(_G._p) ~= "table" then
			_G._p = _G.F.findP()
		end

		return type(_G._p) == "table"
	end

	local function newArray(size)
		if type(table.create) == "function" then
			return table.create(size)
		end

		return {}
	end

	local function getArcadeRemote(remoteName)
		local ok, remote = pcall(function()
			local remoteFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Remote")
			return remoteFolder and remoteFolder:FindFirstChild(remoteName)
		end)

		if ok then
			return remote
		end

		return nil
	end

	local function directNetworkGet(actionName, ...)
		local remote = getArcadeRemote("REQ") or getArcadeRemote("GET")
		if not remote or type(remote.InvokeServer) ~= "function" then
			return false
		end

		local args = { ... }
		local ok, result = pcall(function()
			return remote:InvokeServer(arcadeRemoteKey, actionName, unpack(args))
		end)

		if ok and result ~= nil and result ~= false then
			return true, result, "direct-key"
		end

		ok, result = pcall(function()
			return remote:InvokeServer(actionName, unpack(args))
		end)

		if ok and result ~= nil and result ~= false then
			return true, result, "direct-bare"
		end

		return false
	end

	local function directNetworkPost(actionName, ...)
		local remote = getArcadeRemote("EVT") or getArcadeRemote("POST")
		if not remote or type(remote.FireServer) ~= "function" then
			return false
		end

		local args = { ... }
		local ok = pcall(function()
			remote:FireServer(arcadeRemoteKey, actionName, unpack(args))
		end)

		if ok then
			return true
		end

		ok = pcall(function()
			remote:FireServer(actionName, unpack(args))
		end)

		return ok
	end

	local function networkGet(actionName, ...)
		ensureP()

		local args = { ... }
		local network = type(_G._p) == "table" and _G.F.safeTableGet(_G._p, "Network") or nil
		local getMethod = type(network) == "table" and _G.F.safeTableGet(network, "get") or nil

		if type(getMethod) == "function" then
			local ok, result = pcall(function()
				return getMethod(network, actionName, unpack(args))
			end)

			if ok and result ~= nil and result ~= false then
				return true, result, "network"
			end
		end

		local connection = type(_G._p) == "table" and _G.F.safeTableGet(_G._p, "Connection") or nil
		getMethod = type(connection) == "table" and _G.F.safeTableGet(connection, "get") or nil

		if type(getMethod) == "function" then
			local ok, result = pcall(function()
				return getMethod(connection, actionName, unpack(args))
			end)

			if ok and result ~= nil and result ~= false then
				return true, result, "connection"
			end
		end

		return directNetworkGet(actionName, ...)
	end

	local function networkPost(actionName, ...)
		ensureP()

		local args = { ... }
		local network = type(_G._p) == "table" and _G.F.safeTableGet(_G._p, "Network") or nil
		local postMethod = type(network) == "table" and _G.F.safeTableGet(network, "post") or nil

		if type(postMethod) == "function" then
			local ok = pcall(function()
				postMethod(network, actionName, unpack(args))
			end)

			if ok then
				return true
			end
		end

		local connection = type(_G._p) == "table" and _G.F.safeTableGet(_G._p, "Connection") or nil
		postMethod = type(connection) == "table" and _G.F.safeTableGet(connection, "post") or nil

		if type(postMethod) == "function" then
			local ok = pcall(function()
				postMethod(connection, actionName, unpack(args))
			end)

			if ok then
				return true
			end
		end

		return directNetworkPost(actionName, ...)
	end

	local function getDiscDropGridClass()
		ensureP()

		local arcadeController = type(_G._p) == "table" and _G.F.safeTableGet(_G._p, "ArcadeController") or nil
		local gridClass = type(arcadeController) == "table" and _G.F.safeTableGet(arcadeController, "DiscDropGrid") or nil

		if type(gridClass) == "table" and type(gridClass.new) == "function" then
			return gridClass
		end

		return nil
	end

	local function cloneDiscDropGrid(grid)
		if type(grid) ~= "table" or type(grid.grid) ~= "table" then
			return nil
		end

		local clone = setmetatable({}, getmetatable(grid))
		clone.score = tonumber(grid.score) or 0
		clone.combo = tonumber(grid.combo) or 1
		clone.nextBombScore = tonumber(grid.nextBombScore) or 5000
		clone.guiHandler = nil
		clone.srand = Random.new(math.random(1, 1000000000))
		clone.grid = newArray(8)

		for y = 1, 8 do
			clone.grid[y] = newArray(8)
			local row = grid.grid[y]

			for x = 1, 8 do
				local cell = type(row) == "table" and row[x] or nil
				clone.grid[y][x] = {
					value = type(cell) == "table" and cell.value or 0,
					x = x,
					y = y
				}
			end
		end

		return clone
	end

	local function scoreDiscDropMove(grid, move)
		local clone = cloneDiscDropGrid(grid)
		if not clone or type(clone.TrySwap) ~= "function" then
			return -math.huge
		end

		local beforeScore = tonumber(clone.score) or 0
		local ok, swapped = pcall(function()
			return clone:TrySwap(move[1], move[2], move[3], move[4])
		end)

		if not ok or not swapped then
			return -math.huge
		end

		local afterScore = tonumber(clone.score) or beforeScore
		local scoreGain = afterScore - beforeScore
		local combo = tonumber(clone.combo) or 1
		return scoreGain * 1000 + combo + math.random()
	end

	local function chooseDiscDropMove(grid)
		if type(grid) ~= "table" or type(grid.GetPossibleMoveList) ~= "function" then
			return nil
		end

		local ok, moves = pcall(function()
			return grid:GetPossibleMoveList()
		end)

		if not ok or type(moves) ~= "table" then
			return nil
		end

		local bestMove = nil
		local bestScore = -math.huge

		for index = 1, #moves - 1, 2 do
			local first = moves[index]
			local second = moves[index + 1]

			if type(first) == "table" and type(second) == "table" then
				local move = { first.x, first.y, second.x, second.y }
				local score = scoreDiscDropMove(grid, move)

				if score > bestScore then
					bestScore = score
					bestMove = move
				end
			end
		end

		return bestMove
	end

	local function renderDiscDropStatus(grid, movesMade, message)
		updateDiscDropUi(grid, movesMade, message)
	end

	local function runAutoDiscDrop()
		local gridClass = getDiscDropGridClass()
		if not gridClass then
			setDiscDropStatus("ArcadeController.DiscDropGrid is not loaded.")
			return false, "ArcadeController.DiscDropGrid is not loaded. Open the arcade area once, then turn this on."
		end

		local okSeed, seed = networkGet("DiscDrop_NewGame")
		if not okSeed then
			setDiscDropStatus("Could not start a Disc Drop game.")
			return false, "Could not start a Disc Drop game."
		end

		local okGrid, grid = pcall(function()
			return gridClass.new(seed)
		end)

		if not okGrid or type(grid) ~= "table" then
			setDiscDropStatus("Could not build the Disc Drop grid.")
			return false, "Could not build the Disc Drop grid."
		end

		local startedAt = os.clock()
		local movesMade = 0
		local lastScore = tonumber(grid.score) or 0
		local lastMove = nil
		renderDiscDropStatus(grid, movesMade, "Started")

		while _G.autoDiscDropEnabled and _G.uiAlive do
			local move = chooseDiscDropMove(grid)
			if not move then
				break
			end

			local okMove = networkPost("DiscDrop_Move", move[1], move[2], move[3], move[4])
			if not okMove then
				setDiscDropStatus("Could not send Disc Drop move.")
				return false, "Could not send Disc Drop move."
			end

			local swapped = false
			pcall(function()
				swapped = grid:TrySwap(move[1], move[2], move[3], move[4])
			end)

			if not swapped then
				break
			end

			movesMade = movesMade + 1
			lastMove = move

			local currentScore = tonumber(grid.score) or lastScore
			if currentScore > lastScore then
				lastScore = currentScore
			end

			renderDiscDropStatus(grid, movesMade, "Playing")
			task.wait(0.08)
		end

		recordDiscDropGameScore(grid)
		networkPost("DiscDrop_Finish", math.floor(os.clock() - startedAt), true)
		renderDiscDropStatus(grid, movesMade, movesMade > 0 and "Finished" or "No moves")
		return movesMade > 0, movesMade > 0 and nil or "No Disc Drop moves were available."
	end

	function api:isDiscDropEnabled()
		return _G.autoDiscDropEnabled
	end

	function api:setDiscDropEnabled(value, keepVisual)
		_G.autoDiscDropEnabled = value == true

		if not _G.autoDiscDropEnabled and not keepVisual then
			setLabelText(discDropStatusLabel, "Stopped.")
			setLabelText(discDropLiveLabel, "Score: 0 | Moves: 0 | Combo: 0")
			refreshDiscDropRecordsLabel()
		end
	end

	function api:stopAll()
		_G.autoDiscDropEnabled = false
		setLabelText(discDropStatusLabel, "Stopped.")
		setLabelText(discDropLiveLabel, "Score: 0 | Moves: 0 | Combo: 0")
		refreshDiscDropRecordsLabel()
	end

	function api:runAutoDiscDrop()
		return runAutoDiscDrop()
	end

	function api:refreshStats()
		refreshDiscDropRecordsLabel()
	end

	function api:attachUi(tab)
		if not tab then
			return
		end

		_G.configUi.autoDiscDropToggle = tab:AddToggle({
			Name = "Auto Disc Drop",
			Default = _G.autoDiscDropEnabled,
			Color = Color3.fromRGB(90, 170, 255),
			Callback = function(value)
				_G.F.setAutoDiscDropEnabled(value)
			end
		})

		discDropStatusLabel = tab:AddLabel("Idle")
		discDropLiveLabel = tab:AddLabel("Score: 0 | Moves: 0 | Combo: 0")
		discDropRecordsLabel = tab:AddLabel("Last score: 0 | Best score: 0")
		_G.discDropStatusLabel = discDropStatusLabel
		_G.discDropLiveLabel = discDropLiveLabel
		_G.discDropRecordsLabel = discDropRecordsLabel
		refreshDiscDropRecordsLabel()
	end

	return api
end)()

_G.F.setAutoDiscDropEnabled = function(value)
	_G.autoDiscDropEnabled = value and true or false

	if ArcadeAutomation then
		if not _G.autoDiscDropEnabled then
			ArcadeAutomation:stopAll()
		end
	end
end

_G.F.setAutoCatchEnabled = function(value)
	_G.autoCatchEnabled = value

	if value and CatchAutomation then
		CatchAutomation:resetState()
	end
end

_G.F.getEncounterPool = function()
	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end

	if type(_G._p) ~= "table" then
		return nil, "Hook is not ready."
	end

	local currentChunk = _G._p.DataManager and _G._p.DataManager.currentChunk
	local regionData = currentChunk and currentChunk.regionData
	if type(regionData) ~= "table" then
		return nil, "Current region has no encounter data."
	end

	if regionData.Grass and not (regionData.NoGrassIndoors and currentChunk.indoors) then
		return regionData.Grass
	end

	if regionData.GrassNotRequired and regionData.Grass then
		return regionData.Grass
	end

	return nil, "No grass encounter pool found here."
end

_G.F.startAutoEncounter = function()
	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end

	local battleClient = type(_G._p) == "table" and (_G._p.BattleClient or _G._p.Battle) or nil
	if type(battleClient) ~= "table" then
		return false, "BattleClient is not ready."
	end

	if _G.F.getCurrentBattle() then
		return false, "Battle already active."
	end

	local masterControl = type(_G._p) == "table" and _G._p.MasterControl or nil
	if type(masterControl) == "table" and masterControl.WalkEnabled == false then
		return false, "Movement is disabled."
	end

	local pool, reason = _G.F.getEncounterPool()
	if not pool then
		return false, reason
	end

	local ok, result = pcall(function()
		return battleClient:doWildBattle(pool, {})
	end)

	if not ok then
		return false, tostring(result)
	end

	return true
end

_G.F.shouldFilterEncounterTarget = function()
	return _G.F.normalizeLoomianSearchName(_G.encounterTargetLoomian) ~= ""
end

_G.F.isWrongEncounterTargetFoe = function(battle)
	if not _G.F.shouldFilterEncounterTarget() or not _G.F.hasWildFoeLoaded(battle) then
		return false
	end

	local monster = _G.F.getBattleFoeMonster(battle)
	local name = _G.F.normalizeLoomianSearchName(_G.F.getEncounterFoeSpeciesName(monster))
	if name == "" then
		return false
	end

	return not _G.F.monsterMatchesSearchTarget(monster, _G.encounterTargetLoomian)
end

_G.F.isMatchingEncounterTargetFoe = function(battle)
	if not _G.F.shouldFilterEncounterTarget() or not _G.F.hasWildFoeLoaded(battle) then
		return false
	end

	local monster = _G.F.getBattleFoeMonster(battle)
	local name = _G.F.normalizeLoomianSearchName(_G.F.getEncounterFoeSpeciesName(monster))
	if name == "" then
		return false
	end

	return _G.F.monsterMatchesSearchTarget(monster, _G.encounterTargetLoomian)
end

_G.F.handleEncounterTargetMatchFound = function(battle)
	if _G.encounterTargetStopBattle == battle then
		return
	end

	_G.encounterTargetStopBattle = battle

	local foe = _G.F.getBattleFoeMonster(battle)
	local displayName = _G.F.getMonsterDisplayName(foe)
	if displayName == "" then
		displayName = _G.encounterTargetLoomian
	end

	_G.F.pauseAutoEncounterForBattle(battle, displayName, "Target", "Target Found")
end

_G.F.setAutoEncounterEnabled = function(value)
	_G.autoEncounterEnabled = value
end

_G.F.fossilNormalizeInteractKind = function(value)
	return string.lower(string.gsub(tostring(value or ""), "%s+", ""))
end

_G.F.getFossilChunkRoots = function()
	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end

	local roots = {}
	local currentChunk = type(_G._p) == "table" and _G._p.DataManager and _G._p.DataManager.currentChunk or nil

	if type(currentChunk) == "table" and currentChunk.map then
		table.insert(roots, currentChunk.map)
	end

	if type(currentChunk) == "table" and type(currentChunk.GetMap) == "function" then
		local ok, map = pcall(function()
			return currentChunk:GetMap()
		end)

		if ok and map and map ~= currentChunk.map then
			table.insert(roots, map)
		end
	end

	return roots
end

_G.F.getFossilInteractPosition = function(model, tag)
	local main = model and (model:FindFirstChild("Main") or model:FindFirstChild("Base"))
	if main and main:IsA("BasePart") then
		return main.Position
	end

	local parent = tag and tag.Parent
	if parent and parent:IsA("BasePart") then
		return parent.Position
	end

	if model and model:IsA("Model") and model.PrimaryPart then
		return model.PrimaryPart.Position
	end

	return nil
end

_G.F.collectFossilInanimateInteracts = function()
	local entries = {}

	for _, root in ipairs(_G.F.getFossilChunkRoots()) do
		local ok, descendants = pcall(function()
			return root:GetDescendants()
		end)

		if ok then
			for _, item in ipairs(descendants) do
				if item.Name == "#InanimateInteract" and item:IsA("StringValue") then
					table.insert(entries, {
						tag = item,
						model = item.Parent,
						kind = tostring(item.Value or ""),
						position = _G.F.getFossilInteractPosition(item.Parent, item)
					})
				end
			end
		end
	end

	return entries
end

_G.F.setFossilStatus = function(text)
	_G.lastFossilBatchText = tostring(text or "Idle")

	if _G.fossilStatusLabel and type(_G.fossilStatusLabel.Set) == "function" then
		pcall(function()
			_G.fossilStatusLabel:Set("Status: " .. _G.lastFossilBatchText)
		end)
	end
end

_G.F.refreshFossilStats = function()
	if _G.fossilStatsLabel and type(_G.fossilStatsLabel.Set) == "function" then
		pcall(function()
			_G.fossilStatsLabel:Set(string.format(
				"Batches: %d | Revived: %d | Last Queued: %d",
				_G.totalFossilBatches,
				_G.totalFossilRevived,
				_G.lastFossilQueuedCount
			))
		end)
	end
end

_G.F.getPetrolithTableInfo = function()
	local root = _G.F.getRoot()
	if not root then
		return false, "Character root not ready."
	end

	local wanted = _G.F.fossilNormalizeInteractKind(_G.TARGET_PETROLITH_INTERACT)
	local bestDistance = math.huge
	local found = false

	for _, entry in ipairs(_G.F.collectFossilInanimateInteracts()) do
		if _G.F.fossilNormalizeInteractKind(entry.kind) == wanted and entry.position then
			found = true
			local distance = (root.Position - entry.position).Magnitude
			if distance < bestDistance then
				bestDistance = distance
			end
		end
	end

	if not found then
		return false, "Petrolith Table not found in this chunk."
	end

	return true, string.format("Petrolith Table nearby: %.1f studs", bestDistance)
end

_G.F.refreshPetrolithTableLabel = function()
	local found, message = _G.F.getPetrolithTableInfo()
	local text = found and message or ("Petrolith Table: " .. tostring(message))

	if _G.fossilMachineLabel and type(_G.fossilMachineLabel.Set) == "function" then
		pcall(function()
			_G.fossilMachineLabel:Set(text)
		end)
	end
end

_G.F.clearFossilNpcChat = function()
	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end

	if type(_G._p) ~= "table" or type(_G._p.NPCChat) ~= "table" then
		return
	end

	pcall(function()
		_G._p.NPCChat.fastForward = true
		_G._p.NPCChat.skipping = true
		_G._p.NPCChat.TextSpeedMultiplier = 100
	end)

	pcall(function()
		if type(_G._p.NPCChat.isChatting) == "function"
			and _G._p.NPCChat:isChatting()
			and type(_G._p.NPCChat.clear) == "function" then
			_G._p.NPCChat:clear()
		end
	end)

	pcall(function()
		if type(_G._p.NPCChat.manualAdvance) == "function" then
			_G._p.NPCChat:manualAdvance()
		end
	end)

	_G.F.callMethodsIfPresent(_G._p.NPCChat, {
		"manualAdvance", "ManualAdvance",
		"advance", "Advance",
		"next", "Next",
		"skip", "Skip",
		"close", "Close",
		"finish", "Finish",
		"continue", "Continue"
	})
end

_G.F.getFossilMonsterDisplayName = function(monster, index)
	if type(monster) ~= "table" then
		return "Revive " .. tostring(index)
	end

	local summary = _G.F.safeTableGet(monster, "summ")
	if type(summary) == "table" then
		local nickname = _G.F.safeTableGet(summary, "nickname")
		if type(nickname) == "string" and nickname ~= "" then
			return nickname
		end

		local name = _G.F.safeTableGet(summary, "name")
		if type(name) == "string" and name ~= "" then
			return name
		end
	end

	for _, key in ipairs({ "nickname", "name", "species", "id" }) do
		local value = _G.F.safeTableGet(monster, key)
		if value ~= nil and tostring(value) ~= "" then
			return tostring(value)
		end
	end

	return "Revive " .. tostring(index)
end

_G.F.processFossilReviveFollowUps = function(entries)
	if type(_G._p) ~= "table" then
		_G._p = _G.F.findP()
	end

	if type(entries) ~= "table" or type(_G._p) ~= "table" or type(_G._p.Monster) ~= "table" then
		return
	end

	local processor = _G.F.safeTableGet(_G._p.Monster, "processMovesAndEvolution")
	if type(processor) ~= "function" then
		return
	end

	for _, entry in ipairs(entries) do
		pcall(function()
			processor(_G._p.Monster, entry, true)
		end)
	end
end

_G.F.planFossilRegularSet = function(subcountByKey, orderedKeys)
	local reviveCount = 0

	while true do
		local chosen = {}

		for _, key in ipairs(orderedKeys) do
			if (subcountByKey[key] or 0) > 0 then
				table.insert(chosen, key)
			end

			if #chosen >= 3 then
				break
			end
		end

		if #chosen < 3 then
			break
		end

		for _, key in ipairs(chosen) do
			subcountByKey[key] = subcountByKey[key] - 1
		end

		reviveCount = reviveCount + 1
	end

	return reviveCount
end

_G.F.buildPetrolithBatch = function(pieces, limit)
	local reviveKinds = {}
	local groupedKinds = {}
	local groupedOrder = {}

	for _, piece in ipairs(pieces) do
		local qty = math.max(0, tonumber(piece.qty) or 0)
		local kind = piece.kind

		if qty > 0 and kind ~= nil then
			if piece.lone then
				for _ = 1, qty do
					if #reviveKinds >= limit then
						return reviveKinds
					end

					table.insert(reviveKinds, kind)
				end
			else
				local kindKey = tostring(kind)
				local group = groupedKinds[kindKey]
				if not group then
					group = {
						kind = kind,
						subcountByKey = {},
						orderedKeys = {}
					}
					groupedKinds[kindKey] = group
					table.insert(groupedOrder, group)
				end

				local subkey = string.lower(tostring(piece.subkind or ""))
				if subkey ~= "" then
					if group.subcountByKey[subkey] == nil then
						group.subcountByKey[subkey] = 0
						table.insert(group.orderedKeys, subkey)
					end

					group.subcountByKey[subkey] = group.subcountByKey[subkey] + qty
				end
			end
		end
	end

	for _, group in ipairs(groupedOrder) do
		if #reviveKinds >= limit then
			break
		end

		if tonumber(group.kind) == 6 then
			local subcountByKey = group.subcountByKey
			local aCount = subcountByKey.a or 0
			local bCount = subcountByKey.b or 0
			local cCount = subcountByKey.c or 0
			local dCount = subcountByKey.d or 0

			while #reviveKinds < limit and aCount > 0 and bCount > 0 and (cCount > 0 or dCount > 0) do
				if cCount > 0 then
					aCount = aCount - 1
					bCount = bCount - 1
					cCount = cCount - 1
					table.insert(reviveKinds, group.kind)
				else
					aCount = aCount - 1
					bCount = bCount - 1
					dCount = dCount - 1
					table.insert(reviveKinds, 7)
				end
			end
		else
			local subcountByKey = {}
			for key, value in pairs(group.subcountByKey) do
				subcountByKey[key] = value
			end

			local plannedCount = _G.F.planFossilRegularSet(subcountByKey, group.orderedKeys)
			for _ = 1, plannedCount do
				if #reviveKinds >= limit then
					break
				end

				table.insert(reviveKinds, group.kind)
			end
		end
	end

	return reviveKinds
end

_G.F.runAutoFossil = function()
	if _G.fossilBusy then
		return false, "Auto Fossil is already running."
	end

	_G.fossilBusy = true
	_G.F.setFossilStatus("Scanning Petrolith inventory...")

	local ok, pieces, limit = _G.F.rallyPdsGet("getPetroliths")
	if not ok then
		_G.fossilBusy = false
		_G.F.setFossilStatus("Could not reach the Petrolith service.")
		return false, "Could not reach the Petrolith service."
	end

	if pieces == "ns" then
		_G.fossilBusy = false
		_G.F.setFossilStatus("Loomian Care is full.")
		return false, "Loomian Care is full. Make space before reviving more Petroliths."
	end

	if type(pieces) ~= "table" then
		_G.fossilBusy = false
		_G.F.setFossilStatus("Petrolith data was not ready.")
		return false, "Petrolith data was not ready."
	end

	local numericLimit = math.max(1, tonumber(limit) or 30)
	local reviveKinds = _G.F.buildPetrolithBatch(pieces, numericLimit)
	_G.lastFossilQueuedCount = #reviveKinds
	_G.F.refreshFossilStats()

	if #reviveKinds == 0 then
		_G.fossilBusy = false
		_G.F.setFossilStatus("No complete Petrolith sets found.")
		return false, "No complete Petrolith sets found."
	end

	_G.F.setFossilStatus(string.format("Reviving %d set(s)...", #reviveKinds))

	local reviveOk, revivedMonsters, partyCount, careCount, followUps = _G.F.rallyPdsGet("revivePetroliths", reviveKinds)
	if not reviveOk then
		_G.fossilBusy = false
		_G.F.setFossilStatus("revivePetroliths failed.")
		return false, "revivePetroliths failed."
	end

	if type(revivedMonsters) ~= "table" then
		_G.fossilBusy = false
		_G.F.setFossilStatus("The Petrolith revive returned no results.")
		return false, "The Petrolith revive returned no results."
	end

	_G.F.processFossilReviveFollowUps(followUps)
	_G.F.clearFossilNpcChat()

	local revivedCount = #revivedMonsters
	local revivedNames = {}

	for index, monster in ipairs(revivedMonsters) do
		table.insert(revivedNames, _G.F.getFossilMonsterDisplayName(monster, index))
	end

	_G.totalFossilBatches = _G.totalFossilBatches + 1
	_G.totalFossilRevived = _G.totalFossilRevived + revivedCount
	_G.F.refreshFossilStats()

	local partyValue = tonumber(partyCount) or 0
	local careValue = tonumber(careCount) or 0
	local storageText = ""

	if partyValue > 0 or careValue > 0 then
		storageText = string.format(" | Party: %d | Care: %d", partyValue, careValue)
	end

	local shortList = revivedCount > 0 and table.concat(revivedNames, ", ") or "Unknown result"
	if #shortList > 150 then
		shortList = string.sub(shortList, 1, 147) .. "..."
	end

	_G.fossilBusy = false
	_G.F.setFossilStatus(string.format("Revived %d Loomian(s)%s", revivedCount, storageText))
	_G.OrionLib:MakeNotification({
		Name = "Auto Fossil",
		Content = shortList,
		Time = 7,
	})

	return true, string.format("Revived %d Loomian(s)%s", revivedCount, storageText)
end

_G.F.disableAllFeatures = function()
	_G.autoEncounterEnabled = false
	_G.autoEncounterPausedBattle = nil
	_G.autoEncounterPausedDisplayName = nil
	_G.autoEncounterPausedReason = nil
	_G.autoCatchEnabled = false
	_G.F.setAutoFishingEnabled(false)
	_G.autoBringEnabled = false
	_G.autoRallyEnabled = false
	_G.autoTrainerEnabled = false
	_G.autoMoveOneEnabled = false
	_G.autoFossilEnabled = false
	_G.autoEggRainEnabled = false
	_G.autoDiscDropEnabled = false
	_G.autoBoonaryEnabled = false
	_G.autoBoonaryBusy = false
	_G.autoBoonaryTriggered = false
	_G.F.setWallSparkleUmvEnabled(false)
	_G.F.setUmvMiningRevealEnabled(false)
	_G.F.setRemoteSparkleMineEnabled(false)
	_G.F.setCtrlClickTpEnabled(false)
	_G.F.setAntiAfkEnabled(false)
	_G.lastAutoMoveOneRequest = nil
	_G.pendingAutoMoveOneRequest = nil
	_G.pendingAutoMoveOneAt = 0
	_G.naturalRunPausedSpecialBattle = nil
	_G.encounterTargetStopBattle = nil
	if StaticAutomation then
		StaticAutomation:setEnabled(false)
	end
	_G.arcerosAutoEnabled = false
	if CatchAutomation then
		CatchAutomation:resetState()
	end
	if ArcadeAutomation then
		ArcadeAutomation:stopAll()
	end
	if _G.savingDisabled then
		_G.F.setSavingDisabled(false)
	end
	_G.F.clearAllBattleFastForward()
end

_G.CONFIG_VERSION = 1
_G.CONFIG_AUTOSAVE_FILE = "config.json"
_G.configProfileName = "default"
_G.configUi = {}
_G.applyingConfig = false

_G.CONFIG_DIR = "LLSPLOIT"

_G.F.getConfigDirectory = function()
	if type(os) == "table" and type(os.getenv) == "function" then
		local localAppData = os.getenv("LOCALAPPDATA") or os.getenv("LocalAppData")
		if localAppData and localAppData ~= "" then
			return localAppData .. "\\Potassium\\workspace\\LLSPLOIT"
		end
	end
	return _G.CONFIG_DIR
end

_G.F.sanitizeConfigName = function(name)
	name = tostring(name or "default")
	name = string.gsub(name, "[^%w%-_ ]", "")
	name = string.gsub(name, "^%s*(.-)%s*$", "%1")
	if name == "" then
		name = "default"
	end
	return name
end

_G.F.ensureConfigDirectory = function()
	local dir = _G.F.getConfigDirectory()
	if not makefolder or not isfolder then
		return dir
	end

	pcall(function()
		if isfolder(dir) then
			return
		end

		makefolder(dir)
		if isfolder(dir) then
			return
		end

		local accumulated = ""
		local useBackslash = string.find(dir, "\\", 1, true) ~= nil
		for segment in string.gmatch(dir, "[^/\\]+") do
			if accumulated == "" then
				accumulated = segment
			elseif useBackslash then
				accumulated = accumulated .. "\\" .. segment
			else
				accumulated = accumulated .. "/" .. segment
			end
			if not isfolder(accumulated) then
				makefolder(accumulated)
			end
		end
	end)

	return dir
end

_G.F.getConfigFilePath = function(fileName)
	local dir = _G.F.ensureConfigDirectory()
	if string.find(dir, "\\", 1, true) then
		return dir .. "\\" .. fileName
	end
	return dir .. "/" .. fileName
end

_G.F.getGoppieFormesText = function()
	if #_G.GOPPIE_FORMES == 0 then
		return ""
	end

	return table.concat(_G.GOPPIE_FORMES, ", ")
end

_G.F.syncGoppieFormesTextbox = function()
	if not _G.goppieFormesTextbox then
		return
	end

	local text = _G.F.getGoppieFormesText()
	if type(_G.goppieFormesTextbox.Set) == "function" then
		_G.goppieFormesTextbox:Set(text)
	elseif _G.goppieFormesTextbox.Instance then
		pcall(function()
			_G.goppieFormesTextbox.Instance.Text = text
		end)
	end
end

_G.F.saveGoppieFormesToFile = function(silent)
	if not writefile then
		if not silent then
			warn("[Goppie Formes] writefile is not available in this executor.")
		end
		return false, "writefile unavailable"
	end

	_G.F.ensureConfigDirectory()

	local payload = {
		version = 1,
		formes = _G.GOPPIE_FORMES,
	}

	local ok, encoded = pcall(function()
		return _G.HttpService:JSONEncode(payload)
	end)
	if not ok then
		if not silent then
			warn("[Goppie Formes] Failed to encode save data.")
		end
		return false, "encode failed"
	end

	local path = _G.F.getConfigFilePath(_G.GOPPIE_FORMES_FILE)
	local writeOk, writeErr = pcall(function()
		writefile(path, encoded)
	end)
	if not writeOk then
		if not silent then
			warn("[Goppie Formes] Failed to save: " .. tostring(writeErr))
		end
		return false, tostring(writeErr)
	end

	if not silent then
		pcall(function()
			_G.OrionLib:MakeNotification({
				Name = "Goppie Formes",
				Content = "Saved to " .. path,
				Time = 4,
			})
		end)
	end

	return true
end

_G.F.loadGoppieFormesFromFile = function()
	if not readfile or not isfile then
		return false
	end

	local path = _G.F.getConfigFilePath(_G.GOPPIE_FORMES_FILE)
	if not isfile(path) then
		return false
	end

	local readOk, contents = pcall(function()
		return readfile(path)
	end)
	if not readOk or type(contents) ~= "string" or contents == "" then
		return false
	end

	local decodeOk, data = pcall(function()
		return _G.HttpService:JSONDecode(contents)
	end)
	if not decodeOk or type(data) ~= "table" then
		return false
	end

	local formes = data.formes
	if type(formes) ~= "table" then
		return false
	end

	_G.GOPPIE_FORMES = {}
	for _, entry in ipairs(formes) do
		if _G.F.isMeaningfulFormeValue(entry) then
			table.insert(_G.GOPPIE_FORMES, tostring(entry))
		end
	end

	_G.F.rebuildExcludedFormes()
	return true
end

_G.F.setGoppieFormesFromText = function(text)
	local entries = {}

	for part in string.gmatch(tostring(text or ""), "[^,]+") do
		local trimmed = string.gsub(part, "^%s*(.-)%s*$", "%1")
		if trimmed ~= "" then
			table.insert(entries, trimmed)
		end
	end

	_G.GOPPIE_FORMES = entries
	_G.F.rebuildExcludedFormes()
	_G.F.saveGoppieFormesToFile(true)
end

_G.F.addGoppieForme = function(value)
	if not _G.F.isMeaningfulFormeValue(value) then
		return false
	end

	if _G.F.isGoppieFormeSaved(value) then
		return false
	end

	table.insert(_G.GOPPIE_FORMES, tostring(value))
	_G.F.rebuildExcludedFormes()
	local saved = _G.F.saveGoppieFormesToFile(true)
	_G.F.syncGoppieFormesTextbox()
	if not saved then
		warn("[Goppie Formes] Added " .. tostring(value) .. " in memory but file save failed.")
	end
	return true
end

_G.F.registerCaughtGoppieFormeFromBattle = function(battle)
	if type(battle) ~= "table" then
		return false
	end

	local foe = _G.F.getBattleFoeMonster(battle)
	local formeValue = _G.F.getFishingGoppieFormeValue(battle)
	if not _G.F.isMeaningfulFormeValue(formeValue) then
		return false
	end

	if not _G.F.isGoppieMonster(foe) and not _G.F.isFishingGoppieBattle(battle) then
		return false
	end

	_G.lastAutoFishingGoppieForme = formeValue
	_G.lastAutoFishingGoppieFormeAt = os.clock()

	if _G.F.isGoppieFormeSaved(formeValue) then
		return true
	end

	local added = _G.F.addGoppieForme(formeValue)
	if added then
		pcall(function()
			_G.OrionLib:MakeNotification({
				Name = "Goppie Formes",
				Content = "Saved caught forme: " .. tostring(formeValue),
				Time = 4,
			})
		end)
	end

	return added
end

_G.F.setToggleUi = function(toggle, value)
	if type(toggle) == "table" and type(toggle.Set) == "function" then
		toggle:Set(value and true or false)
	end
end

_G.F.setSliderUi = function(slider, value)
	if type(slider) == "table" and type(slider.Set) == "function" then
		slider:Set(tonumber(value) or slider.Value)
	end
end

_G.F.configBool = function(value, fallback)
	if value == nil then
		return fallback and true or false
	end
	if type(value) == "boolean" then
		return value
	end
	if type(value) == "number" then
		return value ~= 0
	end
	if type(value) == "string" then
		local normalized = string.lower(value)
		if normalized == "true" or normalized == "1" or normalized == "yes" or normalized == "on" then
			return true
		end
		if normalized == "false" or normalized == "0" or normalized == "no" or normalized == "off" then
			return false
		end
	end
	return fallback and true or false
end

_G.F.getToggleConfigValue = function(toggle, fallback)
	if type(toggle) == "table" and toggle.Value ~= nil then
		return toggle.Value and true or false
	end
	return fallback and true or false
end

_G.F.collectConfigSnapshot = function()
	return {
		version = _G.CONFIG_VERSION,
		profile = _G.configProfileName,
		staticInteractTarget = _G.staticInteractTarget,
		beastTarget = _G.F.getSelectedBeastName(),
		autoStaticEnabled = _G.F.getToggleConfigValue(_G.configUi.autoStaticToggle, StaticAutomation and StaticAutomation:isEnabled() or false),
		autoArcerosEnabled = _G.F.getToggleConfigValue(_G.configUi.autoArcerosToggle, _G.arcerosAutoEnabled),
		trainerId = _G.trainerId,
		autoTrainerEnabled = _G.F.getToggleConfigValue(_G.configUi.autoTrainerToggle, _G.autoTrainerEnabled),
		autoTrainerDelay = _G.autoTrainerDelay,
		autoMoveOneEnabled = _G.F.getToggleConfigValue(_G.configUi.autoMoveOneToggle, _G.autoMoveOneEnabled),
		autoMoveOneDelay = _G.autoMoveOneDelay,
		autoMoveSlot = _G.autoMoveSlot,
		autoRallyEnabled = _G.F.getToggleConfigValue(_G.configUi.autoRallyToggle, _G.autoRallyEnabled),
		rallyDelay = _G.rallyDelay,
		keepGleaming = _G.F.getToggleConfigValue(_G.configUi.keepGleamingToggle, _G.keepGleaming),
		keepSecretAbility = _G.F.getToggleConfigValue(_G.configUi.keepSecretAbilityToggle, _G.keepSecretAbility),
		keepAll = _G.F.getToggleConfigValue(_G.configUi.keepAllToggle, _G.keepAll),
		alwaysKeepText = _G.alwaysKeepText,
		autoEncounterEnabled = _G.F.getToggleConfigValue(_G.configUi.autoEncounterToggle, _G.autoEncounterEnabled),
		encounterTargetLoomian = _G.encounterTargetLoomian,
		autoEncounterDelay = _G.autoEncounterDelay,
		autoCatchEnabled = _G.F.getToggleConfigValue(_G.configUi.autoCatchToggle, _G.autoCatchEnabled),
		autoCatchDisc = _G.autoCatchDisc,
		stopOnGleaming = _G.F.getToggleConfigValue(_G.configUi.stopOnGleamingToggle, _G.stopOnGleaming),
		stopOnGamma = _G.F.getToggleConfigValue(_G.configUi.stopOnGammaToggle, _G.stopOnGamma),
		stopOnWisp = _G.F.getToggleConfigValue(_G.configUi.stopOnWispToggle, _G.stopOnWisp),
		autoFossilEnabled = _G.F.getToggleConfigValue(_G.configUi.autoFossilToggle, _G.autoFossilEnabled),
		autoFossilDelay = _G.autoFossilDelay,
		autoDiscDropEnabled = _G.F.getToggleConfigValue(_G.configUi.autoDiscDropToggle, _G.autoDiscDropEnabled),
		discDropHighScore = _G.discDropHighScore,
		autoBoonaryEnabled = _G.F.getToggleConfigValue(_G.configUi.autoBoonaryToggle, _G.autoBoonaryEnabled),
		autoBoonaryTixThreshold = _G.autoBoonaryTixThreshold,
		autoBoonaryGroup = _G.autoBoonaryGroup,
		autoEggRainEnabled = _G.F.getToggleConfigValue(_G.configUi.autoEggRainToggle, _G.autoEggRainEnabled),
		autoEggRainDelay = _G.autoEggRainDelay,
		wallSparkleUmvEnabled = _G.F.getToggleConfigValue(_G.configUi.wallSparkleUmvToggle, _G.wallSparkleUmvEnabled),
		umvMiningRevealEnabled = _G.F.getToggleConfigValue(_G.configUi.umvMiningRevealToggle, _G.umvMiningRevealEnabled),
		remoteSparkleMineEnabled = _G.F.getToggleConfigValue(_G.configUi.remoteSparkleMineToggle, _G.remoteSparkleMineEnabled),
		autoFishingEnabled = _G.F.getToggleConfigValue(_G.configUi.autoFishingToggle, _G.autoFishingEnabled),
		autoFishingDelay = _G.autoFishingDelay,
		fastForwardEnabled = _G.F.getToggleConfigValue(_G.configUi.fastForwardToggle, _G.fastForwardEnabled),
		ctrlClickTpEnabled = _G.F.getToggleConfigValue(_G.configUi.ctrlClickTpToggle, _G.ctrlClickTpEnabled),
		antiAfkEnabled = _G.F.getToggleConfigValue(_G.configUi.antiAfkToggle, _G.antiAfkEnabled),
	}
end

_G.F.applyConfigVariables = function(data)
	if type(data) ~= "table" then
		return false, "Invalid config data."
	end

	if data.autoStaticEnabled ~= nil and StaticAutomation then
		StaticAutomation:setEnabled(_G.F.configBool(data.autoStaticEnabled, false))
	end

	if data.autoArcerosEnabled ~= nil then
		_G.arcerosAutoEnabled = _G.F.configBool(data.autoArcerosEnabled, false)
	end

	if data.beastTarget ~= nil and _G.BEAST_HUNTS[tostring(data.beastTarget)] then
		_G.beastTarget = tostring(data.beastTarget)
	end

	if data.staticInteractTarget ~= nil then
		_G.staticInteractTarget = string.gsub(tostring(data.staticInteractTarget), "^%s*(.-)%s*$", "%1")
	end

	if data.trainerId ~= nil then
		local parsed = tonumber(data.trainerId)
		if parsed then
			_G.trainerId = math.floor(parsed)
		end
	end

	if data.autoTrainerEnabled ~= nil then
		_G.autoTrainerEnabled = _G.F.configBool(data.autoTrainerEnabled, false)
	end

	if data.autoTrainerDelay ~= nil then
		_G.autoTrainerDelay = tonumber(data.autoTrainerDelay) or _G.autoTrainerDelay
	end

	if data.autoMoveOneEnabled ~= nil then
		_G.autoMoveOneEnabled = _G.F.configBool(data.autoMoveOneEnabled, false)
	end

	if data.autoMoveOneDelay ~= nil then
		_G.autoMoveOneDelay = tonumber(data.autoMoveOneDelay) or _G.autoMoveOneDelay
	end

	if data.autoMoveSlot ~= nil then
		_G.F.setAutoMoveSlot(data.autoMoveSlot)
	end

	if data.autoRallyEnabled ~= nil then
		_G.autoRallyEnabled = _G.F.configBool(data.autoRallyEnabled, false)
	end

	if data.rallyDelay ~= nil then
		_G.rallyDelay = tonumber(data.rallyDelay) or _G.rallyDelay
	end

	if data.keepGleaming ~= nil then
		_G.keepGleaming = _G.F.configBool(data.keepGleaming, _G.keepGleaming)
	end

	if data.keepSecretAbility ~= nil then
		_G.keepSecretAbility = _G.F.configBool(data.keepSecretAbility, _G.keepSecretAbility)
	end

	if data.keepAll ~= nil then
		_G.keepAll = _G.F.configBool(data.keepAll, _G.keepAll)
	end

	if data.alwaysKeepText ~= nil then
		_G.F.setAlwaysKeepList(data.alwaysKeepText)
	end

	if data.autoEncounterEnabled ~= nil then
		_G.F.setAutoEncounterEnabled(_G.F.configBool(data.autoEncounterEnabled, false))
	end

	if data.encounterTargetLoomian ~= nil then
		_G.encounterTargetLoomian = string.gsub(tostring(data.encounterTargetLoomian), "^%s*(.-)%s*$", "%1")
	end

	if data.autoEncounterDelay ~= nil then
		_G.autoEncounterDelay = tonumber(data.autoEncounterDelay) or _G.autoEncounterDelay
	end

	if data.autoCatchEnabled ~= nil then
		_G.F.setAutoCatchEnabled(_G.F.configBool(data.autoCatchEnabled, false))
	end

	if data.autoCatchDisc ~= nil then
		_G.autoCatchDisc = string.gsub(tostring(data.autoCatchDisc), "^%s*(.-)%s*$", "%1")
	end

	if data.stopOnGleaming ~= nil then
		_G.stopOnGleaming = _G.F.configBool(data.stopOnGleaming, _G.stopOnGleaming)
	end

	if data.stopOnGamma ~= nil then
		_G.stopOnGamma = _G.F.configBool(data.stopOnGamma, _G.stopOnGamma)
	end

	if data.stopOnWisp ~= nil then
		_G.stopOnWisp = _G.F.configBool(data.stopOnWisp, _G.stopOnWisp)
	end

	if data.autoFossilEnabled ~= nil then
		_G.autoFossilEnabled = _G.F.configBool(data.autoFossilEnabled, false)
	end

	if data.autoFossilDelay ~= nil then
		_G.autoFossilDelay = tonumber(data.autoFossilDelay) or _G.autoFossilDelay
	end

	if data.autoDiscDropEnabled ~= nil then
		_G.autoDiscDropEnabled = _G.F.configBool(data.autoDiscDropEnabled, false)
	end

	if data.discDropHighScore ~= nil then
		local parsed = tonumber(data.discDropHighScore)
		if parsed and parsed >= 0 then
			_G.discDropHighScore = math.floor(parsed)
		end
	end

	if data.autoBoonaryEnabled ~= nil then
		_G.F.setAutoBoonaryEnabled(_G.F.configBool(data.autoBoonaryEnabled, false))
	end

	if data.autoBoonaryTixThreshold ~= nil then
		local parsed = tonumber(data.autoBoonaryTixThreshold)
		if parsed and parsed > 0 then
			_G.autoBoonaryTixThreshold = math.floor(parsed)
		end
	end

	if data.autoBoonaryGroup ~= nil then
		local parsed = tonumber(data.autoBoonaryGroup)
		if parsed and parsed > 0 then
			_G.autoBoonaryGroup = math.floor(parsed)
		end
	end

	if data.autoEggRainEnabled ~= nil then
		_G.autoEggRainEnabled = _G.F.configBool(data.autoEggRainEnabled, false)
	end


	if data.autoFishingEnabled ~= nil then
		_G.F.setAutoFishingEnabled(_G.F.configBool(data.autoFishingEnabled, false))
	end

	if data.autoFishingDelay ~= nil then
		_G.autoFishingDelay = tonumber(data.autoFishingDelay) or _G.autoFishingDelay
	end

	if data.autoEggRainDelay ~= nil then
		_G.autoEggRainDelay = tonumber(data.autoEggRainDelay) or _G.autoEggRainDelay
	end

	if data.wallSparkleUmvEnabled ~= nil then
		_G.F.setWallSparkleUmvEnabled(_G.F.configBool(data.wallSparkleUmvEnabled, false))
	end

	if data.umvMiningRevealEnabled ~= nil then
		_G.F.setUmvMiningRevealEnabled(_G.F.configBool(data.umvMiningRevealEnabled, false))
	end

	if data.remoteSparkleMineEnabled ~= nil then
		_G.F.setRemoteSparkleMineEnabled(_G.F.configBool(data.remoteSparkleMineEnabled, false))
	elseif data.remoteMineClickEnabled ~= nil then
		_G.F.setRemoteSparkleMineEnabled(_G.F.configBool(data.remoteMineClickEnabled, false))
	end

	if data.fastForwardEnabled ~= nil then
		_G.F.setFastForwardEnabled(_G.F.configBool(data.fastForwardEnabled, false))
	end

	if data.ctrlClickTpEnabled ~= nil then
		_G.F.setCtrlClickTpEnabled(_G.F.configBool(data.ctrlClickTpEnabled, false))
	end

	if data.antiAfkEnabled ~= nil then
		_G.F.setAntiAfkEnabled(_G.F.configBool(data.antiAfkEnabled, false))
	end

	return true
end

_G.F.syncConfigUiFromVariables = function()
	if not _G.configUi.autoStaticToggle then
		return
	end

	_G.applyingConfig = true
	_G.F.setToggleUi(_G.configUi.autoStaticToggle, StaticAutomation:isEnabled())
	if _G.configUi.autoArcerosToggle then
		_G.F.setToggleUi(_G.configUi.autoArcerosToggle, _G.arcerosAutoEnabled)
	end
	if _G.configUi.beastTargetDropdown and type(_G.configUi.beastTargetDropdown.Set) == "function" then
		pcall(function()
			_G.configUi.beastTargetDropdown:Set(_G.F.getSelectedBeastName())
		end)
	end
	_G.F.setToggleUi(_G.configUi.autoTrainerToggle, _G.autoTrainerEnabled)
	_G.F.setSliderUi(_G.configUi.autoTrainerDelay, _G.autoTrainerDelay)
	_G.F.setToggleUi(_G.configUi.autoMoveOneToggle, _G.autoMoveOneEnabled)
	_G.F.setSliderUi(_G.configUi.autoMoveOneDelay, _G.autoMoveOneDelay)
	_G.F.setAutoMoveSlot(_G.autoMoveSlot)
	_G.F.setToggleUi(_G.configUi.autoRallyToggle, _G.autoRallyEnabled)
	_G.F.setSliderUi(_G.configUi.rallyDelay, _G.rallyDelay)
	_G.F.setToggleUi(_G.configUi.keepGleamingToggle, _G.keepGleaming)
	_G.F.setToggleUi(_G.configUi.keepSecretAbilityToggle, _G.keepSecretAbility)
	_G.F.setToggleUi(_G.configUi.keepAllToggle, _G.keepAll)
	_G.F.setToggleUi(_G.configUi.autoEncounterToggle, _G.autoEncounterEnabled)
	_G.F.setSliderUi(_G.configUi.encounterDelay, _G.autoEncounterDelay)
	_G.F.setToggleUi(_G.configUi.autoCatchToggle, _G.autoCatchEnabled)
	_G.F.setToggleUi(_G.configUi.stopOnGleamingToggle, _G.stopOnGleaming)
	_G.F.setToggleUi(_G.configUi.stopOnGammaToggle, _G.stopOnGamma)
	_G.F.setToggleUi(_G.configUi.stopOnWispToggle, _G.stopOnWisp)
	_G.F.setToggleUi(_G.configUi.autoFossilToggle, _G.autoFossilEnabled)
	_G.F.setSliderUi(_G.configUi.autoFossilDelay, _G.autoFossilDelay)
	if _G.configUi.autoDiscDropToggle then
		_G.F.setToggleUi(_G.configUi.autoDiscDropToggle, _G.autoDiscDropEnabled)
	end
	if ArcadeAutomation then
		ArcadeAutomation:refreshStats()
	end
	if _G.configUi.autoBoonaryToggle then
		_G.F.setToggleUi(_G.configUi.autoBoonaryToggle, _G.autoBoonaryEnabled)
	end
	_G.F.setToggleUi(_G.configUi.autoEggRainToggle, _G.autoEggRainEnabled)
	_G.F.setSliderUi(_G.configUi.autoEggRainDelay, _G.autoEggRainDelay)
	if _G.configUi.wallSparkleUmvToggle then
		_G.F.setToggleUi(_G.configUi.wallSparkleUmvToggle, _G.wallSparkleUmvEnabled)
	end
	if _G.configUi.umvMiningRevealToggle then
		_G.F.setToggleUi(_G.configUi.umvMiningRevealToggle, _G.umvMiningRevealEnabled)
	end
	if _G.configUi.remoteSparkleMineToggle then
		_G.F.setToggleUi(_G.configUi.remoteSparkleMineToggle, _G.remoteSparkleMineEnabled)
	end
	_G.F.refreshWallSparkleUmvUi()
	_G.F.refreshUmvMiningUi()
	if _G.configUi.fastForwardToggle then
		_G.F.setToggleUi(_G.configUi.fastForwardToggle, _G.fastForwardEnabled)
	end
	if _G.configUi.autoFishingToggle then
		_G.F.setToggleUi(_G.configUi.autoFishingToggle, _G.autoFishingEnabled)
	end
	if _G.configUi.ctrlClickTpToggle then
		_G.F.setToggleUi(_G.configUi.ctrlClickTpToggle, _G.ctrlClickTpEnabled)
	end
	if _G.configUi.antiAfkToggle then
		_G.F.setToggleUi(_G.configUi.antiAfkToggle, _G.antiAfkEnabled)
	end
	_G.F.syncGoppieFormesTextbox()
	_G.applyingConfig = false
end

_G.F.readConfigDataFromFile = function(fileName)
	if not readfile or not isfile then
		return nil
	end

	local path = _G.F.getConfigFilePath(fileName)
	if not isfile(path) then
		return nil
	end

	local readOk, contents = pcall(function()
		return readfile(path)
	end)
	if not readOk or type(contents) ~= "string" or contents == "" then
		return nil
	end

	local decodeOk, data = pcall(function()
		return _G.HttpService:JSONDecode(contents)
	end)
	if decodeOk and type(data) == "table" then
		return data
	end

	return nil
end

_G.F.applyConfigSnapshot = function(data, syncUi)
	if type(data) ~= "table" then
		return false, "Invalid config data."
	end

	if data.profile then
		_G.configProfileName = _G.F.sanitizeConfigName(data.profile)
	end

	local applied, applyErr = _G.F.applyConfigVariables(data)
	if not applied then
		return false, applyErr
	end

	if syncUi then
		_G.F.syncConfigUiFromVariables()
	end

	return true
end

_G.F.saveConfigToFile = function(fileName, snapshot, silent)
	if not writefile then
		if not silent then
			_G.OrionLib:MakeNotification({
				Name = "Config",
				Content = "File save is not supported in this environment.",
				Time = 4,
			})
		end
		return false, "writefile unavailable"
	end

	local payload = snapshot or _G.F.collectConfigSnapshot()
	local ok, encoded = pcall(function()
		return _G.HttpService:JSONEncode(payload)
	end)
	if not ok then
		if not silent then
			_G.OrionLib:MakeNotification({
				Name = "Config",
				Content = "Failed to encode config.",
				Time = 4,
			})
		end
		return false, "encode failed"
	end

	local path = _G.F.getConfigFilePath(fileName)
	local writeOk, writeErr = pcall(function()
		writefile(path, encoded)
	end)
	if not writeOk then
		if not silent then
			_G.OrionLib:MakeNotification({
				Name = "Config",
				Content = "Failed to save config.",
				Time = 4,
			})
		end
		return false, tostring(writeErr)
	end

	if not silent then
		_G.OrionLib:MakeNotification({
			Name = "Config",
			Content = "Saved to " .. path,
			Time = 4,
		})
	end

	return true
end

_G.F.loadConfigFromFile = function(fileName, silent)
	if not readfile or not isfile then
		if not silent then
			_G.OrionLib:MakeNotification({
				Name = "Config",
				Content = "File load is not supported in this environment.",
				Time = 4,
			})
		end
		return false, "readfile unavailable"
	end

	local path = _G.F.getConfigFilePath(fileName)
	if not isfile(path) then
		if not silent then
			_G.OrionLib:MakeNotification({
				Name = "Config",
				Content = "Config file not found.",
				Time = 4,
			})
		end
		return false, "not found"
	end

	local readOk, contents = pcall(function()
		return readfile(path)
	end)
	if not readOk or type(contents) ~= "string" or contents == "" then
		if not silent then
			_G.OrionLib:MakeNotification({
				Name = "Config",
				Content = "Failed to read config.",
				Time = 4,
			})
		end
		return false, "read failed"
	end

	local decodeOk, data = pcall(function()
		return _G.HttpService:JSONDecode(contents)
	end)
	if not decodeOk or type(data) ~= "table" then
		if not silent then
			_G.OrionLib:MakeNotification({
				Name = "Config",
				Content = "Config file is invalid.",
				Time = 4,
			})
		end
		return false, "invalid json"
	end

	if data.profile then
		_G.configProfileName = _G.F.sanitizeConfigName(data.profile)
	end

	local applyOk, applyErr = _G.F.applyConfigSnapshot(data, true)
	if not applyOk then
		if not silent then
			_G.OrionLib:MakeNotification({
				Name = "Config",
				Content = applyErr or "Failed to apply config.",
				Time = 4,
			})
		end
		return false, applyErr
	end

	if not silent then
		_G.OrionLib:MakeNotification({
			Name = "Config",
			Content = "Loaded from " .. path,
			Time = 4,
		})
	end

	return true
end

_G.startupConfig = _G.F.readConfigDataFromFile(_G.CONFIG_AUTOSAVE_FILE)
_G.F.loadGoppieFormesFromFile()
task.defer(function()
	_G.F.installGoppieCaptureNetworkHook()
end)
if _G.startupConfig then
	if _G.startupConfig.profile then
		_G.configProfileName = _G.F.sanitizeConfigName(_G.startupConfig.profile)
	end
end

_G.Window = _G.OrionLib:MakeWindow({
	Name = "LLSPLOIT",
	HidePremium = true,
	SaveConfig = false,
	IntroEnabled = false,
	CloseCallback = function()
		_G.uiAlive = false
		_G.F.disableAllFeatures()
	end
})

_G.InformationTab = _G.Window:MakeTab({ Name = "Information", Icon = "info" })
_G.EncountersTab = _G.Window:MakeTab({ Name = "Encounters", Icon = "activity" })
_G.TrainersTab = _G.Window:MakeTab({ Name = "Trainers", Icon = "swords" })
_G.StaticTab = _G.Window:MakeTab({ Name = "Static", Icon = "zap" })
_G.RallyTab = _G.Window:MakeTab({ Name = "Rally", Icon = "repeat" })
_G.FishingTab = _G.Window:MakeTab({ Name = "Fishing", Icon = "waves" })
_G.ArcadeTab = _G.Window:MakeTab({ Name = "Arcade", Icon = "gamepad-2" })
_G.ShopTab = _G.Window:MakeTab({ Name = "Shop", Icon = "shopping-bag" })
_G.UmvTab = _G.Window:MakeTab({ Name = "UMV", Icon = "eye" })
_G.EggRainTab = _G.Window:MakeTab({ Name = "Egg Rain", Icon = "cloud-rain" })
_G.SettingsTab = _G.Window:MakeTab({ Name = "Settings", Icon = "settings" })

local informationCurrencySection = _G.InformationTab:AddSection({ Name = "Currencies" })
_G.informationLabels.money = informationCurrencySection:AddLabel("Money: N/A")
_G.informationLabels.tix = informationCurrencySection:AddLabel("Tix: N/A")
_G.informationLabels.bp = informationCurrencySection:AddLabel("BP: N/A")

local informationStatusSection = _G.InformationTab:AddSection({ Name = "Status" })
_G.informationLabels.status = informationStatusSection:AddLabel("Loaded: 0/3")
informationStatusSection:AddButton({
	Name = "Refresh Information",
	Icon = "refresh-cw",
	Callback = function()
		_G.F.refreshInformationLabels()
	end
})
_G.F.refreshInformationLabels()

local informationBoonarySection = _G.InformationTab:AddSection({ Name = "Tix Boonary Automation" })
_G.autoBoonaryStatusLabel = informationBoonarySection:AddLabel("Idle")

_G.configUi.autoBoonaryToggle = informationBoonarySection:AddToggle({
	Name = "Auto Boonary at Tix Cap",
	Default = _G.autoBoonaryEnabled,
	Color = Color3.fromRGB(255, 190, 85),
	Callback = function(value)
		_G.F.setAutoBoonaryEnabled(value)
	end
})

informationBoonarySection:AddTextbox({
	Name = "Tix Threshold",
	Default = tostring(_G.autoBoonaryTixThreshold),
	TextDisappear = false,
	Callback = function(value)
		local parsed = tonumber((tostring(value or ""):gsub(",", "")))
		if parsed and parsed > 0 then
			_G.autoBoonaryTixThreshold = math.floor(parsed)
		else
			_G.OrionLib:MakeNotification({ Name = "Auto Boonary", Content = "Type a numeric Tix threshold.", Time = 4 })
		end
	end
})

informationBoonarySection:AddTextbox({
	Name = "PC Group",
	Default = tostring(_G.autoBoonaryGroup),
	TextDisappear = false,
	Callback = function(value)
		local parsed = tonumber(value)
		if parsed and parsed > 0 then
			_G.autoBoonaryGroup = math.floor(parsed)
		else
			_G.OrionLib:MakeNotification({ Name = "Auto Boonary", Content = "Type a numeric PC group.", Time = 4 })
		end
	end
})

informationBoonarySection:AddButton({
	Name = "Max Buy Boonary",
	Icon = "shopping-cart",
	Callback = function()
		task.spawn(function()
			local ok, reason = _G.F.purchaseMaxArcadeBoonarys()
			if ok then
				_G.OrionLib:MakeNotification({ Name = "Max Buy Boonary", Content = "Purchase succeeded.", Time = 4 })
			else
				_G.OrionLib:MakeNotification({ Name = "Max Buy Boonary", Content = tostring(reason), Time = 6 })
			end
		end)
	end
})

informationBoonarySection:AddButton({
	Name = "Run Boonary Cycle Now",
	Icon = "play",
	Callback = function()
		task.spawn(function()
			local ok, reason = _G.F.runAutoBoonaryCycle()
			if not ok and reason then
				_G.OrionLib:MakeNotification({ Name = "Auto Boonary", Content = tostring(reason), Time = 5 })
			end
		end)
	end
})

informationBoonarySection:AddButton({
	Name = "Release Non-Gleam Boonarys Now",
	Icon = "trash",
	Callback = function()
		task.spawn(function()
			local callOk, ok, reason = pcall(function()
				return _G.F.cleanBoonaryPcBoxes(false)
			end)
			if not callOk then
				_G.OrionLib:MakeNotification({ Name = "Boonary Sweep", Content = tostring(ok), Time = 6 })
				return
			end
			_G.OrionLib:MakeNotification({ Name = "Boonary Sweep", Content = tostring(reason), Time = 6 })
		end)
	end
})

informationBoonarySection:AddButton({
	Name = "Print Boonary Preview",
	Icon = "terminal",
	Callback = function()
		task.spawn(function()
			local callOk, ok, reason = pcall(function()
				-- Dry-run the direct PC session sweep first; fall back to the
				-- legacy heuristic preview if no session is available.
				local sweepOk, sweepReason = _G.F.cleanBoonaryPcBoxes(true)
				if sweepOk then
					return sweepOk, sweepReason
				end
				print("[Auto Boonary Preview] PC session unavailable (" .. tostring(sweepReason) .. "); using legacy scan.")
				return _G.F.printBoonaryStoragePreview(_G.autoBoonaryGroup)
			end)

			if not callOk then
				print("[Auto Boonary Preview] ERROR: " .. tostring(ok))
				_G.F.setAutoBoonaryStatus("Preview error: " .. tostring(ok))
				_G.OrionLib:MakeNotification({ Name = "Auto Boonary Preview", Content = tostring(ok), Time = 5 })
				return
			end

			if not ok and reason then
				_G.OrionLib:MakeNotification({ Name = "Auto Boonary Preview", Content = tostring(reason), Time = 5 })
			end
		end)
	end
})

_G.StaticTab:AddSection({ Name = "Static Hunt" })

_G.configUi.autoStaticToggle = _G.StaticTab:AddToggle({
	Name = "Auto Static",
	Default = StaticAutomation:isEnabled(),
	Color = Color3.fromRGB(80, 185, 255),
	Callback = function(value)
		StaticAutomation:setEnabled(value)
		if value and _G.arcerosAutoEnabled and _G.configUi.autoArcerosToggle then
			_G.arcerosAutoEnabled = false
			pcall(function()
				_G.configUi.autoArcerosToggle:Set(false)
			end)
		end
	end
})
StaticAutomation:attachToggle(_G.configUi.autoStaticToggle)
StaticAutomation:attachStatsLabel(_G.StaticTab:AddLabel("Soft Resets: 0"))

_G.StaticTab:AddTextbox({
	Name = "Interact Target",
	Default = _G.staticInteractTarget,
	TextDisappear = false,
	Callback = function(value)
		_G.staticInteractTarget = string.gsub(tostring(value or ""), "^%s*(.-)%s*$", "%1")
	end
})

_G.StaticTab:AddButton({
	Name = "Interact Now",
	Icon = "zap",
	Callback = function()
		local started, reason = StaticAutomation:startInteraction()
		if not started and reason then
			_G.OrionLib:MakeNotification({ Name = "Static", Content = reason, Time = 4 })
		end
	end
})

_G.StaticTab:AddSection({ Name = "Beasts of Judgement" })

_G.configUi.beastTargetDropdown = _G.StaticTab:AddDropdown({
	Name = "Beast",
	Options = { "Arceros", "Glacadia" },
	Default = _G.F.getSelectedBeastName(),
	Callback = function(value)
		if _G.BEAST_HUNTS[tostring(value)] then
			_G.beastTarget = tostring(value)
		end
	end
})

_G.configUi.autoArcerosToggle = _G.StaticTab:AddToggle({
	Name = "Auto Beast Soft Reset",
	Default = _G.arcerosAutoEnabled,
	Color = Color3.fromRGB(255, 120, 60),
	Callback = function(value)
		_G.arcerosAutoEnabled = value and true or false
		if value then
			if StaticAutomation and StaticAutomation:isEnabled() and _G.configUi.autoStaticToggle then
				StaticAutomation:setEnabled(false)
				pcall(function()
					_G.configUi.autoStaticToggle:Set(false)
				end)
			end
		elseif StaticAutomation and not StaticAutomation:isEnabled() then
			StaticAutomation:setEnabled(false)
		end
	end
})

_G.arcerosStatsLabel = _G.StaticTab:AddLabel("Soft Resets: 0")

_G.StaticTab:AddButton({
	Name = "Soft Reset Now",
	Icon = "flame",
	Callback = function()
		local started, reason = StaticAutomation:startInteraction("arceros")
		if not started and reason then
			_G.OrionLib:MakeNotification({ Name = _G.F.getSelectedBeastName(), Content = reason, Time = 4 })
		end
	end
})

_G.StaticTab:AddButton({
	Name = "Walk to Soft Reset Trigger",
	Icon = "footprints",
	Callback = function()
		if not StaticAutomation then
			return
		end

		local walked, reason = StaticAutomation:walkToArcerosTrigger()
		if not walked and reason then
			_G.OrionLib:MakeNotification({ Name = _G.F.getSelectedBeastName(), Content = reason, Time = 4 })
		elseif not _G.F.getSelectedBeastTrigger() then
			_G.OrionLib:MakeNotification({
				Name = _G.F.getSelectedBeastName(),
				Content = "Soft reset trigger not found. Go to the Beasts of Judgement chamber first.",
				Time = 4
			})
		end
	end
})

_G.StaticTab:AddButton({
	Name = "Reset Stats",
	Icon = "rotate-ccw",
	Callback = function()
		if StaticAutomation then
			StaticAutomation:resetStats()
		end
	end
})

_G.configUi.autoTrainerToggle = _G.TrainersTab:AddToggle({
	Name = "Auto Trainer",
	Default = _G.autoTrainerEnabled,
	Color = Color3.fromRGB(170, 110, 255),
	Callback = function(value) _G.autoTrainerEnabled = value end
})

_G.TrainersTab:AddTextbox({
	Name = "Trainer ID",
	Default = tostring(_G.trainerId),
	TextDisappear = false,
	Callback = function(value)
		local parsed = tonumber(value)
		if parsed then
			_G.trainerId = math.floor(parsed)
		else
			_G.OrionLib:MakeNotification({ Name = "Invalid Trainer ID", Content = "Type a numeric trainer ID.", Time = 4 })
		end
	end
})

_G.configUi.autoTrainerDelay = _G.TrainersTab:AddSlider({
	Name = "Auto Trainer Delay",
	Min = 0.5, Max = 10, Increment = 0.1,
	Default = _G.autoTrainerDelay, ValueName = "s",
	Callback = function(value) _G.autoTrainerDelay = value end
})

_G.TrainersTab:AddButton({
	Name = "Start Trainer Now",
	Icon = "swords",
	Callback = function()
		local started, reason = _G.F.startAutoTrainer()
		if not started and reason then
			_G.OrionLib:MakeNotification({ Name = "Auto Trainer", Content = reason, Time = 4 })
		end
	end
})

_G.configUi.autoMoveOneToggle = _G.TrainersTab:AddToggle({
	Name = "Auto Use Move",
	Default = _G.autoMoveOneEnabled,
	Color = Color3.fromRGB(255, 205, 75),
	Callback = function(value)
		_G.autoMoveOneEnabled = value
		if not value then
			_G.lastAutoMoveOneRequest = nil
			_G.pendingAutoMoveOneRequest = nil
			_G.pendingAutoMoveOneAt = 0
		end
	end
})

for slot = 1, 4 do
	_G.autoMoveSlotToggles[slot] = _G.TrainersTab:AddToggle({
		Name = "Use Move Slot " .. tostring(slot),
		Default = slot == _G.autoMoveSlot,
		Color = Color3.fromRGB(255, 205, 75),
		Callback = function(value)
			if _G.syncingAutoMoveSlotToggles then return end
			if value then
				_G.F.setAutoMoveSlot(slot)
			elseif _G.autoMoveSlot == slot then
				task.defer(function() _G.F.setAutoMoveSlot(slot) end)
			end
		end
	})
end

_G.configUi.autoMoveOneDelay = _G.TrainersTab:AddSlider({
	Name = "Auto Move Delay",
	Min = 0.05, Max = 1, Increment = 0.05,
	Default = _G.autoMoveOneDelay, ValueName = "s",
	Callback = function(value) _G.autoMoveOneDelay = value end
})

_G.configUi.autoRallyToggle = _G.RallyTab:AddToggle({
	Name = "Auto Rally",
	Default = _G.autoRallyEnabled,
	Color = Color3.fromRGB(90, 220, 145),
	Callback = function(value)
		_G.autoRallyEnabled = value
		if value then
			_G.lastRallyActionText = "Auto Rally enabled."
			_G.F.refreshRallyUI()
		end
	end
})

_G.rallyStatsLabel = _G.RallyTab:AddLabel("Kept: 0 | Released: 0")
_G.rallyStatusLabel = _G.RallyTab:AddLabel("Idle")

_G.configUi.keepGleamingToggle = _G.RallyTab:AddToggle({ Name = "Keep Gleaming", Default = _G.keepGleaming, Color = Color3.fromRGB(255, 215, 90), Callback = function(v) _G.keepGleaming = v end })
_G.configUi.keepSecretAbilityToggle = _G.RallyTab:AddToggle({ Name = "Keep Secret Ability", Default = _G.keepSecretAbility, Color = Color3.fromRGB(149, 88, 204), Callback = function(v) _G.keepSecretAbility = v end })
_G.configUi.keepAllToggle = _G.RallyTab:AddToggle({ Name = "Keep All (no releasing)", Default = _G.keepAll, Color = Color3.fromRGB(255, 120, 120), Callback = function(v) _G.keepAll = v end })

_G.RallyTab:AddTextbox({
	Name = "Always Keep (names, comma-separated)",
	Default = _G.alwaysKeepText,
	TextDisappear = false,
	Callback = function(value) _G.F.setAlwaysKeepList(value) end
})

_G.configUi.rallyDelay = _G.RallyTab:AddSlider({
	Name = "Rally Delay",
	Min = 0.5, Max = 10, Increment = 0.5,
	Default = _G.rallyDelay, ValueName = "s",
	Callback = function(value) _G.rallyDelay = value end
})

_G.RallyTab:AddButton({
	Name = "Handle Rally Now",
	Icon = "zap",
	Callback = function()
		local didWork, reason = _G.F.runAutoRally()
		if not didWork and reason then
			_G.OrionLib:MakeNotification({ Name = "Auto Rally", Content = reason, Time = 4 })
		end
	end
})

_G.RallyTab:AddButton({
	Name = "Open Rally Menu",
	Icon = "menu",
	Callback = function()
		local opened, reason = _G.F.openRallyMenu()
		if not opened and reason then
			_G.OrionLib:MakeNotification({ Name = "Rally", Content = reason, Time = 4 })
		end
	end
})

_G.RallyTab:AddButton({
	Name = "Reset Rally Stats",
	Icon = "refresh-cw",
	Callback = function()
		_G.rallyKept = 0
		_G.rallyReleased = 0
		_G.lastRallyActionText = "Stats reset."
		_G.F.refreshRallyUI()
	end
})

_G.configUi.autoEncounterToggle = _G.EncountersTab:AddToggle({
	Name = "Auto Encounter",
	Default = _G.autoEncounterEnabled,
	Color = Color3.fromRGB(0, 190, 180),
	Callback = function(value)
		_G.F.setAutoEncounterEnabled(value)
	end
})

_G.EncountersTab:AddTextbox({
	Name = "Target Loomian",
	Default = _G.encounterTargetLoomian,
	TextDisappear = false,
	Callback = function(value)
		_G.encounterTargetLoomian = string.gsub(tostring(value or ""), "^%s*(.-)%s*$", "%1")
	end
})

_G.configUi.encounterDelay = _G.EncountersTab:AddSlider({
	Name = "Encounter Delay",
	Min = 0.5,
	Max = 6,
	Default = _G.autoEncounterDelay,
	Increment = 0.25,
	ValueName = "s",
	Callback = function(value)
		_G.autoEncounterDelay = value
	end
})



FishingAutomation:attachUi(_G.FishingTab)

_G.configUi.fastForwardToggle = _G.FishingTab:AddToggle({
	Name = "Fast Forward",
	Default = _G.fastForwardEnabled,
	Color = Color3.fromRGB(255, 170, 70),
	Callback = function(value)
		_G.F.setFastForwardEnabled(value)
	end
})

_G.goppieFormesTextbox = _G.FishingTab:AddTextbox({
	Name = "Goppie Formes",
	Default = _G.F.getGoppieFormesText(),
	TextDisappear = false,
	Callback = function(value)
		_G.F.setGoppieFormesFromText(value)
	end
})

task.defer(function()
	_G.F.syncGoppieFormesTextbox()
end)

_G.configUi.autoCatchToggle = _G.EncountersTab:AddToggle({
	Name = "Auto Catch",
	Default = _G.autoCatchEnabled,
	Color = Color3.fromRGB(255, 120, 180),
	Callback = function(value)
		_G.F.setAutoCatchEnabled(value)
	end
})

_G.EncountersTab:AddTextbox({
	Name = "Capture Disc",
	Default = _G.autoCatchDisc,
	TextDisappear = false,
	Callback = function(value)
		_G.autoCatchDisc = string.gsub(tostring(value or ""), "^%s*(.-)%s*$", "%1")
	end
})

_G.configUi.stopOnGleamingToggle = _G.EncountersTab:AddToggle({
	Name = "Stop on Gleaming",
	Default = _G.stopOnGleaming,
	Color = Color3.fromRGB(255, 215, 90),
	Callback = function(value)
		_G.stopOnGleaming = value
	end
})

_G.configUi.stopOnGammaToggle = _G.EncountersTab:AddToggle({
	Name = "Stop on Gamma",
	Default = _G.stopOnGamma,
	Color = Color3.fromRGB(120, 220, 120),
	Callback = function(value)
		_G.stopOnGamma = value
	end
})

_G.configUi.stopOnWispToggle = _G.EncountersTab:AddToggle({
	Name = "Stop on Wisp",
	Default = _G.stopOnWisp,
	Color = Color3.fromRGB(180, 140, 255),
	Callback = function(value)
		_G.stopOnWisp = value
	end
})


_G.EncountersTab:AddButton({
	Name = "Start Encounter Now",
	Icon = "zap",
	Callback = function()
		local started, reason = _G.F.startAutoEncounter()

		if not started and reason then
			_G.OrionLib:MakeNotification({
				Name = "Auto Encounter",
				Content = reason,
				Time = 4
			})
		end
	end
})


local umvExplorationSection = _G.UmvTab:AddSection({ Name = "Exploration" })

_G.wallSparkleUmvCountLabel = umvExplorationSection:AddLabel("Marked: 0")
_G.wallSparkleUmvStatusLabel = umvExplorationSection:AddLabel("ESP: Off")
_G.umvMiningRevealedCountLabel = umvExplorationSection:AddLabel("Revealed: 0")
_G.remoteSparkleMineStatusLabel = umvExplorationSection:AddLabel("Remote Mine: Off")

_G.configUi.wallSparkleUmvToggle = umvExplorationSection:AddToggle({
	Name = "Through-Walls ESP",
	Default = _G.wallSparkleUmvEnabled,
	Color = Color3.fromRGB(255, 211, 67),
	Callback = function(value)
		_G.F.setWallSparkleUmvEnabled(value)
	end
})

_G.configUi.umvMiningRevealToggle = umvExplorationSection:AddToggle({
	Name = "Reveal Hidden Items",
	Default = _G.umvMiningRevealEnabled,
	Color = Color3.fromRGB(72, 220, 255),
	Callback = function(value)
		_G.F.setUmvMiningRevealEnabled(value)
	end
})

_G.configUi.remoteSparkleMineToggle = umvExplorationSection:AddToggle({
	Name = "Remote Sparkle Mine (E)",
	Default = _G.remoteSparkleMineEnabled,
	Color = Color3.fromRGB(255, 120, 180),
	Callback = function(value)
		_G.F.setRemoteSparkleMineEnabled(value)
	end
})

umvExplorationSection:AddButton({
	Name = "Mine Nearest Sparkle",
	Icon = "crosshair",
	Callback = function()
		task.spawn(function()
			_G.F.setRemoteSparkleMineStatus("Mining...")
			local ok, reason = _G.F.runRemoteSparkleMine()
			if ok then
				_G.F.setRemoteSparkleMineStatus("Done - press E for next.")
				_G.OrionLib:MakeNotification({
					Name = "Remote Mine",
					Content = "Teleported and started mining.",
					Time = 3,
				})
			else
				_G.F.setRemoteSparkleMineStatus(reason or "Failed")
				_G.OrionLib:MakeNotification({
					Name = "Remote Mine",
					Content = reason or "Failed to start mining.",
					Time = 5,
				})
			end
		end)
	end
})

_G.F.refreshWallSparkleUmvUi()
_G.F.refreshUmvMiningUi()
if _G.wallSparkleUmvEnabled then
	_G.F.setWallSparkleUmvStatus(string.format("Enabled — %d WallSparkle part(s) marked.", _G.wallSparkleUmvCount))
else
	_G.F.setWallSparkleUmvStatus("Off")
end

local umvFossilSection = _G.UmvTab:AddSection({ Name = "Fossils" })

_G.fossilStatusLabel = umvFossilSection:AddLabel("Status: Idle")
_G.fossilStatsLabel = umvFossilSection:AddLabel("Batches: 0 | Revived: 0 | Last Queued: 0")
_G.fossilMachineLabel = umvFossilSection:AddLabel("Petrolith Table: searching...")

_G.configUi.autoFossilToggle = umvFossilSection:AddToggle({
	Name = "Auto Fossil",
	Default = _G.autoFossilEnabled,
	Color = Color3.fromRGB(80, 185, 255),
	Callback = function(value)
		_G.autoFossilEnabled = value
		_G.nextAutoFossilAt = 0

		if value then
			_G.F.setFossilStatus("Auto Fossil enabled.")
		else
			_G.F.setFossilStatus("Auto Fossil disabled.")
		end
	end
})

_G.configUi.autoFossilDelay = umvFossilSection:AddSlider({
	Name = "Fossil Loop Delay",
	Min = 1,
	Max = 30,
	Increment = 0.5,
	Default = _G.autoFossilDelay,
	ValueName = "s",
	Callback = function(value)
		_G.autoFossilDelay = value
	end
})

umvFossilSection:AddButton({
	Name = "Revive Fossils Now",
	Icon = "zap",
	Callback = function()
		local success, reason = _G.F.runAutoFossil()
		if not success and reason then
			_G.OrionLib:MakeNotification({
				Name = "Auto Fossil",
				Content = reason,
				Time = 5,
			})
		end
	end
})

umvFossilSection:AddButton({
	Name = "Reset Fossil Stats",
	Icon = "refresh-cw",
	Callback = function()
		_G.totalFossilBatches = 0
		_G.totalFossilRevived = 0
		_G.lastFossilQueuedCount = 0
		_G.F.refreshFossilStats()
		_G.F.setFossilStatus("Stats reset.")
	end
})

_G.F.refreshFossilStats()
_G.F.refreshPetrolithTableLabel()

ArcadeAutomation:attachUi(_G.ArcadeTab)

_G.eggRainStatusLabel = _G.EggRainTab:AddLabel("Status: Idle")

_G.configUi.autoEggRainToggle = _G.EggRainTab:AddToggle({
	Name = "Auto Egg Rain",
	Default = _G.autoEggRainEnabled,
	Color = Color3.fromRGB(255, 215, 90),
	Callback = function(value)
		_G.autoEggRainEnabled = value
		_G.F.setEggRainStatus(value and "Auto Egg Rain enabled." or "Auto Egg Rain disabled.")
	end
})

_G.configUi.autoEggRainDelay = _G.EggRainTab:AddSlider({
	Name = "Bring Delay",
	Min = 0.1,
	Max = 3,
	Increment = 0.1,
	Default = _G.autoEggRainDelay,
	ValueName = "s",
	Callback = function(value)
		_G.autoEggRainDelay = value
	end
})

_G.EggRainTab:AddButton({
	Name = "Bring Egg Once",
	Icon = "zap",
	Callback = function()
		local success, reason = _G.F.runEggRainBringOnce()
		if not success and reason then
			_G.OrionLib:MakeNotification({
				Name = "Egg Rain",
				Content = reason,
				Time = 4,
			})
		end
	end
})

for _, shopInfo in ipairs(_G.SHOP_DEFINITIONS) do
	local shopId = shopInfo.Id
	local shopLabel = shopInfo.Label

	_G.ShopTab:AddButton({
		Name = shopLabel,
		Icon = "shopping-bag",
		Callback = function()
			local opened, reason = _G.F.openShop(shopId, shopLabel)
			if not opened and reason then
				_G.OrionLib:MakeNotification({
					Name = "Shop",
					Content = tostring(reason),
					Time = 4,
				})
			end
		end
	})
end

-- Build each Settings element in isolation. If any one element's construction
-- throws at runtime (e.g. an OrionLib event-hookup hitting a thread capability
-- error), the failure must stay contained to that element and never abort the
-- rest of the tab -- otherwise the essential Config/Unload controls below get
-- silently dropped along with it.
local function settingsBuild(label, builder)
	local ok, err = pcall(builder)
	if not ok then
		warn("[LLSPLOIT] Settings element '" .. tostring(label) .. "' failed to build: " .. tostring(err))
	end
end

local settingsMovementSection
settingsBuild("Movement section", function()
	settingsMovementSection = _G.SettingsTab:AddSection({ Name = "Movement" })
end)

if settingsMovementSection then
	settingsBuild("Ctrl + Click Teleport", function()
		_G.configUi.ctrlClickTpToggle = settingsMovementSection:AddToggle({
			Name = "Ctrl + Click Teleport",
			Default = _G.ctrlClickTpEnabled,
			Color = Color3.fromRGB(120, 200, 255),
			Callback = function(value)
				_G.F.setCtrlClickTpEnabled(value)
			end
		})
	end)
end

local settingsGeneralSection
settingsBuild("General section", function()
	settingsGeneralSection = _G.SettingsTab:AddSection({ Name = "General" })
end)

if settingsGeneralSection then
	settingsBuild("Anti AFK", function()
		_G.configUi.antiAfkToggle = settingsGeneralSection:AddToggle({
			Name = "Anti AFK",
			Default = _G.antiAfkEnabled,
			Color = Color3.fromRGB(120, 255, 160),
			Callback = function(value)
				_G.F.setAntiAfkEnabled(value)
			end
		})
	end)

	-- Deliberately not saved to config: silently restoring a no-save state on the
	-- next injection could cost the user hours of progress.
	settingsBuild("Disable Saving", function()
		settingsGeneralSection:AddToggle({
			Name = "Disable Saving",
			Default = _G.savingDisabled,
			Color = Color3.fromRGB(255, 150, 120),
			Callback = function(value)
				local ok, reason = _G.F.setSavingDisabled(value)
				if not ok and reason then
					pcall(function()
						_G.OrionLib:MakeNotification({
							Name = "Disable Saving",
							Content = reason,
							Time = 4
						})
					end)
				end
			end
		})
	end)
end

settingsBuild("Config Name", function()
	_G.SettingsTab:AddTextbox({
		Name = "Config Name",
		Default = _G.configProfileName,
		TextDisappear = false,
		Callback = function(value)
			_G.configProfileName = _G.F.sanitizeConfigName(value)
		end
	})
end)

settingsBuild("Save Config", function()
	_G.SettingsTab:AddButton({
		Name = "Save Config",
		Icon = "save",
		Callback = function()
			local snapshot = _G.F.collectConfigSnapshot()
			snapshot.profile = _G.configProfileName
			local fileName = _G.F.sanitizeConfigName(_G.configProfileName) .. ".json"
			_G.F.saveConfigToFile(fileName, snapshot, false)
			_G.F.saveConfigToFile(_G.CONFIG_AUTOSAVE_FILE, snapshot, true)
		end
	})
end)

settingsBuild("Load Config", function()
	_G.SettingsTab:AddButton({
		Name = "Load Config",
		Icon = "folder-open",
		Callback = function()
			local fileName = _G.F.sanitizeConfigName(_G.configProfileName) .. ".json"
			_G.F.loadConfigFromFile(fileName, false)
		end
	})
end)

settingsBuild("Unload Script", function()
	_G.SettingsTab:AddButton({
		Name = "Unload Script",
		Icon = "power",
		Callback = function()
			_G.uiAlive = false
			_G.F.disableAllFeatures()

			task.defer(function()
				pcall(function()
					_G.OrionLib:Destroy()
				end)
			end)
		end
	})
end)

_G.startupConfigApplied = false
if _G.startupConfig then
	_G.F.applyConfigSnapshot(_G.startupConfig, true)
	_G.startupConfigApplied = true
end

task.spawn(function()
	while _G.uiAlive do
		_G.F.refreshPetrolithTableLabel()
		task.wait(2)
	end
end)

task.spawn(function()
	local lastNoticeAt = 0

	while _G.uiAlive do
		if _G.autoDiscDropEnabled then
			local didWork, reason = ArcadeAutomation:runAutoDiscDrop()

			if not didWork and reason and os.clock() - lastNoticeAt >= 8 then
				lastNoticeAt = os.clock()
				warn("[Auto Disc Drop] " .. tostring(reason))

				pcall(function()
					_G.OrionLib:MakeNotification({
						Name = "Auto Disc Drop",
						Content = reason,
						Time = 4
					})
				end)
			end

			task.wait(0.25)
		else
			task.wait(0.2)
		end
	end
end)

task.spawn(function()
	while _G.uiAlive do
		if _G.autoFossilEnabled and not _G.fossilBusy and os.clock() >= _G.nextAutoFossilAt then
			local success, reason = _G.F.runAutoFossil()
			_G.nextAutoFossilAt = os.clock() + _G.autoFossilDelay

			if not success and reason and reason ~= "No complete Petrolith sets found." then
				_G.OrionLib:MakeNotification({
					Name = "Auto Fossil",
					Content = reason,
					Time = 5,
				})
			end
		end

		task.wait(0.15)
	end
end)

task.spawn(function()
	local lastNoticeAt = 0

	while _G.uiAlive do
		if _G.autoEggRainEnabled then
			local success, reason
			local ok, err = pcall(function()
				success, reason = _G.F.runEggRainBringOnce()
			end)

			if not ok then
				success = false
				reason = tostring(err)
				if type(_G.F.setEggRainStatus) == "function" then
					_G.F.setEggRainStatus(reason)
				end
			end

			if not success and reason and reason ~= "No Egg Rain parts found." and os.clock() - lastNoticeAt >= 5 then
				lastNoticeAt = os.clock()
				warn("[Egg Rain] " .. tostring(reason))

				pcall(function()
					_G.OrionLib:MakeNotification({
						Name = "Egg Rain",
						Content = reason,
						Time = 4,
					})
				end)
			end

			task.wait(math.max(0.05, tonumber(_G.autoEggRainDelay) or 0.25))
		else
			task.wait(0.2)
		end
	end
end)

-- Egg Rain battle service: run away from hatch battles unless the foe is
-- Gleaming/Gamma, in which case pause Auto Egg Rain so it can be caught.
-- Mirrors the Auto Static run ladder (input-state gate, foe-flag settle
-- delay, non-blocking tryRun).
task.spawn(function()
	local currentBattle = nil
	local battleFirstSeenAt = 0
	local foeLoadedAt = 0
	local lastRunAttemptAt = 0
	local runAttemptBattle = nil
	local runAttemptStartedAt = 0
	local lastSpecialNoticeAt = 0

	while _G.uiAlive do
		local staticBusy = false
		pcall(function()
			staticBusy = StaticAutomation and StaticAutomation:isAutomationActive() or false
		end)

		if _G.autoEggRainEnabled and not staticBusy then
			pcall(function()
				local battle = _G.F.getCurrentBattle()
				if type(battle) ~= "table" then
					currentBattle = nil
					foeLoadedAt = 0
					return
				end

				local now = os.clock()

				if currentBattle ~= battle then
					currentBattle = battle
					battleFirstSeenAt = now
					foeLoadedAt = 0
				end

				if _G.F.hasWildFoeLoaded(battle) then
					local foe = battle.p2.monsters[1]
					local gleamValue = foe and _G.F.getMonsterGleamValue(foe)

					if _G.isActiveFlag(gleamValue) then
						if now - lastSpecialNoticeAt >= 2 then
							lastSpecialNoticeAt = now
							_G.autoEggRainEnabled = false

							if _G.configUi.autoEggRainToggle and type(_G.configUi.autoEggRainToggle.Set) == "function" then
								task.defer(function()
									pcall(function()
										_G.configUi.autoEggRainToggle:Set(false)
									end)
								end)
							end

							_G.F.setEggRainStatus(string.format(
								"Found %s (Gleaming/Gamma: %s) - paused.",
								tostring(foe and (foe.name or foe.species) or "wild Loomian"),
								tostring(gleamValue)
							))

							pcall(function()
								_G.OrionLib:MakeNotification({
									Name = "Egg Rain Paused",
									Content = string.format(
										"Found %s (Gleaming/Gamma: %s). Catch it manually!",
										tostring(foe and (foe.name or foe.species) or "wild Loomian"),
										tostring(gleamValue)
									),
									Time = 8,
								})
							end)
						end

						return
					end
				end

				_G.F.setBattleFastForward(true, battle)
				_G.F.applyBattleAnimationFastForward(battle, false)

				if battle.ended then
					_G.F.clearBattleRunTiming(battle)
					return
				end

				if not _G.F.isStaticBattleReadyToEnd(battle) then
					return
				end

				if foeLoadedAt == 0 then
					foeLoadedAt = now
				end

				-- Let the gleam/gamma flags settle before any escape can fire.
				if now - foeLoadedAt < 1 then
					return
				end

				local allowTimedFallback = now - battleFirstSeenAt >= 6

				if not _G.F.isBattleRunMenuReady(battle, allowTimedFallback) then
					return
				end

				if now - lastRunAttemptAt < 0.35 then
					return
				end

				lastRunAttemptAt = now

				if runAttemptBattle == battle and now - runAttemptStartedAt < 8 then
					return
				end

				runAttemptBattle = battle
				runAttemptStartedAt = now

				task.spawn(function()
					pcall(function()
						_G.F.naturalRunFromBattle(battle, allowTimedFallback)
					end)

					if runAttemptBattle == battle then
						runAttemptBattle = nil
					end
				end)
			end)

			task.wait(0.08)
		else
			task.wait(0.2)
		end
	end
end)

task.spawn(function()
	while _G.uiAlive do
		if CatchAutomation and CatchAutomation:isEnabled() then
			pcall(function()
				CatchAutomation:serviceBattle()
			end)
			task.wait(0.06)
		else
			task.wait(0.2)
		end
	end
end)

task.spawn(function()
	while _G.uiAlive do
		if CatchAutomation and CatchAutomation:isEnabled() then
			pcall(function()
				CatchAutomation:serviceNicknamePrompt()
			end)
			task.wait(0.12)
		else
			task.wait(0.2)
		end
	end
end)

task.spawn(function()
	while _G.uiAlive do
		pcall(function()
			_G.F.refreshInformationLabels()
		end)
		task.wait(2)
	end
end)

task.spawn(function()
	while _G.uiAlive do
		if _G.autoBoonaryEnabled and not _G.autoBoonaryBusy and not _G.autoBoonaryTriggered then
			local tix = _G.F.getCurrentTixCount()
			if tix and tix >= (tonumber(_G.autoBoonaryTixThreshold) or 999999) then
				_G.autoBoonaryTriggered = true
				_G.F.setAutoBoonaryStatus("Tix threshold reached: " .. _G.F.formatInfoValue(tix))

				task.spawn(function()
					local ok, reason = _G.F.runAutoBoonaryCycle()
					if not ok and reason then
						_G.OrionLib:MakeNotification({
							Name = "Auto Boonary",
							Content = tostring(reason),
							Time = 5,
						})
						_G.autoBoonaryTriggered = false
					end
				end)
			else
				_G.F.setAutoBoonaryStatus("Waiting for " .. _G.F.formatInfoValue(_G.autoBoonaryTixThreshold) .. " Tix.")
			end
		end

		task.wait(2)
	end
end)

_G.UserInputService.WindowFocused:Connect(function() _G.windowFocused = true end)
_G.UserInputService.WindowFocusReleased:Connect(function() _G.windowFocused = false end)
task.spawn(function()
	while _G.uiAlive do
		if StaticAutomation and StaticAutomation:isAutomationActive() then
			pcall(function()
				StaticAutomation:serviceBattle()
			end)
			task.wait(0.06)
		else
			task.wait(0.2)
		end
	end
end)

task.spawn(function()
	local lastNoticeAt = 0
	local quietReasons = {
		["Waiting for static encounter data."] = true,
		["Waiting for battle input."] = true,
		["Waiting for the static prompt."] = true,
		["Waiting for the chunk to load."] = true,
		["Battle is not ready for Run."] = true,
		["Cannot interact right now."] = true
	}

	while _G.uiAlive do
		if StaticAutomation and StaticAutomation:isAutomationActive() then
			local didWork, reason
			local ok, err = pcall(function()
				didWork, reason = StaticAutomation:runCycle()
			end)

			if not ok then
				warn("[Auto Static] " .. tostring(err))
			elseif not didWork and reason and not quietReasons[reason] and os.clock() - lastNoticeAt >= 8 then
				lastNoticeAt = os.clock()
				warn("[Auto Static] " .. tostring(reason))

				pcall(function()
					_G.OrionLib:MakeNotification({
						Name = "Auto Static",
						Content = reason,
						Time = 4
					})
				end)
			end

			task.wait(_G.windowFocused and 0.12 or 0.2)
		else
			task.wait(0.2)
		end
	end
end)
task.spawn(function()
	local lastFailure = nil
	local lastFailureNoticeAt = 0

	while _G.uiAlive do
		if _G.autoTrainerEnabled then
			_G.F.clickThroughNpcChat()

			local battle = _G.F.getCurrentBattle()
			if battle then
				_G.F.setBattleFastForward(true, battle)
				_G.F.skipEncounterCutscene(battle)
				pcall(function()
					_G.F.dismissTrainerSwitchPrompt()
				end)
			end

			local started, reason = _G.F.startAutoTrainer()

			if not started and reason and reason ~= "Battle already active." and reason ~= lastFailure then
				lastFailure = reason

				local now = os.clock()
				if now - lastFailureNoticeAt >= 4 then
					lastFailureNoticeAt = now

					pcall(function()
						_G.OrionLib:MakeNotification({
							Name = "Auto Trainer",
							Content = reason,
							Time = 4
						})
					end)
				end
			elseif started then
				lastFailure = nil
			end

			task.wait(_G.autoTrainerDelay)
		else
			lastFailure = nil
			task.wait(0.2)
		end
	end
end)

task.spawn(function()
	while _G.uiAlive do
		if _G.autoTrainerEnabled then
			_G.F.clickThroughNpcChat()

			local battle = _G.F.getCurrentBattle()
			if battle then
				_G.F.setBattleFastForward(true, battle)
				_G.F.skipEncounterCutscene(battle)
				pcall(function()
					_G.F.dismissTrainerSwitchPrompt()
				end)
			end

			-- Click through the mastery level-up report if one appeared, so a
			-- level-up at battle end doesn't leave doTrainerBattle blocked on OK.
			pcall(function()
				_G.F.dismissMasteryReport()
			end)

			pcall(function()
				_G.F.dismissTrainerSwitchPrompt()
			end)

			task.wait(0.08)
		else
			task.wait(0.2)
		end
	end
end)

task.spawn(function()
	while _G.uiAlive do
		if _G.autoMoveOneEnabled then
			_G.F.useMoveOne()
			task.wait(_G.autoMoveOneDelay)
		else
			task.wait(0.2)
		end
	end
end)
task.spawn(function()
	local lastNoticeAt = 0
	local quietReasons = {
		["No rallied Loomians waiting."] = true
	}

	while _G.uiAlive do
		if _G.autoRallyEnabled then
			local didWork, reason
			local ok, err = pcall(function()
				didWork, reason = _G.F.runAutoRally()
			end)

			if not ok then
				warn("[Auto Rally] " .. tostring(err))
			elseif not didWork and reason and not quietReasons[reason] and os.clock() - lastNoticeAt >= 8 then
				lastNoticeAt = os.clock()
				warn("[Auto Rally] " .. tostring(reason))
				pcall(function()
					_G.OrionLib:MakeNotification({
						Name = "Auto Rally",
						Content = reason,
						Time = 4
					})
				end)
			end

			task.wait(_G.rallyDelay)
		else
			task.wait(0.2)
		end
	end
end)

do
	_G.CodexGetEndDelay = function()
		return _G.windowFocused and _G.focusedEndDelay or _G.backgroundEndDelay
	end

	_G.CodexGetEndRetryDelay = function()
		return _G.windowFocused and _G.focusedRunDelay or _G.backgroundRunDelay
	end

	_G.CodexTryRunBattle = function(battle, forceSkip)
		if not battle then
			return false
		end

		if _G.F.isFishingBattleStarting(battle) or _G.F.isBattleSetupPending(battle) then
			return false
		end

		if forceSkip then
			_G.F.setBattleFastForward(true, battle)
			_G.F.skipEncounterCutscene(battle)
		elseif _G.autoEncounterEnabled then
			_G.F.setBattleFastForward(true, battle)
			_G.F.applyBattleAnimationFastForward(battle, false)
		end

		if _G.autoEncounterEnabled and not (CatchAutomation and CatchAutomation:shouldCatchBattle(battle)) then
			-- Auto Use Move + Auto Encounter: attack instead of running, so
			-- encounters get KO'd for EXP rather than fled from.
			if _G.autoMoveOneEnabled then
				return _G.F.useMoveOne(battle)
			end

			return _G.F.naturalRunFromBattle(battle, true)
		end

		return false
	end

	task.spawn(function()
		local lastBattleObject = nil
		local lastBattleSeenAt = 0
		local battleFirstSeenAt = 0
		local lastEndAttemptAt = 0
		local lastBattleProgressSignature = nil
		local lastBattleProgressAt = 0

		while _G.uiAlive do
			if _G.autoEncounterEnabled or _G.autoEncounterPausedBattle then
				if type(_G._p) ~= "table" then
					_G._p = _G.F.findP()
				end

				-- Wild wins grant mastery too; when fighting encounters (Auto
				-- Use Move) the level-up report would block doWildBattle just
				-- like trainer battles, so click it through here as well.
				if _G.autoMoveOneEnabled then
					pcall(function()
						_G.F.dismissMasteryReport()
					end)
				end

				if type(_G._p) == "table" then
					local battle = _G.F.getCurrentBattle()
					local now = os.clock()

					if battle then
						local catchManaged = CatchAutomation and CatchAutomation:shouldCatchBattle(battle)
						if _G.F.isFishingGoppieBattle(battle)
							and (_G.autoFishingEnabled or _G.fastForwardEnabled or (_G.autoCatchEnabled and catchManaged)) then
							task.wait(_G.windowFocused and _G.focusedRunDelay or _G.backgroundRunDelay)
						else
						lastBattleSeenAt = now

						if battle ~= lastBattleObject then
							lastBattleObject = battle
							battleFirstSeenAt = now
							lastEndAttemptAt = 0
							lastBattleProgressSignature = _G.F.getBattleProgressSignature(battle)
							lastBattleProgressAt = now
							_G.F.skipEncounterCutscene(battle)
						end

						local targetMatch = _G.F.isMatchingEncounterTargetFoe(battle)
						local roamerMatch = _G.F.isMatchingRoamingLegendaryFoe(battle)

						if targetMatch then
							_G.F.handleEncounterTargetMatchFound(battle)
						end

						if roamerMatch then
							_G.F.handleRoamingLegendaryFound(battle)
						end

						local automationPausedForGleaming = _G.F.pauseNaturalRunForSpecialBattle(battle)
						local automationPausedForFoundEncounter = _G.autoEncounterPausedBattle == battle

						if not automationPausedForFoundEncounter and not targetMatch and not roamerMatch and not catchManaged and not automationPausedForGleaming then
							local battleProgressSignature = _G.F.getBattleProgressSignature(battle)
							if battleProgressSignature ~= lastBattleProgressSignature then
								lastBattleProgressSignature = battleProgressSignature
								lastBattleProgressAt = now
							end

							if not _G.F.isBattleSetupPending(battle) then
								_G.F.setBattleFastForward(true, battle)
								_G.F.applyBattleAnimationFastForward(battle, false)

								if now - lastBattleProgressAt >= _G.fastForwardStuckDelay then
									_G.F.nudgeFastForwardBattle(battle)
									lastBattleProgressAt = now
								end
							end

							local battleAge = now - battleFirstSeenAt
							local retryAge = lastEndAttemptAt == 0 and math.huge or now - lastEndAttemptAt

							if _G.autoMoveOneEnabled
								and battleAge >= _G.CodexGetEndDelay()
								and retryAge >= _G.CodexGetEndRetryDelay() then
								-- Attack branch first: with Auto Use Move on, every
								-- non-special encounter gets fought (even wrong-target
								-- ones), instead of being run from.
								lastEndAttemptAt = now
								_G.CodexTryRunBattle(battle, false)
							elseif _G.F.isWrongEncounterTargetFoe(battle) and _G.F.isBattleRunMenuReady(battle, true) then
								lastEndAttemptAt = now
								_G.CodexTryRunBattle(battle, false)
							elseif not _G.F.shouldFilterEncounterTarget()
								and battleAge >= _G.CodexGetEndDelay()
								and retryAge >= _G.CodexGetEndRetryDelay() then
								lastEndAttemptAt = now
								_G.CodexTryRunBattle(battle, false)
							end
						end

						task.wait(_G.windowFocused and _G.focusedRunDelay or _G.backgroundRunDelay)
						end
					else
						if lastBattleObject and (now - lastBattleSeenAt) >= _G.encounterReleaseDelay then
							_G.F.releaseFinishedBattle(lastBattleObject)
							_G.F.clearNaturalRunSpecialPause(lastBattleObject)
							_G.F.resumeAutoEncounterAfterPausedBattle(lastBattleObject)
							lastBattleObject = nil
							battleFirstSeenAt = 0
							lastEndAttemptAt = 0
							lastBattleProgressSignature = nil
							lastBattleProgressAt = 0
						elseif _G.autoEncounterPausedBattle then
							_G.F.resumeAutoEncounterAfterPausedBattle(nil)
						end

						task.wait(_G.windowFocused and 0.18 or 0.15)
					end
				else
					task.wait(0.2)
				end
			else
				_G.F.clearAllBattleFastForward()
				lastBattleObject = nil
				battleFirstSeenAt = 0
				lastEndAttemptAt = 0
				lastBattleProgressSignature = nil
				lastBattleProgressAt = 0
				task.wait(0.2)
			end
		end
	end)
end


task.spawn(function()
	local lastFailure = nil
	local lastFailureNoticeAt = 0

	while _G.uiAlive do
		if _G.autoEncounterEnabled then
			if type(_G._p) ~= "table" then
				_G._p = _G.F.findP()
			end

			local started, reason = _G.F.startAutoEncounter()

			if not started and reason and reason ~= "Battle already active." and reason ~= lastFailure then
				lastFailure = reason

				local now = os.clock()
				if now - lastFailureNoticeAt >= 4 then
					lastFailureNoticeAt = now

					pcall(function()
						_G.OrionLib:MakeNotification({
							Name = "Auto Encounter",
							Content = reason,
							Time = 4
						})
					end)
				end
			elseif started then
				lastFailure = nil
			end

			task.wait(_G.autoEncounterDelay)
		else
			lastFailure = nil
			task.wait(0.2)
		end
	end
end)

task.defer(function()
	if not _G.startupConfigApplied then
		_G.F.syncConfigUiFromVariables()
	end

	local lastEncoded = _G.HttpService:JSONEncode(_G.F.collectConfigSnapshot())
	task.spawn(function()
		while _G.uiAlive do
			task.wait(1)
			if not _G.applyingConfig then
				local ok, encoded = pcall(function()
					return _G.HttpService:JSONEncode(_G.F.collectConfigSnapshot())
				end)
				if ok and encoded ~= lastEncoded then
					lastEncoded = encoded
					_G.F.saveConfigToFile(_G.CONFIG_AUTOSAVE_FILE, nil, true)
				end
			end
		end
	end)
end)


do
	_G.CodexTryRunFishingBattle = function(battle, forceSkip)
		if not battle then
			return false
		end

		if _G.F.isFishingBattleStarting(battle) or _G.F.isBattleSetupPending(battle) then
			return false
		end

		if forceSkip then
			_G.F.setBattleFastForward(true, battle)
			_G.F.skipEncounterCutscene(battle)
		elseif _G.fastForwardEnabled then
			_G.F.setBattleFastForward(true, battle)
			_G.F.applyBattleAnimationFastForward(battle, false)
		end

		if CatchAutomation and CatchAutomation:shouldCatchBattle(battle) then
			return false
		end

		if not _G.autoFishingEnabled then
			return false
		end

		if _G.F.isAutoFishingExcludedGoppieBattle(battle) then
			return _G.F.naturalRunFromBattle(battle)
		end

		local foe = _G.F.getBattleFoeMonster(battle)
		local formeValue = _G.F.getFishingGoppieFormeValue(battle)
		if not _G.F.isGoppieMonster(foe) and not _G.F.isMeaningfulFormeValue(formeValue) then
			return _G.F.naturalRunFromBattle(battle)
		end

		return false
	end

	task.spawn(function()
		local lastBattleObject = nil
		local encounterActive = false
		local lastBattleSeenAt = 0
		local battleFirstSeenAt = 0
		local lastEndAttemptAt = 0
		local lastBattleProgressSignature = nil
		local lastBattleProgressAt = 0

		while _G.uiAlive do
			if _G.autoFishingEnabled or _G.fastForwardEnabled or _G.autoCatchEnabled then
				if type(_G._p) ~= "table" then
					_G._p = _G.F.findP()
				end

				if type(_G._p) == "table" then
					local battle = _G.F.getCurrentBattle()
					local now = os.clock()
					local catchManaged = CatchAutomation and CatchAutomation:shouldCatchBattle(battle)
					local fishingBattle = battle and _G.F.isFishingGoppieBattle(battle)
					local manageFishingBattle = fishingBattle
						and (_G.autoFishingEnabled or _G.fastForwardEnabled or (_G.autoCatchEnabled and catchManaged))

					if battle and manageFishingBattle then
						local runAutomationEnabled = _G.autoFishingEnabled
						lastBattleSeenAt = now
						if _G.autoFishingEnabled then
							_G.F.rememberAutoFishingGoppieFormeFromBattle(battle)
						end

						if battle ~= lastBattleObject then
							lastBattleObject = battle
							battleFirstSeenAt = now
							lastEndAttemptAt = 0
							lastBattleProgressSignature = _G.F.getBattleProgressSignature(battle)
							lastBattleProgressAt = now

							if runAutomationEnabled then
								encounterActive = true
							end
						elseif runAutomationEnabled and not encounterActive then
							encounterActive = true
						end

						local automationPausedForGleaming = _G.F.pauseNaturalRunForSpecialBattle(battle)

						if not catchManaged then
							local battleProgressSignature = _G.F.getBattleProgressSignature(battle)
							if battleProgressSignature ~= lastBattleProgressSignature then
								lastBattleProgressSignature = battleProgressSignature
								lastBattleProgressAt = now
							end

							if not _G.F.isBattleSetupPending(battle)
								and (_G.fastForwardEnabled or _G.autoFishingEnabled)
								and not automationPausedForGleaming then
								_G.F.setBattleFastForward(true, battle)
								_G.F.applyBattleAnimationFastForward(battle, false)

								if now - lastBattleProgressAt >= _G.fastForwardStuckDelay then
									_G.F.nudgeFastForwardBattle(battle)
									lastBattleProgressAt = now
								end
							end

							local battleAge = now - battleFirstSeenAt
							local retryAge = lastEndAttemptAt == 0 and math.huge or now - lastEndAttemptAt

							if _G.autoFishingEnabled and not automationPausedForGleaming
								and battleAge >= _G.CodexGetEndDelay() and retryAge >= _G.CodexGetEndRetryDelay() then
								lastEndAttemptAt = now
								_G.CodexTryRunFishingBattle(battle, false)
							end
						end

						task.wait(_G.windowFocused and _G.focusedRunDelay or _G.backgroundRunDelay)
					else
						if lastBattleObject and (now - lastBattleSeenAt) >= _G.encounterReleaseDelay then
							_G.F.releaseFinishedBattle(lastBattleObject)
							_G.F.clearNaturalRunSpecialPause(lastBattleObject)
							lastBattleObject = nil
							battleFirstSeenAt = 0
							lastEndAttemptAt = 0
							lastBattleProgressSignature = nil
							lastBattleProgressAt = 0
						end

						if encounterActive and (now - lastBattleSeenAt) >= _G.encounterReleaseDelay then
							encounterActive = false
						end

						task.wait(_G.windowFocused and 0.18 or 0.15)
					end
				else
					task.wait(0.2)
				end
			else
				lastBattleObject = nil
				encounterActive = false
				battleFirstSeenAt = 0
				lastEndAttemptAt = 0
				lastBattleProgressSignature = nil
				lastBattleProgressAt = 0
				task.wait(0.2)
			end
		end
	end)
end

task.spawn(function()
	local lastNoticeAt = 0
	local quietReasons = {
		["Battle already active."] = true,
		["Fishing already in progress."] = true,
		["NPC chat is busy."] = true
	}

	while _G.uiAlive do
		if FishingAutomation and FishingAutomation:isEnabled() then
			local didWork, reason

			local ok, err = pcall(function()
				didWork, reason = FishingAutomation:runCycle()
			end)

			if not ok then
				warn("[Auto Fishing] " .. tostring(err))
			elseif not didWork and reason and not quietReasons[reason] and os.clock() - lastNoticeAt >= 8 then
				lastNoticeAt = os.clock()
				warn("[Auto Fishing] " .. tostring(reason))

				pcall(function()
					_G.OrionLib:MakeNotification({
						Name = "Auto Fishing",
						Content = reason,
						Time = 4
					})
				end)
			end

			task.wait(0.25)
		else
			task.wait(0.2)
		end
	end
end)

_G.OrionLib:Init()
