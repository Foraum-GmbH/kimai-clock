internal import Combine
import SwiftUI

struct PopupView: View {
    @AppStorage("serverIP") private var serverIP: String?
    @AppStorage("isSecure") private var isSecure: Bool?
    @AppStorage("apiToken") private var apiToken: String?
    @AppStorage("syncTimer") private var syncTimerOption: String = "sync_on_open"
    @AppStorage("idleThreshold") private var idleThreshold: String = ""

    @EnvironmentObject var iconModel: IconModel
    @EnvironmentObject var timerModel: TimerModel
    @EnvironmentObject var updateManager: UpdateManager
    @EnvironmentObject var apiManager: ApiManager
    @EnvironmentObject var recentActivitiesManager: RecentActivitiesManager
    @EnvironmentObject var popoverState: PopoverState

    @StateObject private var subscriptionManager = SubscriptionManager()
    @State private var openSection: String? = "recent_activities"
    @State private var isHovering = false
    @State private var pulse = false
    @State private var searchValue = ""
    @FocusState private var isSearchFocused: Bool
    @State private var showDescriptionAlert = false
    @State private var showEditDescriptionAlert = false
    @State private var timesheetDescription = ""
    @State private var contextMenuActionTaken = false
    @State private var isContextMenuOpen = false

    let closePopup: () -> Void
    let startRemoteTimerProcess: (Double) -> Void
    private let searchSubject = PassthroughSubject<String, Never>()
    private let options = ["sync_on_open", "sync_every_5_min", "sync_every_15_min", "sync_every_30_min"]

    private var isTimerRunning: Bool {
        (timerModel.isActive ?? false) || timerModel.timer != 0
    }

    /// Suggestions for an empty search field only while it is focused
    private var visibleSearchResults: [Activity] {
        searchValue.isEmpty && !isSearchFocused ? [] : apiManager.searchResults
    }

    private var tagMenu: some View {
        Menu {
            ForEach(apiManager.tagOptions, id: \.self) { tag in
                Toggle(tag, isOn: Binding(
                    get: { apiManager.sessionTags.contains(tag) },
                    set: { isOn in
                        if isOn {
                            apiManager.sessionTags.append(tag)
                        } else {
                            apiManager.sessionTags.removeAll { $0 == tag }
                        }
                    }
                ))
            }
        } label: {
            // the default menu style hugs its title, a plain button label can fill the width
            HStack(spacing: 4) {
                Text(apiManager.sessionTags.isEmpty
                     ? NSLocalizedString("select_tags", comment: "")
                     : apiManager.sessionTags.joined(separator: ", "))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .foregroundStyle(apiManager.sessionTags.isEmpty ? .secondary : .primary)
                Spacer(minLength: 0)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color(nsColor: .separatorColor))
            )
            .contentShape(Rectangle())
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        // same rules as the description
        .disabled(timerModel.isActive == true || apiManager.activeActivity == nil)
    }

    private var shouldShowDescription: Bool {
        apiManager.activeActivity != nil || isTimerRunning
    }

