--
-- Ruleset-agnostic "keep/drop" dice pool notation, since CoreRPG's own dice
-- string grammar (DiceManager.convertStringToDice) only understands NdM
-- combined with +/-, with no concept of keeping/dropping individual dice from
-- a pool. FGU's only native "keep 1 of 2" mechanic (5E-style advantage) is
-- hardcoded to exactly two dice (manager_action_d20.lua's encode/decodeAdvantage),
-- not a generic pool.
--
-- Grammar: NdM(kh|kl|dh|dl)K(+/-F)
--   kh/kl = keep highest/lowest K of the N dice; dh/dl = drop highest/lowest K.
--   Examples: 3d6kl1 (keep lowest 1 of 3), 4d6dl1 (classic ability-score gen),
--   2d20kh1 / 2d20kl1 (advantage/disadvantage equivalents).
--   v1 supports exactly one dice-group-with-modifier per string.
--
function onInit()
    Comm.registerSlashHandler("pool", performAction);
    ActionsManager.registerResultHandler("dicepool", onRoll);
end

-- Parses a pool string into (aDice, nMod, sMode, nKeepDrop), or nil if it
-- doesn't match the NdM(kh|kl|dh|dl)K(+/-F) grammar. Lua patterns have no
-- alternation ("|"), so the mode is matched as a 2-char class [kd][hl]
-- (kh/kl/dh/dl) rather than a real alternation group.
function parsePoolString(s)
    if not s then
        return nil;
    end
    s = s:gsub("%s+", ""):lower();

    local sCount, sSize, sMode, sKeepDrop, sModSign, sModVal =
        s:match("^(%d+)d(%d+)([kd][hl])(%d+)([%+%-]?)(%d*)$");
    if not sCount then
        return nil;
    end

    local nCount = tonumber(sCount);
    local nSize = tonumber(sSize);
    local nKeepDrop = tonumber(sKeepDrop);
    if not nCount or nCount < 1 or not nSize or nSize < 2 then
        return nil;
    end
    if not nKeepDrop or nKeepDrop < 1 or nKeepDrop > nCount then
        return nil;
    end

    local nMod = 0;
    if sModVal and sModVal ~= "" then
        nMod = tonumber(sModVal) or 0;
        if sModSign == "-" then
            nMod = -nMod;
        end
    end

    local aDice = {};
    for _ = 1, nCount do
        table.insert(aDice, "d" .. nSize);
    end

    return aDice, nMod, sMode, nKeepDrop;
end

function isPoolString(s)
    return parsePoolString(s) ~= nil;
end

function performAction(sCommand, sParams)
    sParams = StringManager.trim(sParams or "");
    if sParams == "" or sParams == "?" or sParams:lower() == "help" then
        createHelpMessage();
        return;
    end

    local aDice, nMod, sMode, nKeepDrop = parsePoolString(sParams);
    if not aDice then
        ChatManager.SystemMessage("Usage: /pool NdM(kh|kl|dh|dl)K(+/-F) -- e.g. /pool 3d6kl1");
        return;
    end

    local rActor = nil;
    if User.getCurrentIdentity() then
        rActor = ActorManager.resolveActor("charsheet." .. User.getCurrentIdentity());
    end

    local rRoll = {};
    rRoll.sType = "dicepool";
    rRoll.aDice = aDice;
    rRoll.nMod = nMod;
    rRoll.sPoolMode = sMode;
    rRoll.nPoolKeepDrop = nKeepDrop;
    rRoll.sDesc = "[POOL] " .. sParams;

    ActionsManager.performAction(nil, rActor, rRoll);
end

-- Sorts rRoll.aDice ascending by .result and splits into kept/dropped piles
-- per rRoll.sPoolMode/nPoolKeepDrop. Shared with the Table hookup
-- (manager_dicepool_tables.lua), which needs the same split before pruning
-- rRoll.aDice down to the kept dice.
function splitPool(rRoll)
    local aSorted = {};
    for _, v in ipairs(rRoll.aDice or {}) do
        table.insert(aSorted, v);
    end
    table.sort(aSorted, function(a, b) return (a.result or 0) < (b.result or 0) end);

    local nCount = #aSorted;
    local sMode = rRoll.sPoolMode;
    local nKeepDrop = rRoll.nPoolKeepDrop or 0;

    -- Reduce all four modes to "keep the first N of the sorted-ascending list"
    -- or "keep the last N" -- kl/dh keep from the front, kh/dl keep from the back.
    local nKeepFront, nKeepBack;
    if sMode == "kl" then
        nKeepFront = nKeepDrop;
    elseif sMode == "dh" then
        nKeepFront = nCount - nKeepDrop;
    elseif sMode == "kh" then
        nKeepBack = nKeepDrop;
    elseif sMode == "dl" then
        nKeepBack = nCount - nKeepDrop;
    end

    local aKept, aDropped = {}, {};
    for i, v in ipairs(aSorted) do
        local bKeep;
        if nKeepFront then
            bKeep = (i <= nKeepFront);
        else
            bKeep = (i > (nCount - (nKeepBack or 0)));
        end
        table.insert(bKeep and aKept or aDropped, v);
    end
    return aKept, aDropped;
end

function onRoll(rSource, rTarget, rRoll)
    local aKept, aDropped = splitPool(rRoll);

    local nTotal = rRoll.nMod or 0;
    for _, v in ipairs(aKept) do
        nTotal = nTotal + (v.result or 0);
    end

    local rMessage = ActionsManager.createActionMessage(rSource, rRoll);
    rMessage.text = rMessage.text .. "\n[KEPT]";
    for _, v in ipairs(aKept) do
        rMessage.text = rMessage.text .. " " .. v.result;
    end
    if #aDropped > 0 then
        rMessage.text = rMessage.text .. "\n[DROPPED]";
        for _, v in ipairs(aDropped) do
            rMessage.text = rMessage.text .. " " .. v.result;
        end
    end
    rMessage.text = rMessage.text .. "\n[TOTAL] " .. nTotal;

    Comm.deliverChatMessage(rMessage);
end

function createHelpMessage()
    local rMessage = ChatManager.createBaseMessage(nil, nil);
    rMessage.text = rMessage.text ..
        "The \"/pool\" command rolls a dice pool and keeps/drops some of the results.\r\n" ..
        "Format: NdM(kh|kl|dh|dl)K(+/-F)\r\n" ..
        "  kh/kl = keep highest/lowest K of the N dice, dh/dl = drop highest/lowest K.\r\n" ..
        "Examples:\r\n" ..
        "  /pool 3d6kl1   (keep lowest 1 of 3d6)\r\n" ..
        "  /pool 4d6dl1   (drop lowest 1 of 4d6 -- classic ability-score generation)\r\n" ..
        "  /pool 2d20kh1  (advantage)\r\n" ..
        "  /pool 2d20kl1  (disadvantage)\r\n" ..
        "  /pool 4d6dl1+2 (drop lowest 1 of 4d6, then add 2)";
    Comm.deliverChatMessage(rMessage);
end
