import SwiftUI

// Displays user-configurable preferences backed by UserPreferencesStore (UserDefaults).
// Changes take effect immediately — no Save button needed because each @Published write
// flushes to UserDefaults synchronously on didSet.
struct PreferencesCard: View {
    @ObservedObject var prefs: UserPreferencesStore
    @State private var showResetConfirm = false

    // Typed binding adapter: converts the raw String stored in UserPreferencesStore
    // to/from SearchSortOption for the Picker without making the Services layer
    // depend on ViewModel types.
    private var sortBinding: Binding<SearchSortOption> {
        Binding(
            get: { SearchSortOption(rawValue: prefs.defaultSortOptionRaw) ?? .relevance },
            set: { prefs.defaultSortOptionRaw = $0.rawValue }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {

            // Header
            HStack(spacing: 10) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Preferences")
                        .font(.poppinsSemiBold(14))
                        .foregroundStyle(AppTheme.primaryText)

                    Text("Saved locally on this device")
                        .font(.poppinsRegular(11))
                        .foregroundStyle(AppTheme.secondaryText)
                }
                Spacer()
            }

            Divider()

            // Default sort order — persisted to UserDefaults as raw string
            HStack {
                Label("Default Sort", systemImage: "arrow.up.arrow.down")
                    .font(.poppinsRegular(13))
                    .foregroundStyle(AppTheme.primaryText)
                Spacer()
                Picker("Default Sort", selection: sortBinding) {
                    ForEach(SearchSortOption.allCases) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.menu)
                .font(.poppinsRegular(13))
                .tint(AppTheme.accent)
            }

            Divider()

            // Offline banner toggle — controls the connectivity indicator in Browse
            Toggle(isOn: $prefs.showOfflineBanner) {
                Label("Show Offline Banner", systemImage: "wifi.slash")
                    .font(.poppinsRegular(13))
                    .foregroundStyle(AppTheme.primaryText)
            }
            .tint(AppTheme.accent)

            Divider()

            // Reset button
            Button(role: .destructive) {
                showResetConfirm = true
            } label: {
                HStack {
                    Spacer()
                    Text("Reset to Defaults")
                        .font(.poppinsRegular(13))
                    Spacer()
                }
            }
            .confirmationDialog(
                "Reset all preferences to their default values?",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Reset", role: .destructive) {
                    prefs.resetToDefaults()
                }
                Button("Cancel", role: .cancel) {}
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.cardBackground)
                .shadow(color: .black.opacity(0.05), radius: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }
}
