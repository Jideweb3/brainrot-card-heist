[![make.fun · roblox-brainrot-01](https://make.fun/badge/roblox-brainrot-01.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![rank](https://make.fun/badge/roblox-brainrot-01/Jideweb3/brainrot-card-heist/rank.svg)](https://make.fun/bounty/roblox-brainrot-01/leaderboard?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)
[![reward](https://make.fun/badge/roblox-brainrot-01/Jideweb3/brainrot-card-heist/reward.svg)](https://make.fun/bounty/roblox-brainrot-01?utm_source=github&utm_medium=readme&utm_campaign=roblox-brainrot-01)

# Brainrot Card Heist

An original 3D Roblox brainrot card game. Entry for the make.fun [roblox-brainrot-01](https://make.fun/bounty/roblox-brainrot-01) bounty — "Make the best AI Roblox brainrot game".

Play it: https://www.roblox.com/games/82918775751710

## The loop

Pull cards from the giant card machine in the plaza, carry them back to your base, and slot them on stands to earn cash every second — or buy cards straight off the conveyor belt that rolls past the machine, each one wearing its price. Cards come in rarities from Common to Secret, with Gold, Diamond and Rainbow mutations, and every card floats a big name-and-earnings tag so the whole plaza can see what you are carrying. A luck shop sells timed boosts that fatten the odds of Epic-and-better pulls, and a full collection page tracks all 18 cards and their mutations. Other players can steal your placed cards — lock your base, knock a thief's card loose with your bat, and watch out for the raccoon thief event, announced on a server-wide banner. Rebirth to reset for a permanent income multiplier and extra stands. An original music loop, composed for the game, plays throughout.

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
| `src/shared/CardData.luau` | The 18 cards: rarities, earn-per-second, pull weights, mutations, belt pricing and the luck shop catalog |
| `src/server/init.server.luau` | Server bootstrap: loads GameServer and starts it |
| `src/server/GameServer.luau` | The core loop: machine pulls, card reveal, carrying, placing, stealing, the bat, floating card tags, the luck shop, background music |
| `src/server/WorldBuilder.luau` | Builds the world: plaza, card machine, the conveyor belt, 8 player bases, brainrot statues, classic studded floors |
| `src/server/ConveyorService.luau` | The card belt: spawns priced cards that ride past the machine for anyone to buy |
| `src/server/DataService.luau` | Cash/cards leaderstats and DataStore saving |
| `src/server/RebirthService.luau` | Rebirths: doubling cost, permanent income multiplier, extra stands |
| `src/server/BaseLockService.luau` | Base locking: 60-second shield dome, 90-second cooldown |
| `src/server/ThiefEvent.luau` | The raccoon thief event that raids unlocked bases |
| `src/client/Game.client.luau` | The player side: HUD, reveal banners, event banner, notices |
| `src/client/CardDex.client.luau` | The collection page: every card's picture, rarity and earnings, plus the mutation ladder |
| `src/client/Shop.client.luau` | The luck shop: product rows, buying, and the live luck countdown on the shop button |

Built with Rojo: the scripts live under src/, and game.rbxl is the built place file. Run `node main.ts` to package the entry dossier.
