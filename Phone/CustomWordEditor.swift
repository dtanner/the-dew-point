import SwiftUI
import WeatherData

/// Sheet for entering, editing, or clearing the custom word for one band.
/// Length is capped live and Save is gated on the same validation the model
/// applies, so a rejected word can't be saved silently.
struct CustomWordEditor: View {
    let defaultWord: String
    let isCustomized: Bool
    /// Where the band sits, e.g. "65–74°, dew point 63°+", when it isn't the
    /// current reading's band.
    let bandRange: String?
    let onSave: (String) -> Void
    let onReset: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @FocusState private var focused: Bool

    init(defaultWord: String, initialText: String, isCustomized: Bool, bandRange: String? = nil,
         onSave: @escaping (String) -> Void, onReset: @escaping () -> Void) {
        self.defaultWord = defaultWord
        self.isCustomized = isCustomized
        self.bandRange = bandRange
        self.onSave = onSave
        self.onReset = onReset
        _text = State(initialValue: initialText)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(defaultWord, text: $text)
                        .font(.title3.weight(.semibold))
                        .focused($focused)
                        .submitLabel(.done)
                        .onChange(of: text) { _, new in
                            if new.count > ComfortWord.maxLength {
                                text = String(new.prefix(ComfortWord.maxLength))
                            }
                        }
                        .onSubmit(save)
                } header: {
                    Text("Instead of “\(defaultWord)”, say")
                } footer: {
                    if let bandRange {
                        Text("Applies whenever conditions fall in this band: \(bandRange).")
                    } else {
                        Text("Applies whenever conditions fall in this band.")
                    }
                }
                if isCustomized {
                    Section {
                        Button("Reset to \(defaultWord)", role: .destructive) {
                            onReset()
                            dismiss()
                        }
                    }
                }
            }
            .navigationTitle("Your word")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .disabled(ComfortWord.validate(text) == nil)
                }
            }
            .onAppear { focused = true }
        }
    }

    private func save() {
        guard ComfortWord.validate(text) != nil else { return }
        onSave(text)
        dismiss()
    }
}
