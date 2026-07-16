--
-- Story Pins
--
-- A "pin" is two linked pieces, the same mechanism CoreRPG's own Combat
-- Tracker uses to tie a CT entry to its token on the map: a plain Token
-- dropped onto the image, and a database record (under image.<id>.pins)
-- holding the link/name data, tied to that token via tokenrefnode/
-- tokenrefid (TokenManager.linkToken in stock CoreRPG writes those fields).
--
-- Dropping a record onto the panel (campaign/scripts/storypins_list.lua)
-- only creates the database entry -- it does not place a token on the map.
-- Placement happens when the entry's token thumbnail is dragged onto the
-- image (campaign/scripts/storypins_token.lua), the same native drag/drop
-- CoreRPG already uses for portraits/tokens everywhere else. That drop
-- calls back into replacePinToken() below to link the new token to the
-- pin's database record.
--

local fOnDoubleClick;

function onInit()
	ToolbarManager.registerButton("image_storypins", {
		sType = "toggle",
		sIcon = "image_pin",
		sTooltipRes = "tooltip_storypins",
		fnGetDefault = StoryPinsManager.getButtonDefault,
		fnOnValueChange = StoryPinsManager.onButtonToggle
	})

	fOnDoubleClick = TokenManager.onDoubleClick;
	TokenManager.onDoubleClick = StoryPinsManager.onDoubleClick;

	Token.addEventHandler("onDelete", StoryPinsManager.onTokenDelete);

	DB.addHandler("image.*.pins.*.name", "onUpdate", onPinNameUpdated)
end

function onTokenDelete(tokenMap)
	if not Session.IsHost then
		return;
	end

	local nodePin = StoryPinsManager.getPinFromToken(tokenMap)
	if nodePin then
		DB.setValue(nodePin, "tokenrefnode", "string", "");
		DB.setValue(nodePin, "tokenrefid", "string", "");
	end
end

function onDoubleClick(tokenMap, vImage)
	local nodePin = StoryPinsManager.getPinFromToken(tokenMap)

	-- Not a pin token -- fall through to normal token behavior
	if not nodePin then
		return fOnDoubleClick(tokenMap, vImage);
	end

	local sClass, sRecord = DB.getValue(nodePin, "link", "", "");

	if Session.IsHost then
		if sRecord ~= "" then
			Interface.openWindow(sClass, sRecord);
		else
			Interface.openWindow(sClass, nodePin);
		end
		return true;
	end

	local nodeEntry;
	if sRecord ~= "" then
		nodeEntry = DB.findNode(sRecord);
	else
		nodeEntry = nodePin;
	end

	if nodeEntry then
		Interface.openWindow(sClass, nodeEntry);
	else
		ChatManager.SystemMessage(Interface.getString("storypins_error_openotherlinkedtokenwithoutaccess"));
	end
	vImage.clearSelectedTokens();
	return true;
end

function onPinNameUpdated(nodeName)
	local nodePin = DB.getParent(nodeName);
	local token = StoryPinsManager.getTokenFromPin(nodePin);
	if token then
		StoryPinsManager.updateTooltip(token, nodePin);
	end
end

function getButtonDefault(c)
	return 0
end

function onButtonToggle(c)
	local cImage = WindowManager.callOuterWindowFunction(c.window, "getImage");
	local bShow = c.getValue() == 1

	if cImage.window.updateStoryPinsVisibility then
		cImage.window.updateStoryPinsVisibility(bShow)
	end
end

function replacePinToken(nodePin, newTokenInstance)
	local oldTokenInstance = StoryPinsManager.getTokenFromPin(nodePin);
	if oldTokenInstance and oldTokenInstance ~= newTokenInstance then
		if not newTokenInstance then
			local nodeContainerOld = oldTokenInstance.getContainerNode();
			if nodeContainerOld then
				local x,y = oldTokenInstance.getPosition();
				newTokenInstance = Token.addToken(DB.getPath(nodeContainerOld), DB.getValue(nodePin, "token", ""), x, y);
			end
		end
		-- New token's scale should match the old one
		local scale = oldTokenInstance.getScale();
		newTokenInstance.setScale(scale);

		oldTokenInstance.delete();
	end

	if not newTokenInstance then
		return;
	end

	TokenManager.linkToken(nodePin, newTokenInstance);
	StoryPinsManager.updateVisibility(nodePin);
	StoryPinsManager.updateTooltip(newTokenInstance, nodePin);

	-- Only the GM can reposition pins
	newTokenInstance.setPublicEdit(false);
end

function updateTooltip(token, node)
	if not token or not node then
		return;
	end

	token.setName(DB.getValue(node, "name", ""));
end

function getPinFromToken(token)
	if not token then
		return nil;
	end

	local nodeContainer = token.getContainerNode();
	local nId = token.getId();
	local sContainerNode = DB.getPath(nodeContainer);

	for _,v in ipairs(DB.getChildList(nodeContainer, "..pins")) do
		local sPinContainerName = DB.getValue(v, "tokenrefnode", "");
		local nPinId = tonumber(DB.getValue(v, "tokenrefid", "")) or 0;
		if (sPinContainerName == sContainerNode) and (nPinId == nId) then
			return v;
		end
	end

	return nil;
end

function getTokenFromPin(vEntry)
	local nodePin = nil;
	if type(vEntry) == "string" then
		nodePin = DB.findNode(vEntry);
	elseif type(vEntry) == "databasenode" then
		nodePin = vEntry;
	end
	if not nodePin then
		return nil;
	end

	return Token.getToken(DB.getValue(nodePin, "tokenrefnode", ""), DB.getValue(nodePin, "tokenrefid", ""));
end

function updateVisibility(nodePin)
	local token = StoryPinsManager.getTokenFromPin(nodePin);
	if not token then
		return;
	end

	local bVis = StoryPinsManager.getTokenVisibilityFromPin(nodePin);

	if not bVis then
		token.setVisible(false);
		return;
	end

	if token.isVisible() ~= true then
		token.setVisible(nil);
	end
end

function getTokenVisibilityFromPin(vEntry)
	local nodePin = nil;
	if type(vEntry) == "string" then
		nodePin = DB.findNode(vEntry);
	elseif type(vEntry) == "databasenode" then
		nodePin = vEntry;
	end
	if not nodePin then
		return true;
	end

	return (DB.getValue(nodePin, "tokenvis", 0) == 1);
end

function openMap(nodePin)
	if not nodePin then
		return;
	end
	ImageManager.centerOnToken(StoryPinsManager.getTokenFromPin(nodePin), true);
end
