function onInit()
	-- Acquire token reference, if a token was already placed on the map
	self.linkToken()

	registerMenuItem(Interface.getString("list_menu_deleteitem"), "delete", 6);
	registerMenuItem(Interface.getString("list_menu_deleteconfirm"), "delete", 6, 7);

	self.onEditModeChanged()
end

function onMenuSelection(selection, subselection)
	if selection == 6 and subselection == 7 then
		DB.deleteNode(getDatabaseNode())
	end
end

function onEditModeChanged()
	local bEditMode = WindowManager.getEditMode(self, "list_iedit");
	idelete.setVisible(bEditMode);
end

function onVisibilityChanged()
	StoryPinsManager.updateVisibility(getDatabaseNode());
end

function onLinkChanged()
	local node = link.getTargetDatabaseNode();
	if node and node ~= getDatabaseNode() then
		name.setLink(DB.createChild(node, "name", "string"), true);
	end
end

function linkToken()
	local imageinstance = token.populateFromImageNode(tokenrefnode.getValue(), tokenrefid.getValue());
	if imageinstance then
		TokenManager.linkToken(getDatabaseNode(), imageinstance);
		imageinstance.setPublicEdit(false);
	end
end

function setLink(sClass, sRecord)
	link.setValue(sClass, sRecord);
end

function setToken(sToken)
	token.setValue(sToken)
end
