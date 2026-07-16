function onInit()
	DB.addHandler(DB.getPath(window.getDatabaseNode(), "pins.*"), "onDelete", onPinDeleted);
end

function onClose()
	DB.removeHandler(DB.getPath(window.getDatabaseNode(), "pins.*"), "onDelete", onPinDeleted);
end

function addEntry(sClass, sRecord)
	local w = createWindow();
	if not w then
		return;
	end
	w.setLink(sClass, sRecord)

	-- If the dropped record already has its own token/portrait, use it as
	-- the pin's starting token image
	local node = DB.findNode(sRecord);
	if node then
		local token = DB.getValue(node, "token", "");
		if token ~= "" then
			w.setToken(token);
		end
	end

	return w;
end

function onDrop(x, y, draginfo)
	local sDragType = draginfo.getType();
	if sDragType ~= "shortcut" then
		return false;
	end

	local sClass, sRecord = draginfo.getShortcutData()
	self.addEntry(sClass, sRecord);
	return true;
end

function onPinDeleted(nodeDeleted)
	local token = StoryPinsManager.getTokenFromPin(nodeDeleted);
	if token then
		token.delete();
	end
end
