function updateStoryPinsVisibility(bShowPinsWindow)
	if not storypins then return end

	if bShowPinsWindow ~= storypins.isVisible() then
		storypins.subwindow.list_iedit.setValue(0);
		storypins.setVisible(bShowPinsWindow);
	end
end
