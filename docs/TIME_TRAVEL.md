# Deterministic branches and time travel

`BranchSession` coordinates the existing two `SimulationEngine` actors through the presentation model's single command chain. Each actor owns independent value state, ledger, loans and RNG. The renderer only sees immutable summaries.

`SimulationSnapshot` schema 1 contains all economic state. Backward-compatible optional fields add crisis plans, public claims, settlement queues, supply changes, player configuration and comparable-randomness metadata. `SessionArchive` version 1 stores both worlds, furthest visited day, demo stage, pre-crisis baseline and recorded unassisted future. The baseline/future checkpoint count is fixed; no per-frame or per-day full-state cache exists.

General timeline scrub recreates both worlds from their saved seed/configuration and replays ordered commands to the selected previously visited day. It restores actual finances, not chart positions. UI playback pauses while scrubbing. Full ledger/history retention means long sessions still grow; cold checkpoint archival remains a future optimization.

Before new crisis/policy comparison, both branches record `stableRandomFromDay`. Before that boundary the original Phase 1 RNG stream remains unchanged. From the boundary, counter-based SplitMix64 streams are keyed by simulation seed, day, household index and decision channel. Exogenous daily variation and hiring draws therefore align even when policy changes eligibility, employment or choice-set size. Crisis selection/withdrawal rules do not consume the household RNG stream. The boundary is persisted so timeline replay preserves the same warmup and subsequent draws.

## The Great Bank Run

1. Recreate seed 2026 with the standard population.
2. Advance seven healthy warmup days; save the complete baseline and restore the same state into B.
3. Choose the largest actual deposit bank. Schedule the same 90%-severity, 35-day bank run from day 8 in both worlds.
4. Calculate the unassisted future to day 35; retain A as the recorded future.
5. Rewind B to the actual day-7 baseline. A's recorded future remains available, so the UI explicitly labels different current horizons instead of subtracting incomparable values.
6. Reinstall the identical run in B. Schedule a repayable, fixed-rate central-bank advance equal to half that bank's baseline deposit liabilities.
7. Replay B to A's day-35 horizon. Compare actual employment, business survival, stress, defaults, unmet withdrawal flows, outstanding central-bank claims and fiscal outflows.

The advance amount is derived from bank state, not from a hardcoded rescue outcome. A controlled fixture verifies the documented settlement-window mechanism. The app never guarantees all policies improve every metric.

Cancellation completes a logical paired day before yielding. Demo retries restore the saved baseline before recalculation. Resets create a fresh baseline and clear demo metadata. Playback is guarded when the displayed worlds are intentionally at different days during the rewind step.
