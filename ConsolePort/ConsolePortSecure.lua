local _
local _, G = ...;

local function MainBarAction(action)
	if 	type(action) == "table" and
		action:GetParent() and
		action:GetParent() == MainMenuBarArtFrame then
		return action:GetID();
	else
		return nil;
	end
end

function ConsolePort:CreateManager()
	if not ConsolePortManager then
		local m = CreateFrame("Frame", "ConsolePortManager", ConsolePort, "SecureHandlerStateTemplate");
		SecureHandlerExecute(m, [[
			CP_BUTTONS = newtable();
			UpdateMainActionBar = [=[
				local page = ...;
				if page == "tempshapeshift" then
					if HasTempShapeshiftActionBar() then
						page = GetTempShapeshiftBarIndex();
					else
						page = 1;
					end
				elseif page == "possess" then
					page = self:GetFrameRef("MainMenuBarArtFrame"):GetAttribute("actionpage");
					if page <= 10 then
						page = self:GetFrameRef("OverrideActionBar"):GetAttribute("actionpage");
					end
					if page <= 10 then
						page = 12;
					end
				end
				self:SetAttribute("actionpage", page);
				for btn in pairs(CP_BUTTONS) do
					btn:SetAttribute("actionpage", page);
				end
			]=]
		]]);
		m:SetFrameRef("MainMenuBarArtFrame", MainMenuBarArtFrame)
		m:SetFrameRef("OverrideActionBar", OverrideActionBar)
		local state = {};
		table.insert(state, "[overridebar][possessbar]possess");
		for i = 2, 6 do
			table.insert(state, ("[bar:%d]%d"):format(i, i));
		end
		local _, playerClass = UnitClass("player");
		if playerClass == "DRUID" then
			table.insert(state, "[bonusbar:1,stealth]8");
		elseif playerClass == "WARRIOR" then
			table.insert(state, "[stance:2]7");
			table.insert(state, "[stance:3]8");
		end
		for i = 1, 4 do
			table.insert(state, ("[bonusbar:%d]%d"):format(i, i+6));
		end
		table.insert(state, "[stance:1]tempshapeshift");
		table.insert(state, "1");
		state = table.concat(state, ";");
		local now = SecureCmdOptionParse(state);
		m:SetAttribute("actionpage", now);
		RegisterStateDriver(m, "page", state);
		m:SetAttribute("_onstate-page", [=[
			self:Run(UpdateMainActionBar, newstate);
		]=]);
	end
end

function ConsolePort:CreateSecureButton(name, modifier, clickbutton, UIcommand)
	local btn 	= CreateFrame("Button", name..modifier, UIParent, "SecureActionButtonTemplate");
	local functionRefs = {
		"Taxi", "Gossip", "Quest", "Map", "Book", "Spec", "Glyph", "Menu",
		"Bags", "Gear", "Shop", "Misc", "Popup", "Loot", "Stack", -- "List" (taint issue, left out atm)
	}
	btn.name 	= name;
	btn.timer 	= 0;
	btn.state 	= G.STATE_UP;
	btn.action 	= _G[clickbutton];
	btn.command = UIcommand;
	btn.mod 	= modifier;
	btn.default = {
		type = "click",
		attr = "clickbutton",
		val  = btn.action
	};
	for i, func in pairs(functionRefs) do
		btn[func] = function(btn) self[func](self, btn.command, btn.state); end;
	end
	btn.rebind 	= function(btn) self:ChangeButtonBinding(btn); end;
	btn.revert 	= function()
		if  MainBarAction(btn.default.val) then
			btn.default.type = "action";
			btn.default.attr = "action";
			btn.default.val  = MainBarAction(btn.default.val);
		end
		btn:SetAttribute("type", btn.default.type);
		btn:SetAttribute(btn.default.attr, btn.default.val);
	end
	btn:SetID(btn.action:GetID());
	btn.revert();
	btn:SetAttribute("actionpage", ConsolePortManager:GetAttribute("actionpage"));
	btn:RegisterEvent("PLAYER_REGEN_DISABLED");
	btn:SetScript("OnEvent", function(self, event, ...)
		self.revert();
	end);
	btn:HookScript("OnMouseDown", function(self, button)
		local func = self:GetAttribute("type");
		local click = self:GetAttribute("clickbutton");
		self.state = G.STATE_DOWN;
		self.timer = 0;
		if 	func == "click" or func == "action" then
			click:SetButtonState("PUSHED");
			return;
		end
		-- Fire function twice where keystate is requested
		if 	self[func] then self[func](self); end;
	end);
	btn:HookScript("OnMouseUp", function(self, button)
		local func = self:GetAttribute("type");
		local click = self:GetAttribute("clickbutton");
		self.state = G.STATE_UP;
		if func == "click" or func == "action" then
			click:SetButtonState("NORMAL");
		end
	end);
	if 	btn.command == G.UP or
		btn.command == G.DOWN or
		btn.command == G.LEFT or
		btn.command == G.RIGHT then
		btn:SetScript("OnUpdate", function(self, elapsed)
			self.timer = self.timer + elapsed;
			if self.timer >= 0.2 and btn.state == G.STATE_DOWN then
				local func = self:GetAttribute("type");
				if func and self[func] then self[func](self); end;
				self.timer = 0;
			end
		end);
	end
	ConsolePortManager:SetFrameRef("NewButton", btn);
	SecureHandlerExecute(ConsolePortManager, [[
        CP_BUTTONS[self:GetFrameRef("NewButton")] = true
    ]]);
end
