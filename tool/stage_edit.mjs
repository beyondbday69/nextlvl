import { readFileSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const dist = path.join(HERE, "..", "dist");
const editLua = path.join(HERE, "..", "..", "unpack_repack_tool", "PAK TOOL", "EDIT", "Content", "Lua");
const editBR = path.join(HERE, "..", "..", "unpack_repack_tool", "PAK TOOL", "EDIT", "Content", "Lua", "GameLua", "Mod", "BRMod", "Gameplay", "Core");

import { mkdirSync } from "node:fs";
mkdirSync(editLua, { recursive: true });
mkdirSync(editBR, { recursive: true });

writeFileSync(path.join(editLua, "game_frontend_hud.lua"), readFileSync(path.join(dist, "game_frontend_hud.lua")));
writeFileSync(path.join(editBR, "BRPlayerCharacterBase.lua"), readFileSync(path.join(dist, "BRPlayerCharacterBase.lua")));
console.log("EDIT folder updated:");
console.log("  " + path.join(editLua, "game_frontend_hud.lua"));
console.log("  " + path.join(editBR, "BRPlayerCharacterBase.lua"));