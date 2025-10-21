internal import Combine
import SwiftUI

struct PopupView: View {
    @AppStorage("serverIP") private var serverIP: String?
    @AppStorage("apiToken") private var apiToken: String?
    @AppStorage("syncTimer") private var syncTimerOption: String = "sync_on_open"

    @EnvironmentObject var iconModel: IconModel
    @EnvironmentObject var timerModel: TimerModel
    @EnvironmentObject var updateManager: UpdateManager
    @EnvironmentObject var apiManager: ApiManager
    @EnvironmentObject var recentActivitiesManager: RecentActivitiesManager

    @StateObject private var subscriptionManager = SubscriptionManager()
    @State private var openSection: String?
    @State private var isHovering = false
    @State private var pulse = false
    @State private var searchValue = ""

    let closePopup: () -> Void
    let startRemoteTimerProcess: (Double) -> Void
    private let searchSubject = PassthroughSubject<String, Never>()
    private let options = ["sync_on_open", "sync_every_5_min", "sync_every_15_min", "sync_every_30_min"]

    private func normalizeServerURL(_ input: String) -> String {
        var url = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://" + url
        }

        url = url.replacingOccurrences(of: "^http://", with: "https://", options: .regularExpression)

        guard let comps = URLComponents(string: url) else {
            return url
        }

        var normalized = "https://" + (comps.host ?? "")

        if let port = comps.port {
            normalized += ":\(port)"
        }

        return normalized
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button(action: {
                    if timerModel.isActive ?? false {
                        apiManager.stopActivity()
                            .sink { success in
                                if success {
                                    timerModel.pause()
                                    timerModel.isActive = false
                                    iconModel.setSystemIcon("play.circle")
                                    ChimeManager.shared.play(.pause)
                                } else {
                                    ChimeManager.shared.play(.error)
                                    timerModel.isActive = true
                                }
                            }
                            .store(in: &subscriptionManager.cancellables)
                    } else {
                        apiManager.startActivity()
                            .sink { id in
                                if id != nil {
                                    timerModel.start()
                                    timerModel.isActive = true
                                    iconModel.setSystemIcon("pause.circle")
                                    recentActivitiesManager.add(apiManager.activeActivity)
                                    ChimeManager.shared.play(.start)
                                } else {
                                    ChimeManager.shared.play(.error)
                                    timerModel.isActive = false
                                }
                            }
                            .store(in: &subscriptionManager.cancellables)
                    }
                }) {
                    Image(systemName: (timerModel.isActive ?? false) ? "pause.fill" : "play.fill")
                        .frame(width: 24, height: 24)
                }
                .disabled(apiManager.activeActivity == nil)
                .buttonStyle(AdaptiveButtonStyle(
                    isProminent: !(timerModel.isActive ?? false),
                    isDisabled: apiManager.activeActivity == nil
                ))

                Button(action: {
                    apiManager.stopActivity()
                        .sink { success in
                            if success {
                                apiManager.activeActivity = nil

                                timerModel.stop()
                                timerModel.isActive = false
                                iconModel.setSystemIcon("circle")
                                ChimeManager.shared.play(.stop)
                            } else {
                                ChimeManager.shared.play(.error)
                                timerModel.isActive = true
                            }
                        }
                        .store(in: &subscriptionManager.cancellables)
                }) {
                    Image(systemName: "stop.fill")
                        .frame(width: 24, height: 24)
                }
                .disabled(timerModel.timer == 0)
                .buttonStyle(AdaptiveButtonStyle(
                    isDanger: true,
                    isDisabled: timerModel.timer == 0
                ))

                Text(timerModel.formattedTimePopup)
                    .font(.system(.largeTitle, design: .monospaced))
                    .fontWeight(.bold)
                    .frame(minWidth: 80)

