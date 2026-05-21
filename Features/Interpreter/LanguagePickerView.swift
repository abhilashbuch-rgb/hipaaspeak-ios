import SwiftUI

struct LanguagePickerView: View {
    @Binding var source: SupportedLanguage
    @Binding var target: SupportedLanguage
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("You speak") {
                    ForEach(SupportedLanguage.allCases) { lang in
                        Button {
                            if lang != target {
                                source = lang
                            }
                        } label: {
                            HStack {
                                Text(lang.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if source == lang {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .disabled(lang == target)
                    }
                }

                Section("Patient speaks") {
                    ForEach(SupportedLanguage.allCases) { lang in
                        Button {
                            if lang != source {
                                target = lang
                            }
                        } label: {
                            HStack {
                                Text(lang.displayName)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if target == lang {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                        .disabled(lang == source)
                    }
                }
            }
            .navigationTitle("Languages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
