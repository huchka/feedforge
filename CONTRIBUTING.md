# Contributing to FeedForge

## Development Workflow

This project follows a structured SDLC. All tracking lives on GitHub.

### For issues that need design (`phase:design`)

1. **Write a design doc** on the [wiki](https://github.com/huchka/feedforge/wiki) using the [Design Doc Template](https://github.com/huchka/feedforge/wiki/Design-Doc-Template)
2. **Self-review** the design (re-read the next day for non-trivial work)
3. **Update the issue** with the wiki link and change label from `phase:design` → `phase:ready`
4. **Move the issue** from "Backlog" → "Ready for Dev" on the [project board](https://github.com/users/huchka/projects/1)

### For issues ready to implement (`phase:ready`)

1. **Move to "In Progress"** on the project board
2. **Create a branch** from `main`: `feat/N-short-description`, `fix/N-short-description`, or `infra/N-short-description`
3. **Implement** — write tests alongside code
4. **Commit** using conventional commits: `feat:`, `fix:`, `infra:`, `docs:`, `chore:`
5. **Push branch and open a PR** using the PR template. Reference the issue with `Closes #N`
6. **Self-review** the PR diff before merging
7. **Merge to main**
8. **Deploy** with `skaffold run` and verify in the target environment
9. **Move to "Done"** on the project board

## Project Board

[FeedForge Project](https://github.com/users/huchka/projects/1)

| Column | Meaning |
|--------|---------|
| Backlog | Not yet planned or needs design |
| Ready for Dev | Design done, ready to implement |
| In Progress | Actively being worked on |
| In Review | PR open, awaiting review |
| Done | Merged and verified |

## Labels

| Label | Purpose |
|-------|---------|
| `type:feature` | New functionality |
| `type:bug` | Something broken |
| `type:chore` | Infra, refactor, CI/CD |
| `type:docs` | Documentation only |
| `priority:high` | Do next |
| `priority:medium` | Planned |
| `priority:low` | Backlog filler |
| `phase:design` | Needs design before dev |
| `phase:ready` | Design done, ready to implement |
| `size:S` | ~1-2 hours |
| `size:M` | ~half day |
| `size:L` | ~1+ days |

## Branch Naming

```
feat/N-short-description
fix/N-short-description
infra/N-short-description
```

Where `N` is the GitHub issue number.

## Design Docs

- Live on the [GitHub Wiki](https://github.com/huchka/feedforge/wiki)
- One page per feature or epic
- Use the [Design Doc Template](https://github.com/huchka/feedforge/wiki/Design-Doc-Template)
- Link from the corresponding GitHub issue
