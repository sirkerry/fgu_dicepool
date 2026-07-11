# fgu_dicepool

Ruleset-agnostic Fantasy Grounds Unity extensions, by Kerry Harrison (sirkerry).

Each extension lives in its own folder under `extensions/`, fully
self-contained with its own workflow scripts (`backup.sh`/`deploy.sh`/
`sync-to-repo.sh`/`restore.sh`/`build-ext.sh`) and README — see
[[feedback_live_first_no_symlinks]]: all FGU dev happens live at
`~/.smiteworks/fgdata/extensions/<name>/`, never via symlink; these repo
folders are git-tracked backups synced with `sync-to-repo.sh`.

## Extensions

- **[table-keepdrop](extensions/table-keepdrop/README.md)** — Table
  Keep/Drop. Stock FGU already natively supports keep/drop dice notation
  everywhere (`/die 3d6kl1`, etc.) — Tables are the one place that doesn't
  reach, since they roll through a separate array-based pathway. Adds a
  Keep High/Keep Low/Drop High/Drop Low + amount field to Table records so
  the row lookup uses the post-keep/drop total. No `<ruleset>` tag — loads
  for any CoreRPG-based ruleset.
