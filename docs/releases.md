# Private-to-public snapshot record

## Published first Phase 1 snapshot — 6 November 2026

- User explicitly authorized Codex to execute the prepared private/public commit/export/push procedure. Publication completed; historical pending statements below describe preparation at the source snapshot.
- Exact private source commit: `c6bd973b0cfca05ae2167984e19621a3899ca47a`.
- Private task commits: `bdc3f01` contract/tests, `c6dbd50` UI, `c6bd973` evidence/documentation/release plan. Pushed and remote main verified before exporting.
- Public root commit: [`53245388788d3194efbfcd031d9b2120c93d6007`](https://github.com/TheDarkKnightSujo/MicroCover/commit/53245388788d3194efbfcd031d9b2120c93d6007), message `feat: import verified Phase 1 MicroCover snapshot`.
- Public origin: `https://github.com/TheDarkKnightSujo/MicroCover.git`, main. Git ls-remote and anonymous GitHub REST ref/commit reads confirmed this exact SHA and public visibility.
- Actual Git author/committer: existing configured identity Abhiraj Kochale. GitHub API maps the commit author to `abhirajkochale`; this is author attribution, not a claim to have inspected the transport credential/pusher account. No author reset, coauthor fabrication, backdating or force push.
- Published content: all 182 manifest source/config/docs/vendor files plus `SOURCE_SNAPSHOT.txt` = 183 files. No prior public files or deletions: checkout/remote were empty. `.env.example` only; no credentials, `.git`, CLI state, dependency installs or generated builds copied.
- Equivalence: every staged file blob and mode among the 182 manifest files matched the exact private source commit. Initial raw-byte comparison failed because Git archive used Windows CRLF conversion (181 text files); follow-up checks proved all differences were line endings only and committed Git content was identical. No product fix or weakened comparison was substituted.
- Checks: staged whitespace checks passed for all three private groups and public snapshot; scoped secret patterns found zero matches; existing 115 contract tests/lint/typecheck/build and real testnet checkpoint remain applicable to identical product blobs. No new product changes or fabricated rerun results.
- Public source retains the genuine author/AI disclosure and private SHA; private commit graph remains retained privately rather than copied as `.git`.
- Final result before this bookkeeping update: private/public checkouts clean and tracking their remote heads. This release-only metadata update is private, so public snapshot remains exactly mapped to source `c6bd973`, not a later bookkeeping SHA.
- Phase 1 PASSED, Phase 2 NOT_STARTED. Studio judge access and application-wide licence decision remain unresolved; publishing does not assert sponsor eligibility.

## Historical preparation record (superseded by publication above)

At preparation time, no public release existed. The public checkout at `C:\GitHub\MicroCover` was inspected after Phase 1: unborn main, only `.git` present, origin `https://github.com/TheDarkKnightSujo/MicroCover.git`. Private foundation/planning commits were pushed earlier; Phase 1 source/evidence were then uncommitted. Phase 1 had passed real testnet checks; Phase 0 judge access remained unresolved. Do not confuse a private push, passed functional checkpoint and public publication.

## First public snapshot — prepared, not published

- Scope: Studio foundation plus completed Phase 1 contract/tests/UI, build configuration, third-party vendored source/licences and truthful project/AI-use/evidence documentation.
- Publisher: current user, per explicit request; replaces earlier proposed Phase 1 assignment to Atharva7406. Actual GitHub account/author recorded when published, not inferred from the remote URL.
- Exact source commit: pending human private commits. Export only from that committed SHA, never a timestamp or uncommitted working tree.
- Manifest: `docs/public-release-files.txt`; commands: `docs/first-public-commit.md`.
- Implementation: current user with documented Arc Studio/Codex assistance. Publication by another teammate in future does not reassign authorship.
- Checks: existing 115 contract tests, lint/typecheck/build and ABI match pass; source parity reconfirmed after final human testnet flows. Documentation-only publication preparation does not require repeating unchanged product tests.
- Public SHA / push: pending. No public checkout modification or Git write performed by the agent.
- Open-source licence selection: D14 still pending; retain vendored forge-std licences and do not infer that Solidity SPDX tags license the whole application.

For each human-approved release, record:

- Phase or intermediate release name:
- Exact private source commit SHA:
- Actual implementation author(s) and AI assistance:
- Assigned publisher / actual publisher:
- Reviewed file list and deletions:
- Checks run against that exact source and results:
- Public snapshot commit SHA / PR:
- Public commit message identifying imported private SHA:
- Deployed public SHA, if any:
- Required event-history disclosure/acceptance evidence:

Publisher rotation is in contributions.md. Do not fill pending actions as completed or use a timestamp in place of a source commit.
