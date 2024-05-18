local openui_manager = {}

openui_manager.init = function(config)
	local hierarchyActions = require("hierarchyactions")
	local theme = require("uitheme").current
	openui = {}

	Pointer:Show()

	if config == nil then
		config = {}
	end
	local defaultConfig = {
		debug = false,
		debugLevel = 0, -- 0: From messages, 1: From warns
		cameraLayer = 11,
		maxLayers = 500,
		layerStep = -0.1,
		collisionGroup = 12,
		buttonPadding = 4,
		buttonBorder = 3,
		buttonUnderline = 1,
	}
	for key, defaultValue in pairs(defaultConfig) do
		defaultConfig[key] = config[key] or defaultValue
	end

	--[[ Config variables ]]
	openui.debug = defaultConfig.debug
	openui.debugLevel = defaultConfig.debugLevel
	openui.cameraLayer = defaultConfig.cameraLayer
	openui.maxLayers = defaultConfig.maxLayers
	openui.layerStep = defaultConfig.layerStep
	openui.collisionGroup = defaultConfig.collisionGroup
	openui.buttonPadding = defaultConfig.buttonPadding
	openui.buttonBorder = defaultConfig.buttonBorder
	openui.buttonUnderline = defaultConfig.buttonUnderline

	--[[ Camera setup ]]
	openui.Camera = Camera()
	openui.Camera:SetParent(World)
	openui.Camera.On = true
	openui.Camera.Far = openui.maxLayers * 2 + math.max(Screen.Width, Screen.Height)
	openui.Camera.Projection = ProjectionMode.Orthographic
	openui.Camera.Width = Screen.Width
	openui.Camera.Height = Screen.Height
	openui.Camera.Layers = openui.cameraLayer

	--[[ Root setup ]]
	openui.Root = Object()
	openui.Root:SetParent(World)
	openui.Root.Position = Number3(-Screen.Width * 0.5, -Screen.Height * 0.5, openui.maxLayers)
	openui.Root.Name = "[OpenUI:Root]"

	--[[ Other Vars ]]
	openui.nodeID = 1

	openui.ButtonState = {
		Idle = "ButtonState:Idle",
		Pressed = "ButtonState:Pressed",
	}

	--[[ Debug ]]
	openui.Debug = {}
	openui.Debug.Say = function(message)
		if openui.debug ~= true then return end
		if openui.debugLevel > 0 then return end
		print("[OpenUI:Message] "..message)
	end
	openui.Debug.Warn = function(message)
		if openui.debug ~= true then return end
		if openui.debugLevel > 1 then return end
		print("[OpenUI:Warning] "..message)
	end

	--[[ Utils ]]
	openui.mergeConfigs = function(defaultConfig, config)
		local mergedConfig = {}
		for key, defaultValue in pairs(defaultConfig) do
			if config[key] ~= nil then
				mergedConfig[key] = config[key]
			else
				mergedConfig[key] = defaultValue
			end
		end
		return mergedConfig
	end

	openui.checkTable = function(tabl, val)
		for key, value in pairs(tabl) do
			if value == val then
				return true
			end
		end

		return false
	end

	openui.setupObject = function(ui, object, collides)
		hierarchyActions:applyToDescendants(object, { includeRoot = true }, function(o)
			if o == nil or type(o) == "Object" then
				return
			end
			o.IsUnlit = true

			o.Layers = ui.cameraLayer

			o.CollidesWithGroups = {}
			o.CollisionGroups = { ui.collisionGroup }
			o.Physics = PhysicsMode.Disabled
		end)

		if collides and object.Width ~= nil and object.Height ~= nil then
			object.Physics = PhysicsMode.Trigger
			object.CollisionBox = Box(Number3(0, 0, 0), Number3(object.Width, object.Height, 0.1))
		end
	end

	openui.parseTextSize = function(ui, textSize)
		if textSize == "default" then
			return Text.FontSizeDefault
		elseif textSize == "big" then
			return Text.FontSizeBig
		elseif textSize == "small" then
			return Text.FontSizeSmall
		else
			return textSize
		end
	end

	openui.getNumber2 = function(ui, number3)
		return Number2(number3.X, number3.Y)
	end
	
	openui.getNumber3 = function(ui, number2, z)
		if z == nil then
			z = 0
		end
		return Number3(number2.X, number2.Y, z)
	end

	openui.spToWp = function(ui, number2)
		return Number2(number2.X / Screen.Width, number2.Y / Screen.Height)
	end

	openui.wpToSp = function(ui, number2)
		return Number2(number2.X * Screen.Width, number2.Y * Screen.Height)
	end

	openui.dot2Dcollision = function(ui, min, max, dot)
		if min.X <= dot.X and dot.X <= max.X then
			if min.Y <= dot.Y and dot.Y <= max.Y then
				return true
			end
		end
		return false
	end

	openui.dot3Dcollision = function(ui, min, max, dot)
		if min.X <= dot.X and dot.X <= max.X then
			if min.Y <= dot.Y and dot.Y <= max.Y then
				if min.Z <= dot.Z and dot.Z <= max.Z then
					return true
				end
			end
		end
		return false
	end

	openui.WorldToUIPosition = function(ui, from)
		from = ui:getNumber2(from)
		return from - ui:getNumber2(ui.Root.Position)
	end

	--[[ Metatables ]]
	openui.nodeMetatable = {
		__type = function(self)
			return "[OpenUI:Node <" .. self.openui_Tag .. ">]"
		end,
		__tostring = function(self)
			return "[OpenUI:Node #" .. (self.ID or "nil") .. " <" .. self.openui_Tag .. ">]"
		end,
		__index = function(self, key)
			local value = self.values[key]
			if value == nil then
				value = self.values.propertyGet(self, key)
			end
			if value == nil then
				if key == "Position" or key == "LocalPosition" then
					return self.values.Object.LocalPosition
				elseif key == "Rotation" or key == "LocalRotation" then
					return self.values.Object.LocalRotation
				elseif key == "Parent" then
					if self.values.Object.Parent == openui.Root then
						return openui.Root
					else
						return self.values.Object.Parent.openui_node
					end
				elseif key == "GetChildren" then
					return function(s)
						if s == nil then
							error("openui.Node:GetChildren(index) - use ':' instead of '.'", 2)
						end
						local children = {}
						for child_i = 1, s.Object.ChildrenCount do
							local childNode = s.Object:GetChild(child_i).openui_node
							if childNode ~= nil then
								if childNode.openui_Tag ~= nil and childNode.openui_Tag ~= "removed" then
									table.insert(children, childNode)
								end
							end
						end
						return children
					end
				elseif key == "GetChild" then
					return function(s, index)
						if s == nil then
							error("openui.Node:GetChild(index) - use ':' instead of '.'", 2)
						end
						if type(index) ~= "number" and type(index) ~= "integer" then
							error("openui.Node:GetChild(index) - index is not a number", 2)
						end
						return self:GetChildren()[index]
					end
				elseif key == "ChildrenCount" then
					return #self:GetChildren()
				elseif key == "SetParent" then
					return function(s, parentNode)
						if s == nil then
							error("openui.Node:SetParent(parentNode) - use ':' instead of '.'", 2)
						end

						if parentNode ~= openui.Root then
							s.Object:SetParent(parentNode.Object)
							s.Object.LocalPosition.Z = s.ID * openui.layerStep
						else
							s.Object:SetParent(openui.Root)
							s.Object.LocalPosition.Z = openui.maxLayers + s.ID * openui.layerStep
						end
					end
				elseif key == "AddChild" then
					return function(s, childNode)
						if s == nil then
							error("openui.Node:AddChild(childNode) - use ':' instead of '.'", 2)
						end

						if s.Object ~= nil and s.Object.openui_node ~= nil then
							s.Object.openui_node:SetParent(s)
						end
					end
				end
			else
				return value
			end
			return value
		end,
		__newindex = function(self, key, value)
			local doNotSetValue = self.values.propertyChange(self, key, value)

			if doNotSetValue == nil then
				local doNotSetValue = false
				if key == "Position" or key == "LocalPosition" then
					if type(value) == "Number2" then
						self.values.Object.LocalPosition = Number3(value.X, value.Y, self.values.Object.LocalPosition.Z)
						return
					end
					self.values.Object.LocalPosition = value
					return
				elseif key == "Rotation" or key == "LocalRotation" then
					self.values.Object.LocalRotation = value
					return
				end
				self.values[key] = value
			end
		end,
	}

	--[[ Node object ]]
	--
	--Base object of 'openui' module
	--
	--Example:
	--local node = openui:Node()
	--
	openui.Node = function(ui, config)
		if ui == nil then
			error("openui.Node() - Use ':' instead of '.'", 2)
		end
		if config == nil then
			config = {}
		end

		local node = {}
		node.values = {}
		node.values.Object = Object()
		node.values.Object:SetParent(openui.Root)

		node.values.Object.openui_node = node

		local defaultConfig = {
			openui_Tag = "node",
			init = function(self) end,
			finalizer = function(self) end,
			propertyChange = function(self, key, value) end,
			propertyGet = function(self, key) end,
			parentDidResize = function(self) end,
			parentResizeWrapper = function(self)
				if self.parentDidResize ~= nil then
					self:parentDidResize()
				end
			end,
			didResize = function(self) end,
			resizeWrapper = function(self)
				if self.didResize ~= nil then
					self:didResize()
				end

				for child_i = 1, self.Object.ChildrenCount do
					local childNode = self.Object:GetChild(child_i).openui_node

					if childNode ~= nil then
						childNode:parentResizeWrapper()
					end
				end
			end,
		}

		local nodeConfig = ui.mergeConfigs(defaultConfig, config)
		for key, value in pairs(nodeConfig) do
			node.values[key] = value
		end

		node.values.remove = function(self)
			self:finalizer()

			for child_i = 1, self.Object.ChildrenCount do
				local childNode = self.Object:GetChild(child_i).openui_node
				if childNode ~= nil then
					if childNode.openui_Tag ~= nil and childNode.openui_Tag ~= "removed" then
						childNode:remove()
					end
				end
			end

			self.Object.openui_node = nil
			self.Object:SetParent(nil)
			self.Object.Tick = nil
			self.Object = nil

			self.openui_Tag = "removed"
		end

		node.values.ID = openui.nodeID
		openui.nodeID = openui.nodeID + 1

		node.values.Object.LocalPosition = Number3(0, 0, 0)
		node.values.Object.LocalPosition.Z = ui.maxLayers + node.values.ID * ui.layerStep

		setmetatable(node, ui.nodeMetatable)

		node:init()
		node.init = nil
		return node
	end

	--[[ Frame object ]]
	--
	--Frame, used to make rectanges on the screen
	--
	--Example:
	--local frame = openui:Frame()
	--
	openui.Frame = function(ui, config)
		if ui == nil then
			error("openui.Frame() - Use ':' instead of '.'", 2)
		end
		if config == nil then
			config = {}
		end

		local defaultConfig = {}
		local config = ui.mergeConfigs(defaultConfig, config)

		local nodeConfig = {
			openui_Tag = "frame",
		}
		nodeConfig.init = function(self)
			for key, value in pairs(config) do
				self[key] = value
			end

			self.quad = Quad()
			self.quad:SetParent(self.Object)
			self.quad.IsDoubleSided = true

			self.quad.Color = Color(0, 0, 0, 255)

			self.quad.LocalPosition = Number3(0, 0, 0)

			ui:setupObject(self.Object)
		end
		nodeConfig.finalizer = function(self)
			self.quad:SetParent(nil)
			self.quad = nil
		end
		nodeConfig.propertyGet = function(self, key)
			if key == "Color" then
				return self.quad.Color
			elseif key == "Image" then
				return self.quad.Image
			elseif key == "Width" then
				return self.quad.Width
			elseif key == "Height" then
				return self.quad.Height
			end
		end
		nodeConfig.propertyChange = function(self, key, value)
			if key == "Color" then
				self.quad.Color = value
				return true
			elseif key == "Image" then
				self.quad.Image = value
				return true
			elseif key == "Width" then
				self.quad.Width = value
				self:resizeWrapper()
				return true
			elseif key == "Height" then
				self.quad.Height = value
				self:resizeWrapper()
				return true
			end
		end

		local node = ui:Node(nodeConfig)
		return node
	end

	--[[ Text object ]]
	--
	--Text, used to display text on the screen
	--
	--Example:
	--local text = openui:Text("Test")
	--
	openui.Text = function(ui, text, config)
		if ui == nil then
			error("openui.Text() - Use ':' instead of '.'", 2)
		end
		if type(text) ~= "string" then
			error("openui.Text(text, config) - text must be a string", 2)
		end
		if config == nil then
			config = {}
		end

		local defaultConfig = {
			textSize = Text.FontSizeDefault,
		}
		local config = ui.mergeConfigs(defaultConfig, config)

		local nodeConfig = {
			openui_Tag = "text",
		}
		nodeConfig.init = function(self)
			for key, value in pairs(config) do
				self[key] = value
			end

			self.text = Text()
			self.text:SetParent(self.Object)

			self.text.Anchor = { 0, 0 }
			self.text.Type = TextType.World
			self.text.Text = text
			self.text.Padding = 0
			self.text.Color = Color(255, 255, 255, 255)
			self.text.BackgroundColor = Color(0, 0, 0, 0)
			self.text.MaxDistance = ui.maxLayers + 1000

			self.text.FontSize = ui:parseTextSize(self.textSize)

			self.text.LocalPosition = Number3(0, 0, 0)

			ui:setupObject(self.Object)
		end
		nodeConfig.finalizer = function(self)
			self.text:SetParent(nil)
			self.text = nil
		end
		nodeConfig.propertyGet = function(self, key)
			if key == "Color" then
				return self.text.Color
			elseif key == "BackgroundColor" then
				return self.text.BackgroundColor
			elseif key == "Text" then
				return self.text.Text
			elseif key == "Width" then
				return self.text.Width
			elseif key == "Height" then
				return self.text.Height
			elseif key == "FontSize" then
				return self.text.FontSize
			end
		end
		nodeConfig.propertyChange = function(self, key, value)
			if key == "Color" then
				self.text.Color = value
				return true
			elseif key == "BackgroundColor" then
				self.text.BackgroundColor = value
				return true
			elseif key == "Text" then
				self.text.Text = value
				return true
			elseif key == "Width" then
				self.text.Width = value
				self:resizeWrapper()
				return true
			elseif key == "Height" then
				self.text.Height = value
				self:resizeWrapper()
				return true
			elseif key == "FontSize" then
				self.text.FontSize = ui:parseTextSize(value)
				self:resizeWrapper()
				return true
			end
		end

		local node = ui:Node(nodeConfig)
		return node
	end

	--[[ Button object ]]
	--
	--Button, used to make pressable buttons on the screen
	--
	--Example:
	--local button = openui:Button("Test")
	--button.OnRelease = function() end
	--
	openui.TextButton = function(ui, text, config)
		if ui == nil then
			error("openui.Button() - Use ':' instead of '.'", 2)
		end
		if type(text) ~= "string" then
			error("openui.Button(text, config) - text must be a string", 2)
		end
		if config == nil then
			config = {}
		end

		local defaultConfig = {
			textSize = "default",
			color = Color(63, 63, 63),
			colorPressed = Color(40, 40, 40),
			textColor = Color(255, 255, 255),
			textColorPressed = Color(255, 255, 255),
			shadow = true,
			shadowOffset = Number2(0, -4),
			shadowColor = Color(0, 0, 0, 100),
		}
		local config = ui.mergeConfigs(defaultConfig, config)

		local nodeConfig = {
			openui_Tag = "button",
		}
		nodeConfig.init = function(self)
			for key, value in pairs(config) do
				self[key] = value
			end

			self.background = Quad()
			self.background.IsDoubleSided = true
			self.background.Color = self.color
			self.background.LocalPosition = Number3(0, 0, 0)
			self.background:SetParent(self.Object)

			ui:setupObject(self.background, true)

			if self.shadow == true then
				self.shadow = Quad()
				self.shadow.IsDoubleSided = true
				self.shadow.Color = self.shadowColor
				self.shadow.LocalPosition = ui:getNumber3(self.shadowOffset, -ui.layerStep)
				self.shadow:SetParent(self.Object)

				ui:setupObject(self.shadow)
			end

			self.text = Text()
			self.text.Anchor = { 0, 0 }
			self.text.Type = TextType.World
			self.text.Text = text
			self.text.Padding = 0
			self.text.Color = self.textColor
			self.text.BackgroundColor = Color(0, 0, 0, 0)
			self.text.MaxDistance = ui.maxLayers + 1000
			self.text.FontSize = ui:parseTextSize(self.textSize)
			self.text.LocalPosition = Number3(0, 0, ui.layerStep)
			self.text:SetParent(self.Object)

			ui:setupObject(self.text)

			self.fixedWidth = self.text.Width + ui.buttonPadding + ui.buttonBorder
			self.fixedHeight = self.text.Height + ui.buttonPadding + ui.buttonBorder

			self.background.Width = self.fixedWidth
			self.background.Height = self.fixedHeight
			self.background.CollisionBox =
				Box(Number3(0, 0, 0), Number3(self.background.Width, self.background.Height, 0.1))

			self.State = ui.ButtonState.Idle
			self.Pressed = false
			self.RefreshState = function(_)
				if self.Pressed == true then
					self.State = ui.ButtonState.Pressed
				else
					self.State = ui.ButtonState.Idle
				end
			end

			self.RefreshColors = function(_)
				self:RefreshState()
				if self.State == ui.ButtonState.Idle then
					self.background.Color = self.colors[1]
					self.text.Color = self.textColor
				elseif self.State == ui.ButtonState.Pressed then
					self.background.Color = self.colorsPressed[1] or self.colors[3]
					self.text.Color = self.textColorPressed or self.textColor
				end

				if self.shadow ~= nil and type(self.shadow) ~= "boolean" then
					self.shadow.Color = self.shadowColor
				end
			end

			self.Refresh = function(_)
				local padding = ui.buttonPadding
				local border = ui.buttonBorder
				local underlinePadding = 0

				local paddingAndBorder = padding + border

				local content = self.text

				local paddingLeft = paddingAndBorder
				local paddingBottom = paddingAndBorder
				local totalWidth
				local totalHeight

				if self.fixedWidth ~= nil then
					totalWidth = self.fixedWidth
					paddingLeft = (totalWidth - content.Width) * 0.5
				else
					totalWidth = content.Width + paddingAndBorder * 2
				end

				if self.fixedHeight ~= nil then
					totalHeight = self.fixedHeight
					paddingBottom = (totalHeight - content.Height) * 0.5
				else
					totalHeight = content.Height + paddingAndBorder * 2 + underlinePadding
				end

				self.background.LocalPosition = Number3(0, 0, 0)
				self.background.Width = totalWidth
				self.background.Height = totalHeight

				if self.shadow ~= nil and type(self.shadow) ~= "boolean" then
					self.shadow.LocalPosition = Number3(0, -4, -ui.layerStep)
					self.shadow.Width = totalWidth
					self.shadow.Height = totalHeight
				end

				content.LocalPosition = Number3(
					totalWidth * 0.5 - content.Width * 0.5,
					totalHeight * 0.5 - content.Height * 0.5,
					ui.layerStep
				)
			end

			self.setColor = function(_, background, text, doNotRefresh)
				if background ~= nil then
					if type(background) ~= "Color" then
						error("setColor - first parameter (background color) should be a Color", 2)
					end
					self.colors = { Color(background), Color(background), Color(background) }
					self.colors[2]:ApplyBrightnessDiff(theme.buttonTopBorderBrightnessDiff)
					self.colors[3]:ApplyBrightnessDiff(theme.buttonBottomBorderBrightnessDiff)
				end
				if text ~= nil then
					if type(text) ~= "Color" then
						error("setColor - second parameter (text color) should be a Color", 2)
					end
					self.textColor = Color(text)
				end
				if doNotRefresh ~= true then
					self:RefreshColors()
				end
			end

			self.setColorPressed = function(self, background, text, doNotRefresh)
				if background ~= nil then
					self.colorsPressed = { Color(background), Color(background), Color(background) }
					self.colorsPressed[2]:ApplyBrightnessDiff(theme.buttonTopBorderBrightnessDiff)
					self.colorsPressed[3]:ApplyBrightnessDiff(theme.buttonBottomBorderBrightnessDiff)
				end
				if text ~= nil then
					self.textColorPressed = Color(text)
				end
				if doNotRefresh ~= true then
					self:RefreshColors()
				end
			end

			self.setShadowColor = function(self, color, doNotRefresh)
				self.shadowColor = Color(color)
				if doNotRefresh ~= true then
					self:RefreshColors()
				end
			end

			self:setColor(config.color, config.textColor, true)
			self:setColorPressed(config.colorPressed, config.textColorPressed, true)
			self:setShadowColor(config.shadowColor, true)

			self:RefreshColors()
			self:Refresh()

			self.OnPress = function(_, pe) end
			self.OnRelease = function(_, pe) end
			self.OnCancel = function(_, pe) end
			self.OnDrag = function(_, pe) end

			self.pointerDownWrapper = function(_, pe)
				local x = pe.X * Screen.Width
				local y = pe.Y * Screen.Height

				local dot = Number2(x, y)
				local check = ui:dot2Dcollision(
					ui:WorldToUIPosition(self.Object.Position),
					ui:WorldToUIPosition(ui:getNumber2(self.Object.Position) + Number2(self.Width, self.Height)),
					dot
				)

				if check == true then
					self.Pressed = true
					self:RefreshColors()
					self:OnPress(pe)
				end
			end
			self.pointerUpWrapper = function(_, pe)
				if self.Pressed == true then
					local x = pe.X * Screen.Width
					local y = pe.Y * Screen.Height

					local dot = Number2(x, y)

					self.Pressed = false
					self:RefreshColors()

					local check = ui:dot2Dcollision(
						ui:WorldToUIPosition(self.Object.Position),
						ui:WorldToUIPosition(ui:getNumber2(self.Object.Position) + Number2(self.Width, self.Height)),
						dot
					)

					if check == true then
						self:OnRelease(pe)
					else
						self:OnCancel(pe)
					end
				end
			end
			self.pointerCancelWrapper = function(_, pe)
				if self.Pressed == true then
					self.Pressed = false
					self:RefreshColors()
					self:OnCancel(pe)
				end
			end
			self.pointerDragWrapper = function(_, pe)
				if self.Pressed then
					local x = pe.X * Screen.Width
					local y = pe.Y * Screen.Height

					local dot = Number2(x, y)
					local check = ui:dot2Dcollision(
						ui:WorldToUIPosition(self.Object.Position),
						ui:WorldToUIPosition(ui:getNumber2(self.Object.Position) + Number2(self.Width, self.Height)),
						dot
					)

					self:OnDrag(pe, check)
				end
			end

			self.pointerDownListener = LocalEvent:Listen(LocalEvent.Name.PointerDown, function(pe)
				self:pointerDownWrapper(pe)
			end)
			self.pointerUpListener = LocalEvent:Listen(LocalEvent.Name.PointerUp, function(pe)
				self:pointerUpWrapper(pe)
			end)
			self.pointerCancelListener = LocalEvent:Listen(LocalEvent.Name.PointerCancel, function(pe)
				self:pointerCancelWrapper(pe)
			end)
			self.pointerDragListener = LocalEvent:Listen(LocalEvent.Name.PointerDrag, function(pe)
				self:pointerDragWrapper(pe)
			end)
		end
		nodeConfig.finalizer = function(self)
			self.pointerUpWrapper:Remove()
			self.pointerDownWrapper:Remove()
			self.pointerDragWrapper:Remove()
			self.pointerCancelWrapper:Remove()

			self.text:SetParent(nil)
			self.background:SetParent(nil)
			if self.shadow then
				self.shadow:SetParent(nil)
			end
			self.shadow = nil
			self.background = nil
			self.text = nil
		end
		nodeConfig.propertyGet = function(self, key)
			if key == "Width" then
				return self.fixedWidth
			elseif key == "Height" then
				return self.fixedHeight
			elseif key == "Text" then
				return self.text.Text
			end
		end
		nodeConfig.propertyChange = function(self, key, value)
			if key == "Width" then
				self.fixedWidth = value
				self:Refresh()
				self:resizeWrapper()
				return true
			elseif key == "Height" then
				self.fixedHeight = value
				self:Refresh()
				self:resizeWrapper()
				return true
			elseif key == "Text" then
				self.text.Text = value
				return true
			end
		end

		local node = ui:Node(nodeConfig)
		return node
	end

	--[[ HorizontalSlider object ]]
	--
	--HorizontalSlider, used to make sliders on the screen
	--
	--Example:
	--local slider = openui:HorizontalSlider(0, 100) -- [From 0 to 100]
	--slider.Value -- [set or get value of a slider]
	--
	openui.HorizontalSlider = function(ui, min, max, config)
		if ui == nil then
			error("openui.HorizontalSlider() - Use ':' instead of '.'", 2)
		end
		if type(min) ~= "number" and type(min) ~= "integer" then
			error("openui.HorizontalSlider(min, max, config) - min must be a number", 2)
		end
		if type(max) ~= "number" and type(max) ~= "integer" then
			error("openui.HorizontalSlider(min, max, config) - max must be a number", 2)
		end
		if config == nil then
			config = {}
		end

		local defaultConfig = {
			value = min,
			rounded = false,
			barSize = 32,
			barColor = Color(50, 50, 200),
			barColorPressed = Color(50, 50, 170),
			backgroundColor = Color(50, 50, 50),
			shadow = true,
			shadowColor = Color(0, 0, 0, 100),
			shadowOffset = Number2(0, -4),
		}
		local config = ui.mergeConfigs(defaultConfig, config)

		local nodeConfig = {
			openui_Tag = "horizontalslider",
		}
		nodeConfig.init = function(self)
			for key, value in pairs(config) do
				self[key] = value
			end
			self.val = self.value
			self.Min = min
			self.Max = max

			local lerp = function(a, b, w)
				return a + (b - a) * w
			end

			local round = function(x)
				return math.floor(x + 0.5)
			end

			self.button = ui:TextButton("", defaultConfig)
			self.button:SetParent(self)
			self.button:setColor(self.backgroundColor)
			self.button:setColorPressed(self.backgroundColor)

			self.button.Height = 50
			self.button.Width = 100

			self.bar = ui:Frame()
			self.bar:SetParent(self)
			self.bar.Color = self.barColor

			self.button.OnDrag = function(_, pe)
				local x = pe.X * Screen.Width

				local scPos = ui:WorldToUIPosition(self.Object.Position)

				local p = math.max(0, math.min(1, (x - scPos.X) / self.Width))
				local v = math.max(0, math.min(1, (x - (scPos.X + self.barSize / 2)) / (self.Width - self.barSize)))
				local d = lerp(self.Min, self.Max, v)
				self.Value = d
			end

			self.button.OnPress = function(pe)
				self.bar.Color = self.barColorPressed
			end
			self.button.OnRelease = function(pe)
				self.bar.Color = self.barColor
			end
			self.button.OnCancel = self.button.OnRelease

			self.setValue = function(_, value)
				self.val = value
				local pos =
					lerp(self.barSize / 2, self.Width - self.barSize / 2, (self.val - self.Min) / (self.Max - self.Min))
				if self.rounded == true then
					self.bar.Position.X = round(pos) - self.barSize / 2
				else
					self.bar.Position.X = pos - self.barSize / 2
				end
			end
			self.getValue = function(_, value)
				return self.val
			end

			self.bar.parentDidResize = function()
				self.bar.Width = self.barSize
				self.bar.Height = self.Height
				self:setValue(self.val)
			end
			self.bar.parentDidResize()

			self:setValue(self.value)
			self.value = nil
		end
		nodeConfig.finalizer = function(self)
			self.button:remove()
			self.bar:remove()
			self.button = nil
			self.bar = nil
		end
		nodeConfig.propertyGet = function(self, key)
			if key == "Width" then
				return self.button.Width
			elseif key == "Height" then
				return self.button.Height
			elseif key == "Value" then
				local round = function(x)
					return math.floor(x + 0.5)
				end

				if self.rounded == true then
					return round(self:getValue())
				else
					return self:getValue()
				end
			end
		end
		nodeConfig.propertyChange = function(self, key, value)
			if key == "Width" then
				self.button.Width = value
				self:resizeWrapper()
				return true
			elseif key == "Height" then
				self.button.Height = value
				self:resizeWrapper()
				return true
			elseif key == "Value" then
				self:setValue(value)
				return true
			end
		end

		local node = ui:Node(nodeConfig)
		return node
	end

	--[[ VerticalSlider object ]]
	--
	--VerticalSlider, used to make sliders on the screen
	--
	--Example:
	--local slider = openui:VerticalSlider(0, 100) -- [From 0 to 100]
	--slider.Value -- [set or get value of a slider]
	--
	openui.VerticalSlider = function(ui, min, max, config)
		if ui == nil then
			error("openui.VerticalSlider() - Use ':' instead of '.'", 2)
		end
		if type(min) ~= "number" and type(min) ~= "integer" then
			error("openui.VerticalSlider(min, max, config) - min must be a number", 2)
		end
		if type(max) ~= "number" and type(max) ~= "integer" then
			error("openui.VerticalSlider(min, max, config) - max must be a number", 2)
		end
		if config == nil then
			config = {}
		end

		local defaultConfig = {
			value = min,
			rounded = false,
			barSize = 32,
			barColor = Color(50, 50, 200),
			barColorPressed = Color(50, 50, 170),
			backgroundColor = Color(50, 50, 50),
			shadow = true,
			shadowColor = Color(0, 0, 0, 100),
			shadowOffset = Number2(0, -4),
		}
		local config = ui.mergeConfigs(defaultConfig, config)

		local nodeConfig = {
			openui_Tag = "verticalslider",
		}
		nodeConfig.init = function(self)
			for key, value in pairs(config) do
				self[key] = value
			end
			self.val = self.value
			self.Min = min
			self.Max = max

			local lerp = function(a, b, w)
				return a + (b - a) * w
			end

			local round = function(x)
				return math.floor(x + 0.5)
			end

			self.button = ui:TextButton("", defaultConfig)
			self.button:SetParent(self)
			self.button:setColor(self.backgroundColor)
			self.button:setColorPressed(self.backgroundColor)

			self.button.Height = 100
			self.button.Width = 50

			self.bar = ui:Frame()
			self.bar:SetParent(self)
			self.bar.Color = self.barColor

			self.button.OnDrag = function(_, pe)
				local y = pe.Y * Screen.Height

				local scPos = ui:WorldToUIPosition(self.Object.Position)

				local p = math.max(0, math.min(1, (y - scPos.Y) / self.Height))
				local v = math.max(0, math.min(1, (y - (scPos.Y + self.barSize / 2)) / (self.Height - self.barSize)))
				local d = lerp(self.Min, self.Max, v)
				self.Value = d
			end

			self.button.OnPress = function(pe)
				self.bar.Color = self.barColorPressed
			end
			self.button.OnRelease = function(pe)
				self.bar.Color = self.barColor
			end
			self.button.OnCancel = self.button.OnRelease

			self.setValue = function(_, value)
				self.val = value
				local pos = lerp(
					self.barSize / 2,
					self.Height - self.barSize / 2,
					(self.val - self.Min) / (self.Max - self.Min)
				)
				if self.rounded == true then
					self.bar.Position.Y = round(pos) - self.barSize / 2
				else
					self.bar.Position.Y = pos - self.barSize / 2
				end
			end
			self.getValue = function(_, value)
				return self.val
			end

			self.bar.parentDidResize = function()
				self.bar.Width = self.Width
				self.bar.Height = self.barSize
				self:setValue(self.val)
			end
			self.bar.parentDidResize()

			self:setValue(self.value)
			self.value = nil
		end
		nodeConfig.finalizer = function(self)
			self.button:remove()
			self.bar:remove()
			self.button = nil
			self.bar = nil
		end
		nodeConfig.propertyGet = function(self, key)
			if key == "Width" then
				return self.button.Width
			elseif key == "Height" then
				return self.button.Height
			elseif key == "Value" then
				local round = function(x)
					return math.floor(x + 0.5)
				end

				if self.rounded == true then
					return round(self:getValue())
				else
					return self:getValue()
				end
			end
		end
		nodeConfig.propertyChange = function(self, key, value)
			if key == "Width" then
				self.button.Width = value
				self:resizeWrapper()
				return true
			elseif key == "Height" then
				self.button.Height = value
				self:resizeWrapper()
				return true
			elseif key == "Value" then
				self:setValue(value)
				return true
			end
		end

		local node = ui:Node(nodeConfig)
		return node
	end

	--[[ Checkbox object ]]
	--
	--Checkbox, used to make checkboxes on the screen
	--
	--Example:
	--local checkbox = openui:Checbox()
	--checkbox.Checked -- true of false
	--
	openui.Checkbox = function(ui, config)
		if ui == nil then
			error("openui.Checkbox() - Use ':' instead of '.'", 2)
		end
		if config == nil then
			config = {}
		end

		local defaultConfig = {
			backgroundColor = Color(64, 64, 64),
			checkedColor = Color(50, 50, 200),
			checkedColorPressed = Color(50, 50, 170),
			uncheckedColor = Color(20, 20, 20),
			uncheckedColorPressed = Color(20, 20, 10),
		}
		local config = ui.mergeConfigs(defaultConfig, config)

		local nodeConfig = {
			openui_Tag = "checkbox",
		}
		nodeConfig.init = function(self)
			for key, value in pairs(config) do
				self[key] = value
			end

			self.frame = ui:Frame()
			self.frame:SetParent(self)
			self.frame.Color = self.backgroundColor

			self.button = ui:TextButton("", { shadow = false })
			self.button:SetParent(self.frame)

			self.OnToggle = function(_) end

			self.Checked = false
			self.UpdateColor = function(_)
				if self.Checked == true then
					self.button:setColor(self.checkedColor)
					self.button:setColorPressed(self.checkedColorPressed)
					self.button:RefreshColors()
				else
					self.button:setColor(self.uncheckedColor)
					self.button:setColorPressed(self.uncheckedColorPressed)
					self.button:RefreshColors()
				end
			end

			self.Toggle = function(_)
				self.Checked = not self.Checked
				if self.Checked == nil then
					self.Checked = false
				end
				self:UpdateColor()
				self:OnToggle()
			end
			self.button.OnRelease = function()
				self:Toggle()
			end

			self.button.parentDidResize = function(_)
				self.button.Width = self.frame.Width * 0.9 - 2
				self.button.Height = self.frame.Height * 0.9 - 2
				self.button.Position =
					Number2(self.frame.Width / 2 - self.button.Width / 2, self.Height / 2 - self.button.Height / 2)
			end

			self:UpdateColor()
		end
		nodeConfig.finalizer = function(self)
			self.button:remove()
			self.button = nil
			self.frame:remove()
			self.frame = nil
		end
		nodeConfig.propertyGet = function(self, key)
			if key == "Width" then
				return self.frame.Width
			elseif key == "Height" then
				return self.frame.Height
			end
		end
		nodeConfig.propertyChange = function(self, key, value)
			if key == "Width" then
				self.frame.Width = value
				self:resizeWrapper()
				return true
			elseif key == "Height" then
				self.frame.Height = value
				self:resizeWrapper()
				return true
			end
		end

		local node = ui:Node(nodeConfig)
		return node
	end

	--[[ Listeners ]]
	openui.screenResizeCallback = function(ui)
		ui.Camera.Width = Screen.Width
		ui.Camera.Height = Screen.Height
		ui.Camera.Far = openui.maxLayers + math.max(Screen.Width, Screen.Height)
		ui.Root.Position = Number3(-Screen.Width * 0.5, -Screen.Height * 0.5, ui.maxLayers)

		for child_i = 1, ui.Root.ChildrenCount do
			local childNode = ui.Root:GetChild(child_i).openui_node

			if childNode ~= nil then
				childNode:parentResizeWrapper()
			end
		end
	end

	openui.screenResizeListener = LocalEvent:Listen(LocalEvent.Name.ScreenDidResize, function()
		openui:screenResizeCallback()
	end)

	--[[ Modules ]]
	openui.ImportNode = function(ui, name, node)
		if ui == nil then
			error("openui:ImportNode() - use ':' instead of '.'", 2)
		end
		if type(name) ~= "string" then
			error("openui:ImportNode(name, node) - name should be a string", 2)
		end
		if type(node) ~= "function" then
			error("openui:ImportNode(name, node) - node should be a function (node constructor)", 2)
		end

		if ui[name] == nil then
			ui[name] = node
		else
			error("openui:ImportNode(name, node) - name '" .. name .. " is already imported/part of openui", 2)
		end
	end

	--[[ Debug Warning ]]
	if openui.debug then
		print("[OPENUI]: Debug mode enabled (openui_Setup({debug=true})")
	end

	return openui
end

return openui_manager
