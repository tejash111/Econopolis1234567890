import EconopolisCore
import SwiftUI

struct EconomistScreen: View {
  @Bindable var model: SimulationViewModel
  @State private var question = ""
  @State private var response = ""
  @State private var source = ""
  @State private var crisis: CrisisPlan?
  @State private var policy: PolicyPlan?
  @State private var task: Task<Void, Never>?
  @State private var isParsing = false
  private let examples = [
    "Explain the impact of the bank run", "Compare the two worlds",
    "Increase interest rates by 2 percentage points", "Simulate a recession for 30 days",
    "Show me businesses at risk",
  ]
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        WorldPicker(model: model)
        HStack {
          Image(systemName: "sparkles").font(.title2).foregroundStyle(.purple)
          Text("Understand. Explore. Decide.").font(.title2.bold())
        }
        Text("Offline Economist").font(.caption.bold()).foregroundStyle(.purple)
        Text(
          "Questions use recorded evidence. Scenario commands open an editable preview and require confirmation. The Swift engine computes all outcomes."
        ).font(.subheadline).foregroundStyle(.secondary)
        HStack(alignment: .bottom) {
          TextField("Ask about your economy", text: $question, axis: .vertical).lineLimit(1...4)
            .submitLabel(.send).onSubmit(answer).padding(14).background(
              Color.cardSurface, in: RoundedRectangle(cornerRadius: 16)
            ).accessibilityLabel("Question for the economic assistant")
          Button(action: answer) { Image(systemName: "arrow.up").frame(width: 44, height: 44) }
            .buttonStyle(.borderedProminent).tint(.purple).disabled(
              question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isBusy
                || isParsing
            ).accessibilityLabel("Ask economist")
        }
        if isParsing { ProgressView("Reading your request…") }
        if !response.isEmpty {
          VStack(alignment: .leading, spacing: 12) {
            Text(source).font(.caption).foregroundStyle(.secondary)
            Text(response).font(.subheadline).textSelection(.enabled)
          }.padding(16).background(.purple.opacity(0.07), in: RoundedRectangle(cornerRadius: 20))
            .accessibilityElement(children: .combine)
        }
        ForEach(examples, id: \.self) { example in
          Button {
            question = example
            answer()
          } label: {
            HStack {
              Text(example).multilineTextAlignment(.leading)
              Spacer()
              Image(systemName: "arrow.up.left")
            }.frame(minHeight: 44).contentShape(Rectangle())
          }.buttonStyle(.plain).foregroundStyle(.purple)
        }
        NavigationLink {
          InstitutionDirectory(model: model, category: .businesses)
        } label: {
          Label("Explore actual businesses", systemImage: "building.2")
        }.frame(minHeight: 44).contentShape(Rectangle())
        Text(
          "No cloud model or API key. This deterministic parser supports documented commands; optional Foundation Models inference is not enabled. Unsupported requests do not change the economy. This is not real-world financial advice."
        ).font(.caption).foregroundStyle(.secondary)
      }.padding(18)
    }.background(Color.cityNight).navigationTitle("AI Economist").navigationBarTitleDisplayMode(
      .inline
    )
    .sheet(item: $crisis) { CrisisEditor(model: model, initial: $0) }
    .sheet(item: $policy) { PolicyEditor(model: model, initial: $0) }
    .onDisappear {
      task?.cancel()
      isParsing = false
    }
  }
  private func answer() {
    guard let update = model.update, let entities = model.entities else { return }
    task?.cancel()
    isParsing = true
    let prompt = question
    let context = IntentContext(update: update)
    let world = model.world
    task = Task {
      defer { isParsing = false }
      do {
        let intent = try await OfflineEconomistProvider().interpret(prompt, context: context)
        try Task.checkCancellation()
        try SimulationCommandValidator.validate(intent, context: context)
        source = "\(world.rawValue) · day \(update.metrics.day) · deterministic offline mode"
        switch intent {
        case .query(let query, let target):
          let other = world == .a ? model.branches?.b : model.branches?.a
          response = EconomicExplanationService.explain(
            query, update: update, entities: entities, other: other)
          if let target, query == .district,
            let activity = update.metrics.districts.first(where: { $0.id == target }),
            let district = update.districts.first(where: { $0.id == target })
          {
            response +=
              " \(district.name): \(activity.employed) employed residents, \(activity.activeBusinesses) active firms, \(money(activity.consumerSpending)) seller spending today."
          }
        case .crisis(let plan):
          response =
            "A \(plan.kind.rawValue.lowercased()) preview is ready. Review the target, severity and duration before confirming. No state has changed."
          crisis = plan
        case .policy(let plan):
          response =
            "Review \(plan.kind.rawValue.lowercased()) in World B. The preview explains its funding and obligations. No policy has been applied yet."
          policy = plan
        case .unsupported(let message): response = message
        }
      } catch is CancellationError {} catch {
        response =
          "This command could not be validated. Check the target, amount, timing and supported ranges. No action was executed."
      }
    }
  }
}
