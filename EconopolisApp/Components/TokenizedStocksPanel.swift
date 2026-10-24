import Charts
import SwiftUI

/// One shared read-only market model feeds both tabs; financial state remains in the simulator.
struct TokenizedStocksPanel: View {
  @Environment(CryptoViewModel.self) private var market
  let compact: Bool
  @State private var connection = false
  var body: some View {
    VStack(alignment: .leading, spacing: compact ? 8 : 14) {
      HStack {
        Label("Tokenized stocks", systemImage: "chart.line.uptrend.xyaxis")
          .font(compact ? .subheadline.weight(.semibold) : .headline)
        Spacer()
        if market.isLoading { ProgressView().controlSize(.small) }
        Menu {
          Button(market.paused ? "Resume market updates" : "Pause market updates") {
            market.paused.toggle()
          }
          Button("Market connection") { market.configuring = true }
          Button("Retry market connection") { market.retry() }
            .disabled(market.cooldownUntil.map { $0 > .now } ?? false)
        } label: {
          Image(systemName: "ellipsis").frame(width: 44, height: 44)
        }
        .accessibilityLabel("Market options").accessibilityIdentifier("marketOptions")
      }
      if !market.hasKey && !market.isLoading {
        HStack {
          Text("Connect for live stock-token prices.").font(.subheadline).foregroundStyle(
            .secondary)
          Spacer()
          Button("Connect") { market.configuring = true }.frame(minHeight: 44)
            .accessibilityIdentifier("connectStocks")
        }
      } else if market.watchlist.isEmpty {
        Text(market.isLoading ? "Loading stock listings…" : "No stock listings available.")
          .font(.subheadline).foregroundStyle(.secondary)
      } else if compact {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 10) {
            ForEach(market.watchlist, id: \.self) { id in
              stock(id, compact: true).frame(width: 146, alignment: .leading)
                .padding(12).background(Color.cardSurface, in: RoundedRectangle(cornerRadius: 14))
            }
          }
        }.accessibilityIdentifier("cityStockStrip")
      } else {
        VStack(spacing: 0) {
          ForEach(market.watchlist, id: \.self) { id in
            stock(id, compact: false).padding(.vertical, 12)
            if id != market.watchlist.last { Divider() }
          }
        }
      }
      if let error = market.error {
        Text(error.replacingOccurrences(of: "CoinGecko", with: "Market service"))
          .font(.caption).foregroundStyle(.secondary)
      }
      if !compact {
        Text(
          "USD · stock-token market prices · refreshes every minute\(market.paused ? " · paused" : "")"
        )
        .font(.caption).foregroundStyle(.secondary)
        Text(
          "Tokens provide exposure to the named company. Token prices can differ from underlying share prices."
        )
        .font(.caption).foregroundStyle(.secondary)
      }
    }
    .padding(compact ? 10 : 16)
    .background(compact ? Color.clear : Color.cardSurface, in: RoundedRectangle(cornerRadius: 18))

  }
  @ViewBuilder private func stock(_ id: String, compact: Bool) -> some View {
    let coin = market.symbols.first { $0.id == id }
    let record = market.records[id]
    let title = coin?.name.replacingOccurrences(of: " xStock", with: "") ?? id
    VStack(alignment: .leading, spacing: 5) {
      HStack {
        VStack(alignment: .leading, spacing: 3) {
          Text(title).font(compact ? .subheadline.weight(.semibold) : .headline).lineLimit(1)
          Text(coin?.symbol.uppercased() ?? id).font(.caption).foregroundStyle(.secondary)
        }
        if !compact {
          Spacer()
          if let prices = record?.quote?.sparklineIn7d?.price, prices.count > 1 {
            Chart(Array(prices.enumerated()), id: \.offset) { item in
              LineMark(x: .value("Sample", item.offset), y: .value("USD", item.element))
                .foregroundStyle(.blue).lineStyle(StrokeStyle(lineWidth: 1.5))
            }.chartXAxis(.hidden).chartYAxis(.hidden)
              .chartYScale(domain: .automatic(includesZero: false)).frame(width: 64, height: 28)
              .accessibilityLabel("Seven-day stock-token trend")
          }
          VStack(alignment: .trailing, spacing: 4) {
            price(record)
            change(record)
          }
        }
      }
      if compact {
        price(record)
        change(record)
      }
      if let quote = record?.quote {
        TimelineView(.periodic(from: .now, by: 30)) { context in
          if quote.isStale(at: context.date) || record?.error != nil || market.paused {
            Text(market.paused ? "Paused" : "Stale price").font(.caption2).foregroundStyle(
              .secondary)
          } else if !compact, let updated = quote.updatedAt {
            Text("Updated \(updated.formatted(date: .omitted, time: .shortened))")
              .font(.caption2).foregroundStyle(.secondary)
          }
        }
      }
    }.accessibilityElement(children: .combine).accessibilityIdentifier("stock-\(id)")
  }
  private func price(_ record: CryptoQuoteRecord?) -> some View {
    Text(record?.fetchedAt == nil ? "Loading…" : cryptoMoney(record?.quote?.currentPrice))
      .font(.subheadline.weight(.semibold)).monospacedDigit()
  }
  @ViewBuilder private func change(_ record: CryptoQuoteRecord?) -> some View {
    if let value = record?.quote?.priceChangePercentage24h {
      Text("\(value >= 0 ? "+" : "")\(value.formatted(.number.precision(.fractionLength(2))))%")
        .font(.caption.monospacedDigit()).foregroundStyle(value >= 0 ? .green : .red)
        .accessibilityLabel("24-hour change \(value.formatted()) percent")
    } else {
      Text("24h unavailable").font(.caption).foregroundStyle(.secondary)
    }
  }
}
struct MarketConnectionSheet: View {
  @Environment(CryptoViewModel.self) private var market
  @Environment(\.dismiss) private var dismiss
  @State private var key = ""
  @State private var saving = false
  var body: some View {
    NavigationStack {
      Form {
        Section("Market access") {
          SecureField("Market API key", text: $key).textContentType(.password)
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .accessibilityIdentifier("cryptoAPIKey")
          Button("Save key and connect") {
            saving = true
            Task {
              defer { saving = false }
              if await market.saveKey(key) {
                key = ""
                dismiss()
              }
            }
          }.disabled(
            saving
              || !CryptoMarketError.validKey(key.trimmingCharacters(in: .whitespacesAndNewlines)))
          if saving { ProgressView() }
        }
        if let error = market.error {
          Text(error.replacingOccurrences(of: "CoinGecko", with: "Market service"))
        }
        if market.hasKey {
          Button("Remove saved key", role: .destructive) {
            Task {
              await market.disconnect()
              dismiss()
            }
          }
        }
      }.navigationTitle("Market connection").navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") {
              key = ""
              dismiss()
            }
          }
        }
    }.presentationDetents([.medium, .large])
  }
}
func cryptoMoney(_ value: Decimal?) -> String {
  guard let value, !value.isNaN else { return "Unavailable" }
  return value.formatted(.currency(code: "USD").precision(.fractionLength(2...6)))
}
