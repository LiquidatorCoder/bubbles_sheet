# Brief: <task-id>

## Asked for

<What the user actually requested, in their framing. Not your restatement of it.>

## Done means

<Observable conditions. Each one must be checkable by someone who was not in the
conversation — a command that exits zero, a named widget test that passes, a behaviour
visible in the example app. "Works correctly" is not a condition.>

- [ ]
- [ ]

## Out of scope

<Things deliberately not being changed, so a later reader knows they were considered.>

## Tier

<fast | normal | full — and why. Cross-check against .claude/docs/routing.yaml; the
classifier's opinion of the changed files overrides a too-low declaration anyway.>

## Review

<none | standard | adversarial — and why. `none` is correct for most changes in this
repo; anything touching pubspec.yaml, lib/bubbles_sheet.dart's exports,
lib/src/bubbles_sheet_theme.dart's public fields, or LICENSE is not.>
