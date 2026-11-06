# Phase 1 checkpoint — PASSED

Bounded scope authorized after the user asked to proceed following the explicit Phase 1 explanation. Studio judge-sharing is deferred as an unresolved submission requirement; it is not claimed solved.

## Final checkpoint — 6 November 2026

- [x] Human deployed the reviewed contract through Studio; runtime bytecode matches the checked local build.
- [x] Human created guarantee 1, posted 15 USDC bond, enrolled three distinct beneficiaries at 2 USDC each, admitted synthetic failure and paid exactly 7 USDC to each. All successful receipts and token transfers independently verified.
- [x] Unauthorized admission, excess enrollment, repeat payout and protected withdrawals rejected in decoded read-only calls to actual deployed code/state. These are simulations, not fabricated failed signed transactions.
- [x] Human created different active guarantee 2 (0.2 bond, one enrolled beneficiary, cap 2). Provider OPEN withdrawal rejected NotFailed and FAILED/unpaid withdrawal rejected LiabilitiesUnpaid. Human then paid 0.2 USDC to the beneficiary and withdrew unused 0.1 to provider.
- [x] Final withdrawal tx `0x321b0311ddb27c2bb4adaeae31a9c1052e3807f368211cdecde6566f20826fdf` succeeded with the exact 0.1 USDC return. Repeat withdrawal rejected NothingToWithdraw.
- [x] Both guarantees CLOSED / FAILURE, paid counts complete, all held amounts and obligations zero, actual contract USDC balance zero at block 0x43b49fa. Evidence: `evidence/phase1-guarantee2-closed.json` and `evidence/phase1-final.json`.
- [x] Existing 115-test local suite, lint/typecheck and production build passed; 51 UI ABI entries matched compiled contract. Final Studio source dry run showed zero changes. Product source did not change during manual testing, so prior check results remain applicable.
- [x] Human-operated UI/wallet flow and AI assistance recorded; no invented third-party review, source independence or audit.

Phase 1 is PASSED. No more wallet transactions are needed for this checkpoint. Phase 0 judge-sharing remains unresolved; sponsor eligibility is not asserted. Phase 2 is NOT_STARTED. The three proposed human commit groups below remain unexecuted; no agent commit/push/deployment/signature. Historical pending observations below describe intermediate states and are superseded by this final result. Studio preview styling in human screenshots remains cramped; this checkpoint establishes the tested financial flow, not polished UI presentation.

## Intended behavior

- Preserve existing configurable create/fund and enrollment APIs; full escrow for this demo.
- Reserve 5 USDC compensation per enrolled beneficiary from this guarantee's bond; demo cap 3, contract cap 100.
- Provider-only failure admission closes enrollment; payout recipients and amounts derive from enrolled state.
- Permissionless bounded continuation of payouts, at most 20 per call; no duplicate settlement or cross-guarantee spending.
- Unused bond withdrawal by provider only after failure and all enrolled beneficiaries paid. No OPEN withdrawal or success release.
- Minimal connected UI, actual states/transaction outcomes, and meaningful unit/fuzz/invariant tests.

## Work record

Deployment follow-up: human initiated the prepared Studio request. Address `0xff679b65c1d09e8d49fb18bb656f4509b33af9a0`, transaction `0x6e425c0bbb59428dd4f881b44f872193df16648dc953a87b7825e18f44d56625`. Independent RPC verification found receipt success, exact creation payload in the transaction, no code in the preceding block and the exact reviewed runtime at deployment block. All 10,404 runtime bytes match the compiled local build after filling its 12 USDC immutable references; no metadata exclusion was needed. `usdc`, cohort/batch limits and initial next ID read correctly. Evidence: `docs/evidence/phase1-deployment.json`. This was a nested deployment (`receipt.contractAddress` is null), not a top-level creation transaction; the outer sender is not asserted to be a privileged contract owner.

