--
-- Adds a "Pool" Keep High/Keep Low + amount control to Table records (see
-- campaign/record_table_pool.xml), so rolling the table keeps/drops dice
-- before the row lookup, instead of only being usable via the standalone
-- /pool command. The table's existing dice/mod fields are untouched -- Pool
-- mode/amount are two extra DB fields (poolmode/poolamount) read directly,
-- no string parsing involved (DicePoolManager.parsePoolString/isPoolString
-- remain exclusively used by the /pool slash command).
--
-- ActionsManager.total(rRoll) (manager_actions.lua) is just
-- Utility.getDiceTotal(rRoll.aDice) + rRoll.nMod -- a flat sum of every die
-- in the array, with no concept of "dropped" dice anywhere in the engine.
-- So the approach here is: prune the dropped dice out of rRoll.aDice before
-- stock's own total/row-lookup logic ever runs, so that logic needs no
-- changes at all -- it naturally sums only what's left.
--
-- Two functions need touching:
--   performRoll   - full reimplementation (not a wrapper), since the pool
--                   metadata (sPoolMode/nPoolKeepDrop) has to be attached to
--                   the rRoll object *while it's being constructed* here --
--                   there's no way to inject it from outside afterward.
--   onTableRoll   - thin wrapper: prune rRoll.aDice to the kept dice, then
--                   delegate to whatever was previously registered (stock,
--                   or another extension's override) for the "table" result.
--
function onInit()
    TableManager.performRoll = performRoll_dicepool;

    Original_onTableRoll = ActionsManager.getResultHandler("table");
    ActionsManager.registerResultHandler("table", onTableRoll_dicepool);
end

function performRoll_dicepool(draginfo, rActor, rTableRoll, bUseModStack)
    if (#(rTableRoll.aDice or {}) == 0) and ((rTableRoll.nMod or 0) == 0) then
        rTableRoll.aDice, rTableRoll.nMod = TableManager.getTableDice(rTableRoll.nodeTable);
    end

    local rRoll = {};
    rRoll.sType = "table";
    rRoll.sDesc = string.format("[%s] %s", Interface.getString("table_tag"), StringManager.capitalizeAll(DB.getValue(rTableRoll.nodeTable, "name", "")));
    if rTableRoll.nColumn and rTableRoll.nColumn > 0 then
        rRoll.sDesc = rRoll.sDesc .. " [" .. rTableRoll.nColumn .. " - " .. DB.getValue(rTableRoll.nodeTable, "labelcol" .. rTableRoll.nColumn) .. "]";
    end
    rRoll.sNodeTable = DB.getPath(rTableRoll.nodeTable);

    rRoll.aDice = rTableRoll.aDice;
    rRoll.nMod = rTableRoll.nMod;

    local sPoolMode = DB.getValue(rTableRoll.nodeTable, "poolmode", "");
    local nPoolAmount = DB.getValue(rTableRoll.nodeTable, "poolamount", 0);
    if (sPoolMode == "kh" or sPoolMode == "kl") and nPoolAmount > 0 and nPoolAmount <= #(rRoll.aDice or {}) then
        rRoll.sPoolMode = sPoolMode;
        rRoll.nPoolKeepDrop = nPoolAmount;
    end

    if rTableRoll.bSecret then
        rRoll.bSecret = rTableRoll.bSecret;
    elseif Session.IsHost then
        rRoll.bSecret = (DB.getValue(rTableRoll.nodeTable, "hiderollresults", 0) == 1);
    end
    if rTableRoll.sOutput then
        rRoll.sOutput = rTableRoll.sOutput;
        if rTableRoll.nodeOutput then
            rRoll.sOutputNode = DB.getPath(rTableRoll.nodeOutput);
        end
    elseif Session.IsHost then
        rRoll.sOutput = DB.getValue(rTableRoll.nodeTable, "output", "");
    end

    if bUseModStack and not ModifierStack.isEmpty() then
        local sStackDesc, nStackMod = ModifierStack.getStack(true);
        rRoll.sDesc = rRoll.sDesc .. " [" .. sStackDesc .. "]";
        rRoll.nMod = rRoll.nMod + nStackMod;
    end

    ActionsManager.performAction(draginfo, rActor, rRoll);
end

function onTableRoll_dicepool(rSource, rTarget, rRoll)
    if rRoll.sPoolMode then
        local aKept, aDropped = DicePoolManager.splitPool(rRoll);
        rRoll.aDiceDropped = aDropped;
        rRoll.aDice = aKept;
    end
    Original_onTableRoll(rSource, rTarget, rRoll);
end
