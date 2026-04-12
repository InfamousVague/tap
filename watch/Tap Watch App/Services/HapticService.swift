import WatchKit

class HapticService {
    static let shared = HapticService()

    private init() {}

    enum Pattern {
        case success
        case failure
        case warning
        case confirm
        case start
        case stop
        case notification
        case retry
    }

    func play(_ pattern: Pattern) {
        let device = WKInterfaceDevice.current()

        switch pattern {
        case .success:
            device.play(.success)
        case .failure:
            device.play(.failure)
        case .warning:
            device.play(.retry)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                device.play(.retry)
            }
        case .confirm:
            device.play(.click)
        case .start:
            device.play(.start)
        case .stop:
            device.play(.stop)
        case .notification:
            device.play(.notification)
        case .retry:
            device.play(.retry)
        }
    }

    /// Play a custom sequence of haptics for command execution flow
    func playExecutionSequence(success: Bool) {
        let device = WKInterfaceDevice.current()

        // Start pulse
        device.play(.start)

        // Result after a beat
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            device.play(success ? .success : .failure)
        }
    }
}
