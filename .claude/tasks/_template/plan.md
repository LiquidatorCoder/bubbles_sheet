# Plan: <task-id>

## Change, file by file

| File | Change | Why |
|---|---|---|
| `lib/src/<file>.dart` | | |

## Public API impact

<Does `lib/bubbles_sheet.dart`'s export list change? Does any exported widget's or
`showBubblesSheet`'s signature change? Does `BubblesSheetThemeData` gain, lose or rename
a field — and are `copyWith` and `lerp` updated in step? If yes to any: this is a
release-path change — full tier, and `CHANGELOG.md` gets an entry in the same change.>

## Verification

<Which tier, and which checks in it actually exercise this change. Name the test files
under `test/` that cover it. If nothing in the suite exercises it — a paint-only or
gesture-timing change, say — state that here rather than letting a green run imply
coverage that does not exist.>

## Risks

<What could break for a downstream consumer: a changed default detent, inset or corner
radius; a chrome slot that stops rendering; a sheet that no longer dismisses.>
