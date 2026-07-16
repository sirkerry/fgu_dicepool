# Story Pins

Ruleset-agnostic FGU extension — no `<ruleset>` tag, loads for any ruleset built on CoreRPG.

Adds a **Story Pins** panel to Image/Map windows. Drop any record onto the panel (a story entry, NPC, item, another image — anything draggable as a "shortcut") to create a pin entry, then drag that entry's token thumbnail onto the map to place the pin. Double-click a placed pin to open whatever it's linked to.

## Why this exists

Stock CoreRPG (confirmed by reading `CoreRPG.pak` directly — `scripts/`, `campaign/record_image.xml`) has no pin database schema, no `addPin`-style API, and no scriptable way to drop a linked marker onto a map. It does ship the icon assets for one (`graphics/icons/image_pin.png`, `image_pin_public.png`, both registered in `graphics_icons.xml`), suggesting a native version may be coming, but as of the current build there's nothing wired up to use them.

## How it works

A "pin" is two linked pieces — the same mechanism CoreRPG's own Combat Tracker uses to tie a CT entry to its token on the map:

1. A database record under `image.<id>.pins`, holding the link (`link`, a `windowreference` field — class + record path of whatever was dropped) and a display `name`.
2. A plain `Token` placed on the image, tied to that record via `tokenrefnode`/`tokenrefid` — written by stock `TokenManager.linkToken()` (`scripts/manager_token.lua`), not anything custom.

Dropping a record onto the panel (`campaign/scripts/storypins_list.lua:onDrop`) only creates the database entry — it does **not** auto-place a token on the map. Placement happens when the entry's token thumbnail (a standard `tokenfield` control) is dragged onto the image, the same native drag/drop CoreRPG already uses everywhere for portraits and tokens (`campaign/scripts/storypins_token.lua`). That drop calls `StoryPinsManager.replacePinToken()` to link the new token back to the pin's record.

Double-clicking any token on any image routes through `TokenManager.onDoubleClick`, which this extension wraps: if the clicked token belongs to a pin, it opens the linked record instead of normal token click behavior; otherwise it falls through to whatever was previously registered.

This design — including the panel layout, the drop/drag flow, and the token-linking approach — is adapted directly from the community **Points of Interest** extension by Saagael (`reference/extensions/PointsOfInterest` in this workspace), which already proved the pattern works. This version is a leaner, ruleset-agnostic port: renamed (`poi` → `pins`, `POI` → `StoryPinsManager`), and the unidentified/ID-state mirroring logic (`isidentified`/`nonid_name`, relevant to items/NPCs that can be hidden from players) was dropped since it isn't central to marking locations on a map.

## Files

- `extension/campaign/record_image_storypins.xml` — merges the panel into `imagewindow`/`imagepanelwindow`, plus the toolbar toggle button, the pin-entry windowclass, and the token-thumbnail template.
- `extension/campaign/scripts/storypins_imagewindow.lua` — shows/hides the panel from the toolbar toggle.
- `extension/campaign/scripts/storypins_list.lua` — handles dropping a record onto the panel to create an entry; deletes the entry's token when the entry itself is deleted.
- `extension/campaign/scripts/storypins_entry.lua` — per-entry behavior: linking to the placed token on init, right-click delete, mirroring the linked record's `name`.
- `extension/campaign/scripts/storypins_token.lua` — drag-to-place/reposition the pin's token on the map.
- `extension/scripts/manager_storypins.lua` — toolbar button registration, the `TokenManager.onDoubleClick` wrapper, and the pin↔token lookup/link helpers.

## Compatibility

- Any CoreRPG-based ruleset (no `<ruleset>` tag in `extension.xml`)
- Wraps `TokenManager.onDoubleClick` by capturing and chaining to the previous handler, so it composes with other extensions that also hook it (rather than overwriting a fixed reference)
- Uses stock CoreRPG's `image_pin` icon (already shipped in `CoreRPG.pak`) for the toolbar toggle — no custom artwork needed

## Status

Confirmed working live in Fantasy Grounds Unity: dropping a record onto the panel creates an entry, dragging its token thumbnail onto the map places the pin, and double-clicking it opens the linked record. Built from static source analysis (reading the shipping `CoreRPG.pak` and the proven `PointsOfInterest` extension) and then verified in-client rather than assumed — this wasn't an exhaustive pass across every ruleset/permission combination, so if you hit an edge case (e.g. player-side double-click permissions, or a ruleset that overrides `imagewindow`/`TokenManager.onDoubleClick` itself), treat it as a compatibility gap to check first.

## Installation

Drop the `story-pins` folder into your Fantasy Grounds Unity `extensions/` directory and enable it, or run `./deploy.sh` from this repo folder to push it to the live `~/.smiteworks/fgdata/extensions/story-pins/` (see [[feedback_live_first_no_symlinks]] — all dev happens live, this folder is the git-tracked backup, synced with `./sync-to-repo.sh`).
