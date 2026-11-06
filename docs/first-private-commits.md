# First private commits — human commands

Historical instructions: human completed section 1 as `91b692fd0a6192fc0ab031e6befa4389ae336faf` and section 2 as `3d01d41c209132d32b9b542fe087db5fb1c156c1`, then pushed private main. Do not rerun these initial-commit steps. User now authorizes agents to make and verify subsequent local task commits; see AGENTS.md. These commits do not certify Phase 0 as PASSED.

## 1. Review and save the Studio foundation

Run in PowerShell:

```powershell
cd C:\GitHub\MicroCover-Private
git status --short --branch
git remote -v
git var GIT_AUTHOR_IDENT
git add -- .gitignore .env.example .bun-version .foundry-version .oxlintrc.json bun.lock foundry.toml index.html package.json postcss.config.js remappings.txt tailwind.config.js tsconfig.json vite.config.ts README.md AGENTS.md src scripts contracts lib
git diff --cached --stat
git diff --cached --check
git diff --cached
```

Verify the author is you, review the staged files and ensure there are no secrets, `.env`, dependencies or generated build output. Then run:

```powershell
git commit -m "chore: import tested Arc Studio foundation"
```

## 2. Review and save planning/evidence notes

```powershell
git add -- MicroCover_Implementation_Plan.md MicroCover_Phase_By_Phase_Runbook.md SETUP_CHECKLIST.md docs arkiv
git diff --cached --stat
git diff --cached --check
git diff --cached
```

Review the remaining documentation, AI-use disclosure and evidence, then run:

```powershell
git commit -m "docs: record Phase 0 setup evidence and publication workflow"
git status --short --branch
git log -2 --oneline
```

Share the two commit hashes for the checkpoint record. Private push/public snapshot commands will be prepared from the actual committed state. No phase should be published as passed until its human checkpoint review is recorded. Later verified snapshots use the publisher rotation in contributions.md and exact source-SHA mapping in releases.md.
