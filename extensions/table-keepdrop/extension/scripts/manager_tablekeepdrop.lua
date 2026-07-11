--
-- Adds a "Pool" Keep High/Keep Low + amount control to Table records (see
-- campaign/record_table_pool.xml), so rolling the table keeps/drops dice
-- before the row lookup.
--
-- This is scoped to Table records only. Stock FGU already natively supports
-- keep/drop dice-pool notation everywhere else via the /die command and the
-- {expr=...} roll form (e.g. /die 3d6kl1, or aDice={expr="4d6d1"} as the
-- official 5E ruleset's own character wizard uses for ability scores) --
-- confirmed via Fantasy Grounds' own "All Things Dice" documentation. Tables
-- are the one place that doesn't reach: TableManager/DiceManager roll tables
-- through a separate array-based pathway with no concept of an expr string
-- at all, so this extension only needs to cover that gap, not reimplement
-- keep/drop from scratch.
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
    TableManager.performRoll = performRoll_tablekeepdrop;

    Original_onTableRoll = ActionsManager.getResultHandler("table");
    ActionsManager.registerResultHandler("table", onTableRoll_tablekeepdrop);
end

function performRoll_tablekeepdrop(draginfo, rActor, rTableRoll, bUseModStack)
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
    local bValidMode = (sPoolMode == "kh") or (sPoolMode == "kl") or (sPoolMode == "dh") or (sPoolMode == "dl");
    if bValidMode and nPoolAmount > 0 and nPoolAmount <= #(rRoll.aDice or {}) then
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

-- Sorts rRoll.aDice ascending by .result and splits into kept/dropped piles
-- per rRoll.sPoolMode ("kh"/"kl"/"dh"/"dl") + nPoolKeepDrop.
function splitPool(rRoll)
    local aSorted = {};
    for _, v in ipairs(rRoll.aDice or {}) do
        table.insert(aSorted, v);
    end
    table.sort(aSorted, function(a, b) return (a.result or 0) < (b.result or 0) end);

    local nCount = #aSorted;
    local nAmount = rRoll.nPoolKeepDrop or 0;
    local sMode = rRoll.sPoolMode;

    -- Reduce all four modes to "keep the first N of the sorted-ascending list"
    -- or "keep the last N" -- kl/dh keep from the front, kh/dl keep from the back.
    local nKeepFront, nKeepBack;
    if sMode == "kl" then
        nKeepFront = nAmount;
    elseif sMode == "dh" then
        nKeepFront = nCount - nAmount;
    elseif sMode == "kh" then
        nKeepBack = nAmount;
    elseif sMode == "dl" then
        nKeepBack = nCount - nAmount;
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

function onTableRoll_tablekeepdrop(rSource, rTarget, rRoll)
    if rRoll.sPoolMode then
        local aKept, aDropped = splitPool(rRoll);
        rRoll.aDiceDropped = aDropped;
        rRoll.aDice = aKept;
    end
    Original_onTableRoll(rSource, rTarget, rRoll);
end
