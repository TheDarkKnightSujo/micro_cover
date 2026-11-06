# MicroCover prerequisite setup — start here

This package creates instructions and tracking documents, not product code. No deployment, sponsor integration or GitHub commit has been performed by creating it.

## Where files go

Place AGENTS.md, this checklist and both full plan files in the root of your local MicroCover-Private checkout. Place the docs directory in that same root. The public checkout remains separate. Do not create another nested MicroCover project inside the private folder.

If files already exist, compare and merge them; do not blindly overwrite existing instructions, decisions or verified progress. In particular retain your current full plans if they contain later edits. Never copy or replace either checkout's .git directory.

## Manual checklist

- [ ] Confirm terminal/editor is opened in the private checkout.
- [ ] Inspect git status and preserve uncommitted work.
- [ ] Compare existing AGENTS.md/docs with this package before copying.
- [ ] Put root-level AGENTS.md where Codex/Antigravity can read it.
- [ ] Copy/merge docs and keep existing full plans current.
- [ ] Assign five real owners in docs/contributions.md.
- [ ] Ask Codex to reconcile docs using docs/BOOTSTRAP_PROMPT.md.
- [ ] Resolve Studio setup/source-sync requirement before generating a separate scaffold.
- [ ] Review documentation diff; commit actual prerequisite work as a coherent change.

## Files intentionally deferred

No package.json, app scaffold, Solidity project, .env.example, .gitignore, deployment addresses or network config is fabricated here. The local agent must inspect the actual stack and prepare the relevant configuration in Phase 0. Do not replace an existing .gitignore. Ensure secrets are ignored before the first implementation commit.

No licence is selected on behalf of the team. Choose a suitable open-source licence for submission and preserve third-party notices.

## Suggested prerequisite commit

After review, stage only the actual documentation paths. If both full plans are new, include them. Existing modified files need review first.

    git status
    git diff --stat
    git add AGENTS.md SETUP_CHECKLIST.md docs/
    git diff --cached
    git commit -m "docs: add MicroCover agent instructions and phase prerequisites"

Do not push automatically. Follow docs/git-workflow.md and the full plan when publishing a validated phase.
