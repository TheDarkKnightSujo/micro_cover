# Why Arkiv — hypothesis to demonstrate

The proposed benefit is publicly queryable evidence receipts and claim/history metadata without requiring access permission to MicroCover's private database. Money remains on Arc; raw/private payloads remain off public storage.

Phase5 now implements a public audit read model, filtered by guarantee/cohort/type. Readers can rerun a public query without private SQLite permission. The UI reconstructs a receipt prefix and compares its root with Arc. That proves integrity against a commitment, not source truth, source independence or complete collection; both feeds remain team-controlled.

Remaining dependencies: trusted creator, RPC/index availability, retention and hosting. Readonly flags still permit deletion/transfer and expiry. Durable outbox is recovery data, not proof of publication. Live benefit is not yet demonstrated: current queries are blocked by anonymous quota and missing access-key configuration. No completed sponsor integration or public deployment is claimed.
