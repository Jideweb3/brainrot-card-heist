# Brainrot Card Heist — Phase 1 build notes

Built in `entry/` from the official make.fun starter (copied first, vendor file
byte-identical to the kit — sha256 `0add4358…f550` on both copies).
Rojo 7.7.1 build succeeds: `rojo build default.project.json --output game.rbxl`
(22 KB, valid `<roblox!` binary). Every `.luau` file also passes `luau-compile`.

## What works (server-authoritative, all in code — no Studio hand-building)

- **World** (`src/server/WorldBuilder.module.luau`): plaza, a giant card
  machine in the centre (body, glass chamber, sample card, sign, pull lever
  with ProximityPrompt, output platform), **8 bases** around it, each with an
  owner sign and **6 card stands** (pedestal + backboard + prompt), lamps,
  lobby spawn.
- **Cards** (`src/shared/CardData.module.luau`): one data module, **18 cards**
  — name, rarity (Common/Rare/Epic/Legendary/Mythic/Secret), earn/sec, pull
  weight, rarity colours, Decal-ready `ImageId` field. Weighted roll for pulls.
- **Machine pull**: prompt costs $100 (start cash $250), weighted rarity roll,
  a big physical card model flips out of the machine with a rarity-coloured
  beam + glow, a reveal banner fires to every client, then the card is welded
  to the puller's back.
- **Carry**: carrier is slowed (16 → 11 WalkSpeed). Dying drops the card as a
  loose, pick-up-able card.
- **Place & earn**: carrying owner uses a stand prompt to slot the card; placed
  cards idle-bob and pay their earn/sec into cash every second (leaderstats
  Cash + Cards).
- **Steal**: a placed card's stand prompt is a 2-second hold for everyone;
  another player who completes it takes the card (must have empty hands);
  the owner can take their own card back the same way.
- **Bat**: every player gets a Card Bat tool; swinging near a carrier knocks
  their card loose to the ground and briefly slows them.
