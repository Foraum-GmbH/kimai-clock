import SwiftUI
internal import Combine

@MainActor
class SubscriptionManager: ObservableObject {
    var cancellables = Set<AnyCancellable>()
}
