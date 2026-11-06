# First private commits — human commands

Originally prepared for unborn private main. The human completed section 1 as commit `91b692fd0a6192fc0ab031e6befa4389ae336faf`; section 2 is next. These commands have not been run by the agent. They save Phase 0 work; they do not certify its checkpoint as PASSED. Inspect the working tree again before staging, as it may have changed since preparation.

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
