# NEXTLVL — Encrypted Lua Payload System (PUBG Mobile)

Encrypted chunk pipeline: **build → deploy → worker → in-game loader**. Koi bhi worker URL pakad le,
woh encrypted base64 chunks ke alawa kuch nahi dekh payega, aur in-game dump impossible hai
(chunk source kabhi memory me nahi rehta).

## Architecture

```
[Game at match start]  BRPlayerCharacterBase.lua (battle bridge, pak-injected)
      │  loads key.txt + .device_id (fail-safe auto-generation)
      │  har match file re-executes → per-match reset → cached chunks phir se run
      │  POST /validate → session token + allowed_files
      │  POST /g {session, dev, f} → base64 + RC4-encrypted chunk (allowlist + session quota)
      ▼
   decrypt (RC4, master key + chunk name) → loadstring → run only when in-match

[Game at lobby]  game_frontend_hud.lua (frontend bootstrap)
      │  same validate → fetch → exec chain (login page agar key missing ho)
```

- **Worker** (`worker/kv_worker.js`): sirf `/validate` aur `/g` public. Raw `.lua` serving nahi.
  Rate limits: validate 20/min per IP, 10/min per key; `/g` 60/min per session.
  Kill switch: KV `meta_kill`. Admin API: `push_chunk`, `save_script`, `kill_set/get`, keys CRUD.
- **Encryption**: RC4 (JS `tool/lib/rc4.mjs` ↔ pure-Lua 5.1 nibble-XOR version, byte-identical).
  Chunk key = **master key (32 bytes, FIXED via `--key`)** + chunk name. Config (host + master key)
  bootstrap me masked arrays. Random-key builds log "(random key - use --key to pin it)".
- **In-game login page**: key.txt missing/empty hone par UMG login page (EditableTextBox + native
  keyboard), key save karke fetch chain start.
- **Canary**: `NL<ver>-<key4>-<dev8>` watermark top-left + `.nextlvl_canary` file (identification).
- **Second-match fix**: `BRPlayerCharacterBase.lua` har match reload hota hai (slua require cache
  nahi karta); file-scope me `_G._NEXTLVL_EXECUTED = nil` reset → chunks har match re-execute.
- **Anti-dump**: `string.dump` nuked, `debug.sethook`/`debug.debug` blocked, mobdebug taint check,
  buffers nil'd + `collectgarbage`, no FileLog, silent errors.

## Ban-free Pak Route (res_pufferpatch + update blocker)

`game_patch`/`core_patch` paks modify karne par ban risk. Recommended setup:

1. Phone `Paks` folder me se **saare `game_patch_4.5.0.*` aur `core_patch_4.5.0.*` delete** karo.
2. `Paks` me **`new.filelist`/`mottd` folder** banao (update blocker — game update prevent).
3. Hamare 2 files `res_pufferpatch` (sabse naya version, e.g. `.21390`) me inject karo:
   - `Content/Lua/game_frontend_hud.lua`
   - `Content/Lua/GameLua/Mod/BRMod/Gameplay/Core/BRPlayerCharacterBase.lua`
   - Mount `ShadowTrackerExtra` same hai, enc=47 SM4, cm=1 zlib.
4. `inject_res.py` (`unpack_repack_tool/`) res pak target karta hai; `inject_run.py` game_patch ke
   liye. Verify: `verify_inject.py` (hardcoded game_patch) ya direct TencentPakFile check.

> Loader/frontend change = **naya pak** zaroori. Payload (c01-c04) change = sirf `deploy.mjs`,
> pak nahi (fixed master key ki wajah se).

## File Map

| Path | Kya hai |
|---|---|
| `worker/kv_worker.js` | Worker v2 — Cloudflare pe deploy (module: `kv_worker.js`) |
| `tool/build.mjs` | Payload compile + encrypt + frontend/bridge injection. `--key <64hex>` pin karta hai |
| `tool/templates/bootstrap.lua` | Frontend in-game loader (lobby, `game_frontend_hud.lua`) |
| `tool/templates/battle_bridge.lua` | Battle loader (`BRPlayerCharacterBase.lua`): login page, canary, per-match reset |
| `tool/lib/rc4.mjs` | RC4/chunkKey/xor helpers (Lua version se sync) |
| `tool/deploy.mjs` | `dist/deploy_manifest.json` ke chunks worker pe push |
| `tool/stage_edit.mjs` | `dist/` → `unpack_repack_tool/PAK TOOL/EDIT/` staging |
| `src/payloads/1.lua` | c01 — SRCHUB menu (ESP, aimbot, recoil comp, burst aim) |
| `src/payloads/2.lua` | c02 — ModMenu (dropdowns/checkboxes/sliders, settings save) |
| `src/payloads/3.lua` | c03 — OPTISKI skin system |
| `src/payloads/4.lua` | c04 — utility script |
| `src/frontend_original.lua` | Original `game_frontend_hud.lua` (anchor: `return game_frontend_hud`) |
| `dist/` | Final build: `game_frontend_hud.lua`, `BRPlayerCharacterBase.lua`, `chunks/c01.lua..c04.lua`, manifests |
| `tests/` | worker_test.mjs, harness.lua, crypto tests, rc4_cross.mjs |
| `backup/` | Original `kv_worker.js` + `BRPlayerCharacterBase.lua` |
| `tool/lua51/` | lua5.1.exe / luac5.1.exe (local testing) |

