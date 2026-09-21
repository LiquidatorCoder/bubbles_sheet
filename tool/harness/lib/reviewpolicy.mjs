// bubbles_sheet's own review policy: changed files -> required independent-review mode.
//
// Repo-specific by design (the generic runtime ships no review policy — see
// ~/.claude/harness/runtime/README.md's "Left out" section).
//
// The judgement encoded here is narrow and was arrived at by reading this repo, not by
// importing another repo's categories. bubbles_sheet makes no network calls, handles no
// credentials, persists nothing, ships no native platform directories, and has no
// signing configuration — so none of the usual trust-boundary categories apply. It has
// exactly one way to affect anyone outside this checkout: **being published to pub.dev**
// and consumed as a widget API. That is what review gates.
//
// LOCKSTEP with `.claude/docs/routing.yaml`'s `review:` block — see the same note in
// classify.mjs.

import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { join } from "node:path";

import { matchesPattern } from "./classify.mjs";

export const REVIEW_MODES = ["none", "standard", "adversarial"];
export const MODE_RANK = { none: 0, standard: 1, adversarial: 2 };

// Files whose content defines what review means here. Hashed into a review.json's
// review_policy_fingerprint.
export const REVIEW_POLICY_FILES = ["tool/harness/lib/reviewpolicy.mjs", "tool/harness/review", ".claude/docs/routing.yaml"];

// The release path, and nothing else.
export const RELEASE_PATH_PATTERNS = [
  { match: "pubspec.yaml", mode: "standard", why: "version, SDK/Flutter constraints and publish metadata" },
  { match: "lib/bubbles_sheet.dart", mode: "standard", why: "the export barrel; it also re-exports package:smooth_sheets, so a dropped export breaks imports downstream" },
  { match: "lib/src/bubbles_sheet_theme.dart", mode: "standard", why: "BubblesSheetThemeData is a public ThemeExtension that host apps construct, copyWith and lerp — a changed field or builder signature is a breaking change, not an implementation detail" },
  { match: "LICENSE", mode: "standard", why: "distribution terms of a published artifact" },
];

export const DEFAULT_MODE = "none";

export function maxMode(a, b) {
  return MODE_RANK[a] >= MODE_RANK[b] ? a : b;
}

/** { mode, reasons:[{path, mode, why}] } — reasons lists only files at the max mode. */
export function requiredReviewMode(changedFiles) {
  let mode = DEFAULT_MODE;
  const hits = [];
  for (const path of changedFiles) {
    for (const rule of RELEASE_PATH_PATTERNS) {
      if (matchesPattern(path, rule.match)) {
        hits.push({ path, mode: rule.mode, why: rule.why });
        mode = maxMode(mode, rule.mode);
        break;
      }
    }
  }
  return { mode, reasons: hits.filter((h) => h.mode === mode) };
}

/** sha256 over REVIEW_POLICY_FILES' bytes. A missing file hashes as absent, not zero. */
export function reviewPolicyFingerprint({ cwd, policyFiles = REVIEW_POLICY_FILES }) {
  const h = createHash("sha256");
  const sep = Buffer.from([0]);
  for (const rel of [...policyFiles].sort()) {
    h.update(rel);
    h.update(sep);
    try {
      h.update(readFileSync(join(cwd, rel)));
    } catch {
      h.update("<absent>");
    }
    h.update(sep);
  }
  return `sha256:${h.digest("hex")}`;
}
