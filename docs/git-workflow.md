# Two-folder Git workflow

Authoritative detailed commands are in section 2 of MicroCover_Implementation_Plan.md. Inspect current history before running any branch/bootstrap command. This document is a checklist, not permission to rewrite repository history.

## Folders

- MicroCover-Private/: canonical working checkout with its own GitHub origin.
- MicroCover/: separate submission checkout with its own GitHub origin.
- Never copy either .git directory or run git init inside an existing checkout.

## Per task

1. Start from the agreed current base and a clean/preserved working tree.
2. Work in a bounded task branch as the actual author.
3. Inspect git diff; stage related files/hunks, not unrelated changes/secrets.
4. Run applicable checks and commit a coherent functional change.
5. Review and integrate private work before promoting the validated phase.
6. The user selected manual snapshots on 6 November 2026: the assigned publisher updates their private clone to an exact verified source SHA, then copies the reviewed release files into their separate public clone. Follow the snapshot requirements below and record the mapping in docs/releases.md.
7. Git history transfer remains the full plan's preferred alternative when the team chooses it; inspect ancestry before using that procedure. A manually copied snapshot does not preserve private Git history, and the two histories must not be blindly fast-forwarded or reset into each other.

## Manual snapshots, if selected

Copying files transfers content, not original history. Track source SHA, actual authors, publisher, copied/deleted files and validation; disclose the process and retain the genuine history for judges. Adding files one at a time does not reconstruct past work. Do not copy secrets, dependencies, builds or .git. Account for deleted files so stale code does not survive.

The sole implementation operator is the current user; publication follows the rotation in docs/contributions.md. Use a complete working phase as the normal release unit. An intermediate release must also name a reviewed, reproducible private commit; a timestamp alone is not a source identifier. The publisher's snapshot commit should say it imports that source SHA and identify actual implementation/AI assistance accurately. Do not reauthor the user's source work as the publisher's implementation.

Prepare a release file list before copying. Exclude `.git`, `.env` and secret variants, `.npmrc`, wallet/CLI credential files, `.arc-studio`, `node_modules`, `dist`, Foundry output/cache and private evidence. Include placeholder examples and applicable third-party licences. Avoid an indiscriminate whole-directory copy. Review additions, modifications and deletions in the public clone before the human publishes. Record event-history acceptance as unverified until the team confirms it with organizers; retain the private source history and offer it as required.

## Before public publication

- [ ] Repo ancestry inspected; no blind force-push/reset.
- [ ] Reachable history checked for credentials/personal data.
- [ ] Actual authorship retained; publisher not relabeled as author.
- [ ] Validated source commit and test results recorded.
- [ ] Public deployment corresponds to public source commit.

Use docs/progress.md to record private/public SHA or PR. Team members contribute real implementation, validation or documentation; equal commit counts are not an objective.
