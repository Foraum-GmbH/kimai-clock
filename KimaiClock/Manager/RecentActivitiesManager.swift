internal import Combine
import SwiftUI

@MainActor
class RecentActivitiesManager: ObservableObject {
    @AppStorage("recentActivitys") private var storedActivities: Data = Data()

    @Published private(set) var activities: [Activity] = []
    private let maxLength = 6

    init() {
        load()
    }

    func add(_ activity: Activity?) {
        guard let activity else { return }
        activities.removeAll { $0.id == activity.id }
        activities.insert(activity, at: 0)
        if activities.count > maxLength {
            activities.removeLast()
        }
        save()
    }

    func clear(_ activity: Activity?) {
        guard let activity else { return }
        activities.removeAll { $0.id == activity.id }
        save()
    }

    func clearAll() {
        activities.removeAll()
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(activities) {
            storedActivities = data
        }
    }

    private func load() {
        if let decoded = try? JSONDecoder().decode([Activity].self, from: storedActivities) {
            activities = decoded
        }
    }
}
