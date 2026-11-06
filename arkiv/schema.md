# Public history v1 — live publication pending

Implemented6November2026 using SDK1.0.1 and existing viem2.57.5. Rabdi7794095, tGLM gas, RPC `https://rpc.rabdi.db-chain.testnet.arkiv.network`; chain ID independently read. [Official network](https://docs.arkiv.network/networks/rabdi/).

Schema `microcover.public-history.v1`, defined in src/microcover/arkivRecords.ts:

| Column | Type | Indexed | Meaning |
|---|---|---|---|
| recordId | str | yes | Canonical hash of schema/domain/type/bodyHash |
| consumer | str | yes | Lowercase Arc contract |
| guaranteeId | str | yes | Decimal ID, scoped by consumer |
| cohortId | str | yes | Frozen cohort hash |
| recordType | str | yes | EVIDENCE_PAGE, SNAPSHOT, ARC_EVENT |
| bodyHash | str | no | Keccak256 of canonical public JSON |
| bodyEncoding | str | no | gzip-json-v1 |
| body | bytes | no | Gzip transport of UTF-8 canonical public JSON, decoded bound60000 bytes |

SDK adds indexed arkiv.schema. Receipt pages contain at most30 public receipts: source/group, source/receipt times, payload hash, previous hash and receipt hash. Private envelopes/raw payloads are excluded. Snapshot links ordered page IDs and frozen public activation/policy; UI recomputes the prefix, commitment and outcome, then separately compares with current Arc anchor. Arc event records contain actual transaction/log/block references, timestamps and decoded public arguments. They never replace Arc balance/outcome reads.

Proposed writer: Account1 `0x1d39fc0e5293ab949d63217ffb375357adf3933f`, human approval/signature pending. Retention seven days from publication, longer than the completed120s review/uncertainty windows. Readonly attributes and permissionless extension are requested at creation. **Readonly still permits owner deletion/transfer.** Expired/deleted entities disappear; transferred entities leave our owner-filtered query. Retain the external outbox and extend expiry if evidence is still needed. No renewal automation or perpetual availability is claimed; longer-lived future guarantees need retention review.

Rerunnable query:

```text
arkiv.schema = str('microcover.public-history.v1') AND $creator = addr(0x1d39fc0e5293ab949d63217ffb375357adf3933f) AND $owner = addr(0x1d39fc0e5293ab949d63217ffb375357adf3933f) AND consumer = str('0xdcd11bb347f063b5a876c8816f5a02b8ea0f11e0') AND guaranteeId = str('2') ORDER BY $key ASC
```

Add `AND recordType = str('ARC_EVENT')` before ORDER BY for type filtering. JSON-RPC arkiv_query selects key/creator/owner/attributes/creationFlags/expiresAt, limit0x64. Keyset pages add `$key > key(lastKey)`; UI caps20 pages and rejects incomplete integrity claims. Filtering creator AND owner prevents another account copying the tag from becoming trusted history. [RPC methods](https://docs.arkiv.network/json-rpc/querying-data/), [filters](https://docs.arkiv.network/querying/filter/), [expiry](https://docs.arkiv.network/writing/expiration/).

New entity key, writer transaction and fresh-browser read: **pending**. Phase0 Hub sample is not proof of this schema. Actual current anonymous query returnedHTTP429; saved access key must be configured server-side.

The HTTP413 estimation fix compresses bytes only. bodyHash/recordId are still calculated over original canonical JSON. Decoder validates gzip with a60000-byte output bound and rejects unsupported bodyEncoding. Arkiv stores opaque bytes; this adds no new financial or evidence semantics.
