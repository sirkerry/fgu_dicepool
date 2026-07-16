function onDrop(x, y, draginfo)
	local sPrototype, dropref = draginfo.getTokenData();
	if (sPrototype or "") == "" then
		return nil;
	end

	setPrototype(sPrototype);
	StoryPinsManager.replacePinToken(window.getDatabaseNode(), dropref);
	return true;
end

function onDragStart(button, x, y, draginfo)
	draginfo.setType("token");
	draginfo.setTokenData(getValue());

	if window.link then
		local sClass, sRecord = window.link.getValue();
		if sRecord == "" then
			sRecord = window.getDatabasePath();
		end
		draginfo.setShortcutData(sClass, sRecord);
	end
	return true;
end

function onDragEnd(draginfo)
	local prototype, dropref = draginfo.getTokenData();
	if dropref then
		StoryPinsManager.replacePinToken(window.getDatabaseNode(), dropref);
	end
	return true;
end

function onClickDown(button, x, y)
	return true;
end

function onDoubleClick(x, y)
	StoryPinsManager.openMap(window.getDatabaseNode());
end
