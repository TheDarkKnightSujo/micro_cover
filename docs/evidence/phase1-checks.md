# Phase 1 local verification — 6 November 2026

Private starting commit: `da20961db901` (uncommitted changes listed in checkpoint). No deployment or wallet signature. Existing Studio project `c47658be-4463-462f-89b8-a0a418962a3d`; implementation and review-fix prompts retained under `docs/prompts/`.

| Exact command / check | Actual result |
|---|---|
| `bun run check` | Exit 0: existing lint runner and `tsc --noEmit` passed on Windows. |
| `wsl bash -lc 'cd /mnt/c/GitHub/MicroCover-Private && ~/.foundry/bin/forge test'` | Exit 0: 115 passed, 0 failed, 0 skipped; 18 suites. Solc 0.8.28. |
| `wsl bash -lc 'cd /mnt/c/GitHub/MicroCover-Private && ~/.foundry/bin/forge build'` | Exit 0, unchanged compilation skipped. Foundry lint warnings include timestamp comparisons and test casts; no claim of a warning-free audit. |
| `bunx vite build` | Exit 0; Vite 6.4.5 production build completed. Third-party annotation and >500 kB bundle warnings remain. |
| `wsl bash -lc 'cd /mnt/c/GitHub/MicroCover-Private && ~/.foundry/bin/forge test --match-contract Phase1GasTest -vv'` | Exit 0: 4/4 targeted gas tests passed. First batch of 20 on 100-member mock cohort: 877,956 gas measured inside test; first batch of 1: 141,498. This is not live Arc gas estimation or proof of throughput. |
| `arc-studio pull --app c47658be-4463-462f-89b8-a0a418962a3d --out C:\GitHub\MicroCover-Private --paths 'contracts/MicroCover.sol' 'contracts/test/**' 'src/microcover/**' 'src/App.tsx' 'src/index.css' --dry-run` | Exit 0; every selected file `=`, zero files would change. |
| `bun "$env:TEMP\microcover-phase1-abi.ts"` | Exit 0: all 51 UI ABI entries matched compiled functions, outputs, event input indexing and error types. Temporary review script parses human-readable ABI text with viem and compares normalized compiled ABI; no app import/environment read. Initial probe stopped early at `address[])`; corrected full-array extraction. A subsequent false mismatch on absent vs false event indexing was fixed in probe normalization; final 51-entry comparison passed. |
| `git diff --check` | Exit 0; CRLF conversion notices only. Includes no automatic staging or commit. |

Tests exercise full three-beneficiary and partial/empty cohorts, a 100-member cohort paid in five bounded calls, duplicate enrollment/payouts, caller authorization, exact accounting, multiple isolated guarantees, donations, invalid parameters, blocked recipients/providers, outgoing fees, reentrancy and events. Six lifecycle invariants each ran 64 runs / 9,600 handler calls with no handler violations; two deterministic reachability tests ensure partial withdrawal and full closure are actually exercised. Original creation/enrollment tests remain. Creation/enrollment/outcome fuzz cases ran 256 cases each; two lifecycle fuzz tests explicitly use 120 cases each.

## Independently reproduced defects and resolution

Against the initial Studio draft, a separate temporary `DraftReview` suite failed both tests: timestamp-zero admission returned NONE; a recipient-tax token underpaid while settlement succeeded. These were real failures, not final results. Studio stored an explicit outcome and added exact recipient receipt checks (including provider withdrawal), plus coherent regression cases in `MicroCover.Review.t.sol` and the token mock. The two independent probes then passed. The complete temporary review copy passed 117 tests (the final 115 plus those two temporary probes); private checkout passed its own 115. Temporary probes and their standalone Foundry config were not imported.

The first private pull dry run exited 1 to protect source copied before a CLI manifest existed. Git inspection showed those source files had no unrelated local edits. After reviewing the temporary snapshot, a targeted `--force` pull imported only the 21 contract/test/UI changes listed in the checkpoint. No `.env`, credentials, generated build output, Studio AGENTS.md or deployment tooling was imported. Final dry run confirmed parity.

## Browser checks actually performed

Production preview via `bunx vite preview --host 127.0.0.1 --port 4173 --strictPort` loaded in the in-app browser. Observed undeployed state, illustrative 15/6/21 accounting, editable fields with no funding controls, cohort 101 rejection and amount above uint128 rejection. Changing compensation to 7 recalculated bond 21 and total 27; restored 5. Connect opened the wallet-selection dialog; no wallet was connected or signed.

A separate development process used an explicit **noncontract test address** (`0x0000000000000000000000000000000000000001`) only in its process environment, not a saved config or claimed deployment: `$env:VITE_MICROCOVER_ADDRESS = '0x0000000000000000000000000000000000000001'; bun run dev --host 127.0.0.1 --port 4174 --strictPort`. Looking up ID 1 showed failed reads plus Retry, and actions were disabled, instead of claiming an unknown guarantee or unpaid beneficiary. No fund action was attempted. Real-wallet account switching, network switching, live success/revert receipts and money flow still require the human testnet checkpoint.

## Official API/config references checked

- [Arc contract addresses](https://docs.arc.io/arc/references/contract-addresses): official USDC address `0x3600000000000000000000000000000000000000`, ERC-20 precision 6; native gas precision 18. Same underlying balance; no wrapper required.
- [Wagmi read contracts](https://wagmi.sh/react/api/hooks/useReadContracts) and [transaction receipt hook](https://wagmi.sh/react/api/hooks/useWaitForTransactionReceipt). Existing pinned wagmi/viem dependency types and local typecheck validate the actual used APIs; no SDK upgrade or new dependency.

Limit: these checks are local code review, mocks and undeployed/error UI checks, not an independent security audit, actual USDC transfer test, CRE integration or sponsor eligibility proof.
