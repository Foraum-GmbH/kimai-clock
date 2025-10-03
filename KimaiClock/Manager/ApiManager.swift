internal import Combine
import SwiftUI

struct Activity: Identifiable, Codable, Equatable {
    let id: Int
    let name: String

    // Optional Properties
    let parentTitle: String?
    let project: Int?
    let color: String?

    // Computed Properties
    var activityColor: Color {
        if let hex = color, let color = Color(hex: hex) {
            return color
        } else {
            return Color.kimami
        }
    }

    var uniqueId: String {
        if let project = project {
            return "\(id)-\(project)"
        } else {
            return "\(id)-0"
        }
    }

    var timesheetId: Int?
}

struct Project: Decodable {
    let id: Int
    let name: String
}

struct ServerVersion: Codable {
    let versionId: Int
    let copyright: String
}

struct Timesheet: Codable {
    let activity: Activity
}

@MainActor
class ApiManager: ObservableObject {
    @AppStorage("apiToken") private var apiToken: String?
    @AppStorage("serverIP") public var serverIP: String?
    @AppStorage("syncTimer") private var syncTimerOption: String?

    @Published var searchResults: [Activity] = []
    @Published var serverVersion: String = "..."
    @Published var activeActivity: Activity?

    private var activeTimesheetId: Int?
    private var cancellables = Set<AnyCancellable>()
    private var syncTimer: DispatchSourceTimer?

    private let session: URLSession = {
        let tempSession = URLSession.shared
        tempSession.configuration.urlCache = nil
        tempSession.configuration.httpCookieStorage = nil
        tempSession.configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        tempSession.configuration.httpCookieAcceptPolicy = .never
        return tempSession
    }()

    // MARK: - Timer setup

    func setupSyncTimer() {
        syncTimer?.cancel()
        syncTimer = nil

        guard let option = syncTimerOption,
              let interval = intervalForOption(option) else { return }

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in
            self?.checkForRemoteTimer(false)
        }
        timer.resume()
        syncTimer = timer

