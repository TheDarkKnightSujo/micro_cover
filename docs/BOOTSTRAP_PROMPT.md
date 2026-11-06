# First prompt for Codex in the private folder

Copy the following into Codex after opening the actual private checkout:

```text
Read root AGENTS.md, SETUP_CHECKLIST.md, both MicroCover plan/runbook files and
docs/progress.md. This task is prerequisite reconciliation only, not product
implementation. Inspect existing files, nested AGENTS.md, Git status/history,
package manifests, lockfiles and available Studio output. Preserve all unrelated
and uncommitted work.

Check whether these docs match the real repository. Replace template assumptions
with observed facts; retain pending items where evidence is missing. Record exact
working-directory/run/test/build commands if discoverable. Record file-level AI
assistance accurately. Ensure progress remains NOT_STARTED for unverified phases.

If a real scaffold exists, prepare/reconcile .gitignore and .env.example with its
actual config names, placeholders only; inspect browser-exposed env variables.
If no scaffold exists, do not create one: list the Arc Studio initialization step
and required information. Do not invent token addresses, deployment results,
credentials, scripts or sponsor acceptance. Do not start Phase 1.

Return the observed repository state, changed documentation, missing prerequisites,
manual actions for us, checks run, and a proposed small documentation commit.
Do not commit, push, merge, deploy or touch the separate public folder.
```

Once reconciliation is complete, use the full runbook's Phase 0 prompt. The prerequisites are not a substitute for Studio, access or connectivity checks.