Studio source dry runs still show zero differences for contract/tests/UI and core frontend configuration. The hosted agent's statement that the app is read-only contradicts the actual reviewed files and human screenshots showing Create and fund / Actions. Do not reimplement those actions or redeploy because of that statement. Human reports environment address set and preview restarted; network card screenshot displays the expected address and 0 guarantees. Guarantee funding/enrollment/payout verification remains pending.

- Starting private commit: `da20961` (plus earlier local commits not yet pushed).
- Existing Studio app: `c47658be-4463-462f-89b8-a0a418962a3d`.
- Implementation prompt: `docs/prompts/phase1-provider-failure.txt`.
- Independent tests against the first draft reproduced timestamp-zero outcome inconsistency and recipient-tax underpayment acceptance. Neither is treated as fixed until regression tests pass on the final code. Review request: `docs/prompts/phase1-review-fixes.txt`.
- Imported 21 reviewed source files: `contracts/MicroCover.sol`; lifecycle invariant and token mock updates; new `MicroCover.Phase1.t.sol` and `MicroCover.Review.t.sol`; `src/App.tsx`; `src/microcover/contract.ts`, `errors.ts`, `useGuarantee.ts`, `useTxFlow.ts`, `useUsdcApproval.ts`; updated ExampleCard/LookupCard and new ActionsCard, ApprovalStep, ChainGate, CreateCard, EnrollSection, Field, TxStatus, Workspace components. Existing tooling, dependency versions and lockfile retained.
- All 115 private-checkout contract tests passed; both independent draft regressions now pass. Lint/typecheck/build and 51-entry ABI comparison passed. Contract/app/test source parity with Studio is confirmed. Exact commands, limitations and observed browser checks: `docs/evidence/phase1-checks.md`.
- Documentation changed: AGENTS.md, README.md, progress/interfaces/decisions/runbook/AI-use/sponsor checklist, this checkpoint, Phase 0 deferral notes and Phase 1 prompts/evidence. No private/public Git operation or deployment performed. Local commits are prepared below under the latest user-supplied instructions.

## Proposed human commit groups

Run from `C:\GitHub\MicroCover-Private` after reviewing `git diff` and `git status --short`. Preserve Abhiraj Kochale's existing author identity; AI implementation/review is disclosed in `docs/ai-usage.md`. These commands have **not** been run:

```powershell
git add -- contracts/MicroCover.sol contracts/test/MicroCover.Invariant.t.sol contracts/test/MockUSDC.sol contracts/test/MicroCover.Phase1.t.sol contracts/test/MicroCover.Review.t.sol
git diff --cached --check
git commit -m "feat: settle provider-admitted failure with protected cohort accounting"

git add -- src/App.tsx src/microcover
git diff --cached --check
git commit -m "feat: connect Phase 1 funding enrollment and payout actions"

git add -- AGENTS.md README.md MicroCover_Phase_By_Phase_Runbook.md docs
git diff --cached --check
git commit -m "docs: record Phase 1 checks and manual testnet checkpoint"

git log -3 --oneline
git status --short --branch
```

Do not run a later commit if its preceding cached check fails. Push/publication remains separate; the public checkout has not been modified. Proposed groups are local review units, not fabricated teammate participation.

## Human checkpoint still required after local completion

Real Arc Testnet bond, enrollment and payout transactions must be recorded by the human before PASSED. The agent does not deploy or sign transactions. Current local/mock tests are not a substitute for that testnet evidence. Use only synthetic failure guarantees while this version has no success-release path. No Phase 2 implementation is authorized by Phase 1.

## Exact manual sequence after local verification

