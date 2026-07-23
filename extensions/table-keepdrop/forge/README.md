# Table Keep/Drop

Ruleset-agnostic FGU extension — works with any ruleset built on CoreRPG.

Adds a Pool option (Keep High / Keep Low / Drop High / Drop Low) plus an amount field to Table records, so a table's dice roll can drop dice before the row lookup — for example, roll 3d10, keep the lowest 2, and pick the table row off that reduced total.

## How to Use

1. Open any Table record — it now has a **Pool** cycler and an amount field between the existing dice/modifier fields and the Output field.
2. Set Pool to Keep High, Keep Low, Drop High, or Drop Low, and enter how many dice to keep or drop.
3. Roll the table as normal — the kept dice are summed (plus any modifier) and used to look up the matching row; dropped dice are excluded from the total.

## Known Limitation

The chat roll message shows only the kept dice (e.g. `2d10` for a keep-2-of-3 roll) — it doesn't display which die was dropped.

## Compatibility

- Any CoreRPG-based ruleset
