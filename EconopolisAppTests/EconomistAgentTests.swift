import Foundation
import Testing

@testable import Econopolis

private actor AgentTransport: MarketHTTPTransport {
  var responses: [MarketHTTPResponse]
  var requests: [URLRequest] = []
  init(_ responses: [MarketHTTPResponse]) { self.responses = responses }
  func send(_ request: URLRequest) throws -> MarketHTTPResponse {
    requests.append(request)
    guard !responses.isEmpty else { throw URLError(.notConnectedToInternet) }
    return responses.removeFirst()
  }
}
private func agentResponse(_ json: String, status: Int = 200) -> MarketHTTPResponse {
  .init(data: Data(json.utf8), status: status, retryAfter: nil)
}
private let agentKey = "sk-unit-test-only-not-a-real-key"
private let evidenceCall =
  #"{"status":"completed","output":[{"type":"function_call","name":"read_evidence","call_id":"call-1","arguments":"{\"section\":\"economy\"}"}]}"#
private let evidenceAnswer =
  #"{"status":"completed","output":[{"type":"message","content":[{"type":"output_text","text":"World A day 7: 900 employed in the recorded snapshot."}]}]}"#
private let agentEvidence = EconomistEvidence(
  world: "World A", day: 7, sections: ["economy": "{\"employed\":900}"])
@Suite("GPT-6 Luna read-only specialists", .serialized)
struct EconomistAgentTests {
  @Test func usesRequestedModelAndReturnsVerifiedToolEvidence() async throws {
    let transport = AgentTransport([agentResponse(evidenceCall), agentResponse(evidenceAnswer)])
    let answer = try await EconomistAgent(transport: transport).answer(
      question: "Brief me", specialist: .economy, evidence: agentEvidence, key: agentKey)
    #expect(answer.contains("900 employed"))
    let requests = await transport.requests
    #expect(requests.count == 2)
    #expect(
      requests.allSatisfy {
        $0.url?.absoluteString == "https://api.openai.com/v1/responses" && $0.httpMethod == "POST"
          && $0.value(forHTTPHeaderField: "Authorization") == "Bearer " + agentKey
      })
    let first = try #require(
      try JSONSerialization.jsonObject(with: requests[0].httpBody!) as? [String: Any])
    #expect(first["model"] as? String == "gpt-6-luna")
    #expect(first["store"] as? Bool == false)
    #expect(first["tool_choice"] as? String == "required")
    let tools = try #require(first["tools"] as? [[String: Any]])
    #expect(tools.count == 1 && tools.first?["name"] as? String == "read_evidence")
    let second = String(decoding: requests[1].httpBody!, as: UTF8.self)
    #expect(second.contains("function_call_output") && second.contains("900"))
  }
  @Test func refusesUnknownToolsAndUnrequestedEvidence() async throws {
    for raw in [
      evidenceCall.replacingOccurrences(of: "read_evidence", with: "apply_policy"),
      evidenceCall.replacingOccurrences(of: "economy", with: "private_keys"),
    ] {
      await #expect(throws: EconomistAgentError.invalidResponse) {
        _ = try await EconomistAgent(transport: AgentTransport([agentResponse(raw)])).answer(
          question: "Help", specialist: .policy, evidence: agentEvidence, key: agentKey)
      }
    }
  }
  @Test func refusesUngroundedFinalAnswerAndIncompleteOutput() async throws {
    for raw in [
      evidenceAnswer, evidenceAnswer.replacingOccurrences(of: "completed", with: "incomplete"),
    ] {
      await #expect(throws: EconomistAgentError.invalidResponse) {
        _ = try await EconomistAgent(transport: AgentTransport([agentResponse(raw)])).answer(
          question: "Help", specialist: .risk, evidence: agentEvidence, key: agentKey)
      }
    }
  }
  @Test func invalidCredentialsAndOversizedQuestionsDoNotSend() async throws {
    let transport = AgentTransport([])
    let agent = EconomistAgent(transport: transport)
    await #expect(throws: EconomistAgentError.missingKey) {
      _ = try await agent.answer(
        question: "Help", specialist: .economy, evidence: agentEvidence, key: "")
    }
    await #expect(throws: EconomistAgentError.invalidResponse) {
      _ = try await agent.answer(
        question: String(repeating: "a", count: 4001), specialist: .economy,
        evidence: agentEvidence, key: agentKey)
    }
    #expect(await transport.requests.isEmpty)
  }
  @Test func billingModelAndAuthenticationErrorsRemainSanitized() async throws {
    for (status, code, expected) in [
      (401, "invalid_api_key", EconomistAgentError.authentication),
      (404, "model_not_found", .modelUnavailable), (429, "insufficient_quota", .quota),
      (429, "rate_limit_exceeded", .rateLimited),
    ] {
      let data = "{\"error\":{\"code\":\"\(code)\",\"message\":\"private-details\"}}"
      await #expect(throws: expected) {
        _ = try await EconomistAgent(
          transport: AgentTransport([agentResponse(data, status: status)])
        ).answer(question: "Help", specialist: .economy, evidence: agentEvidence, key: agentKey)
      }
      #expect(!expected.localizedDescription.contains("private-details"))
    }
  }
  @Test func repeatedToolCallsAreBounded() async throws {
    let transport = AgentTransport(Array(repeating: agentResponse(evidenceCall), count: 4))
    await #expect(throws: EconomistAgentError.turnLimit) {
      _ = try await EconomistAgent(transport: transport).answer(
        question: "Help", specialist: .comparison, evidence: agentEvidence, key: agentKey)
    }
    #expect(await transport.requests.count == 4)
  }
}