    private func normalizeServerURL(_ input: String) -> (url: String, isSecure: Bool) {
        var isSecure = true
        var url = input.trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        // Add https:// if no scheme provided
        if !url.hasPrefix("http://") && !url.hasPrefix("https://") {
            url = "https://" + url
        }

        // Check if user explicitly specified http://
        if url.hasPrefix("http://") {
            isSecure = false
        }

        guard let comps = URLComponents(string: url) else {
            return (url, isSecure)
        }

        // build normalized url
        let scheme = comps.scheme ?? "https"
        var normalized = scheme + "://" + (comps.host ?? "")
        normalized += comps.port.map { ":\($0)" } ?? ""
        return (normalized, isSecure)
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
                .accessibilityLabel((timerModel.isActive ?? false) ? "Pause timer" : "Start timer")
                .disabled(apiManager.activeActivity == nil)
                .buttonStyle(AdaptiveButtonStyle(
                    isProminent: !(timerModel.isActive ?? false),
                    isDisabled: apiManager.activeActivity == nil
                ))
                .contextMenu {
                    Button {
                        contextMenuActionTaken = true
                        timesheetDescription = apiManager.sessionDescription
                        showEditDescriptionAlert = true
                    } label: {
                        Label("Edit description", systemImage: "pencil")
                    }
                    .disabled(timerModel.timer == 0)
                }

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
                .accessibilityLabel("Stop timer")
                .disabled(timerModel.timer == 0)
                .buttonStyle(AdaptiveButtonStyle(
                    isDanger: true,
                    isDisabled: timerModel.timer == 0
                ))
                .contextMenu {
                    Button {
                        contextMenuActionTaken = true
                        timesheetDescription = apiManager.sessionDescription
                        showEditDescriptionAlert = true
                    } label: {
                        Label("Edit description", systemImage: "pencil")
                    }
                    .disabled(timerModel.timer == 0)

                    Button {
                        contextMenuActionTaken = true
                        timesheetDescription = apiManager.sessionDescription
                        showDescriptionAlert = true
                    } label: {
                        Label("Stop with description", systemImage: "stop.fill")
                    }
                    .disabled(timerModel.timer == 0)

                    Button(role: .destructive) {
                        contextMenuActionTaken = true
                        apiManager.deleteTimesheet()
                            .sink { success in
                                if success {
                                    apiManager.activeActivity = nil
                                    timerModel.stop()
                                    timerModel.isActive = false
                                    iconModel.setSystemIcon("circle")
                                    ChimeManager.shared.play(.stop)
                                } else {
                                    ChimeManager.shared.play(.error)
                                }
                            }
                            .store(in: &subscriptionManager.cancellables)
                    } label: {
                        Label("Discard & delete", systemImage: "trash")
                    }
                    // while paused there is no running timesheet to delete
                    .disabled(timerModel.isActive != true)
                }
                .alert("Stop with description", isPresented: $showDescriptionAlert) {
                    TextField("Description", text: $timesheetDescription)
                    Button("Stop") {
                        apiManager.updateTimesheetDescription(timesheetDescription)
                            .flatMap { _ in apiManager.stopActivity() }
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
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Add a note before stopping the timer.")
                }
                .alert("Edit description", isPresented: $showEditDescriptionAlert) {
                    TextField("Description", text: $timesheetDescription)
                    Button("Save") {
                        apiManager.updateTimesheetDescription(timesheetDescription)
                            .sink { success in
                                if !success {
                                    ChimeManager.shared.play(.error)
                                }
                            }
                            .store(in: &subscriptionManager.cancellables)
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Update the description for the running timer.")
                }

                Text(timerModel.formattedTimePopup)
                    .font(.system(.largeTitle, design: .monospaced))
                    .fontWeight(.bold)
                    .frame(minWidth: 80)
                    .help(timerModel.formattedTimeStartedAt)

                Spacer()
            }

            HStack(alignment: .center, spacing: 0) {
                Text(apiManager.activeActivity?.name ?? " ")
                    .font(.headline)
                    .foregroundColor(apiManager.activeActivity?.activityColor ?? Color.kimai)
                    .lineLimit(1)
                    .layoutPriority(1)
                Text(apiManager.activeActivity != nil ? " / " + (apiManager.activeActivity!.parentTitle ?? "-") : NSLocalizedString("select_activity", comment: ""))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }

            if shouldShowDescription {
                VStack(alignment: .leading, spacing: 5) {
                    Text(NSLocalizedString("description_placeholder", comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField(
                        apiManager.sessionDescription.isEmpty
                            ? NSLocalizedString("description_placeholder", comment: "")
                            : apiManager.sessionDescription,
                        text: $apiManager.pendingDescription
                    )
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        // editable before start and while paused (applies to the resumed timesheet)
                        .disabled(timerModel.isActive == true || apiManager.activeActivity == nil)

                    // tags are global in Kimai -> no dropdown at all on servers without any
                    if !apiManager.tagOptions.isEmpty {
                        tagMenu
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Divider()

            CollapsibleSection(
                title: NSLocalizedString("activities", comment: ""),
                isExpanded: Binding(
                                get: { openSection == "recent_activities" },
                                set: { openSection = $0 ? "recent_activities" : nil }
                            )
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    Spacer(minLength: 2)

                    if !recentActivitiesManager.activities.isEmpty {
                        Text(NSLocalizedString("recent_activities", comment: ""))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        ForEach(recentActivitiesManager.activities, id: \.uniqueId) { activity in
                            ActivityCell(
                                activity: activity,
                                isActive: apiManager.activeActivity?.uniqueId == activity.uniqueId,
                                canBeRemoved: true,
                                setActive: {
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        apiManager.activeActivity = apiManager.activeActivity?.uniqueId == activity.uniqueId ? nil : activity
                                    }
                                },
                                remove: {
                                    recentActivitiesManager.clear(activity)
                                }
                            )
                        }

                        Divider()
                    }

                    Text(NSLocalizedString("search_activities", comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    TextField(NSLocalizedString("search_activities", comment: ""), text: $searchValue)
                        .focused($isSearchFocused)
                        .onChange(of: searchValue) { _, newValue in
                            searchSubject.send(newValue)
                        }
                        // an empty, focused field suggests the first activities as a hint what to search for
                        .onChange(of: isSearchFocused) { _, focused in
                            if focused && searchValue.isEmpty {
                                searchSubject.send("")
                            }
                        }
                        .onAppear {
                            apiManager.bindSearch(to: searchSubject.eraseToAnyPublisher())
                        }

                    ForEach(visibleSearchResults, id: \.uniqueId) { activity in
                        ActivityCell(
                            activity: activity,
                            isActive: apiManager.activeActivity?.uniqueId == activity.uniqueId,
                            canBeRemoved: false,
                            setActive: {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    apiManager.activeActivity = apiManager.activeActivity?.uniqueId == activity.uniqueId ? nil : activity
                                }
                            },
                            remove: nil
                        )
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: shouldShowDescription)
            }

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
                        .foregroundStyle(.secondary)
                    HStack(spacing: 6) {
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

                        // same as "fetch on open", but on demand and regardless of the selected option
                        Button {
                            apiManager.checkForRemoteTimer(force: true, startRemoteTimerProcess)
                        } label: {
                            Image(systemName: "arrow.clockwise")
                        }
                        .help(NSLocalizedString("fetch_server_timer_now", comment: ""))
                        .accessibilityLabel(NSLocalizedString("fetch_server_timer_now", comment: ""))
                    }

                    Spacer(minLength: 2)

                    Text(NSLocalizedString("autostart_title", comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    LaunchAtLogin.Toggle(NSLocalizedString("autostart", comment: ""))

                    Spacer(minLength: 2)

                    Text(NSLocalizedString("idle_timer_label", comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ZStack(alignment: .trailing) {
                        TextField(NSLocalizedString("idle_timer_placeholder", comment: ""), text: Binding(
                                get: { idleThreshold },
                                set: { newValue in
                                    let filtered = newValue.filter { $0.isNumber }
                                    if filtered.isEmpty {
                                        idleThreshold = ""
                                        return
                                    }
                                    if let minutes = Int(filtered), minutes > 0, minutes <= 480 {
                                        idleThreshold = String(minutes)
                                    }
                                }
                            )
                        )
                            .textFieldStyle(RoundedBorderTextFieldStyle())

                        if !idleThreshold.isEmpty {
                            Text(NSLocalizedString("minutes_suffix", comment: ""))
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.trailing, 10)
                        }
                     }

                    Spacer(minLength: 2)

                    Text(NSLocalizedString("reset_action_title", comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
                        .foregroundStyle(.secondary)
                    TextField(NSLocalizedString("server_url_placeholder", comment: ""), text: Binding(
                            get: { serverIP ?? "" },
                            set: { newValue in
                                let (cleaned, secureURL) = normalizeServerURL(newValue)
                                serverIP = cleaned.isEmpty ? nil : cleaned
                                isSecure = secureURL
                            }
                        )
                    )
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: serverIP) { _, _ in
                            apiManager.getVersion()
                                .store(in: &subscriptionManager.cancellables)
                        }

                    if isSecure == false {
                        HStack(spacing: 4) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.caption)
                            Text(NSLocalizedString("insecure_connection_warning", comment: ""))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 2)
                    }

                    Spacer(minLength: 2)

                    Text(NSLocalizedString("user_api_token_label", comment: ""))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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

                    Spacer(minLength: 2)

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
        .onChange(of: popoverState.isPresented) { _, isPresented in
            openSection = "recent_activities"
            // tags may have been added in Kimai meanwhile
            if isPresented {
                apiManager.fetchTags()
            }
            // the popover may hand the first responder to the search field, suggestions only on a real click
            isSearchFocused = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSMenu.didBeginTrackingNotification)) { _ in
            isContextMenuOpen = NSEvent.opensContextMenu(NSApp.currentEvent)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSMenu.didEndTrackingNotification)) { _ in
            // only a context menu dismissed without an action closes the popover, dropdowns never do
            if isContextMenuOpen && !contextMenuActionTaken {
                closePopup()
            }
            isContextMenuOpen = false
            contextMenuActionTaken = false
        }
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
            .accessibilityLabel("Quit KimaiClock")
            .buttonStyle(PlainButtonStyle())
            .onHover { hovering in
                isHovering = hovering
            }
            .padding(12),
            alignment: .topTrailing
        )
    }
}
