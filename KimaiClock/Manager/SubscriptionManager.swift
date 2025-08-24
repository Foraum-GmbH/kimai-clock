internal import Combine
import SwiftUI

@MainActor
class SubscriptionManager: ObservableObject {
    var cancellables = Set<AnyCancellable>()
}
