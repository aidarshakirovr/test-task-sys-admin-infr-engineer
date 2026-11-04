# Full restore timing record (template)

Fill after a **real** full restore of ~100 GB. Until then RTO remains a hypothesis.

| Field | Value |
|-------|--------|
| Date | YYYY-MM-DD |
| Operator | |
| Source repo (primary/offsite) | |
| Target host / volume | |
| Data size (`du -sh`) | |
| Link speed / storage type | |
| `restic restore` start | |
| `restic restore` end | |
| Elapsed restore (min) | |
| Verification method | sample SHA-256 / full `restic check` / app smoke |
| Smoke target (staging URL/path) | **not** live production localhost |
| App smoke result | pass / fail |
| Measured RTO (min) | |
| Notes / blockers | |

Hypothesis before measurement: ~100 GB over 1 Gbit ≈ 15–25 min; over 100 Mbit ≈ 2.5–4 h (plus verify).
