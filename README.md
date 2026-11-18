[![make.fun · roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/Jideweb3/brainrot-card-heist/rank.svg)](https://make.fun/bounty/roblox-brainrot-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/Jideweb3/brainrot-card-heist/reward.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)

# Brainrot Card Heist

An original 3D Roblox brainrot card game. Entry for the make.fun [roblox-brainrot-01](https://make.fun/bounty/roblox-brainrot-01) bounty — "Make the best AI Roblox brainrot game".

Play it: https://www.roblox.com/games/82918775751710

## The loop

Pull cards from the giant card machine in the plaza, carry them back to your base, and slot them on stands to earn cash every second. Cards come in rarities from Common to Secret, with Gold, Diamond and Rainbow mutations. Other players can steal your placed cards — lock your base, knock a thief's card loose with your bat, and watch out for the raccoon thief event. Rebirth to reset for a permanent income multiplier and extra stands.

## Layout

| Path | Job |
| --- | --- |
| `main.ts` | Entry point: packages the source and screenshots into the entry dossier |
| `vendor/makefun-roblox.ts` | The make.fun Roblox harness (kit file, unchanged) |
| `default.project.json` | Rojo project file: maps `src/` into the Roblox place |
| `game.rbxl` | The built Roblox place (Rojo build output) |
| `PLAY.json` | The play link and the place/universe IDs |
| `TOUR.json` | The screenshot tour: what each picture shows, in order |
| `BUILD_NOTES.md` | Build notes: how the game grew, round by round |
| `LICENSE` | MIT licence |
| `screenshots/` | Captures of the game running in Roblox Studio; `01-world.jpg` is also the game's first thumbnail |
| `src/shared/CardData.luau` | The 18 cards: rarities, earn-per-second, pull weights, mutations |
| `src/server/init.server.luau` | Server bootstrap: loads GameServer and starts it |
| `src/server/GameServer.luau` | The core loop: machine pulls, card reveal, carrying, placing, stealing, the bat |
| `src/server/WorldBuilder.luau` | Builds the world: plaza, card machine, 8 player bases, brainrot statues |
| `src/server/DataService.luau` | Cash/cards leaderstats and DataStore saving |
| `src/server/RebirthService.luau` | Rebirths: doubling cost, permanent income multiplier, extra stands |
| `src/server/BaseLockService.luau` | Base locking: 60-second shield dome, 90-second cooldown |
| `src/server/ThiefEvent.luau` | The raccoon thief event that raids unlocked bases |
| `src/client/Game.client.luau` | The player side: HUD, reveal banners, notices |

Built with Rojo: the scripts live under src/, and game.rbxl is the built place file. Run `node main.ts` to package the entry dossier.
