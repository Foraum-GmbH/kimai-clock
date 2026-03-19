//
//  WidgetSync.swift
//  KimaiClock
//
//  Created by Dominic on 31.01.26.
//

// TimerSharedState.swift

import Foundation

enum WidgetSync {
    static let defaults = UserDefaults(suiteName: "group.de.foraum.KimaiClock")!

    private static let activityKey = "activity"
    private static let timerKey = "timer"
    private static let subtitleKey = "subtitle"
    private static let isActiveKey = "isActive"

    static func save(activity: Activity?) {
        if let activity {
            if let parentTitle = activity.parentTitle {
                defaults.set(parentTitle + " / " + activity.name, forKey: activityKey)
            } else {
                defaults.set(activity.name, forKey: activityKey)
            }
        } else {
            defaults.removeObject(forKey: activityKey)
        }
    }

    static func save(timer: TimeInterval, isActive: Bool?) {
        defaults.set(timer, forKey: timerKey)
        defaults.set(subtitle, forKey: subtitleKey)
        
        if let isActive {
            defaults.set(isActive, forKey: isActiveKey)
        } else {
            defaults.removeObject(forKey: isActiveKey)
        }
    }

    static var timer: TimeInterval {
        defaults.double(forKey: timerKey)
    }

    static var subtitle: String {
        defaults.string(forKey: subtitleKey) ?? "-"
    }

    static var isActive: Bool? {
        defaults.object(forKey: isActiveKey) as? Bool
    }
}
