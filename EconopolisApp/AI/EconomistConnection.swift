import Foundation
import Observation
import SwiftUI

@MainActor @Observable final class EconomistConnection {
  private(set) var hasKey = false
  private(set) var error: String?
  @ObservationIgnored private let credentials: any MarketCredentialStore
  @ObservationIgnored private let agent: any EconomistAgentAPI
  init(
    credentials: any MarketCredentialStore = AIConnection.credentials,
    agent: any EconomistAgentAPI = EconomistAgent()
  ) {
    self.credentials = credentials
    self.agent = agent
  }
  func load() async {
    do { hasKey = try await credentials.read() != nil } catch {
      self.error = "AI secure storage is unavailable."
    }
  }
  func save(_ input: String) async -> Bool {
    let key = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard AIConnection.validKey(key) else {
      error = "Enter a valid OpenAI API key."
      return false
    }
    do {
      try await credentials.save(key)
      hasKey = true
      error = nil
      return true
    } catch {
      self.error = "The AI key could not be saved securely."
      return false
    }
  }
  func disconnect() async {
    do {
      try await credentials.delete()
      hasKey = false
      error = nil
    } catch { self.error = "The saved AI key could not be removed." }
  }
  func answer(_ question: String, specialist: EconomistSpecialist, evidence: EconomistEvidence)
    async throws -> String
  {
    guard let key = try await credentials.read() else { throw EconomistAgentError.missingKey }
    return try await agent.answer(
      question: question, specialist: specialist, evidence: evidence, key: key)
  }
}
struct EconomistConnectionSheet: View {
  @Bindable var connection: EconomistConnection
  @Environment(\.dismiss) private var dismiss
  @State private var key = ""
  @State private var saving = false
  var body: some View {
    NavigationStack {
      Form {
        Section("GPT-6 Luna") {
          SecureField("OpenAI API key", text: $key).textContentType(.password)
            .textInputAutocapitalization(.never).autocorrectionDisabled()
            .accessibilityIdentifier("openAIKey")
          Button("Save AI connection") {
            saving = true
            Task {
              defer { saving = false }
              if await connection.save(key) {
                key = ""
                dismiss()
              }
            }
          }.disabled(
            saving || !AIConnection.validKey(key.trimmingCharacters(in: .whitespacesAndNewlines)))
          if saving { ProgressView() }
          if let error = connection.error { Text(error).foregroundStyle(.secondary) }
        }
        Section {
          Text(
            "Online answers send your question and selected fictional economy or market evidence to OpenAI. Requests use your API project's quota. The key stays in this device's Keychain."
          )
          .font(.footnote).foregroundStyle(.secondary)
          if connection.hasKey {
            Button("Remove AI key", role: .destructive) {
              Task {
                await connection.disconnect()
                dismiss()
              }
            }
          }
        }
      }.navigationTitle("AI connection").navigationBarTitleDisplayMode(.inline)
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
