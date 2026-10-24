import EconopolisCore
import SwiftUI

struct JoinEconomyScreen: View {
  @Environment(\.dismiss) private var dismiss
  let model: SimulationViewModel
  @State private var name = ""
  @State private var district = "district-5"
  @State private var archetype = 2
  @State private var deposit: Int64 = 400_000
  @State private var saving = 3_000.0
  @State private var risk = 5_000.0
  var body: some View {
    NavigationStack {
      Form {
        Section("A fictional citizen") {
          TextField("Fictional name", text: $name).textContentType(.nickname)
          Picker("Home district", selection: $district) {
            ForEach(model.update?.districts ?? []) { Text($0.name).tag($0.id) }
          }
          Picker("Archetype", selection: $archetype) {
            ForEach(WorldGenerator.archetypes) { Text($0.name).tag($0.id) }
          }
          Picker("Starting deposits", selection: $deposit) {
            Text("$1,000 · modest").tag(Int64(100_000))
            Text("$4,000 · standard").tag(Int64(400_000))
            Text("$12,000 · comfortable").tag(Int64(1_200_000))
          }
        }
        Section("Behavior") {
          LabeledContent("Savings preference", value: percent(saving / 100))
          Slider(value: $saving, in: 0...8_000, step: 500)
          LabeledContent("Risk tolerance", value: percent(risk / 100))
          Slider(value: $risk, in: 0...10_000, step: 500)
        }
        Section("New shared baseline") {
          Text(
            "Creates a new 1,001-citizen economy with your fictional citizen in both worlds. Existing outcomes are reset. Your bank, employer or benefit source, spending and crisis exposure are real simulation records. The starting deposit adjustment is funded by the treasury. Do not enter personal financial data."
          ).font(.subheadline)
        }
        Button("Create citizen & restart baseline") {
          model.join(
            PlayerProfile(
              name: name, districtID: district, archetypeID: archetype, startingDeposit: deposit,
              savingPreference: Int(saving), riskTolerance: Int(risk)))
          dismiss()
        }.disabled(
          name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || name.count > 40
            || model.isBusy)
      }.navigationTitle("Join the Economy").navigationBarTitleDisplayMode(.inline).toolbar {
        ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
      }
    }
  }
}
