# Optional live stock market reference

Open **Economy → Live Stocks → Add market-data API key**. Enter the API key in the native secure field. Do not put credentials in chat, source code, a snapshot or UserDefaults. No API secret is requested.

The simulation and Great Bank Run demo remain offline. Only this optional screen contacts an external service. Real-world quotes are not inputs to the synthetic economy, ledger, metrics or branch replay.

## Verified provider contract

The implementation follows the user's supplied OpenAPI contract and Binance's official [Stocks introduction](https://developers.binance.com/en/docs/products/stocks/introduction) and [market-data API reference](https://developers.binance.com/en/docs/catalog/advanced-trading-stocks-trading/api/rest-api/market-data).

Supported GET requests:

| Path | Use |
|---|---|
| `/sapi/v1/equity/market/exchangeInfo` | Actual available stock symbols and supported trading metadata |
| `/sapi/v1/equity/market/quote?symbol=TICKER` | Best bid/ask prices and share sizes for a selected stock |

Both require the `X-MBX-APIKEY` header, without a request signature. The client does not implement order placement, canceling orders, account queries, token mint/redeem, stream-listen keys or accepting legal disclaimers. The tokenized-assets catalog is not part of this stock-quote display.

## What the screen shows

- Up to eight stocks selected from the returned exchange catalog, with search.
- Initial preferred tickers are chosen only if actually present in that catalog; otherwise the first returned symbols are used. No prices are generated locally.
- Best bid and ask in USD, exact string/Decimal parsing, bid/ask share sizes, and optional exchange metadata.
- A five-second refresh target while the screen is active, with sequential bounded watchlist requests and no overlapping batch loop.
- Retrieved time, pause/resume, missing-quote and network/authentication/region/rate-limit states.
- Previously received quotes can remain visible after a failed refresh, labeled stale and retaining their retrieval time. Paused values are identified as paused.

This REST endpoint can return quotes about five seconds old; it is not a tick-by-tick WebSocket feed. Retrieval time is when the app received data, not an exchange execution timestamp. No last-trade price, daily percentage change, company name or candle history is fabricated from fields the endpoint does not supply.

An empty HTTP 200 body, whitespace or JSON `null` produces an unavailable quote. Malformed or mismatched ticker payloads are rejected. HTTP authentication errors and Binance's `-2014` / `-2015` codes show sanitized errors; raw provider messages are not echoed. Numeric `Retry-After` intervals are honored, with a minimum conservative delay and cancelable backoff.

## Storage, network and lifecycle

`MarketKeyStore` uses the iOS Keychain, `WhenUnlockedThisDeviceOnly`, with an app-local service/account. Keys are not synced into session archives or exported reports. UI tests use a separate Keychain service so they never read a user's real saved key. Only symbol preferences use UserDefaults.

`BinanceStocksClient` is an actor with a fixed HTTPS host and only two read-only routes. An ephemeral URLSession disables cookies, URL cache and credential storage. Redirects are refused so the API-key header is never forwarded to a redirect host. Request timeouts are bounded. Keys are header values, not query parameters, and no request/key logging is added.

`StocksViewModel` publishes on the main actor, while Keychain and network/decoding work use actors. SwiftUI owns the single polling task, cancels it on navigation/background/pause and restarts it for connection/watchlist changes. Revision and cancellation guards discard old responses after disconnect or key changes. An empty watchlist sends no quote requests.

### Simulator signing matters

Keychain needs an application identifier. Build and test the Simulator app with **local signing enabled**:

```sh
xcodebuild -project Econopolis.xcodeproj -scheme Econopolis \
  -configuration Debug -derivedDataPath .build/ios \
  -destination 'platform=iOS Simulator,id=SIMULATOR_ID' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=YES CODE_SIGN_IDENTITY=- test
```

This local Simulator signature requires no Apple Developer certificate and is not signed device distribution. Normal Xcode Run uses Simulator signing automatically. Disabling signing may allow the economic demo to run but makes secure key storage fail; the app reports that failure rather than silently storing a key insecurely. Physical-device installation still needs the user's own signing team/provisioning.

## Actual verification and limitations

- The production exchange-info endpoint was probed once **without a key** and returned HTTP 400, code `-2014` (“API-key format invalid”). No authenticated quote was obtained or claimed.
- Nine hosted client/storage/state tests passed in `.build/StocksClientSignedTests.xcresult`.
- Nine tests plus one actual UI onboarding/cancellation test passed in `.build/LiveStocksAcceptance.xcresult` (**10 passed, 0 failed**).
- Tests cover GET-only HTTPS/header construction, no network without credentials, Decimal precision, empty/null quotes, invalid payloads/tickers, sanitized authentication errors, rate-limit delay parsing, isolated Keychain save/update/delete, bounded watchlists and late-response rejection after disconnect.
- Quote fixtures exist only in the test target. They are not displayed as live application data.

Authenticated feed availability, product access, market-session coverage, regional eligibility and real-account quotas require the user's valid provider key and account access. No key was supplied during implementation. The optional screen is implemented, but authenticated end-to-end live-price verification is explicitly pending.

A final credential race regression was added after the initial nine client tests: refresh is suppressed while Keychain deletion is pending, and both old responses and attempted reloads are rejected. `.build/StocksCredentialFinal.xcresult` passed **11 tests** (10 client/storage/lifecycle + 1 actual UI setup/cancellation case), with no failures or runtime warnings. This is separate from the earlier 22-test combined UI/integration result; overlapping tests are not counted twice.
