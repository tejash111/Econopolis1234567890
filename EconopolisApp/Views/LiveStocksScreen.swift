import SwiftUI

struct LiveStocksScreen: View {
  @State private var model = StocksViewModel()
  @Environment(\.scenePhase) private var scenePhase
  @State private var keyEntry = ""
  @State private var configuring = false
  @State private var choosing = false
  @State private var saving = false
  var body: some View {
    List {
      Section {
        Label("Binance stock quotes", systemImage: "chart.line.uptrend.xyaxis").font(.headline)
        Text("External market reference • USD").font(.subheadline).foregroundStyle(.secondary)
        if model.hasKey {
          HStack {
            Label(
              model.paused ? "Updates paused" : "Refresh every 5 seconds",
              systemImage: model.paused ? "pause.circle" : "arrow.triangle.2.circlepath"
            )
            .font(.subheadline)
            Spacer()
            Button(model.paused ? "Resume" : "Pause") { model.paused.toggle() }
          }.frame(minHeight: 44)
        }
      } footer: {
        Text(
          "Best bid and ask, not last-trade prices. The provider can return quotes about 5 seconds old. These real-world observations never change the synthetic city or its deterministic replay."
        )
      }
      if !model.hasKey {
        Section {
          ContentUnavailableView(
            "Connect market data", systemImage: "network",
            description: Text(
              "This API requires a Binance market-data API key, even for quotes. The city simulation continues to work offline."
            ))
          Button("Add market-data API key") { configuring = true }.frame(minHeight: 44)
            .accessibilityIdentifier("addStocksKey")
        }
      }
      if model.isLoading { Section { ProgressView("Loading exchange symbols…") } }
      if let error = model.error {
        Section("Connection status") {
          Text(error).foregroundStyle(.secondary)
          if let until = model.cooldownUntil, until > .now {
            LabeledContent(
              "Earliest retry", value: until.formatted(date: .omitted, time: .standard))
          }
          Button("Retry connection") { model.retry() }
            .disabled(model.cooldownUntil.map { $0 > .now } ?? false)
          Button("Update API key") { configuring = true }
        }
      }
      if model.hasKey && !model.symbols.isEmpty {
        Section {
          ForEach(model.watchlist, id: \.self) { symbol in
            NavigationLink {
              StockQuoteInspector(symbol: symbol, model: model)
            } label: {
              StockQuoteRow(symbol: symbol, record: model.records[symbol], paused: model.paused)
            }
          }
          Button {
            choosing = true
          } label: {
            Label("Edit watchlist", systemImage: "plus.circle")
          }
          if model.watchlist.isEmpty {
            Text("Choose up to eight available stocks to follow.").foregroundStyle(.secondary)
          }
        } header: {
          Text("Watchlist · \(model.watchlist.count) of 8")
        } footer: {
          Text(
            "Only symbols returned by the exchange can be selected. Requests are limited to this watchlist; the app does not poll every listed stock."
          )
        }
      } else if model.hasKey && !model.isLoading && model.error == nil {
        Section {
          Text("The exchange returned no stock symbols. Check your account's market-data access.")
            .foregroundStyle(.secondary)
        }
      }
      Section("About this connection") {
        LabeledContent("Source", value: "Binance Stocks REST API")
        LabeledContent("Access", value: "Market data only")
        Text(
          "No account balances, trades, token minting, order placement or disclaimer acceptance are requested. No API secret is required. Your API key is stored in this device's Keychain and sent only as an HTTPS header to api.binance.com."
        )
        .font(.footnote).foregroundStyle(.secondary)
        if model.hasKey {
          Button("Change API key") { configuring = true }
          Button("Remove saved API key", role: .destructive) { Task { await model.disconnect() } }
        }
        Link(
          "Binance market-data documentation",
          destination: URL(
            string:
              "https://developers.binance.com/en/docs/catalog/advanced-trading-stocks-trading/api/rest-api/market-data"
          )!)
      }
    }.listStyle(.insetGrouped).navigationTitle("Live Stocks").navigationBarTitleDisplayMode(.large)
      .task(id: "\(scenePhase)-\(model.revision)-\(model.paused)") {
        guard scenePhase == .active, !model.paused else { return }
        await model.run()
      }
      .sheet(isPresented: $configuring, onDismiss: { keyEntry = "" }) {
        NavigationStack {
          Form {
            Section {
              SecureField("Binance API key", text: $keyEntry).textContentType(.password)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .accessibilityIdentifier("stocksAPIKey")
            } header: {
              Text("Market-data access")
            } footer: {
              Text(
                "Enter the API key here, not in chat or source code. Only market-data GET requests are used. This connection does not require your API secret or enable order placement."
              )
            }
            Section {
              Button("Save key and connect") {
                saving = true
                Task {
                  defer { saving = false }
                  if await model.saveKey(keyEntry) {
                    keyEntry = ""
                    configuring = false
                  }
                }
              }.disabled(
                saving
                  || !StockMarketError.validKey(
                    keyEntry.trimmingCharacters(in: .whitespacesAndNewlines))
              )
              if saving { ProgressView() }
              if let error = model.error { Text(error).font(.footnote).foregroundStyle(.secondary) }
            }
            Section {
              Text(
                "Availability depends on your Binance account, product access, key restrictions and location. A missing or rejected key never produces fabricated stock prices."
              ).font(.footnote).foregroundStyle(.secondary)
            }
          }.navigationTitle("Connect market data").navigationBarTitleDisplayMode(.inline)
            .toolbar {
              ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                  keyEntry = ""
                  configuring = false
                }
              }
            }
        }.presentationDetents([.medium, .large])
      }
      .sheet(isPresented: $choosing) { StockWatchlistEditor(model: model) }
  }
}
private struct StockQuoteRow: View {
  let symbol: String
  let record: StockQuoteRecord?
  let paused: Bool
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text(symbol).font(.headline)
        Spacer()
        if record?.error != nil {
          Label("Stale", systemImage: "exclamationmark.circle").font(.caption).foregroundStyle(
            .orange)
        }
      }
      if let quote = record?.quote {
        HStack {
          VStack(alignment: .leading, spacing: 3) {
            Text("Bid").font(.caption).foregroundStyle(.secondary)
            Text(stockPrice(quote.bidPrice)).monospacedDigit()
          }
          Spacer()
          VStack(alignment: .trailing, spacing: 3) {
            Text("Ask").font(.caption).foregroundStyle(.secondary)
            Text(stockPrice(quote.askPrice)).monospacedDigit()
          }
        }
      } else {
        Text(
          record?.error != nil
            ? "Quote unavailable"
            : (record?.fetchedAt == nil ? "Waiting for a quote…" : "No quote available")
        ).font(
          .subheadline
        ).foregroundStyle(.secondary)
      }
      if let at = record?.fetchedAt {
        Text("Fetched \(at.formatted(date: .omitted, time: .standard))\(paused ? " · paused" : "")")
          .font(.caption).foregroundStyle(.secondary)
      }
      if let error = record?.error { Text(error).font(.caption).foregroundStyle(.secondary) }
    }.padding(.vertical, 4)
  }
}
private struct StockQuoteInspector: View {
  let symbol: String
  let model: StocksViewModel
  var body: some View {
    List {
      Section("Best bid / ask") {
        StockQuoteRow(symbol: symbol, record: model.records[symbol], paused: model.paused)
        if let quote = model.records[symbol]?.quote {
          LabeledContent("Bid size (shares)", value: quote.bidSize.formatted())
          LabeledContent("Ask size (shares)", value: quote.askSize.formatted())
        }
      }
      if let info = model.symbols.first(where: { $0.symbol == symbol }) {
        Section("Exchange metadata") {
          LabeledContent("Tradability", value: info.tradability)
          if let supported = info.overnightSupported {
            LabeledContent("Overnight", value: supported ? "Supported" : "Not supported")
          }
          if let supported = info.extendedSession {
            LabeledContent("Extended session", value: supported ? "Supported" : "Not supported")
          }
          if let supported = info.fractionable {
            LabeledContent("Fractional shares", value: supported ? "Supported" : "Not supported")
          }
        }
      }
      Section {
        Text(
          "Fetched time is when this app received the response, not a market execution timestamp. The endpoint does not provide price-change percentages, last trades or historical candles; none are invented here."
        )
        .font(.footnote).foregroundStyle(.secondary)
      }
    }.navigationTitle(symbol).navigationBarTitleDisplayMode(.inline)
  }
}
private struct StockWatchlistEditor: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var model: StocksViewModel
  @State private var search = ""
  var body: some View {
    NavigationStack {
      List {
        Section("\(model.watchlist.count) / 8 selected") {
          ForEach(
            model.symbols.filter {
              search.isEmpty || $0.symbol.localizedCaseInsensitiveContains(search)
            }
          ) { stock in
            Button {
              model.toggle(stock.symbol)
            } label: {
              HStack {
                Text(stock.symbol).foregroundStyle(.primary)
                Spacer()
                if model.watchlist.contains(stock.symbol) {
                  Image(systemName: "checkmark").foregroundStyle(.blue)
                }
              }.frame(minHeight: 44).contentShape(Rectangle())
            }.disabled(!model.watchlist.contains(stock.symbol) && model.watchlist.count >= 8)
          }
        }
      }.searchable(text: $search, prompt: "Stock symbol").navigationTitle("Choose stocks")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
  }
}
func stockPrice(_ string: String) -> String {
  guard let value = StockQuote.decimal(string) else { return "Unavailable" }
  return value.formatted(.currency(code: "USD").precision(.fractionLength(2...9)))
}
