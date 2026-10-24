import Foundation
import Testing

@testable import Econopolis

@Suite("Tokenized stock presentation")
struct TokenizedStockTests {
  @Test @MainActor func featuredCompaniesResolveFromCatalogNotGuessedIDs() {
    let companies = ["SpaceX", "NVIDIA", "Apple", "Tesla", "Microsoft", "Amazon"]
    let coins = companies.enumerated().map {
      CryptoCoin(
        id: "provider-id-\($0.offset)", symbol: "T\($0.offset)", name: $0.element + " xStock")
    }
    let unrelated = CryptoCoin(id: "random-meme", symbol: "NVDA", name: "NVIDIA fan token")
    #expect(CryptoViewModel.featuredStocks(in: coins.reversed() + [unrelated]) == coins.map(\.id))
  }
  @Test @MainActor func missingCompanyNeverCreatesAnInventedListing() {
    let coins = [CryptoCoin(id: "real-id", symbol: "ABCX", name: "Example xStock")]
    #expect(CryptoViewModel.featuredStocks(in: coins) == ["real-id"])
    #expect(CryptoViewModel.featuredStocks(in: []).isEmpty)
  }
}