                Spacer()
            }

            HStack(alignment: .center, spacing: 0) {
                Text(apiManager.activeActivity?.name ?? " ")
                    .font(.headline)
                    .foregroundColor(apiManager.activeActivity?.activityColor ?? Color.kimami)
                Text(apiManager.activeActivity != nil ? " / " + (apiManager.activeActivity!.parentTitle ?? "-") : NSLocalizedString("select_activity", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }

            Divider()

            if !recentActivitiesManager.activities.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("recent_activities", comment: ""))
                        .font(.headline)

                    ForEach(recentActivitiesManager.activities, id: \.uniqueId) { activity in
                        ActivityCell(
                            activity: activity,
                            isActive: apiManager.activeActivity?.uniqueId == activity.uniqueId,
                            canBeRemoved: true,
                            setActive: {
                                apiManager.activeActivity = apiManager.activeActivity?.uniqueId == activity.uniqueId ? nil : activity
                            },
                            remove: {
                                recentActivitiesManager.clear(activity)
                            }
                        )
                    }
                }

                Divider()
            }

            TextField(NSLocalizedString("search_activities", comment: ""), text: $searchValue)
                .onChange(of: searchValue) { _, newValue in
                    searchSubject.send(newValue)
                }
                .onAppear {
                    apiManager.bindSearch(to: searchSubject.eraseToAnyPublisher())
                }

            ForEach(apiManager.searchResults, id: \.uniqueId) { activity in
                ActivityCell(
                    activity: activity,
                    isActive: apiManager.activeActivity?.uniqueId == activity.uniqueId,
                    canBeRemoved: false,
                    setActive: {
                        apiManager.activeActivity = apiManager.activeActivity?.uniqueId == activity.uniqueId ? nil : activity
                    },
                    remove: nil
                )
            }

            Divider()

            CollapsibleSection(
                title: NSLocalizedString("settings_title", comment: ""),
                isExpanded: Binding(
                                get: { openSection == "settings" },
                                set: { openSection = $0 ? "settings" : nil }
                            )
            ) {
                VStack(alignment: .leading, spacing: 8) {
                    Spacer(minLength: 8)

                    Text(NSLocalizedString("sync_server_timer", comment: ""))
                        .font(.subheadline)
                    Picker("", selection: $syncTimerOption) {
                        ForEach(options, id: \.self) { option in
                            Text(NSLocalizedString(option, comment: "")).tag(option)
                        }
                    }
                        .labelsHidden()
                        .padding(.leading, 0)
                        .pickerStyle(.menu)
                        .onChange(of: syncTimerOption, { _, _ in
                            apiManager.setupSyncTimer(startRemoteTimerProcess)
                        })

                    Spacer(minLength: 4)

                    Text(NSLocalizedString("autostart_title", comment: ""))
                        .font(.subheadline)
                    LaunchAtLogin.Toggle(NSLocalizedString("autostart", comment: ""))

                    Spacer(minLength: 4)

                    Text(NSLocalizedString("reset_action_title", comment: ""))
                        .font(.subheadline)
                    Button {
                        UserDefaults.standard.set(false, forKey: "appLaunchManager.dontShowAgain")
                        UserDefaults.standard.set(false, forKey: "userIdleManager.dontShowAgain")
                    } label: {
                        Label(NSLocalizedString("reset_alerts", comment: ""), systemImage: "arrow.counterclockwise")
                    }

                    Spacer(minLength: 2)

                    Divider()

                    Spacer(minLength: 2)

                    Text(NSLocalizedString("server_url_label", comment: ""))
                        .font(.subheadline)
                    TextField(NSLocalizedString("server_url_placeholder", comment: ""), text: Binding(
                            get: { serverIP ?? "" },
                            set: { newValue in
                                let cleaned = normalizeServerURL(newValue)
                                serverIP = cleaned.isEmpty ? nil : cleaned
                            }
                        )
                    )
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: serverIP) { _, _ in
                            apiManager.getVersion()
                                .store(in: &subscriptionManager.cancellables)
                        }

                    Spacer(minLength: 4)

                    Text(NSLocalizedString("user_api_token_label", comment: ""))
                        .font(.subheadline)
                    SecureField(NSLocalizedString("user_api_token_placeholder", comment: ""), text: Binding(
                        get: { apiToken ?? "" },
                        set: { newValue in
                            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)

                            if trimmed.isEmpty {
                                apiToken = nil
                            } else {
                                apiToken = trimmed
                            }
                        }
                    ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: apiToken) { _, _ in
                            apiManager.getVersion()
                                .store(in: &subscriptionManager.cancellables)
                        }

                    Spacer(minLength: 4)

                    Text(NSLocalizedString("server_status", value: apiManager.serverVersion, comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .onAppear {
                            apiManager.getVersion()
                                .store(in: &subscriptionManager.cancellables)
                        }
                }
            }

            CollapsibleSection(
                title: NSLocalizedString("about_title", comment: ""),
                isExpanded: Binding(
                                get: { openSection == "about" },
                                set: { openSection = $0 ? "about" : nil }
                            )
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Spacer(minLength: 8)

                    HStack(alignment: .center, spacing: 10) {
                        Button(action: {
                            if let url = URL(string: "https://github.com/Foraum-GmbH/kimai-clock") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Label(NSLocalizedString("github_button", comment: ""), systemImage: "link")
                        }

                        Button(action: {
                            if let url = URL(string: "https://www.kimai.org/de/") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Label(NSLocalizedString("kimai_button", comment: ""), systemImage: "link")
                        }
                    }

                    HStack(alignment: .center, spacing: 10) {
                        Button(action: {
                            if let url = URL(string: "https://paypal.me/undeaDD") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Label(NSLocalizedString("buymeacoffee_button", comment: ""), systemImage: "cup.and.saucer")
                        }

                        Button(action: {
                            if let url = URL(string: "mailto:feedback@foraum.de") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Label(NSLocalizedString("feedback_button", comment: ""), systemImage: "envelope")
                        }
                    }

                    if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                       let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
                        VStack(alignment: .leading, spacing: 12) {
                            Text(String(format: NSLocalizedString("version_text", comment: ""), version, build))
                            Text(NSLocalizedString("copyright_text", comment: ""))
                        }
                    }
                }
                .padding(.horizontal, 4)
            }

            if updateManager.isUpdateAvailable {
                Button {
                    if let url = URL(string: "https://github.com/Foraum-GmbH/kimai-clock/releases/latest") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                        Text(NSLocalizedString("update_available", comment: ""))
                            .font(.caption)
                            .bold()
                    }
                }
                    .foregroundColor(.accentColor)
                    .buttonStyle(.plain)

            }

        }
        .padding(15)
        .frame(width: 320)
        .overlay(
            Button(action: {
                apiManager.stopActivity()
                    .sink { _ in
                        timerModel.stop()
                        timerModel.isActive = false
                        iconModel.setSystemIcon("circle")
                        ChimeManager.shared.play(.stop)
                        NSApplication.shared.terminate(nil)
                    }
                    .store(in: &subscriptionManager.cancellables)
            }) {
                Image(systemName: "power")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(6)
                    .background(
                        Circle()
                            .fill(isHovering ? Color.red : Color.secondary.opacity(0.5))
                    )
            }
            .buttonStyle(PlainButtonStyle())
            .onHover { hovering in
                isHovering = hovering
            }
            .padding(12),
            alignment: .topTrailing
        )
    }
}
