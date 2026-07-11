# fgu_dicepool

Ruleset-agnostic Fantasy Grounds Unity extensions, by Kerry Harrison (sirkerry).

Each extension lives in its own folder under `extensions/`, fully
self-contained with its own workflow scripts (`backup.sh`/`deploy.sh`/
`sync-to-repo.sh`/`restore.sh`/`build-ext.sh`) and README — see
[[feedback_live_first_no_symlinks]]: all FGU dev happens live at
`~/.smiteworks/fgdata/extensions/<name>/`, never via symlink; these repo
folders are git-tracked backups synced with `sync-to-repo.sh`.

## Extensions

- **[dicepool](extensions/dicepool/README.md)** — Dice Pool (Keep/Drop).
  Adds `NdM(kh|kl|dh|dl)K(+/-F)` keep/drop dice pool notation (e.g. `3d6kl1`,
  `4d6dl1`, `2d20kh1`) via a `/pool` slash command, and lets Table records use
  the same syntax in their own dice field so the row lookup uses the
  post-keep/drop total. No `<ruleset>` tag — loads for any CoreRPG-based
  ruleset.
