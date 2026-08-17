import { readFileSync, writeFileSync, mkdirSync, existsSync, rmSync } from "node:fs";
import { execFileSync } from "node:child_process";
import { randomBytes } from "node:crypto";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { rc4, chunkKey, xorBytes } from "./lib/rc4.mjs";

const HERE = path.dirname(fileURLToPath(import.meta.url));
const LUAC = path.join(HERE, "lua51", "luac5.1.exe");

function arg(name, fallback) {
  const i = process.argv.indexOf("--" + name);
  if (i >= 0 && process.argv[i + 1]) return process.argv[i + 1];
  return fallback;
}
function flag(name) {
  return process.argv.includes("--" + name);
}

const payloads = [];
for (let i = 0; i < process.argv.length; i++) {
  if (process.argv[i] === "--payload" && process.argv[i + 1]) payloads.push(process.argv[i + 1]);
}

const frontendPath = arg("frontend", path.join(HERE, "..", "src", "frontend_original.lua"));
const outDir = arg("out", path.join(HERE, "..", "dist"));
const host = arg("host", "");
const version = parseInt(arg("version", "1"), 10);
const bytecode = flag("bytecode");

if (payloads.length === 0) {
  console.error("Usage: node build.mjs --payload <file.lua> [--payload <more.lua>] --host https://worker.workers.dev [--bytecode] [--version 2] [--out dist]");
  process.exit(1);
}
if (!host) {
  console.error("Missing --host (your worker URL, e.g. https://xxx.workers.dev)");
  process.exit(1);
}

const chunksDir = path.join(outDir, "chunks");
if (existsSync(chunksDir)) rmSync(chunksDir, { recursive: true });
mkdirSync(chunksDir, { recursive: true });

const master = randomBytes(32);
const mask = randomBytes(8);

const deployFiles = {};
const manifest = { version, mode: bytecode ? "bytecode" : "text", host, chunks: [] };

for (let i = 0; i < payloads.length; i++) {
  const srcPath = payloads[i];
  const name = "c" + String(i + 1).padStart(2, "0") + ".lua";
  let data = readFileSync(srcPath);

  if (bytecode) {
    if (!existsSync(LUAC)) {
      console.error("luac5.1 not found at " + LUAC + " - install it or build without --bytecode");
      process.exit(1);
    }
    const tmp = path.join(outDir, "_tmp_" + i + ".luac");
    try {
      execFileSync(LUAC, ["-s", "-o", tmp, srcPath]);
      data = readFileSync(tmp);
      rmSync(tmp);
    } catch (e) {
      console.error("luac failed for " + srcPath + ": " + (e.stderr ? e.stderr.toString() : e.message));
      process.exit(1);
    }
    console.log("  [" + name + "] compiled to bytecode (" + data.length + " bytes)");
  } else {
    console.log("  [" + name + "] text mode (" + data.length + " bytes)");
  }

  const key = chunkKey(master, name);
  const enc = rc4(key, new Uint8Array(data));
  const b64 = Buffer.from(enc).toString("base64");

  writeFileSync(path.join(chunksDir, name), b64, "ascii");
  deployFiles[name] = b64;
  manifest.chunks.push({ name, size: data.length });
}

console.log("Master key (KEEP SECRET, store offline): " + master.toString("hex"));

function maskedArr(str) {
  const bytes = Buffer.from(str, "latin1");
  const m = xorBytes(bytes, mask);
  return "{" + Array.from(m).join(",") + "}";
}
function maskArr() {
  return "{" + Array.from(mask).join(",") + "}";
}

let bootstrap = readFileSync(path.join(HERE, "templates", "bootstrap.lua"), "utf8");
bootstrap = bootstrap.replace("@@CFG_VER@@", String(version));
bootstrap = bootstrap.replace("@@CFG_MASK@@", maskArr());
bootstrap = bootstrap.replace("@@CFG_MK@@", maskedArr(master.toString("latin1")));
bootstrap = bootstrap.replace("@@CFG_HOST@@", maskedArr(host));

let frontend = readFileSync(frontendPath, "utf8");
const anchor = "\nreturn game_frontend_hud";
const at = frontend.indexOf(anchor);
if (at < 0) {
  console.error("frontend file: 'return game_frontend_hud' not found - wrong file?");
  process.exit(1);
}
const injected = frontend.slice(0, at) + "\n" + bootstrap + frontend.slice(at);
writeFileSync(path.join(outDir, "game_frontend_hud.lua"), injected, "utf8");

writeFileSync(path.join(outDir, "deploy_manifest.json"), JSON.stringify({ version, files: deployFiles }, null, 2), "utf8");
writeFileSync(path.join(outDir, "manifest.json"), JSON.stringify(manifest, null, 2), "utf8");

const luacProbe = path.join(outDir, "_probe.lua");
writeFileSync(luacProbe, "local _ok = pcall(load, 'return 1')\nreturn _ok\n", "utf8");

console.log("");
console.log("DONE:");
console.log("  injected frontend : " + path.join(outDir, "game_frontend_hud.lua"));
console.log("  chunks            : " + chunksDir + " (" + payloads.length + " files)");
console.log("  deploy manifest   : " + path.join(outDir, "deploy_manifest.json"));
console.log("");
console.log("Next: node tool/deploy.mjs --url <worker> --password <admin>");
console.log("Then repack dist/game_frontend_hud.lua into the game pak (replaces the real one).");