import { rc4, chunkKey } from "../tool/lib/rc4.mjs";
import { readFileSync } from "node:fs";

const b64 = readFileSync("D:/lua_modding/NEXTLVL/dist_test/chunks/c01.lua", "utf8").trim();
const ct = Buffer.from(b64, "base64");
const src = readFileSync("D:/lua_modding/NEXTLVL/dist_test/game_frontend_hud.lua", "utf8");
const mkArr = src.match(/mk = \{([^}]*)\}/)[1].split(",").map(Number);
const maskArr = src.match(/m = \{([^}]*)\}/)[1].split(",").map(Number);
const M = mkArr.map((b, i) => b ^ maskArr[i % maskArr.length]);
const key = chunkKey(Buffer.from(M), "c01.lua");
const pt = Buffer.from(rc4(key, new Uint8Array(ct)));
const orig = readFileSync("D:/lua_modding/NEXTLVL/tests/payload_small.lua", "utf8");
console.log("decrypted:", JSON.stringify(pt.toString()));
console.log("MATCH:", pt.toString() === orig);