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

**APK debug signing:** The v0.3 workflow caches a debug signing key across CI builds to preserve app upgrade compatibility while GitHub retains that cache. The first v0.3 install may still require uninstalling v0.2 (which deletes old app data). Cached keys can expire or be evicted, and this is not production-grade key management. A durable private release signing key is still necessary for long-term installs.


## Prototype 0.4: Surface tension and soft walls

- After a geometric bite, the actual wound stays visible briefly; escaping cells relax back into a smooth, smaller circular amoeba, without regaining any eaten mass.
- Cells continuously pulse and jiggle while swimming, including after recovery.
- Replaced hard vertex clipping at arena boundaries with a smooth, area-preserving deformation: approaching a wall flattens the side facing it and gently expands the opposite side. Corner pressure creates a slightly squarer silhouette, improving corner coverage.
- Rendering and bite collision use exactly the same membrane coordinates; no separate clamping or stacked translucent fills at the wall.
- Preserved the v0.3 portrait layout, cruise steering, Cell Crown win condition and locally saved XP/coins.


## Prototype 0.5 — Corners, skins, upgrades and settings

- **No corner hideouts:** A rounded cell pushing diagonally into a corner now fills the actual corner, using a single solid convex membrane. It remains edible; consumed fragments still preserve bite holes. The existing area-preserving wall squish stays in place.
- **Player outline:** Dark outer membrane and thin bright rim, visible for all cells even against walls.
- **Skin Lab:** Accessible on the home screen AND game-over/victory screens. Purchases use earned coins and are saved locally; owned skins can be re-equipped without paying again.
  - Mint Jelly (free), Bubblegum (75), Arctic Glow (140), Solar Flare (215), Rainbow Flux (365), Galactic (490), Golden Crown (650).
  - Rainbow cycles its colors; Galaxy has starlight speckles; the other skins add distinct cellular pigment effects. Cosmetics do not grant gameplay advantages.
- **Level perks** are automatic and do not cost coins: +2 px nutrient pickup radius per level (maximum +32 px); +2% nutrient mass per level (maximum +24%); and +5 starting mass every three levels (maximum +35).
- **Settings:** sound effects ON/OFF, vibration ON/OFF, and light/dark arena theme. All settings are saved locally. Simple sound effects are generated at runtime for collection, attacks, levels, purchases and end-of-round events.
- The existing local coins, level, username, XP and wins remain compatible with v0.4 saves if the Android debug signature is unchanged.

### Build and installation

Download the APK from the latest successful GitHub Actions build. The Android export enables the VIBRATE permission to support optional haptics. The cached debug signing key is not a durable production release key; if Android rejects an update due to a signature mismatch, reinstalling will erase locally saved progression.


## Prototype 0.7 — Classic refinement (based on v0.5)

After feedback on the v0.6 aesthetic, this version intentionally returns to
the **v0.5 menus, HUD layout, typography, gameplay and skin identifiers**.
The v0.6 experimental full-screen laboratory interface, backbuffer blur,
large fonts and elaborate skin trails are removed from the current build.
Their Git commit history remains available for comparison.

Small changes made on top of the restored v0.5 source:
- Original HUD layout, softened with lightly translucent rounded panels and
  restrained hairline borders. No full-screen blur, giant title redesign or
  custom font swap.
- Original familiar, single-layer colored cells and thin membrane outline.
- Reduced skin ornaments to a few subtle living details **inside** the cell,
  rather than long trails, halos, particles or a separate polygon mesh.
- Replaced the corner convex-hull operation with a local, smoothed contour
  adjustment that preserves the 64-point ring; no square reconstruction.
- Preserved geometric bite subtraction, the short-term bite notch and
  subsequent natural rounding.
- Unchanged original skin IDs/prices, purchased skins, account progression,
  sound, vibration and appearance settings.

New regression tests check the corner vertex count and partial-eating
geometry. This is a conservative revision meant for direct phone feedback.