1. Open the existing [Studio project](https://studio.arc.io/app/c47658be-4463-462f-89b8-a0a418962a3d). Use the latest Phase 1 source in this same project. Do not deploy the old Phase 0 foundation.
2. In Studio chat, submit this deployment request yourself only after reviewing the local results below:

   ```text
   Deploy the current reviewed Phase 1 contracts/MicroCover.sol to Arc Testnet (chain 5042002), with constructor USDC address 0x3600000000000000000000000000000000000000. Do not deploy to another network. Report the contract address and successful deployment transaction. Set the public VITE_MICROCOVER_ADDRESS to that address in this same Studio project and restart its preview. Do not create a guarantee or transfer/approve funds for me. Preserve the Phase 1 source and do not add features.
   ```

   The generated local `deploy:self` script requires Circle developer-controlled wallet credentials and Studio paths; it is not a verified MetaMask deployment command. Do not enter a wallet key into chat. Use Studio's supported Contracts workflow and human wallet confirmations as applicable.
3. Save the actual deployed address, deployment transaction and source version. The address is public configuration; keys are not. Check the network card and explorer bytecode before funding. Local preview, if needed, uses `VITE_MICROCOVER_ADDRESS=<actual deployed address>` in ignored `.env.local`, then `bun run dev --host 127.0.0.1` from `C:\GitHub\MicroCover-Private`; a Vite restart is required.
4. Have one provider and **three distinct beneficiary accounts** on Arc Testnet. Fund provider with more than 15 testnet USDC and each beneficiary with more than 2, leaving extra for gas. Never send funds between Arc and Rabdi for this test. These accounts can all be operated on this laptop. A fourth beneficiary account is needed for the excess-capacity rejection check, but it need not deposit anything successfully.
5. Provider: connect, create with compensation 5, escrow 2, cohort size 3, a sufficiently long join window. Approve exactly 15 USDC, then create. Record the guarantee ID and both transaction hashes; verify bond 15, escrow 0, reserved 0.
6. Each beneficiary: switch account, approve exactly 2 USDC, enroll in that guarantee. Record approvals/enrollments. After all three: bond 15, reserved compensation 15 (a subset of bond), escrow 6, remaining beneficiary obligations 21. No non-guaranteed share goes to the provider in this full-escrow demo.
7. Confirm excess enrollment and attendee failure admission are blocked/revert. A UI-disabled action is not an onchain rejection transaction; record which evidence was actually obtained. Do not bypass wallet warnings just to manufacture a failed transaction. Contract tests cover these reverts independently.
8. Provider: inspect selected ID and terms, click Admit failure, review the irreversible confirmation, then submit. Admission closes enrollment and moves no money. Any connected account can then Continue payouts. The call accepts only ID and bounded count, never caller-selected recipients or amounts.
9. Verify three beneficiary ERC-20 Transfer logs of 7 USDC (2 escrow + 5 compensation), total 21; paid count 3/3, bond/escrow/reserved/remaining owed all 0, status CLOSED, outcome FAILURE. Sender wallet deltas also include native USDC gas, so do not equate them to token payout amounts.
10. Confirm repeat payout is blocked/reverts. For active-liability withdrawal protection, create a separate small synthetic guarantee only if you can complete its failure/payout flow; verify OPEN withdrawal is blocked, and after admission withdrawal stays blocked until its beneficiaries are paid. A partial cohort may withdraw only its unused bond after all enrolled beneficiaries receive their full payouts.
11. Supply actual hashes/IDs and observed outcomes for the checkpoint. No testnet guarantee, settlement or contract address has been inferred from local tests. Phase 1 remains IN_PROGRESS until these manual checks are recorded. Stop before Phase 2.

## Known prototype limits

- Provider admission is the only verdict source. `settlementTime` is stored metadata, not a time-based release or deadline for claiming funds. A provider who never admits failure leaves OPEN funds locked.
- Cohorts cap at 100 and one call pays at most 20; multiple calls may be required. Local mock gas measurements do not establish live Arc gas capacity.
- A token-blocked beneficiary makes its batch revert and blocks the sequential payout cursor; there is no skip, alternate recipient, admin recovery or success-release path.
- Official USDC is the supported asset. Exact token-balance checks do not establish safety for arbitrary malicious or rebasing tokens. Direct donations do not create enrollment capacity and cannot be recovered.
- This contract is not upgradeable. Later-phase changes require a separately reviewed deployment; do not assume an address can be upgraded.
- Judge access to the Studio project remains unresolved. Hosting the frontend does not prove project access; Phase 0 is still not PASSED.

## Real testnet guarantee progress

- Guarantee ID 1 creation and 15 USDC bond verified in successful transaction `0xfd79f245a8dec282a1430fa3df7e89e6b200e182d13b5610cdcfe069bbf9a276`; official token Transfer matches provider and contract. Frozen terms: compensation 5, escrow 2, max 3; join deadline 6 November 2026 16:38:56 IST. OPEN, 0 enrolled as observed at block 0x43b3ddd. Evidence: evidence/phase1-guarantee1.json.
- Three beneficiary enrollments, capacity/authorization checks and three payouts are still pending. Do not repeat creation because the create form now reports too little remaining wallet balance for a second 15 USDC bond. Do not admit failure before the intended cohort enrolls.

- Full cohort now verified at block 0x43b42fa: three enrollment receipts, 2 USDC each, bond 15 / reserved subset 15 / escrow 6 / owed 21. See evidence/phase1-full-cohort.json. Unauthorized admission, excess enrollment and OPEN withdrawal rejected in read-only eth_call probes (not failed signed transactions); see evidence/phase1-pre-admission.json. Admission and payouts still pending.

- Provider admission is verified: tx `0x03691383aa6b753e9d74e3a13f08c1978324860764fad1aa4ca7bbeecc0f5f0c`, status 0x1, FAILED / FAILURE, no token transfers, paid 0/3 and 21 USDC still owed. Evidence: evidence/phase1-admission.json. Next human action is one bounded payout call for the three enrolled beneficiaries.

## Reference settlement result and remaining gate

Human settlement tx `0xf0d954ec68f143fb3e02e3c29039c1677d86c71d96aa09599bed77da878d5a81` succeeded. Agent verified three official token Transfers of 7 USDC each, the exact enrolled recipient set, 15 compensation + 6 escrow returned, CLOSED / FAILURE, paid 3/3, all obligations/held funds zero, contract token balance zero. Repeat payout, closed withdrawal and repeat admission rejected in read-only calls. Historical FAILED withdrawal rejected LiabilitiesUnpaid on guarantee 1; do not mislabel this as a different active guarantee test. Evidence: evidence/phase1-settlement.json / phase1-post-settlement.json.

Checkpoint remains IN_PROGRESS: the phase runbook explicitly requests a withdrawal attempt against a different still-active guarantee. That human testnet item is not yet performed; local cross-guarantee and partial-unused-bond tests already pass. No need to submit deliberately reverting paid transactions: read-only eth_call against the new actual guarantee can verify the restriction once it exists and has an enrollment. A proposed tiny follow-up uses compensation 0.1 / escrow 0.1 / cap 2, bond 0.2, one beneficiary; after testing blocked withdrawal, complete failure/payout and withdraw unused 0.1 so no test funds are left locked. Do not begin Phase 2 or assert PASSED before this gate is resolved.

- Different active guarantee 2 now has one confirmed enrolled beneficiary (receipt/0.1 USDC Transfer), bond 0.2 / reserve subset 0.1 / escrow 0.1 / owed 0.2. Provider OPEN withdrawal eth_call reverted NotFailed. Evidence: phase1-guarantee2-enrolled.json and phase1-guarantee2-open-withdrawal.json. Finish provider admission, unpaid-failure withdrawal check, 0.2 beneficiary payout and 0.1 unused-bond withdrawal; do not leave test funds locked or mark Phase 1 passed before completion.

- Guarantee 2 admission tx `0xb177f03285d8e04b0f7171b841622cf1277b32f6a73323497792ced791f92798` succeeded without token transfers. Provider withdrawal while its beneficiary remains unpaid reverted LiabilitiesUnpaid in eth_call at block 0x43b48bd. Both OPEN and FAILED withdrawal protection now verified on separate guarantee 2; evidence in phase1-guarantee2-admission.json / phase1-guarantee2-failed-withdrawal.json. Finish actual 0.2 payout and 0.1 unused-bond return before final Phase 1 pass.
