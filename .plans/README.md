# Plans

Versioned implementation plans for non-trivial feedforge changes.

## When to use

Drop into Plan Mode (Shift+Tab) and save the resulting plan to this directory before executing, when the task is one of:

- Any `*.tf` change beyond a one-line tweak (new resource, refactor, provider bump)
- Any new or significantly-modified manifest under `k8s/`
- Multi-file refactors crossing module boundaries
- Any `size:L` issue, or any `size:M` issue with architectural tradeoffs
- Anything that mutates Cloud SQL, GCS state buckets, KMS keys, or Workload Identity bindings

Skip Plan Mode for: typo fixes, doc-only changes, single-line bug fixes, dependency bumps with no API change.

## Naming

```
.plans/YYYYMMDD-<kebab-slug>.md
```

Examples:
- `.plans/20260428-redis-memory-tuning.md`
- `.plans/20260501-gateway-api-migration.md`

## Plan structure

Each file should contain:

1. **Goal** — one sentence: what success looks like
2. **Context** — relevant constraints, related issues, current state
3. **Approach** — the chosen path with rejected alternatives noted
4. **Steps** — ordered, verifiable; each step has a check ("plan shows no diff", "kubeconform passes", "pod ready")
5. **Risks / rollback** — what could go wrong, how to undo

## Lifecycle

- Plans are committed alongside the code change they drove (same PR)
- Plans are not edited after merge — they capture decisions in time
- Stale plans (work abandoned) stay in the directory as historical record; do not delete

## Why

Plans become a versioned contract between sessions. A future session (yours or Claude's) can reload the plan and continue without re-deriving context. Without saved plans, Plan Mode output evaporates when the session ends.
