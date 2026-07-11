# Dice Pool (Keep/Drop)

Ruleset-agnostic FGU extension — no `<ruleset>` tag, loads for any ruleset built on CoreRPG.

Adds "keep/drop" dice pool notation that FGU has no native equivalent for. CoreRPG's own dice-string grammar (`DiceManager.convertStringToDice`) only understands `NdM` combined with `+`/`-`; its only native "keep 1 of 2" mechanic (5E-style advantage/disadvantage) is hardcoded to exactly two dice, not a generic pool.

## Grammar

```
NdM(kh|kl|dh|dl)K(+/-F)
```

- `kh`/`kl` = keep highest/lowest `K` of the `N` dice
- `dh`/`dl` = drop highest/lowest `K` of the `N` dice
- `F` = an optional flat modifier

Examples:
- `3d6kl1` — keep the lowest 1 of 3d6
- `4d6dl1` — drop the lowest 1 of 4d6 (classic ability-score generation)
- `2d20kh1` / `2d20kl1` — advantage / disadvantage equivalents
- `4d6dl1+2` — drop lowest 1 of 4d6, then add 2

v1 supports exactly **one** dice-group-with-modifier per string (no mixing `3d6kl1 + 2d8kh1` in a single roll).

## Two ways to use it

1. **Slash command**: `/pool 3d6kl1` — rolls the pool and reports `[KEPT]`/`[DROPPED]`/`[TOTAL]` in chat.
2. **Table records**: a "Pool" cycler (`-` / Keep High / Keep Low) plus an amount field are added between the table's existing Custom (dice + mod) fields and the Output field. Set e.g. a `4d6` table's Pool to Keep High 3, roll it as normal — the row lookup uses the post-keep/drop total, not the raw sum of all dice rolled. Only two modes are offered (not drop-high/drop-low too) since "drop lowest K of N" and "keep highest (N-K) of N" are the same result — no expressiveness is lost.

The table's own `dice` field is *not* used for pool syntax (CoreRPG's `basicdice` widget is drag-and-drop only, with no way to type a string into it) — Pool mode/amount are two dedicated DB fields (`poolmode`/`poolamount`) instead. `DicePoolManager.parsePoolString`/`isPoolString` remain exclusively used by the `/pool` slash command.

Confirmed live in Shadowdark: a 3-row test (`3d10`, Pool = Keep Low 2) correctly summed only the two lowest dice and matched the corresponding table row off that reduced total, not the raw 3-dice sum.

**Known, accepted limitation:** unlike `/pool`'s `[KEPT]`/`[DROPPED]` chat breakdown, a Table roll's chat message doesn't show which die got dropped — only the kept dice appear in the roll box (e.g. `2d10` instead of `3d10` for a keep-2-of-3 roll). This is because the dropped die is pruned out of `rRoll.aDice` before stock's own message-building code ever sees it, and reproducing stock's table chat formatting just to reinsert that detail wasn't judged worth the added complexity.

## How the Table hookup works

`ActionsManager.total(rRoll)` (stock CoreRPG) is just `Utility.getDiceTotal(rRoll.aDice) + rRoll.nMod` — a flat sum of every die in the array, with no concept of "dropped" dice anywhere in the engine. So this extension prunes the dropped dice out of `rRoll.aDice` *before* stock's own total/row-lookup logic runs, meaning that logic needs zero changes — it naturally sums only what's left.

- `TableManager.performRoll` is fully reimplemented (not wrapped) because the pool metadata (mode + keep/drop count) has to be attached to the `rRoll` object while it's being constructed inside that function — there's no way to inject it from outside afterward. It still calls stock `TableManager.getTableDice` unchanged for the dice/mod values; it only adds reading the two new `poolmode`/`poolamount` fields afterward.
- `TableManager.onTableRoll`'s registered result handler is captured via `ActionsManager.getResultHandler("table")` (not by referencing `TableManager.onTableRoll` directly) and re-registered, so this composes correctly with any other extension that's also hooked table rolls, regardless of load order — same approach `2e-target20` uses for skill rolls. The wrapper sorts/splits `rRoll.aDice` into kept/dropped, replaces `rRoll.aDice` with just the kept dice, then delegates to whatever was previously registered.
- The new fields are added via `campaign/record_table_pool.xml` (`merge="join"` + `insertbefore="output"`, the same pattern `2e-brs` uses), positioned between the existing Custom and Output fields — inserting before `output` is enough since every field in that row chains left-to-right off the *previous sibling in document order*, so `output` shifts right automatically without needing to be touched itself.

## Compatibility

- Any CoreRPG-based ruleset (no `<ruleset>` tag in `extension.xml`)
- Touches `TableManager.performRoll` (direct reassignment) and the `"table"` result handler (via `ActionsManager.registerResultHandler`, composable with other extensions)

## Installation

Drop the `dicepool` folder into your Fantasy Grounds Unity `extensions/` directory and enable it — works with any ruleset/campaign.