## Setup Steps

### 1. Worker deploy (Cloudflare)
1. `worker/kv_worker.js` ko Cloudflare Workers pe upload karo — module format,
   part name = module filename (e.g. `kv_worker.js`), content type `application/javascript+module`,
   metadata me `main_module` (API upload). Dashboard se bhi chalega.
2. Two KV namespaces banao: `LULILOLO_KV` (keys/sessions/meta) + `LULILOLO_SCRIPTS` (chunks),
   worker pe bind karo.
3. Secret `ADMIN_PASSWORD` set karo (redeploy ke baad re-set karna padta hai).
4. **Script labels**: admin `/admin` → Scripts tab → Edit → Label field. Labels KV
   (`meta_script_labels`) me store hote hain, content untouched. Key modal + keys table me bhi
   labels dikhte hain (`label (filename)`).

### 2. Build (fixed key — IMPORTANT)
```
node tool/build.mjs --payload src/payloads/1.lua --payload src/payloads/2.lua --payload src/payloads/3.lua --payload src/payloads/4.lua --host "https://<your-worker>.workers.dev" --version 7 --key <your-64hex-master-key>
```
- `--key` **har build pe same rakho** warna chunks decrypt nahi honge existing pak se.
- Output: `dist/game_frontend_hud.lua` (lobby pak), `dist/BRPlayerCharacterBase.lua` (battle pak),
  `dist/chunks/c01.lua..c04.lua` (worker pe push), `deploy_manifest.json`.

### 3. Deploy chunks
```
node tool/deploy.mjs --url "https://<your-worker>.workers.dev" --password <ADMIN_PASSWORD>
```
Phir admin (`/admin`) → Keys → key pe saare chunk names tick karo (`c01.lua`..`c04.lua`).

### 4. Repack (res_pufferpatch route)
```
node tool/stage_edit.mjs
python -X utf8 inject_res.py      # unpack_repack_tool/ me — res_pufferpatch_4.5.0.21390.pak target
```
Result: `unpack_repack_tool/PAK TOOL/RESULT/res_pufferpatch_4.5.0.21390.pak` → phone pe
purana res pak replace. (`inject_run.py` = game_patch route, ban-risk.)

### 5. Device
- `key.txt`: `.../UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/key.txt` (pehli line = key)
- `.device_id`: `.../files/.device_id` (missing ho to khud generate)
- Logs: `.../files/Myweowlogs.txt` — `battle executing c01.lua → OK` har match me aana chahiye.
- Key pe `allowed_files` me chunk names hona zaroori, warna 403.

## Admin Labels API

```
POST /admin/api {action:"save_script", password, filename:"c03.lua", content:"", label:"Skin lua"}
```
⚠️ Empty content save karne se chunk wipe hota hai — content ke bina sirf label set karte waqt
pehle chunk content fetch karke wapas bhejo, ya deploy.mjs se chunks restore karo.

## Kill Switch
- ON: `POST /admin/kill_set {password, kill: true}` — OFF: `kill: false` — Status: `kill_get`
- Kill on hone par `/validate` aur `/g` dono reject.

## Tests (local, Windows)
```
node tests/worker_test.mjs                          # worker logic
cd tests
..\tool\lua51\lua5.1.exe harness.lua ..\dist_test\game_frontend_hud.lua ..\dist_test\chunks\c01.lua
..\tool\lua51\lua5.1.exe crypto_real.lua            # real payload decrypt chain
..\tool\lua51\lua5.1.exe lua_crypto_test.lua        # small payload decrypt chain
```

## Important Caveats
- **`continue` keyword**: real payload Lua 5.2+ syntax use karta hai; `luac5.1 -p` payload pe fail
  karta hai (expected). Sirf `dist/` files luac-check hoti hain.
- **Master key = secret**: jiske paas master key + worker URL ho, chunks decrypt kar sakta hai.
  `--key` har build pe reuse karo; key sirf build machine pe rakho.
- **Bridge change → naya pak**: loader/frontend me koi bhi change pak rebuild mangata hai;
  payload-only changes sirf deploy.
- Rate limits jo client pe race ho, woh log fail ho jayenge (by design).