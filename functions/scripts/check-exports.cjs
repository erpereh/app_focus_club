// Fails when the `portal` codebase would deploy anything but the functions it
// owns. Run after `npm run build` (also wired as a firebase.json predeploy).
const path = require("node:path");

const ALLOWED = ["deleteOwnAccount"];

const exported = Object.keys(require(path.join(__dirname, "..", "lib", "index.js"))).sort();
const unexpected = exported.filter((name) => !ALLOWED.includes(name));
const missing = ALLOWED.filter((name) => !exported.includes(name));

if (unexpected.length || missing.length) {
  console.error("[check-exports] The portal codebase must export exactly:", ALLOWED.join(", "));
  if (unexpected.length) console.error("  unexpected:", unexpected.join(", "));
  if (missing.length) console.error("  missing:", missing.join(", "));
  process.exit(1);
}
console.log("[check-exports] OK:", exported.join(", "));
