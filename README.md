# NEXTLVL — Encrypted Lua Payload System (PUBG Mobile)

Purana approach (plaintext `BRPlayerCharacterBase.lua` + plaintext worker GET serving) ko replace karta hai.
Ab **koi bhi worker URL pakad le, woh encrypted base64 chunks ke alawa kuch nahi dekh payega**,
aur in-game dump impossible hai (chunk source kabhi memory me nahi rehta).

## Architecture

```
[Game at start]  game_frontend_hud.lua (bootstrap injected)
      │  loads key.txt + .device_id (fail-safe auto-generation)
      │  POST /validate → session token (15 min, quota 128 fetches)
      │  POST /g {s, dev, f} → base64 + RC4-encrypted chunk (only on allowlist)
      ▼
   decrypt → loadstring → run only when in-match (GameStatus.Battle
   + GameplayData / CharacterBase / combine_class modules ready)
```

- **Worker** (`worker/kv_worker.js`): sirf `/validate` aur `/g` public hai. Raw `.lua` serving **hataya**
  gaya (leak = 404). Rate limits: validate 20/min per IP, 10/min per key; `/g` 60/min per session.
  Kill switch: KV `meta_kill`. Admin API: `push_chunk`, `kill_set`, `kill_get`.
- **Encryption**: RC4 (JS `tool/lib/rc4.mjs` ↔ pure-Lua 5.1 nibble-XOR version, dono byte-identical).
  Chunk key = master key (32 bytes) + chunk name. Config (host + master key) bootstrap me masked arrays.
- **Anti-dump in loader**: `string.dump` nuked, `debug.sethook`/`debug.debug` blocked, `mobdebug` taint
  check, buffers nil'd + `collectgarbage`, no FileLog, silent errors.

## File Map

| Path | Kya hai |
|---|---|
| `worker/kv_worker.js` | Worker v2 — **yahi Cloudflare pe deploy karna** |
| `tool/build.mjs` | Payload compile + encrypt + frontend injection |
| `tool/templates/bootstrap.lua` | In-game loader (RC4, validate, fetch, poll, exec) |
| `tool/lib/rc4.mjs` | RC4/chunkKey/xor helpers (Lua version se sync rakhna) |
| `tool/deploy.mjs` | `dist/deploy_manifest.json` ke chunks worker pe push |
| `src/payloads/1.lua` | Real payload #1 (SRCHUB menu, skins, PlayerMapMarker) |
| `src/payloads/2.lua` | Real payload #2 (ModMenu) |
| `src/payloads/3.lua` | Real payload #3 (OPTISKI skin system) |
| `src/payloads/4.lua` | Real payload #4 (utility script) |
| `src/frontend_original.lua` | Original `game_frontend_hud.lua` (anchor: `return game_frontend_hud`) |
| `dist/` | Final build: `game_frontend_hud.lua` + `chunks/c01.lua` + manifests |
| `tests/` | worker_test.mjs, harness.lua, crypto tests, rc4_cross.mjs |
| `backup/` | Original `kv_worker.js` + `BRPlayerCharacterBase.lua` |
| `tool/lua51/` | lua5.1.exe / luac5.1.exe (local testing) |

## Setup Steps

### 1. Worker deploy (Cloudflare)
1. `worker/kv_worker.js` ko Cloudflare Workers pe upload karo.
2. Two KV namespaces banao:
   - `LULILOLO_KV` (keys, sessions, meta) — bind `LULILOLO_KV`
   - `LULILOLO_SCRIPTS` (chunks) — bind `LULILOLO_SCRIPTS`
3. Secret env `ADMIN_PASSWORD` set karo (admin API / dashboard key file checkboxes ke liye).

### 2. Build
```
node tool/build.mjs --payload src/payloads/1.lua --payload src/payloads/2.lua --payload src/payloads/3.lua --payload src/payloads/4.lua --host "https://<your-worker>.workers.dev" --out dist
```
- Har payload apna chunk banata hai: `c01.lua`...`c04.lua` (sab ek hi master key se encrypt).
- Har baar naya **master key** print hota hai — **offline store karo** (yaad rahe).
- `dist/` me: `game_frontend_hud.lua` (pak me dalna), `chunks/c01.lua..c04.lua` (worker pe push), `deploy_manifest.json`.

### 3. Deploy chunks
```
node tool/deploy.mjs --url "https://<your-worker>.workers.dev" --password <ADMIN_PASSWORD>
```
Phir admin dashboard (`/admin`) → Keys → apni key pe **saare chunk names tick karo** (`c01.lua`, `c02.lua`, `c03.lua`, `c04.lua`).

### 4. Repack
`dist/game_frontend_hud.lua` ko apne repack tool se game ke pak me inject karo (dumped wala file mat use karo, real file ka anchor chahiye).

### 5. Device
- `key.txt`: `/storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/Paks/key.txt`
  (pehli line = your key)
- `.device_id`: `/storage/emulated/0/Android/data/com.pubg.imobile/files/.device_id`
  (agar file missing ho to loader khud generate kar deta hai)
- Key pe `allowed_files` me chunk name hona zaroori, warna 403.

## Kill Switch
- ON: `POST /admin/kill_set {password, kill: true}`
- OFF: `POST /admin/kill_set {password, kill: false}`
- Status: `POST /admin/kill_get {password}`
- Kill on hone par `/validate` aur `/g` dono reject.

## Tests (local, Windows)
```
node tests/worker_test.mjs                          # worker logic 30/30
cd tests
..\tool\lua51\lua5.1.exe harness.lua ..\dist_test\game_frontend_hud.lua ..\dist_test\chunks\c01.lua
..\tool\lua51\lua5.1.exe crypto_real.lua            # real payload decrypt chain
..\tool\lua51\lua5.1.exe lua_crypto_test.lua        # small payload decrypt chain
```

## Important Caveats
- **`continue` keyword**: real payload Lua 5.2+ syntax use karta hai (`continue` line 267). Game ka patched
  parser text mode me chala leta hai, isliye **text mode = default aur safe**. `--bytecode` sirf tab
  use karna jab game-ka-asli patched `luac` ho; stock luac 5.1 fail karega.
- **Stock Lua 5.1 test limit**: harness real payload ko chala nahi sakta (usi `continue` ki wajah se),
  isliye real payload ka verification `crypto_real.lua` (decrypt chain) se hota hai.
- **Master key = secret**: koi bhi jiske paas master key + worker URL ho, chunks decrypt kar sakta hai.
  Master key sirf build machine pe rakho.
- Rate limits jo bhi client pe race ho, woh log fail ho jayenge (by design).
