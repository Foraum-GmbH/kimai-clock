//
//  PopoverState.swift
//  KimaiClock
//
//  Created by Dominic on 05.02.26.
//

internal import Combine

@MainActor
final class PopoverState: ObservableObject {
    @Published var isPresented = false
}
