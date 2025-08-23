import AudioToolbox

enum ChimeType {
    case start, pause, stop, error
}

class ChimeManager {
    static let shared = ChimeManager()

    func play(_ type: ChimeType) {
        let soundID: SystemSoundID
        switch type {
        case .start:
            soundID = 1330
        case .pause:
            soundID = 1053
        case .stop:
            soundID = 1001
        case .error:
                    soundID = 1006
        }
        AudioServicesPlaySystemSound(soundID)
    }
}
