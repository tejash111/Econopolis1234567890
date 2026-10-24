import Charts
import SwiftUI

struct LiveCryptoScreen: View {
  @State private var model = CryptoViewModel()
  @Environment(\.scenePhase) private var scenePhase
  @State private var configuring = false
  @State private var choosing = false
  @State private var keyEntry = ""
  @State private var saving = false
  var body: some View {
    List {
      Section {
        Label("Crypto markets", systemImage: "chart.line.uptrend.xyaxis").font(.headline)
        Text("CoinGecko Demo · USD").foregroundStyle(.secondary)
        if model.hasKey {
          HStack {
            Label(
              model.paused ? "Updates paused" : "Refresh every minute",
              systemImage: model.paused ? "pause.circle" : "arrow.triangle.2.circlepath"
            )
            .font(.subheadline)
            Spacer()
            Button(model.paused ? "Resume" : "Pause") { model.paused.toggle() }
          }.frame(minHeight: 44)
        }
      } footer: {
        Text(
          "Aggregated market observations, not exchange execution prices. Provider caching can delay updates. External prices never change the fictional city or its deterministic replay."
        )
      }
      if !model.hasKey {
        Section {
          ContentUnavailableView(
            "Connect market data", systemImage: "network",
            description: Text(
              "Connect your CoinGecko Demo key for current crypto prices. The city continues to work offline."
            ))
          Button("Add market-data API key") { configuring = true }
            .frame(minHeight: 44).accessibilityIdentifier("addCryptoKey")
        }
      }
      if model.isLoading { ProgressView("Resolving CoinGecko coin IDs…") }
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
          ForEach(model.watchlist, id: \.self) { id in
            NavigationLink {
              CryptoInspector(id: id, model: model)
            } label: {
              CryptoPriceRow(
                coin: model.symbols.first { $0.id == id }, id: id,
                record: model.records[id], paused: model.paused)
            }
          }
          Button {
            choosing = true
          } label: {
            Label("Edit watchlist", systemImage: "plus.circle")
          }
          if model.watchlist.isEmpty {
            Text("Choose up to eight coins.").foregroundStyle(.secondary)
          }
        } header: {
          Text("Watchlist · \(model.watchlist.count) of 8")
        } footer: {
          Text(
            "Coin IDs are resolved from CoinGecko's catalog. All watched coins share one market request per minute."
          )
        }
      }
      Section("About this connection") {
        LabeledContent("Source", value: "CoinGecko")
        LabeledContent("Plan", value: "Demo")
        Text(
          "Read-only HTTPS requests to api.coingecko.com. The key stays in this device's Keychain. No wallet, trading account or paid API is required. Market data is unavailable offline; the simulation remains available."
        )
        .font(.footnote).foregroundStyle(.secondary)
        if model.hasKey {
          Button("Change API key") { configuring = true }
          Button("Remove saved API key", role: .destructive) { Task { await model.disconnect() } }
        }
        Link(
          "Data provided by CoinGecko",
          destination: URL(string: "https://www.coingecko.com/en/api")!)
        Link(
          "Demo API documentation",
          destination: URL(string: "https://docs.coingecko.com/demo/reference/coins-markets")!)
      }
    }.listStyle(.insetGrouped).navigationTitle("Live Crypto").navigationBarTitleDisplayMode(.large)
      .task(id: "\(scenePhase)-\(model.revision)-\(model.paused)") {
        guard scenePhase == .active, !model.paused else { return }
        await model.run()
      }
      .sheet(isPresented: $configuring, onDismiss: { keyEntry = "" }) {
        NavigationStack {
          Form {
            Section {
              SecureField("CoinGecko Demo API key", text: $keyEntry).textContentType(.password)
                .textInputAutocapitalization(.never).autocorrectionDisabled()
                .accessibilityIdentifier("cryptoAPIKey")
            } header: {
              Text("Demo API access")
            } footer: {
              Text(
                "Enter your Demo key here. It is sent only in the x-cg-demo-api-key HTTPS header, never in URLs, simulation saves or exports."
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
                  || !CryptoMarketError.validKey(
                    keyEntry.trimmingCharacters(in: .whitespacesAndNewlines))
              )
              if saving { ProgressView() }
              if let error = model.error { Text(error).font(.footnote).foregroundStyle(.secondary) }
            }
            Link(
              "Open CoinGecko developer dashboard",
              destination: URL(string: "https://www.coingecko.com/en/developers/dashboard")!)
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
      .sheet(isPresented: $choosing) { CryptoWatchlistEditor(model: model) }
  }
}
private struct CryptoPriceRow: View {
  let coin: CryptoCoin?
  let id: String
  let record: CryptoQuoteRecord?
  let paused: Bool
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        VStack(alignment: .leading) {
          Text(coin?.name ?? id).font(.headline)
          Text(coin?.symbol.uppercased() ?? id).font(.caption).foregroundStyle(.secondary)
        }
        Spacer()
        if let quote = record?.quote {
          VStack(alignment: .trailing) {
            Text(cryptoMoney(quote.currentPrice)).monospacedDigit()
            if let change = quote.priceChangePercentage24h {
              Text("\(change.formatted(.number.precision(.fractionLength(2))))% · 24h")
                .font(.caption).foregroundStyle(change >= 0 ? .green : .red)
            }
          }
        }
      }
      if let quote = record?.quote {
        TimelineView(.periodic(from: .now, by: 30)) { context in
          if quote.isStale(at: context.date) || record?.error != nil || paused {
            Label(paused ? "Paused" : "Stale / timestamp unavailable", systemImage: "clock")
              .font(.caption).foregroundStyle(.secondary)
          }
        }
        if let date = quote.updatedAt {
          Text("Provider updated \(date.formatted(date: .abbreviated, time: .standard))")
            .font(.caption).foregroundStyle(.secondary)
        }
      } else {
        Text(record?.fetchedAt == nil ? "Waiting for market data…" : "Price unavailable")
          .font(.caption).foregroundStyle(.secondary)
      }
      if let error = record?.error { Text(error).font(.caption).foregroundStyle(.secondary) }
    }.padding(.vertical, 4)
  }
}
private struct CryptoInspector: View {
  let id: String
  let model: CryptoViewModel
  var body: some View {
    List {
      Section("Market overview") {
        CryptoPriceRow(
          coin: model.symbols.first { $0.id == id }, id: id,
          record: model.records[id], paused: model.paused)
        if let quote = model.records[id]?.quote {
          LabeledContent("Market cap", value: cryptoMoney(quote.marketCap))
          LabeledContent("24-hour volume", value: cryptoMoney(quote.totalVolume))
          if let prices = quote.sparklineIn7d?.price, prices.count > 1 {
            Chart(Array(prices.enumerated()), id: \.offset) { item in
              LineMark(x: .value("Sample", item.offset), y: .value("USD", item.element))
                .foregroundStyle(.blue)
            }.chartYScale(domain: .automatic(includesZero: false)).chartXAxis(.hidden).frame(
              height: 200
            )
            .accessibilityLabel("CoinGecko seven-day price trend, ordered samples")
            Text("7-day provider sparkline · ordered samples, not exact timestamps")
              .font(.caption).foregroundStyle(.secondary)
          } else {
            Text("Trend history unavailable.").foregroundStyle(.secondary)
          }
        }
      }
      Section("Data provenance") {
        LabeledContent("CoinGecko ID", value: id)
        if let at = model.records[id]?.fetchedAt {
          LabeledContent("Received", value: at.formatted(date: .abbreviated, time: .standard))
        }
        Text(
          "Unavailable fields stay unavailable. Trends and 24-hour changes are returned by CoinGecko, not calculated from the city's simulated history."
        )
        .font(.footnote).foregroundStyle(.secondary)
      }
    }.navigationTitle(model.symbols.first { $0.id == id }?.name ?? id)
      .navigationBarTitleDisplayMode(.inline)
  }
}
private struct CryptoWatchlistEditor: View {
  @Environment(\.dismiss) private var dismiss
  @Bindable var model: CryptoViewModel
  @State private var search = ""
  private var matches: [CryptoCoin] {
    Array(
      model.symbols.filter {
        search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)
          || $0.symbol.localizedCaseInsensitiveContains(search)
          || $0.id.localizedCaseInsensitiveContains(search)
      }.prefix(150))
  }
  var body: some View {
    NavigationStack {
      List {
        Section("\(model.watchlist.count) / 8 selected · first 150 matches") {
          ForEach(matches) { coin in
            Button {
              model.toggle(coin.id)
            } label: {
              HStack {
                VStack(alignment: .leading) {
                  Text(coin.name).foregroundStyle(.primary)
                  Text("\(coin.symbol.uppercased()) · \(coin.id)").font(.caption).foregroundStyle(
                    .secondary)
                }
                Spacer()
                if model.watchlist.contains(coin.id) {
                  Image(systemName: "checkmark").foregroundStyle(.blue)
                }
              }.frame(minHeight: 44)
            }.disabled(!model.watchlist.contains(coin.id) && model.watchlist.count >= 8)
          }
          if matches.isEmpty { Text("No matching coins. Try another name or ticker.") }
        }
      }.searchable(text: $search, prompt: "Coin name, ticker or ID").navigationTitle("Choose coins")
        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
    }
  }
}
func cryptoMoney(_ value: Decimal?) -> String {
  guard let value, !value.isNaN else { return "Unavailable" }
  return value.formatted(.currency(code: "USD").precision(.fractionLength(2...9)))
}
