# Decisions and open items

Accepted direction comes from the user's plans; technical choices below stay pending until observed/implemented. Add dated entries with owner, rationale and evidence when changing a choice.

| ID | Decision | Status / required action |
|---|---|---|
| D01 | Generic protocol for providers/beneficiaries/cohorts | Accepted direction |
| D02 | Three-attendee synthetic concert demo; provider admission first | Accepted planning scenario |
| D03 | Arc + CRE + Arkiv bounty focus | Accepted direction; usage not implemented |
| D04 | Arc Studio required build origin and supported source sync | Existing app targeted via authenticated `--app`; remote tooling edits pulled and local EOF fixes uploaded with `--file`, then targeted dry run confirmed parity. Both source directions verified; judge sharing remains unverified. |
| D05 | Reuse Studio-generated language/framework/package manager | Retained React/Vite/TypeScript + Bun 1.3.14 and Foundry 1.7.1; local checks recorded in runbook.md. |
| D06 | One isolated bond per guarantee; full escrow in first demo | Selected 6 November 2026 under user delegation: preserve Studio's 2 USDC escrow / 5 compensation / 15 bond / 21 total example. Prior 20/10 notes reconciled. Generic contract remains configurable. |
| D07 | Three demo accounts, one enrollment/account | Selected demo configuration; foundation enforces one enrollment per account/guarantee and rejects provider enrollment. |
| D08 | Success release and unlock after configured finality conditions | Pending exact timestamps/state transitions |
| D09 | Evidence source groups, freshness and threshold | Pending explicit policy; no production independence claim |
| D10 | UNCERTAIN locks funds; reviewer system deferred | Accepted scope; document prototype recovery authority/limits |
| D11 | Restricted early operator replaced/connected to actual CRE path | Pending supported receiver/report design |
| D12 | Arkiv receipt schema/owner/expiry | Pending current SDK/network verification |
| D13 | Separate private/public clones; manual snapshot publication | User selected file snapshots on 6 November 2026. Preserve genuine private history and record source SHA/authors/publisher/public SHA; public snapshots do not preserve the private commit graph. No publication performed. |
| D14 | Open-source licence and third-party attribution | Human selection pending |
| D15 | Hosting and persistent collector storage | Pending scaffold/host inspection |
| D16 | Single implementation operator and rotating publishers | User handles all implementation roles on one laptop; the four supplied GitHub accounts publish complete phase snapshots per contributions.md. Publication is not implementation attribution. |
| D17 | Continue Phase 1 while Studio judge-sharing is unresolved | User authorized progression after discussion. Phase 0 technical evidence retained; final sponsor access requirement remains open, with no eligibility or Phase 0 pass asserted. |
| D18 | Phase 1 financial/lifecycle slice | Implemented and locally verified in Studio/private source: full escrow/full-capacity bond; provider-only failure; enrollment-order payouts, batch 1–20; remaining bond only after all failed-cohort payouts. Explicit outcome survives closure and timestamp zero. No OPEN withdrawal or success release. 115 tests pass; real Arc transactions pending. |

## Change entry

6 November 2026 publication update: user explicitly takes the first public commit. First snapshot includes the foundation and completed Phase 1 together. Revised future rotation: Atharva7406 Phase 2, Vedanto28 Phase 3, NamanN-Creator Phase 4, current user Phase 5, Atharva7406 Phase 6. Default to whole verified phases; coherent independently reviewed task snapshots allowed if actually needed. This supersedes the earlier publisher assignments, does not grant the agent permission to publish, and does not reassign implementation authorship. Exact file manifest and human commands are in first-public-commit.md / public-release-files.txt. Public repo remains untouched.

Date / owner / ID:
What changed:
Why:
Affected files/interfaces:
Checks and evidence:
Unresolved consequences:
