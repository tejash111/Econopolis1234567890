# Offline AI Economist

The mandatory implementation is a deterministic native Swift intent parser and evidence-based explanation service. It has no network dependency or API key. `AIModelProvider` is the provider boundary; `OfflineEconomistProvider` is the active implementation. Optional Foundation Models inference is **not enabled** and must not be advertised as implemented.

`SimulationIntentParser` returns typed queries, crisis plans, policy plans or an unsupported explanation. It resolves known banks/districts from actual state, converts supported percentage-point/basis-point inputs, and produces bounded parameters. `SimulationCommandValidator` checks ranges, timing and supported references. The engine independently validates commands again.

Every state-changing intent opens the same editable native preview used by Crisis Lab. No generated text or parser result executes directly. The user must confirm. Canceling a preview has no economic effect. Unsupported/invalid requests provide examples and leave the world unchanged.

Guaranteed example prompts:

- Explain the impact of the bank run
- Compare the two worlds
- Increase interest rates by 2 percentage points
- Simulate a recession for 30 days
- Show me businesses at risk
- What is unemployment?
- Provide emergency liquidity of 1 million dollars
- Guarantee deposits for 30 days

`EconomicExplanationService` reads recorded metrics, actual firm health, withdrawal attempts/settlements, public claims and causal records. It distinguishes stocks, flows, rejected attempts and losses. Same-day branch comparison is required before reporting differences. Citizen profile stories use real decision records, posted transfers, employment/default journal entries and attributed disruption records. Personal balance-history series and GPS routes are not invented.

Limitations: the parser is a documented financial command grammar, not general natural-language intelligence. Reference resolution is intentionally narrow and visible in the editable preview. Optional on-device model integration, richer narrative generation and more conversational memory remain future enhancements. No unsupported inference is described as a market forecast or real financial advice.