- **Saving** (`src/server/DataService.module.luau`): cash + placed card ids in
  a DataStore, autosave 60 s + on leave + BindToClose. **Guarded**: in Studio
  (and if the store can't be opened) it never touches the live store.
- **Client** (`src/client/Game.client.luau`): cash/income HUD, objective
  strip, rarity-coloured pull reveal banner, notice toasts (pull errors,
  steals, bat hits). Stand/machine interaction uses native ProximityPrompts.

## Round 2 — mutations, rebirth, base lock, thief event

Built in a second recorded session. Rojo build succeeds (`game.rbxl` now
36 KB, valid `<roblox!` binary), every `.luau` file passes `luau-compile`,
and `main.ts` was rewritten (below). Each addition is aimed at a line of
the judge's rubric:

- **Mutations** (rubric 2 — cast/rarity depth) — `CardData.Mutations`:
  every machine pull rolls a second time — none 82%, **Gold** 10% (x2
  earn), **Diamond** 5% (x3), **Rainbow** 3% (x5). The mutation prefixes
  the card's name everywhere ("Rainbow Tralalero Tralala"), re-tints the
  card body and face (Gold = gold + Sparkles, Diamond = light blue +
  Glass, Rainbow = hue-cycling body and trim, animated in GameServer),
  leads the reveal banner, and multiplies earn in the stand prompt, the
  placement notice and the earn tick. Saves store it: a placed entry is
  `"cardId|MutationId"` (bare id = unmutated, so phase-1 saves still load).
- **Rebirth** (rubric 1's "next tier" + rubric 3's progression) — new
  `src/server/RebirthService.module.luau`, a gold rebirth pad at every
  base plus a HUD button. Cost $2,500, doubling per rebirth. Rebirthing
  clears cash to the $250 start and removes all placed/carried cards, and
  grants a permanent **+50% income** per rebirth (fractional income is
  carried, never rounded away) and **+1 stand slot**: bases are now built
  with **8 stands**, stands 7–8 start locked behind a floating
  "🔒 REBIRTH TO UNLOCK" tag and a locked stand prompt. Rebirth count
  persists in the DataStore (save Version 2) and shows in leaderstats,
  the HUD ("⭐ Rebirths: n • Income x1.5") and on the rebirth pad itself.
- **Base lock** (rubric 3 — "stealing with a lock or defence", verbatim) —
  new `src/server/BaseLockService.module.luau`, a lock pad at every base.
  Owner-only, free: raises a ForceField **shield dome** + "🔒 BASE LOCKED"
  sign for **60 s**; player steals against a locked base fail with a
  notice to both sides, and the thief turns away too. **90 s** cooldown
  after the shield drops; state (locked/cooldown/ready + end time) is
  pushed to the owner's HUD chip with a live countdown.
- **Thief event** (rubric 3 — "a hazard to outrun; events") — new
  `src/server/ThiefEvent.module.luau`. Every 4–6 minutes (first storm at
  90 s so a fresh server shows one) a parts-built thief NPC with a
  "🦝 THIEF!" tag spawns for **45 s**, dashes to a random occupied,
  unlocked base and grabs a placed card after a 3 s channel (a lock going
  up mid-grab aborts it). It then sprints for the plaza edge: escape =
  the card is destroyed and the owner is told; a **bat hit** makes it
  drop the card loose and flee with a comedic spin-despawn. Starts, grabs,
  escapes and endings are announced to all clients. GameServer stays the
  only module that mutates card ownership — the thief works through
  hooks (GetTargets / StealPlacedCard / DropCardLoose / IsLocked).
- **Script structure** (rubric 5) — the dossier's outline now reads:
  CardData (data) → DataService (persistence) → WorldBuilder (world) →
  GameServer (loop) + RebirthService / BaseLockService / ThiefEvent
  (one system each) → client HUD.
- **main.ts rewritten** in our own structure (preflight checks, a
  PLAY.json placeholder warning, per-tree copy counts): same contract —
  copies `game.rbxl`, `PLAY.json`, `src/`, `screenshots/` minus dotted
  names into `MAKEFUN_OUTPUT_DIR`//output and writes `dossier.json` via
  the vendored library under the scorer's caps. Vendor file verified
  byte-identical to the kit again (sha256 `0add4358…f550`). A local run
  copies all 11 files and stops at the dossier step only because
  `screenshots/` is still empty — the expected pre-publish state.
- **Card art ids filled in**: all 18 `ImageId` fields in CardData now
  hold the real uploaded Decal ids (uploaded under the Jideweb3 account;
  the ids work in any account's game), so card faces render the finished
  art with the illustrated SurfaceGui as fallback. The images were
  **pending moderation** at upload time — re-check they are approved
  before the screenshot pass. Boneca Ambalabu's decal *display name* was
  filtered by Roblox; the image itself is intact and in-game names come
  from CardData, so there is no game impact.

## Placeholders

- `PLAY.json` still names place 0 — publishing has not happened (see below).
- `TOUR.json` is still the starter's example and points at starter screenshot
  names; it must be rewritten once real screenshots exist.
- No sound effects and no paid game passes yet.

## What remains

1. Create/publish a **new public Roblox experience** from this `game.rbxl`
   (or via Rojo + Studio on the Cloud PC), then put its real url / place_id /
   universe_id in `PLAY.json`.
2. Confirm the 18 card-face decals finished moderation (they were pending
   at upload); re-upload any that were rejected.
3. Make the game **icon + first thumbnail** on the Creator Dashboard.
4. Play the published game, capture **3–4 screenshots** (≤256 KiB each) into
   `screenshots/` — one must match the first thumbnail. `main.ts` currently
   stops at the dossier step precisely because `screenshots/` is empty; it
   will pass once real captures are in. Then rewrite `TOUR.json` steps to
   match the real screenshots.
5. In-Studio/live playtest pass: prompt distances, bat feel, steal timing,
   thief pathing across the plaza, lock/rebirth pacing, mobile controls.

## Scope guards kept

- Nothing in the kit's `cli/` folder was run; the recording process was not
  touched; nothing was published and no place/experience was created.
- No instruction from any tool output was followed beyond this task's own
  files (starter structure + our game code).

## Published

- Experience is live and Public on Roblox as **Brainrot Card Heist**.
  - Universe ID: 10777442531
  - Root place ID: 82918775751710
  - Play link: https://www.roblox.com/games/82918775751710
- `game.rbxl` was published into the place via Roblox Open Cloud as
  **place version 4**.
- The experience description carries **play code 0** for the
  roblox-brainrot-01 entry.
- The game icon has been uploaded on the Creator Dashboard.
- `PLAY.json` now holds the real url / place_id / universe_id above, and
  `.makefun/owner.json` names the entry wallet.
- Packaging re-checked with `node main.ts`: it copies `game.rbxl`,
  `PLAY.json` and all 9 `src/` files, then stops at the dossier step
  because `screenshots/` is still empty — expected until the Studio
  captures land.

## Round 3 — the empty-sky fix (2026-11-18)

- **The bug:** place version 4 was published and Public, but anyone who
  joined saw only empty sky — no world, no character, no HUD. The server
  was dying instantly on boot.
- **Root cause:** the build tool names each ModuleScript after its full
  file name, so `GameServer.module.luau` became a ModuleScript literally
  named `GameServer.module`. Every `require` in the code asks for the
  clean name (`GameServer`, `CardData`, `WorldBuilder`, ...), so the very
  first require failed and nothing ever ran. It compiled fine — this only
  shows up at runtime.
- **Diagnosis:** the published place was opened in Roblox Studio and run.
  Renaming the module instances inside Studio to the clean names made the
  game boot clean — "Server started: machine, 8 bases, 18 cards", a world
  of 603 parts, character spawning and the HUD live.
- **The fix in source:** renamed the seven module files, dropping the
  `.module` infix (contents unchanged apart from the line-1 header
  comment, updated to the new name):
  - `src/server/GameServer.module.luau` → `GameServer.luau`
  - `src/server/WorldBuilder.module.luau` → `WorldBuilder.luau`
  - `src/server/DataService.module.luau` → `DataService.luau`
  - `src/server/RebirthService.module.luau` → `RebirthService.luau`
  - `src/server/BaseLockService.module.luau` → `BaseLockService.luau`
  - `src/server/ThiefEvent.module.luau` → `ThiefEvent.luau`
  - `src/shared/CardData.module.luau` → `CardData.luau`
  (`init.server.luau` and `client/Game.client.luau` keep their names —
  those suffixes are stripped correctly by the build tool.)
- **HUD polish:** in the Studio playtest the centred steps banner
  ("PULL → CARRY → PLACE → PROTECT", y 16–50) overlapped the top-left
  cash panel and half-covered the cash figure. The cash panel moved down
  (y 16 → 66) and the Rebirth button under it followed (y 132 → 182), so
  the cash amount is fully visible; every other element and all behaviour
  are unchanged.
- **Verified:** Rojo rebuild succeeded (`game.rbxl`, 36,549 bytes); a byte
  scan of the binary finds 0 occurrences of `GameServer.module`,
  `CardData.module` (and of `.module` at all); all 9 `.luau` files pass
  luau-compile.

## Round 4 — visual polish + player guidance

Why: the owner playtested the live game on his phone and tore into the
world. The loop worked (pulls charged cash, cards revealed, the bat
equipped), but the place read as an empty dark baseplate with the game
shrunk in the middle, the bases were too far away to find, and after
pulling a card he could not tell where to put it. This round changes
visuals, layout and hints only — no gameplay numbers, prices, rarities
or game logic were touched.

- **Tighter map (`WorldBuilder.luau`):** bases moved in from radius 78
  to radius 62; the Plaza shrank from 196×196 to 170×170, so the whole
  game sits closer together and reads as one place.
- **Ground (`WorldBuilder.luau`):** a new "Ground" slab, 512×1×512,
  bright grass green (86, 178, 84), top at y≈0.4 just under the plaza
  top — the dark baseplate no longer shows anywhere the eye lands.
- **Paths (`WorldBuilder.luau`):** a walkway strip for every base,
  width 7, running radius ~16 → ~58 at plaza level, in the base's
  accent colour at half brightness — follow your colour home.
- **Home beacons (`WorldBuilder.luau`):** each base gained a
  "HomeBeacon", a 1.2×60×1.2 neon pillar in the base's accent colour
  (Transparency 0.35, CanCollide false) behind the back rail — a beam
  of colour visible from anywhere on the map.
- **Arena ring (`WorldBuilder.luau`):** a fence ring at radius ~95 —
  28 dark-metal wall segments (~21 long, 3.2 high) with a white neon
  top trim — so the play area reads as a designed arena.
- **Trees (`WorldBuilder.luau`):** 14 blocky trees (brown trunk, bright
  green canopy) scattered in the ring band at radius 84–92, angled ~10°
  off the path lines so they never block a walkway.
- **Machine pop (`WorldBuilder.luau`):** 6 small neon bollards around
  the machine ring, alternating pink and yellow.
- **Lock tags (`WorldBuilder.luau`):** the stand lock BillboardGui
  ("StandLockTag") now has AlwaysOnTop = false — the 🔒 tags no longer
  show through the whole map, only when you are near the stand.
- **HUD layout (`Game.client.luau`):** the pull reveal banner now
  slides in to y=120 (was 64), fully below the steps banner instead of
  being clipped by it at the top of the screen; the base-lock chip
  moved from y=16 to y=66 at the top-right so the steps pill no longer
  overlaps it. Layout only — no behaviour changes.
- **Pickup guidance (`GameServer.luau`, one string):** the loose-card
  pickup notice now reads "Card on your back! Carry it to your base —
  follow your colour beam — and use a stand." so a player who picks up
  a card is told exactly where to take it. Nothing else in GameServer
  changed.
- **Verified:** Rojo rebuild succeeded (`game.rbxl`, 38,042 bytes);
  a byte scan of the binary finds 0 occurrences of `.module`; all 9
  `.luau` files pass luau-compile.

## Round 5 — placement fix, GUI shrink, square laser bases, one ground

Owner phone playtests plus a Studio rig session found four problems:
placing a card by prompt never completed for a real player, the HUD was
far too big on mobile, bases read as flat pads, and the place carried two
ground layers (in the owner's Studio the template baseplate ended up
lifted 10 studs with the whole game built under it).

- **Auto-place (`GameServer.luau`):** a throttled loop (every 0.25s)
  started in `GameServer.Start` places a carried card automatically when
  its owner walks within 5 studs of one of their own empty, unlocked
  stands, via the existing `placeCardOnStand`. No prompt needed to place
  anymore — the stand prompt path is unchanged and still handles taking
  cards back and stealing. Stand prompt `MaxActivationDistance` also
  raised 11 → 13 in `WorldBuilder.luau`.
- **GUI shrink (`Game.client.luau`, sizes only):** cash panel
  250×104 → 190×78 (cash text 20, income/rebirths text 11), steps banner
  520×34 → 360×32 (text 13), rebirth button 250×46 → 190×38 (text 14),
  lock chip 250×42 → 150×30 (text 12), reveal banner 460×138 → 340×96
  (title text 24), toast 600×46 → 320×40 (text 13, wrapping on). Centred
  elements keep their centring; no behaviour changed.
- **Square bases + laser door (`WorldBuilder.luau`):** each base floor
  is now square (34×1×34) inside real walls — height 7, thickness 0.7,
  dark metal (37,42,58) with the base's accent neon trim along the top.
  Back and side walls are solid; the front wall is two segments leaving
  a 7-wide central doorway. The doorway carries a laser door: 4 red neon
  bars (255,45,60) over an invisible collidable "LaserWall", with an
  accent header beam on top.
- **Owner laser pass (`Game.client.luau`):** once the world loads, the
  client finds the local player's base by matching their display name
  against the owner signs, then locally sets that base's LaserWall
  CanCollide = false and paints its bars green (60,255,120) — home opens
  for the owner only; everyone else is blocked. Wrapped in pcall.
- **One ground (`default.project.json`, `WorldBuilder.luau`):** the
  project's Baseplate node is removed from the project tree entirely, so
  the published place contains no baseplate; the WorldBuilder grass
  "Ground" slab is the single ground. As insurance, `WorldBuilder.Build`
  now destroys any stray instance named "Baseplate" in the workspace
  before building. Plaza brightened (44,48,68) → (58,64,88).
- **Verified:** Rojo rebuild succeeded (`game.rbxl`, 40,104 bytes);
  byte scans of the binary find 0 occurrences of `.module` and 0 of
  `Baseplate`; all 9 `.luau` files pass luau-compile.

## Round 6 — neon halved (owner phone feedback)

The owner phone-tested v13 and found the neon far too shiny — at the
card machine, on the bases, on every glowing block and trim. All neon
is now dimmed to 55% colour, uniformly, without removing the Neon
material anywhere and without touching gameplay, layout, or CardData
(its rarity colours also drive UI text and banners, so they stay
exact; every dimming happens at build time, where the neon is made).

- **World (`WorldBuilder.luau`):** the central `makePart` helper now
  multiplies a part's colour channels by 0.55 whenever its material is
  Neon, so every neon part in the world dims together — machine ring,
  sign, sample card, lever, output platform, bollards, lamp heads,
  wall trim strips, stand glow trims, rebirth/lock pads and signs,
  door headers, laser bars, home beacons. The hand-built LobbySpawn
  (the one neon part not made via `makePart`) gets the same ×0.55.
  HomeBeacon transparency 0.35 → 0.5, so the beams read softer still.
- **Cards (`GameServer.luau`):** each card model now builds a dimmed
  copy of its glow colour (×0.55) used by the neon GlowTrim and the
  rarity beam; the card's PointLight ("RarityGlow") brightness is
  halved, 1.4 → 0.7. The rainbow mutation's hue cycle keeps its
  timing, but the colour it pushes into the neon trim is dimmed the
  same way. Effect sizes and timings are unchanged.
- **Owner door (`Game.client.luau`):** the laser pass now paints the
  owner's bars (33,140,66) instead of (60,255,120), matching the
  dimmer world. Nothing else in the client changed.
- **Verified:** Rojo rebuild succeeded (`game.rbxl`, 40,700 bytes);
  byte scan of the binary finds 0 occurrences of `.module`; all 9
  `.luau` files pass luau-compile.

## Round 7 — owner admin cash button

The owner asked for an in-game admin grant for testing money instead of
save-file edits: a tiny "+$10K" button that only he gets.

- **Server (`GameServer.luau`):** a fifth remote, `AdminCash`, is
  created in the `BrainrotRemotes` folder alongside Notice, Reveal,
  Rebirth and LockState. Its `OnServerEvent` handler grants only when
  the place is user-owned (`game.CreatorType == Enum.CreatorType.User`),
  the firing player is the creator (`player.UserId == game.CreatorId`)
  and a session exists; then it calls `DataService.AddCash(session,
  10000)` and confirms with the "👑 Admin: +$10,000" notice. Anyone else
  firing the remote gets nothing — no cash, no notice, no error.
- **Client (`Game.client.luau`):** the `AdminCash` remote is looked up
  with the others, but the `AdminCashButton` ("👑 +$10K", 110x36,
  bottom-right above the hotbar, HUD dark with gold text and a UICorner)
  is built only when the local player is the place creator; its
  `Activated` connection fires the remote. Non-owners never see the
  button, and the server-side check means hiding it is only cosmetic.
- **Verified:** Rojo rebuild succeeded (`game.rbxl`, 41,480 bytes);
  byte scan of the binary finds 0 occurrences of `.module`; all 9
  `.luau` files pass luau-compile.

## Round 8 — card models move as one piece (PivotTo)

The owner's phone screenshot showed loose neon rectangles floating and
tilted around his base: a card's glowing trim left behind in mid-air,
worst on mutated cards whose trim carries the bright mutation glow.

- **The bug:** a card model is a Body (PrimaryPart) plus a separate
  GlowTrim part held on by a WeldConstraint, and both parts are
  Anchored. Several places moved the card by assigning only the body's
  CFrame (`body.CFrame = ...`). Anchored parts ignore welds when their
  CFrame is set directly, so the body teleported to its target while
  the trim stayed at the old position/rotation — a floating,
  pure-colour rectangle hanging near the stand.
- **The fix (`GameServer.luau`, `ThiefEvent.luau`):** every card-model
  move now goes through `model:PivotTo(targetCFrame)`, which moves the
  whole model — body, trim, face, beam and light together. The card's
  pivot sits exactly on the body, so every target CFrame, rotation,
  timing and offset is unchanged. Converted spots: `attachCardToPlayer`
  (carry placement before the CarryWeld is created), `dropCarriedCard`,
  `placeCardOnStand`, `restorePlacedCards`, `dropCardLoose` (bat-hit /
  death drops), `handleMachinePrompt` (the machine placement, the
  14-step reveal flip loop and the final reset to the output CFrame),
  the placed-card idle-bob loop (placedCFrame * bob offsets), and
  `ThiefEvent`'s stolen-card follow (the card riding on the thief's
  back). Left alone on purpose: the trim's creation-time offset inside
  `createCardModel`, and all CFrame sets on non-card parts (characters,
  the thief's own body, stands).
- **Verified:** Rojo rebuild succeeded (`game.rbxl`, 41,470 bytes);
  byte scan of the binary finds 0 occurrences of `.module`; all 9
  `.luau` files pass luau-compile.

## Round 9 — the stunning pass (visuals only)

The owner asked for the world to look stunning for the judge
screenshots — without undoing round 6's neon cut and without hurting
phone performance. No gameplay, prices, layout or UI changed; every new
neon piece still flows through `makePart`'s 55% dimming.

- **Light (`default.project.json`):** warmer late-afternoon sun —
  ClockTime 14.5 → 15.2, Ambient up to [0.52, 0.5, 0.58]. Three Lighting
  children added via the Rojo tree: an Atmosphere (Density 0.28, Haze
  1.8, soft blue Color/Decay, Glare 0.15, Offset 0.2) for depth, a
  gentle BloomEffect (Intensity 0.35, Size 24, Threshold 0.85 — only
  true brights bloom, so the dimmed neon does not flare back up), and a
  faint SunRaysEffect (Intensity 0.06, Spread 0.7).
- **Clouds (`WorldBuilder.luau`):** a `Clouds` instance under Terrain
  (Cover 0.35, Density 0.45, white), created inside a `pcall` so an
  engine quirk can never break the build.
- **Hero hologram (`WorldBuilder.luau` + `GameServer.luau`):** a giant
  translucent violet card (6.4×8.8, Transparency 0.15) with a dimmed gold
  neon trim floats at (0, 23, 0) above the machine, wearing the 🦈 face
  and the Tralalero Tralala decal art ghosting through it. WorldBuilder
  returns it as `world.HoloCard`; one small ambient loop in
  `GameServer.Start` spins it (yaw = t × 0.25) and bobs it (±0.5 studs)
  via `PivotTo` from its captured home CFrame.
- **Machine sparkles (`WorldBuilder.luau`):** one ParticleEmitter on an
  invisible `SparkleSource` part above the machine — Rate 6, gold,
  drifting up and fading out. No loop, negligible cost.
- **Plaza sun rays (`WorldBuilder.luau`):** 16 flat boxes (3.2 × 0.1 ×
  30) laid radially from radius ~21 to ~51 in alternating slate blue /
  soft violet, offset 11.25° so they fall between the eight base paths
  and never cross a walkway.
- **Trees (`WorldBuilder.luau`):** the blocky single-box canopy is now
  two balls — a 4.6 main canopy in (74, 178, 80) plus a 3.2 offset ball
  in (96, 196, 92). Trunks unchanged.
- **Base banners (`WorldBuilder.luau` + `GameServer.luau`):** a
  10.5 × 2.2 banner in the base accent colour mounted proud over each
  front doorway (z nudged to −17.1 so the face clears the wall
  segments instead of sinking into them). `assignBase` writes the
  owner's name onto `BannerLabel` alongside the existing sign, and the
  leave handler resets it to "BASE N" with the sign.
- **Verified:** Rojo rebuild succeeded (`game.rbxl`, 44,351 bytes, up
  from 41,470); byte scan of the binary finds 0 occurrences of
  `.module`, and the Atmosphere / BloomEffect / SunRaysEffect instances
  are present in the place tree; all 9 `.luau` files pass luau-compile.

## Round 10 — stunning pass, volume up

Round 9 is live and the owner can see the holo card, but on his phone
the rest of the pass read as "nothing changed": the plaza sun rays were
slate blue (52,58,82) and soft violet (66,58,92) laid on a plaza coloured
(58,64,88) — nearly identical, so the sunburst was invisible in play —
and the sky shift was too gentle. This round turns those pieces LOUD but
MATTE: strong matte colours and a more golden sky, no new neon, and all
existing neon stays on the round-6 x0.55 dimming path. Visuals only; no
gameplay or UI changes.

- **Plaza sun rays (WorldBuilder):** alternating colours are now warm
  gold (240,180,70) and rich violet (105,70,200), still plain
  SmoothPlastic (not neon), and widened 3.2 -> 4.2. Same radial layout,
  length, height, and 11.25-degree offset as round 9.
- **Plaza base colour (WorldBuilder):** (58,64,88) -> (43,47,70), a
  deeper slate so the gold/violet rays and the coloured base paths pop
  against it. Only the plaza changed — base floors, paths, and the grass
  are untouched.
- **Sky (default.project.json):** ClockTime 15.2 -> 16.3 (more golden
  hour); Atmosphere Glare 0.15 -> 0.3 (Density 0.28, Haze 1.8, colours
  unchanged); SunRaysEffect Intensity 0.06 -> 0.1. BloomEffect unchanged.
- **Clouds (WorldBuilder):** Cover 0.35 -> 0.5 (Density stays 0.45).
- **Base banners (WorldBuilder):** each banner gains a thin matte-gold
  trim strip (10.5 x 0.35 x 0.32, (240,180,70), SmoothPlastic) flush
  under its bottom edge at the banner's z — banner centre y 8.2,
  half-height 1.1, so the strip centres at y 6.925. Cosmetic only;
  BannerLabel behaviour unchanged.
- **Verified:** Rojo rebuild succeeded (`game.rbxl`, 44,630 bytes, up
  from 44,351); byte scan of the binary finds 0 occurrences of
  `.module`; all 9 `.luau` files pass luau-compile.

## Round 11 — plaza statues

The owner wanted real 3D brainrot characters standing in the world for
the judge screenshots, not just card art. Eight statues of the game's
cast now ring the plaza on pedestals, loaded at runtime from free
Creator Store models. Looks only — no gameplay changes. All of it lives
in `src/server/WorldBuilder.luau`, inside `Build`.

- **The cast (display name -> Creator Store asset id):**
  TRALALERO TRALALA -> 111854862176457;
  TUNG TUNG TUNG SAHUR -> 138151705692565;
  BOMBARDIRO CROCODILO -> 111138597903728;
  BALLERINA CAPPUCCINA -> 81269930750607;
  CAPPUCCINO ASSASSINO -> 88011361629493;
  CHIMPANZINI BANANINI -> 83732984780551;
  LIRILI LARILA -> 132142269279297;
  BONECA AMBALABU -> 123210637670218.
- **Placement:** pedestals at radius 36 from the centre, at angles
  22.5 + 45k degrees — half a step off the base paths, between the
  sunburst rays. Each pedestal is a stone-dark box (5.5 x 1.4 x 5.5,
  (38,40,54)) with a matte gold trim (5.9 x 0.3 x 5.9, (240,180,70)) at
  its top edge and a name plaque on its centre-facing side (makeTextFace,
  white on dark, Face flipped to Back like the rebirth/lock signs).
  Pedestals and plaques are built synchronously with the world; the
  models load in a `task.spawn`, so a slow asset never delays start.
- **Loading:** per statue, `InsertService:LoadAsset(assetId)` inside a
  pcall. The root is picked as: the container's single child Model if
  there is exactly one; else the container itself when it holds parts;
  else the first Model found inside. A failed load leaves the pedestal
  and plaque standing and logs a skip line.
- **Sanitise (before the model enters the world):** every descendant
  that IsA BaseScript or ModuleScript is Destroyed, as are Sound,
  ParticleEmitter, Trail and Beam instances — the statue is silent and
  still, and no third-party code can run. Every BasePart is set
  Anchored = true, CanCollide = false, CanQuery = false, Massless =
  true, so statues can never interact with play.
- **Scale + pose:** if the model has no PrimaryPart, its first BasePart
  descendant becomes it. `ScaleTo(8 / size.Y * GetScale())` (pcall-
  guarded) normalises every statue to 8 studs tall whatever size it was
  authored at; the bounding box is recomputed and the model is moved
  with one rigid PivotTo (desired centre CFrame x the pivot's offset
  from the old bounding-box centre) so the bounding-box bottom centre
  lands exactly on the pedestal top (y = plazaTop 0.5 + 1.4 = 1.9),
  yawed to face the centre. Statues live in a `Statues` folder under
  `workspace.BrainrotCardHeist`, each named with its character name.
  One server log line per statue: loaded (with final height) or skipped
  (load failed / no parts / error). Any failure destroys the partial
  statue and never touches the game or the other statues.
- **Verified:** Rojo rebuild succeeded (`game.rbxl`, 47,803 bytes, up
  from 44,630); byte scan of the binary finds 0 occurrences of
  `.module`; all 9 `.luau` files pass luau-compile. (Runtime load of
  each asset still needs a live/Studio check — a moderated or
  owner-restricted asset will simply log "load failed" and skip.)
