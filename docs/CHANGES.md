# Changes against the stock server

All changes are in four files under `deploy/files`, which `setup.ps1` copies over the stock install:
- `cloud/data/default_platform_config.lua` (matchmaker, rewards, loot, trading). Read at start.
- `cloud/data/shard.cfg` (Shard). Read at start.
- `data/gamedata/def/ex/junk.lua` (loot items). The battle server reads it directly, no regeneration needed.
- `data/gamedata/trade.lua` (trading tax). **Needs regeneration** into `cloud/data/aux_limits.xml` after copying.

Every change below was tested on a local server before going live. Values are what we run; tune them to your population.

## Detonation bot AI

`deploy/patches/detonation-ai/apply.ps1` applies a server-only binary patch to
`cloud/DedicatedServer.exe`. The stock executable is not stored in this
repository. The patcher accepts only SHA-256
`061175DA4E4DA8D74BBB599F359CD4B4FD3C3B7BBE0FF9B56E6EC0D88D2C2378`,
backs it up, validates every original byte range, and verifies the patched
SHA-256 before reporting success.

The change makes Detonation bots:

- assign the nearest eligible bot to a free or dropped bomb;
- carry the bomb toward a live enemy bomb site without combat stopping movement;
- keep aiming and firing while delivering it;
- support a friendly carrier and prioritize an enemy carrier;
- clear stale bomb ownership after a carrier is lost;
- select another live enemy bomb site if the current target is destroyed.

Local tests covered dropped-bomb recovery, simultaneous carriers and a carrier
retargeting after another bot destroyed its selected site. Four bot plants were
recorded in the final match, which ended normally with
`BOMB_THE_BASE_BOMBED`. No client modification is required.

Revert: stop all battle servers and restore the newest
`DedicatedServer.exe.before-detonation-ai-*.bak` over
`cloud/DedicatedServer.exe`. A Steam update may replace the supported binary;
in that case the patcher stops without changing it and must be updated for the
new executable.

## Loot

### Common loot tables fixed (stock bug)
The per-rank loot config (`DedicatedServcerServices_SetLootRules`, one row per ship rank) points common loot at `CommonRanks_1_3` … `CommonRanks_13_15`. `data\gamedata\shared\loot_tables.lua` only defines them with a `_v3` suffix, so in stock the trophy search after a battle almost never gave common loot. All 15 rows now use `CommonRanks_*_v3`. Check: a battle log shows `got common loot table 'CommonRanks_1_3_v3'`.

### Loot for ranks 16–17
The loot config stopped at rank 15, so rank 16–17 ships got an empty trophy search. We added rows `[16]` and `[17]` as copies of `[15]`.

### One iridium find per battle
- Each battle gives 5 loot attempts. `rare = { iter = {…} }` is a pity counter: after N non-rare attempts the next one is rare. Every rare `iter` value is now `4`, so 4 common attempts and then 1 rare.
- The rare tables (`RareT1`…`RareT5`, `RareT*Mono`) contain `Iridium_Junk_r1`…`r15`. The personal iridium credited (`tokenCredits`, the green gem used for blueprints) is **10% of the junk's `tokenPrice`**.
- In `junk.lua`, `tokenPrice` of all 15 `Iridium_Junk_r*` is ×5: about 16–47 iridium per battle at ranks 1–3 and about 117 at ranks 13–15.
- `SalvageTokenConversion` and `SalvagePremiumTokenConversion` in `special_values.xml` do **not** affect this.
- The stock daily cap still applies: `sv_tokenCreditsDailyLimit = 1000`, plus a 10,000 account cap (`ai.tokens_cap` in `reputation.lua`).
- The same loot rules seem to apply in open-world zones as well (players reported more containers from mob packs).

## Rewards

### GS (Galactic Standards)
- `reward_bonusGoldForWinner = 25` in `ConfigureGRD()` (stock 0): +25 GS for any won battle, in any mode. Winners only.
- **Gold battles 24/7.** A line before `MatchMaker_SetRewardRates( reward_mult )` replaces the stock schedule (Monday 2–5 h +50, Sunday 10–13 h +100) with one 0–24 h slot per day and `goldReward = 50`:
  ```lua
  for d = 0, 6 do reward_mult[ d ] = { { hourBegin = 0, hourEnd = 24, goldReward = 50 } } end
  ```
  The matchmaker passes `gold_reward` to every battle, but only PvP pays it, and only to the winners. A PvP win is therefore +75 GS. The client shows the gold-hours timer as "1–2 days left", because it seems to look only one day ahead. That is cosmetic.
- Revert: `reward_bonusGoldForWinner = 0`, and delete the `for d = 0, 6` line.

### Credits ×2
`cvars.rate_cred = "2,2,…"` (18 values, one per rank; stock all `1`). A battle log shows it as `"rate_cred"`. `cvars.rate_exp` is the same thing for experience; we keep it at 1.

## Matchmaking (low-online queues)
Below `mm_lowOnlineLo = 250` players online, the `queuesConfigLo` block applies. Bots fill the empty slots, `minPlayers = 1`.

