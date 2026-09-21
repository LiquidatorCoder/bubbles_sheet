# Task lifecycle (`.claude/tasks/`)

Runtime state for the harness. **Only this README and `_template/` are tracked** — every
real task directory is gitignored (see `.gitignore`), because task state is per-checkout
working state, not repository content.

## Layout

```
.claude/tasks/
  README.md              <- tracked
  _template/             <- tracked; copy it to start a task
    brief.md
    plan.md
  .active                <- one line: the active task id
  <task-id>/             <- one directory per task, gitignored
    brief.md             what was asked, and what "done" means
    plan.md              the intended change, file by file
    decisions.md         decisions taken mid-task, with ids (D1, D2, ...)
    state.json           written ONLY by tool/harness/task
    verify.json          written ONLY by tool/harness/verify
    review.json          written ONLY by tool/harness/review (if used)
    adjudication.json    written ONLY by tool/harness/review adjudicate
```

Task ids are `YYYYMMDD-<short-slug>`, e.g. `20260921-flush-corner-radius`.

## States

`planning -> working -> verifying -> ready_to_complete -> complete`, with
`awaiting_user` and `reviewing` as side states. Drive them with the CLI, never by
editing `state.json`:

```
tool/harness/task start 20260921-flush-corner-radius --tier normal
tool/harness/task state working
tool/harness/verify normal --json-out .claude/tasks/20260921-flush-corner-radius/verify.json
tool/harness/task ready
tool/harness/task complete
```

## The one rule worth repeating

`verify.json`, `review.json` and `adjudication.json` are **generated evidence**. Never
write, edit, or hand-craft one. A task is done when `tool/harness/task complete` accepts
it — an agent asserting "verification passed" is not evidence, and the gate will say so.
