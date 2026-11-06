# Issue tracker: Forgejo (self-hosted)

Issues, specs and PRs live on the self-hosted Forgejo at `http://10.10.1.4:3000/jryang/MenuBarMijia` (LAN only). The GitHub account is suspended; do not use `gh`. Every operation goes through `python3 scripts/forge.py`, which reads the repo from `git remote get-url origin` and authenticates with `$FORGEJO_TOKEN` or the credential git already keeps for the host. It bypasses `HTTP(S)_PROXY`, because the local proxy cannot reach the LAN; plain `curl` needs `--noproxy '*'` for the same reason, and git needs `git config http.http://10.10.1.4:3000/.proxy ""` in each clone.

## Conventions

- **Create an issue**: `python3 scripts/forge.py issue create --title "..." --body-file - --label ready-for-agent`, body on stdin (heredoc).
- **Read an issue**: `python3 scripts/forge.py issue view <n>` (body, labels, assignees, comments).
- **List issues**: `python3 scripts/forge.py issue list [--label L] [--state open|closed|all]`; add `--json` for the raw API objects.
- **Comment**: `python3 scripts/forge.py issue comment <n> --body-file -`
- **Apply / remove labels**: `python3 scripts/forge.py issue edit <n> --add-label "..." --remove-label "..."`
- **Close**: `python3 scripts/forge.py issue close <n> --comment-file -`
- **Anything else**: `python3 scripts/forge.py api <METHOD> '{repo}/<path>' [--data JSON] [--paginate]` (Forgejo API v1, Gitea-compatible).

## Migrated issue numbers

Open issues were imported from GitHub with new numbers. Their titles start with `[GH#<old>]`, and their bodies still cite **old GitHub numbers** (`#304`, `GH#304`). Translate through the title prefix: `#5` is `[GH#304]`. An old number with no `[GH#…]` issue was closed before the move; its record is in the NAS backup (`/volume1/docker/forgejo/backups/issues-backup-20261106.md`). New issues, branches and PRs use Forgejo numbers, and existing `issue-<n>` branches may carry either number.

Some migrated bodies hold a broken `## Blocked by` section (`#$(cat n9)` placeholders left by the script that filed them). The `> 原 GitHub Issue … 前置：Blocked by GH#…` banner on the first line is the reliable blocker list.

The GitHub PR history was not migrated: `pending-work.sh` shows `no PR` for every branch that predates the move.

## Pull requests

- **Open**: push the branch to `origin`, then `python3 scripts/forge.py pr create --title "..." --body-file -` (head defaults to the current branch, base to `main`).
- **Read**: `python3 scripts/forge.py pr view <n>`; diff with `git diff origin/main...origin/<branch>`.
- **Checks**: `python3 scripts/forge.py pr checks <n>` lists commit statuses on the head. No Actions runner is registered yet, so the list stays empty; `bash scripts/check.sh --skip-snapshots` is the gate.
- **Merge**: `python3 scripts/forge.py pr merge <n> --method squash --delete-branch`.

Issues and PRs share one number space, so a bare `#42` may be either: `issue view` reads both.

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs as feature requests; `/triage` reads this flag.)_

## When a skill says "publish to the issue tracker"

Create a Forgejo issue with `python3 scripts/forge.py issue create`.

## When a skill says "fetch the relevant ticket"

Run `python3 scripts/forge.py issue view <n>`.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a single issue with **child** issues as tickets.

- **Map**: a single issue labelled `wayfinder:map`, holding the Notes / Decisions-so-far / Fog body.
- **Child ticket**: Forgejo has no sub-issues. Add the child to a task list in the map body and put `Part of #<map>` at the top of the child body. Labels: `wayfinder:<type>` (`research`/`prototype`/`grilling`/`task`). Once claimed, the ticket is assigned to the driving dev.
- **Blocking**: write a `Blocked by: #<n>, #<n>` line (or a `## Blocked by` section) in the child body. No script reads Forgejo's own dependency feature, so the body is the record. A ticket is unblocked when every blocker is closed.
- **Frontier query**: `bash scripts/issue-frontier.sh` checks every open `ready-for-agent` issue in one call: open blockers in the body (old numbers translated for migrated issues), assignees, `claimed:*` labels, an open PR that mentions it, or an `issue-<n>` branch.
- **Claim**: `python3 scripts/forge.py issue edit <n> --assign-me`, the session's first write.
- **Resolve**: comment with the answer, close the issue, then append a context pointer (gist + link) to the map's Decisions-so-far.