### Pools split by ship rank
Stock splits the arcade and coop (vs-AI) queues by `mmValue`, a per-player rating. **On a fresh server `mmValue` is 0 for every player**, so everyone landed in the first queue and T1 met T5. We replaced the 6 + 6 queues with 5 + 5 queues split by ship rank, `mmValue` 0–100:
```lua
InstantiateQueueTemplate( arcadeQueueTemplate, 1, 3, 1, 3, 0, 100, …newbie flags… )
InstantiateQueueTemplate( arcadeQueueTemplate, 4, 6, 4, 6, 0, 100 )
…  7–9, 10–12, 13–17
```
The same goes for `coopQueueTemplate`. Stock coop queues also stopped at rank 15, so rank 16–17 ships could never find a vs-AI battle.

### More bots in PvP
`special = { arcade = 1, botsCount = 8 }` in the low-online arcade template (stock: no `botsCount`), the way the stock `one_against_all` queue does it. `botsCount` is the **total number of participants** (humans + bots), not the number of bots, so 8 means a solo player starts 4v4 with 7 bots. Stock behaviour without it is 1 human + 1 bot. `mm_botsCount` does not affect this. The vs-AI queues ignore `botsCount`.

### One region pool
Every queue had `regionLocalizedTimeInQueue = 10` (training 30): for the first N seconds the matchmaker pairs players only within their region (for example `AR_RU` vs Europe). That matters with several datacenters, but on a single server it just splits the few players you have, and with a 10 s wait, regions never mixed. All 24 occurrences are now `1`, the value the stock sector queues use. A comment there says the default is 120, so we avoid `0`.

### Longer PvP wait
The low-online arcade template has `maxTimeInQueue = 60` (stock 10): the queue waits up to a minute to gather real players before it fills the battle with bots. The vs-AI queues keep 10. There is no join-in-progress (see [KNOWN_ISSUES.md](KNOWN_ISSUES.md)), so this wait is the only way to put players together.

### No game expansion in PvP
`maxExpandTime = 0` in the low-online arcade template (stock 30). With expansion on, the MatchMaker adds queued players to an already created game during its first N seconds, and **it ignores the game's rank range**, so T1 players were added into a T5 game. We saw this in 7 out of 7 mixed-tier battles. Players of one tier still meet: the queue groups them before the game is created, which is why the single region pool and the 60 s wait matter.

### A separate `qid` per tier queue
Each low-online tier queue has its own `qid`: arcade 101–105 and coop 201–205 (stock: 0 everywhere except the sector queues). The MatchMaker's game expansion (`maxExpandTime = 30`: queued players are added to a game during its first 30 s) only fills games whose id matches the queue. With every queue at `qid = 0`, any queue could expand any game, so T1 players ended up in T5 battles. We verified this by decompiling `MatchMaker.exe`. Note that `maxMMValueDiff` (a queue parameter) defaults to unlimited.

### No excessive-bot kicking
`cvars.sv_kickExcessiveBotsEnabled = 0` in `ConfigureDediServer()` (stock 1). When humans join a running battle (expansion adds them in pairs, one per team), the stock battle server kicks "excessive" bots, and it **always takes them from team 1 if team 1 has any** (decompiled `GameplayRules_SpaceBattle.cpp`), so one team ends up two bots short. With kicking off, the joined humans are simply added and the teams stay as balanced as they started. To keep battles from growing too big, the low-online arcade template has `maxPlayers = 16` (stock 24): at most 16 humans plus up to 6 bots.

### PvE missions in a party
Both `-- PVE QUEUE` entries have `maxPlayers = 4` (stock 1), so PvE missions can be played in a party.

## Trading (mail)
In both `ConfigureShard()` blocks:
- `shard_minAntibotCounterForMailSending = 10` (stock 50): sending mail with attachments unlocks after 10 battles.
- `shard_is2StepAuthForMailSendingNeeded = 0` (stock unset, which acts as on). Otherwise players whose battles were played from another PC are blocked.

Admins can set a player's counter with the `setStat` admin task (see [ADMIN.md](ADMIN.md)). 

**Trading tax, softened.** `data/gamedata/trade.lua` → `TradingTax`: 0% up to 2000, 10% up to 10000, 20% above (stock: 0% up to 500, then 10 / 20 / 30 / 50%). The server reads the generated `cloud/data/aux_limits.xml`, so after copying the file regenerate the data (see [ADMIN.md](ADMIN.md#regenerating-game-data)). Only the `<TradingTax>` block should change.

## Flood limit
`shard.cfg`: `sm_reqFreqOverloadLine 5` and `sm_overloadCounterLimit 20`. The stock limit, about 0.8 requests per second, kicks players with "too many messages" while they gather resources in open space. Flood protection stays on, just with headroom.

## Premium as a welcome gift (scripts, not config)
- The tutorial reward is stock: 48 h of premium.
- `deploy/welcome.js` creates a broadcast (`adminMail`) that every account receives once, new ones included. It is a golden letter with 10 years of premium.
- **Never grant premium further than ~60 years ahead.** The client counts the remaining time in 32-bit seconds and overflows at ~68 years, and then shows no premium at all.

## Things we deliberately did not change
- **Progression.** Caps, ranks, faction access and the synergy grind are stock. This kit aims at the original progression, not an "everything unlocked" sandbox. Anyone can build that locally with Gaijin's guide.
- **Account auto-creation on first login** (stock). Disable it with `auth_allowInternalAutoCreate = 0` if you want registration elsewhere.
