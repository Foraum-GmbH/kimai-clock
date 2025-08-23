import SwiftUI
internal import Combine
import LaunchAtLogin

struct PopupView: View {
    @AppStorage("serverIP") private var serverIP: String?
    @AppStorage("apiToken") private var apiToken: String?

    @EnvironmentObject var iconModel: IconModel
    @EnvironmentObject var timerModel: TimerModel
    let closePopup: () -> Void

    @State private var isPlaying = false
    @State private var activeActivity: Activity?

    @State private var searchValue = ""
    private let searchSubject = PassthroughSubject<String, Never>()

    @StateObject private var apiManager = ApiManager()
    @StateObject private var recentActivitiesManager = RecentActivitiesManager()
    @StateObject private var subscriptionManager = SubscriptionManager()

    @MainActor
    private func fetchVersion() {
        apiManager.getVersion()
            .receive(on: DispatchQueue.main) // ensures main thread
            .sink { [weak apiManager] value in
                apiManager?.serverVersion = value
            }
            .store(in: &subscriptionManager.cancellables)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Button(action: {
                    if isPlaying {
                        apiManager.stopActivity(activity: activeActivity)
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
                        apiManager.startActivity(activity: activeActivity)
                            .sink { success in
                                if success {
                                    timerModel.start()
                                    isPlaying = true
                                    iconModel.setSystemIcon("pause.circle")
                                    recentActivitiesManager.add(activeActivity)
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
                .disabled(activeActivity == nil)
                .buttonStyle(AdaptiveButtonStyle(
                    isProminent: !isPlaying,
                    isDisabled: activeActivity == nil
                ))

                Button(action: {
                    apiManager.stopActivity(activity: activeActivity)
                        .sink { success in
                            if success {
                                timerModel.stop()
                                isPlaying = false
                                activeActivity = nil
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
                Text(activeActivity?.name ?? " ")
                    .font(.headline)
                    .foregroundColor(activeActivity?.activityColor ?? Color.kimami)
                Text(activeActivity != nil ? " / " + activeActivity!.parentTitle : NSLocalizedString("select_activity", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
            }

            Divider()

            if (!recentActivitiesManager.activities.isEmpty) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("recent_activities", comment: ""))
                        .font(.headline)

                    ForEach(recentActivitiesManager.activities) { activity in
                        ActivityCell(
                            activity: activity,
                            isActive: activeActivity?.id == activity.id,
                            canBeRemoved: true,
                            setActive: {
                                activeActivity = activeActivity?.id == activity.id ? nil : activity
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

            ForEach(apiManager.searchResults) { activity in
                ActivityCell(
                    activity: activity,
                    isActive: activeActivity?.id == activity.id,
                    canBeRemoved: false,
                    setActive: {
                        activeActivity = activeActivity?.id == activity.id ? nil : activity
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
                            set: { serverIP = $0.isEmpty ? nil : $0 }
                        )
                    )
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: serverIP) { _, _ in fetchVersion() }

                    Spacer(minLength: 8)

                    Text(NSLocalizedString("user_api_token_label", comment: ""))
                        .font(.subheadline)
                    SecureField(NSLocalizedString("user_api_token_placeholder", comment: ""), text: Binding(
                        get: { apiToken ?? "" },
                        set: { apiToken = $0.isEmpty ? nil : $0 }
                    ))
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: apiToken) { _, _ in fetchVersion() }

                    Spacer(minLength: 8)

                    Text(NSLocalizedString("server_status", value: apiManager.serverVersion, comment: ""))
                        .font(.subheadline)
                        .onAppear {
                            fetchVersion()
                        }
                }
            }

            CollapsibleSection(title: NSLocalizedString("about_title", comment: "")) {
                VStack(alignment: .leading, spacing: 12) {
                    Spacer(minLength: 8)

                    HStack(alignment: .center, spacing: 10) {
                        Button(action: {
                            if let url = URL(string: "https://github.com/Foraum-GmbH") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Text(NSLocalizedString("github_button", comment: ""))
                        }

                        Button(action: {
                            if let url = URL(string: "https://www.buymeacoffee.com/foraum") {
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
                        Text(String(format: NSLocalizedString("version_text", comment: ""), version, build))
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(15)
        .frame(width: 320)
    }
}
