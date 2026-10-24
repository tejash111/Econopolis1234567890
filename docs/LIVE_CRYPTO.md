# Live Crypto — CoinGecko Demo

This optional online reference replaces Binance stocks. The fictional economy, crisis demo and replay remain fully offline. No external prices enter the financial ledger or economic metrics.

## Connect

1. Run the iPhone app and open **Economy → Live Crypto**.
2. Choose **Add market-data API key** and paste a CoinGecko **Demo** key.
3. Choose **Save key and connect**. Keys are device-local Keychain entries. Use a replacement key if one has been shared publicly.
4. The catalog resolves Bitcoin, Ethereum and Solana only if those IDs are returned. Edit the watchlist to choose up to eight coins; identical tickers are distinguished by unique IDs.

Demo is explicit: `https://api.coingecko.com/api/v3`, header `x-cg-demo-api-key`. Pro keys need a separate future configuration; the app never guesses the plan or sends credentials to redirects. The old Binance Keychain entry is not read or migrated. Remove old provider credentials through the provider dashboard if no longer needed.

## Actual data flow

- GET `coins/list`: provider catalog for ID resolution. Loaded once per screen-model lifetime/connection. Incomplete listings with blank names/tickers are omitted; valid listings remain available.
- GET `coins/markets?vs_currency=usd&ids=...&sparkline=true&precision=full`: one batch for all watched IDs, once per minute while the screen is active.
- Prices and monetary fields decode as Decimal. Missing fields stay unavailable, empty market results never become fake prices. Duplicate/mismatched IDs, negative monetary values and invalid chart samples are rejected.
- Provider ISO8601 `last_updated` is distinct from app receipt time. Older than 180 seconds, missing or implausibly future timestamps are labeled stale. Paused or failed requests also identify retained observations.
- Seven-day sparklines use the actual returned ordered sample array. The endpoint supplies no per-sample timestamps; the chart does not invent them.
- A process-wide three-second request gate bounds rapid-navigation/retry bursts. HTTP 429 honors Retry-After with a minimum 60-second cooldown. Authentication/plan errors are sanitized; raw provider messages are never shown. No automatic keyless fallback.
- Screen/background cancellation stops polling; revision guards discard stale requests during key removal or replacement.

The app is a periodically refreshed market reference, not a trading terminal or guaranteed real-time execution feed. No wallets, orders, NFTs or DEX analytics are added in this change.

## Files

- `EconopolisApp/MarketData/CoinGeckoClient.swift`: Demo-only API, typed catalog/quotes, validation.
- `MarketHTTPTransport.swift`: ephemeral URLSession, no cookies/cache/credentials, rejects redirects.
- `MarketKeyStore.swift`: dedicated CoinGecko Demo Keychain account and UI-test isolation.
- `CryptoViewModel.swift`: single cancellation-owned refresh, bounded watchlist, backoff and revision handling.
- `EconopolisApp/Views/LiveCryptoScreen.swift`: native grouped UI, secure setup, directory and Swift Charts details.

## Verification

See the dated CoinGecko section of TEST_REPORT.md for real results. Fixture data exists only in test targets. Authenticated production catalog and market requests were verified on 2026-10-24 from the iPhone simulator using the saved Keychain credential: HTTP 200 for both endpoints, three requested observations and three available prices. A production catalog regression (four empty ticker symbols) was fixed by omitting incomplete listings. No key is embedded in this repository.

## References

[Demo market endpoint](https://docs.coingecko.com/demo/reference/coins-markets), [developer dashboard](https://www.coingecko.com/en/developers/dashboard), [API skill](https://github.com/coingecko/skills). Data provided by CoinGecko.
