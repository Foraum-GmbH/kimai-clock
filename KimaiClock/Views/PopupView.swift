internal import Combine
import LaunchAtLogin
import SwiftUI

struct PopupView: View {
    @AppStorage("serverIP") private var serverIP: String?
    @AppStorage("apiToken") private var apiToken: String?

    @EnvironmentObject var iconModel: IconModel
    @EnvironmentObject var timerModel: TimerModel
    let closePopup: () -> Void

    @State private var isPlaying = false
    @State private var isHovering = false

    @State private var searchValue = ""
    private let searchSubject = PassthroughSubject<String, Never>()

    @StateObject private var apiManager = ApiManager()
    @StateObject private var recentActivitiesManager = RecentActivitiesManager()
    @StateObject private var subscriptionManager = SubscriptionManager()

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
                    if isPlaying {
                        apiManager.stopActivity()
                            .sink { success in
                                if success {
                                    timerModel.pause()
                                    isPlaying = false
                                    iconModel.setSystemIcon("play.circle")
                                    ChimeManager.shared.play(.pause)
                                } else {
                                    ChimeManager.shared.play(.error)
                                    isPlaying = true
                                }
                            }
                            .store(in: &subscriptionManager.cancellables)
                    } else {
                        apiManager.startActivity()
                            .sink { id in
                                if let _ = id {
                                    timerModel.start()
                                    isPlaying = true
                                    iconModel.setSystemIcon("pause.circle")
                                    recentActivitiesManager.add(apiManager.activeActivity)
                                    ChimeManager.shared.play(.start)
                                } else {
                                    ChimeManager.shared.play(.error)
                                    isPlaying = false
                                }
                            }
                            .store(in: &subscriptionManager.cancellables)
                    }
                }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .frame(width: 24, height: 24)
                }
                .disabled(apiManager.activeActivity == nil)
                .buttonStyle(AdaptiveButtonStyle(
                    isProminent: !isPlaying,
                    isDisabled: apiManager.activeActivity == nil
                ))

                Button(action: {
                    apiManager.stopActivity()
                        .sink { success in
                            if success {
                                apiManager.activeActivity = nil

                                timerModel.stop()
                                isPlaying = false
                                iconModel.setSystemIcon("circle")
                                ChimeManager.shared.play(.stop)
                            } else {
                                ChimeManager.shared.play(.error)
                                isPlaying = true
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

            CollapsibleSection(title: NSLocalizedString("settings_title", comment: "")) {
                VStack(alignment: .leading, spacing: 8) {
                    Spacer(minLength: 8)

                    LaunchAtLogin.Toggle(NSLocalizedString("autostart", comment: ""))

                    Spacer(minLength: 8)

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

                    Spacer(minLength: 8)

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

                    Spacer(minLength: 8)

                    Text(NSLocalizedString("server_status", value: apiManager.serverVersion, comment: ""))
                        .font(.subheadline)
                        .onAppear {
                            apiManager.getVersion()
                                .store(in: &subscriptionManager.cancellables)
                        }
                }
            }

            CollapsibleSection(title: NSLocalizedString("about_title", comment: "")) {
                VStack(alignment: .leading, spacing: 12) {
                    Spacer(minLength: 8)

                    HStack(alignment: .center, spacing: 10) {
                        Button(action: {
                            if let url = URL(string: "https://github.com/Foraum-GmbH/kimai-clock") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Text(NSLocalizedString("github_button", comment: ""))
                        }

                        Button(action: {
                            if let url = URL(string: "https://paypal.me/undeaDD") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Text(NSLocalizedString("buymeacoffee_button", comment: ""))
                        }

                        Button(action: {
                            if let url = URL(string: "mailto:feedback@foraum.de") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Text(NSLocalizedString("feedback_button", comment: ""))
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
        }
        .padding(15)
        .frame(width: 320)
        .overlay(
            Button(action: {
                apiManager.stopActivity()
                    .sink { _ in
                        timerModel.stop()
                        isPlaying = false
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
