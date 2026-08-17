import { default as worker } from "../worker/kv_worker.js";

class MockKV {
  constructor() { this.map = new Map(); }
  async get(key, type) {
    const v = this.map.get(key);
    if (v === undefined) return null;
    return type === "json" ? JSON.parse(v) : v;
  }
  async put(key, value, opts) {
    this.map.set(key, typeof value === "string" ? value : JSON.stringify(value));
  }
  async delete(key) { this.map.delete(key); }
  async list(opts) {
    const prefix = (opts && opts.prefix) || "";
    const keys = [...this.map.keys()].filter((k) => k.startsWith(prefix)).map((name) => ({ name }));
    return { keys };
  }
}

const env = {
  LULILOLO_KV: new MockKV(),
  LULILOLO_SCRIPTS: new MockKV(),
  ADMIN_PASSWORD: "testpass",
};

const FUTURE = new Date(Date.now() + 30 * 24 * 3600 * 1000).toISOString();

// seed
await env.LULILOLO_KV.put("key_goodkey", JSON.stringify({
  active: true, expiry: FUTURE, device_limit: 1, devices: ["devAAAA"], allowed_files: ["c01.lua", "c02.lua"],
}));
await env.LULILOLO_KV.put("key_afterkill", JSON.stringify({
  active: true, expiry: FUTURE, device_limit: 1, devices: ["devAAAA"], allowed_files: ["c01.lua"],
}));
await env.LULILOLO_KV.put("key_banned", JSON.stringify({ active: false, expiry: FUTURE, device_limit: 1, devices: [] }));
await env.LULILOLO_KV.put("key_expired", JSON.stringify({ active: true, expiry: "2020-01-01T00:00:00Z", device_limit: 1, devices: [] }));
await env.LULILOLO_KV.put("key_full", JSON.stringify({ active: true, expiry: FUTURE, device_limit: 1, devices: ["otherdev"], allowed_files: ["c01.lua"] }));
await env.LULILOLO_SCRIPTS.put("c01.lua", "QUJDREVGR0g="); // "ABCDEFGH"
await env.LULILOLO_SCRIPTS.put("c02.lua", "SU5WRUNPUkV="); // "INVECORE"

function req(url, method = "GET", body = null, headers = {}) {
  const init = { method, headers: { "Content-Type": "application/json", ...headers } };
  if (body) init.body = typeof body === "string" ? body : JSON.stringify(body);
  return worker.fetch(new Request("https://test.local" + url, init), env);
}
const j = (r) => r.json();

let pass = 0, fail = 0;
function check(name, cond, extra = "") {
  if (cond) { pass++; console.log("  [PASS] " + name); }
  else { fail++; console.log("  [FAIL] " + name + " " + extra); }
}

console.log("== validate ==");
let r = await req("/validate", "POST", { key: "goodkey", device_id: "devAAAA" });
let d = await j(r);
check("valid key -> valid:true", d.valid === true, JSON.stringify(d));
check("session issued", typeof d.session === "string" && d.session.length === 64);
check("allowed files returned", Array.isArray(d.allowed_files) && d.allowed_files.includes("c01.lua"));

let session = d.session;

r = await req("/validate", "POST", { key: "wrongkey", device_id: "devAAAA" });
d = await j(r);
check("invalid key -> valid:false", d.valid === false && d.error === "Invalid key");

r = await req("/validate", "POST", { key: "banned", device_id: "devAAAA" });
d = await j(r);
check("banned key -> false", d.valid === false && d.error === "Key banned");

r = await req("/validate", "POST", { key: "expired", device_id: "devAAAA" });
d = await j(r);
check("expired key -> false", d.valid === false && d.error === "Key expired");

r = await req("/validate", "POST", { key: "full", device_id: "newdev" });
d = await j(r);
check("device limit -> false", d.valid === false && d.error === "Device limit reached");

r = await req("/validate", "POST", { key: "goodkey", device_id: "unknown" });
d = await j(r);
check("fake device id rejected", d.valid === false);

console.log("== /g chunk fetch ==");
r = await req("/g", "POST", { session, dev: "devAAAA", f: "c01.lua" });
d = await j(r);
check("valid session fetch -> ok + data", r.status === 200 && d.ok === true && d.data === "QUJDREVGR0g=");

