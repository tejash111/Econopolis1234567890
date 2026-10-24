import EconopolisCore
import SwiftUI

struct EconomistScreen: View {
  @Bindable var model: SimulationViewModel
  @Environment(CryptoViewModel.self) private var market
  @State private var connection = EconomistConnection()
  @State private var online = true
  @State private var showConnection = false
  @State private var specialist: EconomistSpecialist = .economy
  @State private var generation = 0
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
    ScrollViewReader { proxy in
      List {
        Section {
          WorldPicker(model: model)
        }
        Section {
          Label(
            online && connection.hasKey ? "GPT-6 Luna Economist" : "Offline Economist",
            systemImage: "sparkles"
          ).font(.headline).foregroundStyle(
            .primary)
          Text(
            "Ask about recorded results, or describe a scenario to preview it. The simulation calculates every financial outcome."
          )
          .font(.subheadline).foregroundStyle(.secondary)
          HStack(alignment: .bottom, spacing: 12) {
            TextField("Ask about your economy", text: $question, axis: .vertical)
              .font(.body).lineLimit(1...5).submitLabel(.send).onSubmit(answer)
              .frame(minHeight: 44).accessibilityLabel("Question for the economic assistant")
            Button(action: answer) {
              Image(systemName: "arrow.up").font(.body.weight(.semibold)).frame(
                width: 44, height: 44)
            }.buttonStyle(.borderedProminent).buttonBorderShape(.circle)
              .disabled(
                question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isBusy
                  || isParsing
              )
              .accessibilityLabel("Ask economist")
          }
          if isParsing { ProgressView("Reading your request…") }
        } footer: {
          Text("Scenario commands require your confirmation. Questions never change the economy.")
        }
        Section("AI specialists") {
          Toggle("Online specialists", isOn: $online).disabled(!connection.hasKey)
          Button(connection.hasKey ? "Manage AI connection" : "Connect GPT-6 Luna") {
            showConnection = true
          }
          .accessibilityIdentifier("aiConnection")
          if online && connection.hasKey {
            ForEach(EconomistSpecialist.allCases) { role in
              Button {
                specialist = role
                question = role.question
                answer()
              } label: {
                Label(role.rawValue, systemImage: "sparkles").frame(minHeight: 44)
              }.disabled(model.isBusy || isParsing)
            }
            Text(
              "Read-only specialists use the current evidence snapshot. Generated explanations can contain errors; scenario changes still require local confirmation."
            )
            .font(.caption).foregroundStyle(.secondary)
          }
        }
        if !response.isEmpty {

          Section("Recorded evidence") {
            VStack(alignment: .leading, spacing: 12) {
              Text(source).font(.caption).foregroundStyle(.secondary)
              Text(response).font(.body).lineSpacing(3).textSelection(.enabled)
            }.padding(.vertical, 4).accessibilityElement(children: .combine).id(
              "economist-evidence")
          }
        }
        Section("Try asking") {
          ForEach(examples, id: \.self) { example in
            Button {
              question = example
              answer()
            } label: {
              HStack(spacing: 12) {
                Text(example).font(.body).foregroundStyle(.primary).multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: "arrow.up.left").font(.subheadline).foregroundStyle(.blue)
              }.frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel(example)
          }
        }
        Section {
          NavigationLink {
            InstitutionDirectory(model: model, category: .businesses)
          } label: {
            Label("Explore actual businesses", systemImage: "building.2")
          }
        } footer: {
          Text(
            "Offline mode works without a key. Optional online specialists use GPT-6 Luna with read-only evidence tools. The Swift simulator calculates outcomes; confirmed scenario previews control all economic changes."
          )
        }
      }.economicGroupedList().navigationTitle("AI Economist").navigationBarTitleDisplayMode(
        .large
      )
      .scrollDismissesKeyboard(.interactively)
      .task { await connection.load() }
      .sheet(isPresented: $showConnection) { EconomistConnectionSheet(connection: connection) }
      .sheet(item: $crisis) { CrisisEditor(model: model, initial: $0) }
      .sheet(item: $policy) { PolicyEditor(model: model, initial: $0) }
      .onChange(of: response) { _, value in
        if !value.isEmpty { proxy.scrollTo("economist-evidence", anchor: .top) }
      }
      .onChange(of: model.world) { _, _ in
        generation += 1
        task?.cancel()
        isParsing = false
      }
      .onChange(of: online) { _, _ in
        generation += 1
        task?.cancel()
        isParsing = false
      }
      .onChange(of: connection.hasKey) { _, _ in
        generation += 1
        task?.cancel()
        isParsing = false
      }
      .onChange(of: model.update?.seed) { _, _ in
        generation += 1
        task?.cancel()
        isParsing = false
      }
      .onChange(of: model.update?.metrics.day) { _, _ in
        generation += 1
        task?.cancel()
        isParsing = false
      }
      .onDisappear {
        generation += 1
        task?.cancel()
        isParsing = false
      }
    }
  }
  private func answer() {
    guard let update = model.update, let entities = model.entities else { return }
    task?.cancel()
    generation += 1
    let token = generation
    isParsing = true
    let prompt = question
    let context = IntentContext(update: update)
    let world = model.world
    task = Task {
      defer { if generation == token { isParsing = false } }
      do {
        let intent = try await OfflineEconomistProvider().interpret(prompt, context: context)
        try Task.checkCancellation()
        try SimulationCommandValidator.validate(intent, context: context)
        source = "\(world.rawValue) · day \(update.metrics.day) · deterministic offline mode"
        var canExplainOnline = false
        switch intent {
        case .query(let query, let target):
          canExplainOnline = true
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
        case .unsupported(let message):
          response = message
          canExplainOnline = true
        }
        if canExplainOnline && online && connection.hasKey {
          let fallback = response
          let evidence = try EconomistEvidence.build(
            update: update, entities: entities,
            branches: model.branches, world: world,
            market: market.watchlist.compactMap { market.records[$0]?.quote }, question: prompt)
          do {
            let generated = try await connection.answer(
              prompt, specialist: specialist, evidence: evidence)
            try Task.checkCancellation()
            guard generation == token, model.world == world, model.update?.seed == update.seed
            else { return }
            source =
              "GPT-6 Luna · \(specialist.rawValue) · \(world.rawValue) day \(update.metrics.day) · AI interpretation"
            response = generated
          } catch is CancellationError { return } catch {
            guard generation == token else { return }
            let message =
              (error as? EconomistAgentError)?.localizedDescription ?? "Online AI is unreachable."
            source = "Offline fallback · \(world.rawValue) · day \(update.metrics.day)"
            response = message + "\n\n" + fallback
          }
        }
      } catch is CancellationError {} catch {
        response =
          "This command could not be validated. Check the target, amount, timing and supported ranges. No action was executed."
      }
    }
  }
}
