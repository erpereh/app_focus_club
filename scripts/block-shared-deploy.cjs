// Firestore/Storage rules and indexes are owned by web_focus_club. The copies
// in this repository are only for local emulators and are out of date:
// deploying them would remove the rules for notifications, fcmTokens and
// support conversations. Wired as a firebase.json predeploy hook.
const target = process.argv[2] || "this target";
console.error(
  `[deploy-guard] ${target} must be deployed from web_focus_club, not from app_focus_club. ` +
  "See docs/production-release-checklist.md.",
);
process.exit(1);
