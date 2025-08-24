import SwiftUI
internal import Combine

struct Activity: Identifiable, Codable, Equatable {
    let id: Int
    let name: String
    let parentTitle: String
    let project: Int

    let color: String?

    var activityColor: Color {
        if let hex = color, let color = Color(hex: hex) {
            return color
        } else {
            return Color.kimami
        }
    }
}

struct ServerVersion: Codable {
    let versionId: Int
    let copyright: String
}

@MainActor
class ApiManager: ObservableObject {
    @AppStorage("apiToken") private var apiToken: String?
    @AppStorage("serverIP") private var serverIP: String?

    @Published var searchResults: [Activity] = []
    @Published var serverVersion: String = "..."

    private let session: URLSession = {
        let tempSession = URLSession.shared
        //tempSession.configuration.urlCache = nil
        //tempSession.configuration.httpCookieStorage = nil
        //tempSession.configuration.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        //tempSession.configuration.httpCookieAcceptPolicy = .never
        return tempSession
    }()

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
        request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        return session.dataTaskPublisher(for: request)
            .map(\.data)
            .decode(type: ServerVersion.self, decoder: JSONDecoder())
            .map { version in
                return version.versionId < 20000 ? "unsupported" : version.copyright
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
                return self.searchActivitys(query: query)
            }
            .receive(on: RunLoop.main)
            .assign(to: &$searchResults)
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
        request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

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

    func startActivity(activity: Activity?) -> AnyPublisher<Bool, Never> {
        guard let activity,
              let baseURL = serverIP,
              let url = URL(string: "\(baseURL)/api/timesheets") else {
            return Just(false).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiToken ?? "")", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        let body: [String: Any] = ["project": activity.project, "activity": activity.id]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        return session.dataTaskPublisher(for: request)
            .map { $0.response as? HTTPURLResponse }
            .map { $0?.statusCode == 200 }
            .replaceError(with: false)
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

    func stopActivity(activity: Activity?) -> AnyPublisher<Bool, Never> {
        guard let activity,
              let baseURL = serverIP,
              let url = URL(string: "\(baseURL)/api/timesheets/\(activity.id)/stop") else {
            return Just(false).eraseToAnyPublisher()
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.addValue("Bearer \(apiToken ?? "")", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/139.0.0.0 Safari/537.36", forHTTPHeaderField: "User-Agent")

        return session.dataTaskPublisher(for: request)
            .map { $0.response as? HTTPURLResponse }
            .map { $0?.statusCode == 200 }
            .replaceError(with: false)
            .receive(on: RunLoop.main)
            .eraseToAnyPublisher()
    }

}
