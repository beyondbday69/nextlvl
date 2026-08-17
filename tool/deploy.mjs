import { readFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const HERE = path.dirname(fileURLToPath(import.meta.url));

function arg(name, fallback) {
  const i = process.argv.indexOf("--" + name);
  if (i >= 0 && process.argv[i + 1]) return process.argv[i + 1];
  return fallback;
}

const url = arg("url", "").replace(/\/$/, "");
const password = arg("password", "");
const manifestPath = arg("manifest", path.join(HERE, "..", "dist", "deploy_manifest.json"));

if (!url || !password) {
  console.error("Usage: node deploy.mjs --url https://worker.workers.dev --password <admin-password>");
  process.exit(1);
}

const manifest = JSON.parse(readFileSync(manifestPath, "utf8"));
const files = Object.keys(manifest.files || {});

console.log("Deploying " + files.length + " chunk(s) to " + url);

let failed = 0;
for (const f of files) {
  const body = JSON.stringify({
    action: "push_chunk",
    password,
    filename: f,
    data_b64: manifest.files[f],
  });
  try {
    const res = await fetch(url + "/admin/api", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body,
    });
    const out = await res.json();
    if (res.ok && out.success) {
      console.log("  [OK] " + f + " (" + out.size + " b64 chars)");
    } else {
      failed++;
      console.error("  [FAIL] " + f + ": " + (out.error || res.status));
    }
  } catch (e) {
    failed++;
    console.error("  [FAIL] " + f + ": " + e.message);
  }
}

if (failed) {
  console.error("Done with " + failed + " failure(s).");
  process.exit(1);
}
console.log("All chunks deployed. Update your keys' allowed_files to [" + files.map((f) => '"' + f + '"').join(", ") + "] in the admin panel.");