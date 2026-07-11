# Table Keep/Drop

Ruleset-agnostic FGU extension — no `<ruleset>` tag, loads for any ruleset built on CoreRPG.

Adds a "Pool" cycler (`-` / Keep High / Keep Low / Drop High / Drop Low) plus an amount field to Table records, so a table's own dice roll can drop dice *before* the row lookup — e.g. roll `3d10`, keep the lowest 2, and pick the table row off that reduced total.

## Why this exists, and why it's scoped to just Tables

Stock FGU already has rich, native keep/drop dice-pool notation — confirmed via Fantasy Grounds' own ["All Things Dice"](https://fantasygroundsunity.atlassian.net/wiki/spaces/FGCP/pages/2109571073/All+Things+Dice) documentation and the official 5E ruleset's own character wizard (`aDice = { expr = "4d6d1" }` for ability-score generation). The `/die` command and the `expr`-based roll form already support:

| Syntax | Meaning |
|---|---|
| `kN` | keep highest N |
| `klN` | keep lowest N |
| `dN` | drop lowest N |
| `!` / `e!` / `p` | compounding / exploding / penetrating dice (one reroll mechanic per term) |
| `sX#Y` / `fX#Y` | success/fail counting |
| `(3d4+2d6)kl2` | mixed dice sets — keep/drop applies across the whole combined pool |

So `/die 3d6kl1` (or dragging that into a hotkey) already does everything a custom slash command would — with proper native dice-tray animation, no extension needed. An earlier version of this extension reimplemented that in Lua as a `/pool` command; it's been removed as pure duplication.

**Tables are the one place this doesn't reach.** Confirmed by reading `TableManager`/`DiceManager` source directly: a Table's own dice roll goes through a completely separate, array-based pathway (`DiceManager.convertStringToDice`, which only understands `NdM` combined with `+`/`-`) with no concept of an `expr` string at all. So this extension is scoped to exactly that gap — hence the name change from the original "Dice Pool" to "Table Keep/Drop".

## How it works

- A "Pool" cycler (`-`/Keep High/Keep Low/Drop High/Drop Low) + amount number field are added to Table records between the existing Custom (dice + mod) and Output fields, via `campaign/record_table_keepdrop.xml` (`merge="join"` + `insertbefore`, the same pattern `2e-brs` uses). The table's existing dice/mod fields are untouched. Both keep and drop directions are offered on the cycler even though they're mathematically redundant with each other (e.g. "drop lowest 1 of 4" == "keep highest 3 of 4") — it's just more natural to think in whichever direction matches how a given table's row range was designed.
- `TableManager.performRoll` is fully reimplemented (not wrapped): it calls stock `TableManager.getTableDice` unchanged for the dice/mod values, then reads the two new `poolmode`/`poolamount` DB fields and stashes them on the roll object being constructed.
- `TableManager.onTableRoll`'s registered result handler is captured via `ActionsManager.getResultHandler("table")` (not by referencing `TableManager.onTableRoll` directly) and re-registered, composing correctly with any other extension that's also hooked table rolls regardless of load order — same approach `2e-target20` uses for skill rolls. It sorts/splits `rRoll.aDice` into kept/dropped piles per whichever of the four modes is set, replaces `rRoll.aDice` with just the kept dice, then delegates to whatever was previously registered. Because `ActionsManager.total(rRoll)` (stock CoreRPG) is just `Utility.getDiceTotal(rRoll.aDice) + rRoll.nMod` with no concept of "dropped" dice, pruning the array before delegating means the stock row-lookup logic needs zero changes.

Confirmed live in Shadowdark: a `3d10` table with Pool = Keep Low 2 correctly summed only the two lowest dice and matched the corresponding table row off that reduced total, not the raw 3-dice sum.

**Known, accepted limitation:** unlike what a `[KEPT]`/`[DROPPED]` breakdown would show, a Table roll's chat message doesn't display which die got dropped — only the kept dice appear in the roll box (e.g. `2d10` instead of `3d10` for a keep-2-of-3 roll). This is because the dropped die is pruned out of `rRoll.aDice` before stock's own message-building code ever sees it, and reproducing stock's table chat formatting just to reinsert that detail wasn't judged worth the added complexity.

## Compatibility

- Any CoreRPG-based ruleset (no `<ruleset>` tag in `extension.xml`)
- Touches `TableManager.performRoll` (direct reassignment) and the `"table"` result handler (via `ActionsManager.registerResultHandler`, composable with other extensions)

## Installation

Drop the `table-keepdrop` folder into your Fantasy Grounds Unity `extensions/` directory and enable it — works with any ruleset/campaign.
