// bubbles_sheet's own file classifier: changed files -> required verification tier.
//
// Repo-specific by design. The generic harness runtime (~/.claude/harness/runtime/lib)
// deliberately ships no classifier, because "what does this change risk" is a question
// only a specific repo can answer. This one answers it for a published Flutter widget
// package that has a real widget-test suite and a demo app.
//
// LOCKSTEP: `.claude/docs/routing.yaml` is the human-readable statement of this same
// policy, and `RULES` below is its executable form. Node has no built-in YAML parser and
// this repo has no YAML dependency (it is a Dart package), so the policy is not parsed
// from the YAML at runtime. Change both files together. Both are listed in POLICY_FILES,
// so editing either one changes the verification policy fingerprint and invalidates every
// existing verify.json — which is what makes drift loud instead of silent.

export const TIERS = ["fast", "normal", "full"];
export const TIER_RANK = { fast: 0, normal: 1, full: 2 };

// Files whose content defines what verification means here. Hashed into every
// verify.json's verification_policy_fingerprint.
export const POLICY_FILES = [
  "tool/harness/verify",
  "tool/harness/lib/classify.mjs",
  "tool/harness/lib/reviewpolicy.mjs",
  ".claude/docs/routing.yaml",
  "analysis_options.yaml",
];

// Never part of a workspace fingerprint: task bookkeeping, managed worktrees, and
// Dart/Flutter's own generated directories. `.dart_tool/` and `build/` are gitignored
// here anyway; listing them is belt-and-braces for an explicit --files scope.
export const FINGERPRINT_EXCLUDE_PREFIXES = [
  ".claude/tasks/",
  ".claude/worktrees/",
  ".dart_tool/",
  "build/",
  "example/.dart_tool/",
  "example/build/",
  "coverage/",
];

// Shared resources a worker may serialize on. This repo has no codegen step (no
// build_runner in dev_dependencies), no native platform directories of its own, and no
// device/simulator pool — so none of those appear here.
export const LOCK_RESOURCES = ["dependency-resolution", "repo-format", "release"];

// First match wins, in order. Mirrors routing.yaml's `classification:` block.
export const RULES = [
  { match: "pubspec.yaml", tier: "full", why: "SDK/Flutter constraints, dependencies, the published version and the pub.dev screenshot manifest all live here" },
  { match: "CHANGELOG.md", tier: "full", why: "part of the pub.dev release artifact, changed together with the version" },
  { match: "LICENSE", tier: "full", why: "distribution terms of the published archive; pub validates its presence" },
  { match: "lib/bubbles_sheet.dart", tier: "full", why: "the public export barrel, which also re-exports package:smooth_sheets wholesale — removing an export breaks every consumer" },
  { match: "doc/**", tier: "full", why: "pubspec.yaml's `screenshots:` points into doc/screenshots/; pub validates those paths and sizes at publish time" },
  { match: "lib/**", tier: "normal", why: "package implementation consumed by real apps; the widget-test suite is what exercises it" },
  { match: "test/**", tier: "normal", why: "a change to a test changes what passing means — the suite must actually run" },
  { match: "analysis_options.yaml", tier: "normal", why: "very_good_analysis rule set; a change here re-scopes every analyze run in the repo and in example/" },
  { match: "tool/harness/**", tier: "normal", why: "verifier and gate logic" },
  { match: ".claude/docs/routing.yaml", tier: "normal", why: "verification policy" },
  { match: "AGENTS.md", tier: "normal", why: "the rules agents work from" },
  { match: "example/**", tier: "fast", why: "demo app (publish_to: none); not depended on by lib/, and analysed on its own in the normal tier" },
  { match: "README.md", tier: "fast", why: "documentation" },
  { match: "docs/**", tier: "fast", why: "agent-facing documentation; not shipped in the archive" },
  { match: ".claude/tasks/**", tier: "fast", why: "task bookkeeping" },
  { match: "*", tier: "fast", why: "default floor — nothing here is verification-exempt" },
];

const DOUBLESTAR = "__HARNESS_DOUBLESTAR__";

/**
 * Minimal glob matcher for the forms RULES actually uses: an exact path, a `dir/**`
 * prefix, a single `*` segment wildcard, and the bare `*` catch-all. Deliberately not a
 * general glob implementation — a rule form not listed above is a policy authoring
 * mistake, and a silently-mismatching clever matcher would be worse than an obvious one.
 */
export function matchesPattern(path, pattern) {
  if (pattern === "*") return true;
  if (!pattern.includes("*")) return path === pattern;
  if (pattern.endsWith("/**")) {
    const prefix = pattern.slice(0, -2); // keep the trailing slash
    return path.startsWith(prefix);
  }
  const escaped = pattern.replace(/[.+^${}()|[\]\\]/g, "\\$&");
  const body = escaped.split("**").join(DOUBLESTAR).split("*").join("[^/]*").split(DOUBLESTAR).join(".*");
  return new RegExp(`^${body}$`).test(path);
}

/** The tier one path demands, plus the rule that decided it. */
export function classifyFile(path) {
  for (const rule of RULES) {
    if (matchesPattern(path, rule.match)) return { tier: rule.tier, rule: rule.match, why: rule.why };
  }
  // Unreachable while the `*` catch-all is present. Fail closed rather than return
  // undefined if someone ever removes it.
  return { tier: "full", rule: "(no rule matched)", why: "fail closed: no classification rule matched" };
}

/**
 * The highest tier any changed file demands. An EMPTY change set returns "fast" — the
 * floor, not "full": a verify run with nothing changed has nothing to escalate for.
 * Returns { requiredTier, reasons: [{path, tier, rule, why}] } with reasons listing only
 * the files that drove the maximum.
 */
export function classifyChanges(changedFiles) {
  let requiredTier = "fast";
  const all = [];
  for (const path of changedFiles) {
    const c = classifyFile(path);
    all.push({ path, ...c });
    if (TIER_RANK[c.tier] > TIER_RANK[requiredTier]) requiredTier = c.tier;
  }
  return { requiredTier, reasons: all.filter((r) => r.tier === requiredTier) };
}