        print("Sync timer started with interval \(interval) seconds (\(option))")
    }

    private func intervalForOption(_ option: String) -> TimeInterval? {
        switch option {
        case "sync_every_5_min": return 5 * 60
        case "sync_every_15_min": return 15 * 60
        case "sync_every_30_min": return 30 * 60
        default: return nil
        }
    }

    func startAtLaunch() {
        // check timer regardless of option on launch
        checkForRemoteTimer(true)
        checkForRemoteTimer(false)

        setupSyncTimer()
    }

    // MARK: - API methods

    func checkForRemoteTimer(_ onOpen: Bool = false) {
        if activeActivity != nil { return }
        if syncTimerOption == "sync_on_open" && !onOpen { return }
        if syncTimerOption != "sync_on_open" && onOpen { return }

        guard let baseURL = serverIP,
              let url = URL(string: "\(baseURL)/api/timesheets/active") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiToken ?? "")", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36 KimaiClock", forHTTPHeaderField: "User-Agent")

        session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: [Timesheet].self, decoder: JSONDecoder())
            .map { $0.first }
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Failed to fetch remote timer:", error)
                }
            }, receiveValue: { firstTimer in
                if let timer = firstTimer {
                    // TODO: parse & start timer
                    print("Remote timer found: \(timer)")
                } else {
                    print("No Remove timer found")
                }
            })
            .store(in: &cancellables)
    }

    func getVersion() -> AnyCancellable {
        guard let baseURL = serverIP,
              let url = URL(string: "\(baseURL)/api/version") else {
            return Just("404")
                .eraseToAnyPublisher()
                .sink { [weak self] value in
                    self?.serverVersion = "Server: " + value
                }
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiToken ?? "")", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36 KimaiClock", forHTTPHeaderField: "User-Agent")

        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: ServerVersion.self, decoder: JSONDecoder())
            .map { version in
                version.versionId < 20000 ? "unsupported" : version.copyright
            }
            .replaceError(with: "500")
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
            .sink { [weak self] value in
                self?.serverVersion = "Server: " + value
            }
    }

    func bindSearch(to publisher: AnyPublisher<String, Never>) {
        publisher
            .debounce(for: .milliseconds(300), scheduler: RunLoop.main)
            .removeDuplicates()
            .flatMap { [weak self] query -> AnyPublisher<[Activity], Never> in
                guard let self = self, !query.isEmpty else {
                    return Just([]).eraseToAnyPublisher()
                }
                return self.searchActivitiesWithVirtuals(query: query)
            }
            .receive(on: RunLoop.main)
            .assign(to: &$searchResults)
    }

    func searchActivitiesWithVirtuals(query: String, maxSearchLength: Int = 6) -> AnyPublisher<[Activity], Never> {
        return searchActivitys(query: query, maxSearchLength)
            .flatMap { activities -> AnyPublisher<[Activity], Never> in
                let needsVirtuals = activities.contains { $0.project == nil || $0.parentTitle == nil }

                guard needsVirtuals else {
                    return Just(activities).eraseToAnyPublisher()
                }

                guard let baseURL = self.serverIP,
                      let url = URL(string: "\(baseURL)/api/projects") else {
                    return Just(activities).eraseToAnyPublisher()
                }

                var request = URLRequest(url: url)
                request.httpMethod = "GET"
                request.addValue("Bearer \(self.apiToken ?? "")", forHTTPHeaderField: "Authorization")
                request.addValue("application/json", forHTTPHeaderField: "Accept")

                return self.session.dataTaskPublisher(for: request)
                    .map(\.data)
                    .decode(type: [Project].self, decoder: JSONDecoder())
                    .map { projects -> [Activity] in
                        var result: [Activity] = []

                        for activity in activities {
                            if activity.project != nil, activity.parentTitle != nil {
                                result.append(activity)
                            } else {
                                let virtuals = projects.map { project in
                                    Activity(
                                        id: activity.id,
                                        name: activity.name,
                                        parentTitle: project.name,
                                        project: project.id,
                                        color: activity.color
                                    )
                                }
                                result.append(contentsOf: virtuals)
                            }
                        }

                        return result
                    }
                    .replaceError(with: activities)
                    .eraseToAnyPublisher()
            }
            .eraseToAnyPublisher()
    }

    func searchActivitys(query: String, _ maxSearchLength: Int = 6) -> AnyPublisher<[Activity], Never> {
        guard let baseURL = serverIP,
              var components = URLComponents(string: "\(baseURL)/api/activities") else {
            return Just([]).eraseToAnyPublisher()
        }

        components.queryItems = [
            URLQueryItem(name: "orderBy", value: "name"),
            URLQueryItem(name: "order", value: "DESC"),
            URLQueryItem(name: "visible", value: "1"),
            URLQueryItem(name: "term", value: query)
        ]

        guard let url = components.url else {
            return Just([]).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.addValue("Bearer \(apiToken ?? "")", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36 KimaiClock", forHTTPHeaderField: "User-Agent")

        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: [Activity].self, decoder: JSONDecoder())
            .map { activities in
                Array(activities.prefix(maxSearchLength))
            }
            .replaceError(with: [])
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    func startActivity() -> AnyPublisher<Int?, Never> {
        guard let activeActivity,
              let baseURL = serverIP,
              let url = URL(string: "\(baseURL)/api/timesheets") else {
            return Just(nil).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiToken ?? "")", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36 KimaiClock",
                         forHTTPHeaderField: "User-Agent")

        let body: [String: Any?] = [
            "project": activeActivity.project,
            "activity": activeActivity.id
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        return session.dataTaskPublisher(for: request)
            .tryMap { [weak self] data, response -> Int? in
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else { return nil }
                let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let id = json?["id"] as? Int
                if let id = id {
                    self?.activeTimesheetId = id
                }
                return id
            }
            .replaceError(with: nil)
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    func stopActivity() -> AnyPublisher<Bool, Never> {
        guard activeActivity != nil,
              let id = activeTimesheetId else {
            return Just(true).eraseToAnyPublisher()
        }

        guard let baseURL = serverIP,
              let url = URL(string: "\(baseURL)/api/timesheets/\(id)/stop") else {
            return Just(false).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("Bearer \(apiToken ?? "")", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36 KimaiClock", forHTTPHeaderField: "User-Agent")

        return session.dataTaskPublisher(for: request)
            .map { $0.response as? HTTPURLResponse }
            .map { $0?.statusCode == 200 }
            .map {
                self.activeTimesheetId = nil
                return $0
            }
            .replaceError(with: false)
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }
}
