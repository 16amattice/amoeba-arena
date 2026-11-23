# Amoeba Arena — prototype 0.1

**Eat • Escape • Evolve**

A 2D single-player Android arcade prototype. Bigger living cells take bites out of smaller ones instead of consuming them instantly. Losing mass makes victims faster: run, collect nutrients, and grow back. The last bite eliminates a cell.

## Features

- Procedurally animated, continuously wobbling amoeba shapes with visible bite dents and nuclei
- Mass-dependent movement: small cells have higher top speed
- Contact-based bite combat and mass transfer; survival until fully consumed
- Food pellets that replenish mass
- 19 AI competitors that forage, chase prey, and flee predators
- Arena boundaries, minimap, HUD, survival timer, KOs, saved mass record
- Offline touch-drag joystick and desktop WASD/arrow/mouse controls
- No ads, accounts, copied third-party assets, or internet permission

## Play on a computer

Install Godot Engine **4.7.2** (non-.NET edition), import project.godot, and press **F5**. Click or tap to begin, then drag to move. Desktop WASD, arrow keys, and mouse are also supported.

## Build the Android APK

The GitHub Actions workflow at .github/workflows/build-android.yml runs automatically on pushes to main and can be run manually in the **Actions** tab.

After a successful run, open the workflow run, download the **amoeba-arena-android-apk** artifact, extract amoeba-arena.apk, and install it on your phone. Allow installation from your browser/files app if prompted.

The current workflow creates a temporary debug signing key each time. These APKs are for personal testing, not Google Play distribution. Future upgrades may require uninstalling the earlier build due to differing signing keys. A production release requires a securely maintained release key.

## Files

- scripts/game.gd: main gameplay, AI, collision/bites, food, visual effects and HUD
- scenes/main.tscn: starting scene
- tests/arena_smoke.gd: Godot gameplay checks
- scripts/configure_android.py: sets SDK paths on the CI runner
- export_presets.cfg: Android debug APK settings
- .github/workflows/build-android.yml: automated Android build
- assets/icon.svg: procedural amoeba logo

## Scope and roadmap

This is a single-player prototype, not online multiplayer yet. Sound, lobbies, skins, matchmaking, abilities, and balancing remain future work. Godot is open source and subject to its own license; the prototype was written for this project.

## Prototype 0.2 feedback updates

- Portrait Android layout (720 × 1280 design resolution).
- New speed curve with a pronounced escape advantage at 400 versus 600 mass.
- Touch release clears drag/mouse input and immediately stops your cell.
- Slight pellet pickup margin; configurable via `PICKUP_RADIUS` in `scripts/game.gd`.
- Deeper, rounded bite-shaped notches and extra impact particles.
- Start menu lets you type a username (saved locally) which appears above your amoeba and in the live, mass-ranked leaderboard with AI.

This leaderboard is **local to your current offline arena**. It is not an online global ranking.


## Prototype 0.3 — Cell Crown

- Body tissue is represented by editable polygon shapes. Larger cells geometrically subtract covered areas of smaller opponents; surviving fragments remain instead of respawning as circles or losing abstract hit points.
- Cells visually and physically conform to walls and corners. Moving into a corner flattens the membrane inside arena boundaries.
- Cruising movement retains the last touch direction and throttle on release. Drag again to steer.
- **Cell Crown**: Reach first place at a mass of at least 220, then stay first for 24 consecutive seconds to win.
- Permanent local player progression with XP, levels and coins, used for future abilities and skins.

### Reward rules

| Action | XP | Coins |
| --- | ---: | ---: |
| Survive one second | 1 | 0 |
| Every 12 seconds alive | 2 | 3 |
| Eat one nutrient | 1 | 0 |
| Every 12 nutrients | 4 | 2 |
| Consume 5 mass of a rival | 3 | 0 |
| Eliminate a rival | 32 | 16 |
| Win Cell Crown | 150 | 100 |
| Level up | — | 10 + 4 × new level |

Profile stored in user://amoeba_progress.cfg. Current coins/XP don't purchase anything yet. Win condition is for the local AI arena, not multiplayer.

**APK debug-signing caveat:** CI generates a temporary key each build. Upgrading from v0.2 requires uninstalling the old APK, which clears its saved local data. Later APKs will also need stable signing for reliable in-place upgrades.
