# Sponsor evidence tracker

Planning requirements are based on the full implementation plan's official references. Recheck current pages and event announcements during Phase 0. All integration checkboxes below start unchecked; no prize eligibility is asserted by this file.

## Arc — advanced stablecoin contracts

Official: https://ethglobal.com/events/mumbai/prizes/arc

- [ ] Studio project created as build starting point; shareable URL recorded.
- [x] Supported external-edit/source-sync workflow confirmed.
- [ ] Required contract testing/deployment and app connection demonstrated in Studio.
- [ ] Real official testnet USDC bond, escrow and settlement transactions linked.
- [ ] Working frontend/backend, architecture and source links prepared.
- [ ] Studio appears in actual demo; selected bounty stated explicitly.

Evidence URL/commit/owner: pending.

Phase 0 local check (6 November 2026): official Arc Testnet RPC returned chain ID 5042002 via `eth_chainId`. This is read-only connectivity; Studio sharing/deployment, wallet, token balance and transactions remain unverified. See `docs/runbook.md`.

Phase 0 Studio update: human supplied `https://studio.arc.io/app/c47658be-4463-462f-89b8-a0a418962a3d`; authenticated CLI matched that app, and Studio-to-local targeted pull was verified with a zero-difference dry run after tooling edits. Judge sharing and Studio deployment/app connection remain unchecked. The foundation has no settlement or release path, so do not deposit test USDC into it.

Human Preview screenshot shows the undeployed illustrative app. Studio's Share menu offers hosting deployment via Netlify, Hugging Face or Vercel; it did not show a public read-only project link. No hosting account was connected or app published. The Studio project URL must not be described as judge-accessible until sharing is verified.

Independent account test: teammate's screenshots at the exact project URL show `New Project` and an empty Code file list. Project access not demonstrated. Arc staff clarification is required; unsent question is prepared in `docs/arc-sharing-question.md`.

Phase 1: required source was extended through the same Studio project and pulled selectively; contract/app/tests have zero dry-run differences. Private local checks pass (115 contract tests, lint/typecheck, production build). Human testnet deployment, bond, three enrollments and payouts remain pending, so deployment/transaction checkboxes stay unchecked. Judge-sharing remains deferred under D17, not solved by source parity or frontend hosting.

Later deployment verification: human initiated Studio deployment and agent confirmed the exact reviewed runtime at `0xff679b65c1d09e8d49fb18bb656f4509b33af9a0` on Arc Testnet. Evidence: docs/evidence/phase1-deployment.json. User preview shows Create and fund, Actions and address; guarantee count still zero. Real guarantee funding/three enrollments/payouts and sponsor judge access remain pending; combined checklist requirements are not marked complete prematurely.

## Chainlink — CRE workflow

Official: https://ethglobal.com/events/mumbai/prizes/chainlink

- [ ] Meaningful CRE workflow joins Arc and external evidence API.
- [ ] Successful reproducible CLI simulation or live CRE deployment.
- [ ] Consumer/report authorization and actual money-flow connection documented.
- [ ] Simulation, operator relay and deployed network claims distinguished.
- [ ] Commands, source, sanitized output and relevant transactions linked.

Evidence URL/commit/owner: pending. CCIP/Functions are not substitute integrations for this selected workflow.

Phase 0 feasibility: authenticated CLI lists Arc Testnet, and isolated Hello World CLI simulation succeeded. This is not yet the meaningful MicroCover workflow required by this track. See `docs/runbook.md`.

## Arkiv — build from scratch

Official: https://ethglobal.com/events/mumbai/prizes/arkiv

- [ ] Current-network entity write and actual visible app query demonstrated.
- [ ] Writer wallet, real entity key and rerunnable query documented.
- [ ] Schema/expiry/ownership, friction, reach, why-Arkiv and usage files completed.
- [ ] Open-source licence and AI-use disclosure present.
- [ ] Public receipts only; private payloads excluded; retention covers lifecycle.

Evidence URL/commit/owner: pending. No Swarm bonus is selected in the core plan.

Phase 0 feasibility: human funded Rabdi wallet and saved an access key; Hub synthetic entity write and public-RPC read/query succeeded. Creation receipt also verified in the final audit. This is not yet the Phase 5 MicroCover feature. See `docs/runbook.md`.

Subsequent Phase 0 smoke evidence: human created the labelled synthetic Hub sample, key `0x948b565d57bc65cd125a5e8457dfc34ab1b020bb8fa88de20a2c5ffa37c0fccf`. Agent public-RPC get/query returned the expected values and exactly one matching entity. Summary: `docs/evidence/phase0-arkiv-smoke.json`. Owner mutation and expiry apply. This Hub test does not satisfy the Phase 5 visible MicroCover history integration checklist.

## Event submission

Official: https://ethglobal.com/events/mumbai/info/details

- [ ] Dashboard/organizer deadline verified and recorded with IST time.
- [ ] Draft project created; exact required fields reviewed by human.
- [ ] Finalist + partner judging option and actual partner selections verified.
- [ ] Real history, reused material, AI assistance and contributions disclosed.
- [ ] Demo/video conforms to current event rules; all URLs open to judges.
- [ ] Submitted confirmation captured before deadline.

Do not rely on a stale copied deadline. Record the dashboard value and announcements here when manually checked.

Phase 1 reference-flow follow-up: real bond, all three enrollments, provider admission and three exact 7 USDC payouts are verified. Final contract token balance and guarantee liabilities zero, CLOSED / FAILURE. Linked public evidence in phase1-settlement.json and phase1-post-settlement.json. Deployment/funding/payout evidence exists; combined testing milestone still retains the runbook's separate-active-guarantee withdrawal check. No final phase/sponsor eligibility pass or public release asserted.

Phase 1 final: all required contract/app checks and real human testnet flows completed. Three 7 USDC payouts, separate-active-guarantee withdrawal protection, partial 0.2 payout and 0.1 unused-bond return verified. Both guarantees closed with zero token balance/obligations at block 0x43b49fa. Source parity remains exact. Phase 1 PASSED; sponsor eligibility/judge sharing, future phases, public publication and final submission remain separate. Evidence: docs/evidence/phase1-final.json.
