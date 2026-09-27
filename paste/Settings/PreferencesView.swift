import SwiftUI

struct PreferencesView: View {
    @AppStorage(PreferenceKeys.retention) private var retentionRawValue = RetentionPeriod.forever.rawValue
    @AppStorage(PreferenceKeys.useICloudStorage) private var useICloudStorage = false
    @State private var hotkeyCombo: KeyCombo
    @State private var showRestartAlert = false

    let iCloudContainerAvailable: Bool
    let onHotkeyRecordingChanged: (Bool) -> Void
    let onHotkeyApply: (KeyCombo) -> Void
    let onRetentionChanged: () -> Void

    init(
        hotkeyCombo: KeyCombo,
        iCloudContainerAvailable: Bool,
        onHotkeyRecordingChanged: @escaping (Bool) -> Void,
        onHotkeyApply: @escaping (KeyCombo) -> Void,
        onRetentionChanged: @escaping () -> Void = {}
    ) {
        _hotkeyCombo = State(initialValue: hotkeyCombo)
        self.iCloudContainerAvailable = iCloudContainerAvailable
        self.onHotkeyRecordingChanged = onHotkeyRecordingChanged
        self.onHotkeyApply = onHotkeyApply
        self.onRetentionChanged = onRetentionChanged
    }

    var body: some View {
        Form {
            Section(String(localized: "Hotkey")) {
                LabeledContent(String(localized: "Show History Hotkey")) {
                    HotkeyRecorder(
                        current: hotkeyCombo,
                        onRecordingChanged: onHotkeyRecordingChanged,
                        onApply: { combo in
                            hotkeyCombo = combo
                            onHotkeyApply(combo)
                        }
                    )
                    .frame(width: 150, height: 24)
                }
            }
            Section(String(localized: "History")) {
                Picker(String(localized: "Keep History For"), selection: $retentionRawValue) {
                    ForEach(RetentionPeriod.allCases, id: \.rawValue) { period in
                        Text(period.label).tag(period.rawValue)
                    }
                }
                .onChange(of: retentionRawValue) { _, _ in
                    onRetentionChanged()
                }
            }
            Section(String(localized: "Storage")) {
                Toggle(String(localized: "Store in iCloud"), isOn: $useICloudStorage)
                Text(storageFootnote)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 400)
        .fixedSize(horizontal: false, vertical: true)
        .padding()
        .alert(String(localized: "Restart Required"), isPresented: $showRestartAlert) {
            Button(String(localized: "Restart Now")) { Relauncher.relaunch() }
            Button(String(localized: "Later"), role: .cancel) {}
        } message: {
            Text(String(localized: "Changing storage location takes effect after the app restarts."))
        }
        .onChange(of: useICloudStorage) { _, _ in
            showRestartAlert = true
        }
    }

    private var storageFootnote: String {
        if iCloudContainerAvailable {
            String(localized: "History is stored in iCloud Drive. Changing this setting requires restarting the app.")
        } else {
            String(localized: "iCloud storage is unavailable in this build (missing iCloud entitlement). History is stored on this Mac.")
        }
    }
}
