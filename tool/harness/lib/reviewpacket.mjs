// Builds the text packet handed to the independent reviewer, and the two fingerprints
// the completion gate compares it against.
//
// Repo-local on purpose: the generic runtime deliberately does not ship a packet builder
// (arch_wallet's carried a Dart-generated-file regex — see runtime/README.md's "Left
// out"). This one is Dart-aware in the only way that matters for bubbles_sheet.
//
// Determinism is the whole contract here: `buildPacket` must produce byte-identical
// output for an unchanged workspace, or every review goes stale on the next gate check.
// Nothing time-, path-, or environment-dependent may enter the packet text.

import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { join } from "node:path";

// Dart codegen output. bubbles_sheet has no build_runner today, so this matches nothing
// right now — it is here so that adding codegen later does not silently start feeding
// machine-written files to a reviewer.
const GENERATED_RE = /\.(g|freezed|config|gr|mocks)\.dart$/;

const MAX_DIFF_BYTES = 400 * 1024;

export function sha256Hex(s) {
  return createHash("sha256").update(s).digest("hex");
}

export function fingerprintOf(text) {
  return `sha256:${sha256Hex(text)}`;
}

function readOr(path, fallback) {
  try {
    return readFileSync(path, "utf8");
  } catch {
    return fallback;
  }
}

/**
 * The brief/plan content the review was produced against. Kept separate from the packet
 * fingerprint so the gate can tell "the code changed" from "the task's own definition of
 * done changed" — both invalidate a review, for different reasons.
 */
export function reviewInputContentFingerprint({ cwd, taskId }) {
  const dir = join(cwd, ".claude", "tasks", taskId);
  const brief = readOr(join(dir, "brief.md"), "<absent>");
  const plan = readOr(join(dir, "plan.md"), "<absent>");
  return fingerprintOf(`v1\nbrief\n${brief}\nplan\n${plan}\n`);
}

/**
 * The reviewer's input. Returns the packet text; `fingerprintOf(text)` is what lands in
 * review.json's `review_input_fingerprint`.
 */
export function buildPacket({ cwd, taskId, base, changedEntries, mode, tier }) {
  const dir = join(cwd, ".claude", "tasks", taskId);
  const reviewable = changedEntries.filter((e) => !GENERATED_RE.test(e.path));
  const excluded = changedEntries.filter((e) => GENERATED_RE.test(e.path));

  let diff = "";
  try {
    diff = execFileSync("git", ["diff", "-M", base, "--", ...reviewable.map((e) => e.path)], {
      cwd,
      encoding: "utf8",
      maxBuffer: 64 * 1024 * 1024,
      stdio: ["ignore", "pipe", "pipe"],
    });
  } catch (e) {
    diff = `<diff unavailable: ${String(e.message ?? e).split("\n")[0]}>`;
  }
  if (diff.length > MAX_DIFF_BYTES) {
    diff = `${diff.slice(0, MAX_DIFF_BYTES)}\n...[diff truncated at ${MAX_DIFF_BYTES} bytes]`;
  }

  const lines = [
    "# Independent review packet — bubbles_sheet",
    "",
    "bubbles_sheet is a published Flutter package (pub.dev) of modal bottom sheets built",
    "on package:smooth_sheets. Review the diff below for correctness and for anything",
    "that would break a downstream consumer: changed exports in lib/bubbles_sheet.dart",
    "(which also re-exports smooth_sheets), changed constructor or builder signatures on",
    "the public widgets, changed fields on the BubblesSheetThemeData ThemeExtension and",
    "its copyWith/lerp, changed default detent/inset/corner-radius behaviour, and",
    "version/CHANGELOG consistency. The `example/` app is a demo, not a product.",
    "",
    `task_id: ${taskId}`,
    `mode: ${mode}`,
    `tier: ${tier}`,
    `base: ${base}`,
    "",
    "## Brief",
    "",
    readOr(join(dir, "brief.md"), "<no brief.md>").trimEnd(),
    "",
    "## Plan",
    "",
    readOr(join(dir, "plan.md"), "<no plan.md>").trimEnd(),
    "",
    "## Changed files",
    "",
    ...reviewable.map((e) => `- ${e.status} ${e.path}${e.oldPath ? ` (from ${e.oldPath})` : ""}`),
  ];
  if (excluded.length > 0) {
    lines.push("", "## Excluded (generated)", "", ...excluded.map((e) => `- ${e.path}`));
  }
  lines.push("", "## Diff", "", "```diff", diff.trimEnd(), "```", "");
  return lines.join("\n");
}
