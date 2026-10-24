# Optional GPT-6 Luna specialists

ECONOPOLIS remains a native Swift iPhone app with an offline simulator and deterministic economist. Online specialists are an optional connection requested by the user. The confirmed model is exactly `gpt-6-luna`.

## Implemented features

AI Economist provides six specialist modes: economy briefing, bank/business risk, policy coach, citizen stories, World A/B comparison and external stock-token summaries. Each mode changes the question and specialist instructions while using the same bounded, read-only evidence agent. This is six roles, not six simultaneous model calls or an autonomous multi-agent swarm.

The existing offline parser runs first. Recognized crisis/policy commands still open the existing validated, editable confirmation sheets. Online answers have no engine, ledger or command execution tools. Unsupported free-form questions can receive an online explanation, but no model text executes an economic action.

## Native API integration and SDK limit

OpenAI's official Agents SDK is published for Python and TypeScript. The existing iPhone app uses Swift 6 and has no required server. Consequently this implementation uses native URLSession calls to the Responses API with a Swift tool loop; **it does not claim to integrate the official Agents SDK**. Adding that SDK itself would require a separate optional Python/TypeScript service and new deployment work. No such backend is introduced.

- Endpoint: `POST https://api.openai.com/v1/responses`.
- Model: `gpt-6-luna`; reasoning low; max output 1,600 tokens per turn.
- Store: false. This requests no stored response state; it is not a claim of zero provider retention.
- Max four response requests per user question. At most one read tool per turn.
- Tool: `read_evidence(section)` with strict enum schema. Only existing immutable evidence sections are available. First response must query evidence before a final answer is accepted.
- Tool names, call IDs, argument lengths/shape, requested section, response completion and output lengths are validated. Unknown or mutation tools are rejected. Refusals/incomplete output do not become executed commands.
- Reasoning items are passed back during tool continuation. No request/response contents or secrets are logged by app code.
- No automatic retries on billing/auth/model/rate errors. Offline evidence is shown as an explicitly labeled fallback.

## Evidence and privacy

A question captures world/day and a bounded read-only snapshot: metrics, four banks, fifteen businesses with lowest financial health, up to ten named or most-stressed fictional citizens, districts, last fourteen metric observations, fifteen recent transactions, scheduled events/funding and cached external market observations. No real personal financial information is collected. Units and synthetic-model limits accompany the instructions. A/B comparisons include actual metrics and emergency-funding obligations; the agent is told to reject unsynchronized comparisons.

Questions and selected fictional data are sent to OpenAI only when the user requests an online answer. Generated prose can still contain mistakes; it is labeled AI interpretation and cannot replace recorded balances or confirmed scenario execution. There is no claim that all numerical or causal statements can be automatically proven correct.

Keys are supplied by the user and stored in a distinct device Keychain service/account. Never embed a shared key in the app binary or ship one with a release. This user-owned-key hackathon setup is not a centrally funded public consumer service. Connection settings explain network usage and API-project quota. The simulator credential was entered through a no-echo local pipe and verified without printing it. It is not committed or exported. Physical iPhones require their own connection setup.

Cancellation/revision guards stop or discard answers on tab departure, day/world/seed changes and credential/mode changes. The offline engine and deterministic replay have no dependency on model calls.

## Verification

Authenticated minimal GPT-6 Luna request returned HTTP 200 / completed on 2026-10-24. Actual iPhone 17 / iOS 27.0 XCTest opened AI Economist, invoked Economy briefing, waited for the generated interpretation, captured a screenshot and returned to City. Six fixture tests cover requested-model/headers/store/tool output, unknown mutation/section rejection, evidence-required and incomplete outputs, input limits, sanitized auth/billing/rate/model errors, and bounded turns. See TEST_REPORT.md for result bundles and exact commands.

Only the economy role has been verified end to end with a live model in the UI. The other five roles share the tested agent but have not each received a separate live-answer quality evaluation. No physical-device, streaming, speech, persisted chat sessions, SDK backend, Foundation Models or autonomous policy execution is claimed.

## Official references

- [GPT-6 Luna](https://developers.openai.com/api/docs/models/gpt-6-luna)
- [Agents SDK](https://developers.openai.com/api/docs/guides/agents/sdk)
- [Function calling](https://developers.openai.com/api/docs/guides/function-calling)
- [Responses API](https://developers.openai.com/api/reference/resources/responses/methods/create)