r = await req("/g", "POST", { session, dev: "devBBBB", f: "c01.lua" });
d = await j(r);
check("wrong device -> 403", r.status === 403);

r = await req("/g", "POST", { session, dev: "devAAAA", f: "c99.lua" });
d = await j(r);
check("file not in session -> 403", r.status === 403);

r = await req("/g", "POST", { session, dev: "devAAAA", f: "c01.lua" });
d = await j(r);
check("re-fetch same chunk still ok", r.status === 200 && d.ok === true);

r = await req("/g", "POST", { session: "deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef", dev: "devAAAA", f: "c01.lua" });
check("garbage session -> 403", r.status === 403);

r = await req("/g", "POST", { session, dev: "devAAAA", f: "../../evil.lua" });
check("path traversal filename -> 400", r.status === 400);

console.log("== session expiry ==");
await env.LULILOLO_KV.put("sess_stale", JSON.stringify({ dev: "devAAAA", exp: Date.now() - 1000, files: ["c01.lua"], used: 0 }));
r = await req("/g", "POST", { session: "stale", dev: "devAAAA", f: "c01.lua" });
check("expired session -> 403", r.status === 403);

console.log("== quota ==");
const sess2 = JSON.stringify({ dev: "devAAAA", exp: Date.now() + 60000, files: ["c01.lua"], used: 127 });
await env.LULILOLO_KV.put("sess_quota", sess2);
r = await req("/g", "POST", { session: "quota", dev: "devAAAA", f: "c01.lua" });
d = await j(r);
check("128th fetch ok", r.status === 200 && d.ok === true);
r = await req("/g", "POST", { session: "quota", dev: "devAAAA", f: "c01.lua" });
check("quota exceeded -> 403", r.status === 403);

console.log("== rate limit (validate) ==");
let blocked = false;
for (let i = 0; i < 12; i++) {
  r = await req("/validate", "POST", { key: "goodkey", device_id: "devAAAA" });
  if (r.status === 429) { blocked = true; break; }
}
check("validate rate limited after spam", blocked, "status=" + r.status);

console.log("== old .lua leak blocked ==");
r = await req("/c01.lua");
check("GET /c01.lua -> 404 (NO LEAK)", r.status === 404);
r = await req("/1.lua", "POST", "key_path=1.lua");
check("POST /1.lua old style -> 404 (NO LEAK)", r.status === 404);
r = await req("/admin/api", "POST", { action: "get_script", filename: "c01.lua" });
check("get_script without password -> 401", r.status === 401);

console.log("== admin push_chunk / kill switch ==");
r = await req("/admin/api", "POST", { action: "push_chunk", password: "testpass", filename: "c03.lua", data_b64: "TUVOQ0hVTktTTw==" });
d = await j(r);
check("push_chunk ok", r.status === 200 && d.success === true);
const v = await env.LULILOLO_SCRIPTS.get("c03.lua");
check("chunk stored", v === "TUVOQ0hVTktTTw==");

r = await req("/admin/api", "POST", { action: "push_chunk", password: "testpass", filename: "..%2F..%2Fevil.lua", data_b64: "TUVOQw==" });
check("push_chunk bad name rejected", r.status === 400);

r = await req("/admin/api", "POST", { action: "kill_set", password: "testpass", kill: true });
d = await j(r);
check("kill_set ok", d.success === true);
r = await req("/validate", "POST", { key: "goodkey", device_id: "devA" });
check("validate blocked by kill switch", r.status === 403);
r = await req("/g", "POST", { session, dev: "devA", f: "c01.lua" });
check("/g blocked by kill switch", r.status === 403);
r = await req("/admin/api", "POST", { action: "kill_set", password: "testpass", kill: false });
check("kill cleared", (await j(r)).success === true);
r = await req("/validate", "POST", { key: "afterkill", device_id: "devAAAA" });
check("validate works after kill cleared", r.status === 200);

console.log("== admin auth ==");
r = await req("/admin/api", "POST", { action: "list", password: "wrong" });
check("wrong admin password -> 401", r.status === 401);

console.log("");
console.log(pass + " passed, " + fail + " failed");
process.exit(fail ? 1 : 0);