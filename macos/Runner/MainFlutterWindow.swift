import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var deviceSignals: SessionDeviceSignals?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    deviceSignals = SessionDeviceSignals(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }
}

/// No app identity, window, keyboard or screen content is inspected or retained.
/// The vault owner starts/stops this collector; OS screen/session suspension also
/// pauses duration. These minutes measure an open session, not human attention.
private final class SessionDeviceSignals {
  private let channel: FlutterMethodChannel
  private var observers: [NSObjectProtocol] = []
  private var enabled = false
  private var activationTimes: [Date] = []
  private var activeIntervals: [DateInterval] = []
  private var activeSince: Date?
  private var sessionActive = true
  private var screenAwake = true

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "steady_through/device_signals", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "capabilities":
        result([
          "usageSupported": true, "usageGranted": true,
          "motionSupported": false, "motionGranted": false,
          "platformNote": "macOS counts activations only while Steady Through is in the foreground, within the last 60 minutes of this collector session. This is not a history of switching among other apps and may stay zero. Screen-awake session minutes do not measure attention. Motion is unavailable."
        ])
      case "openUsageSettings": result(nil)
      case "requestMotionPermission": result(false)
      case "start":
        let args = call.arguments as? [String: Any]
        self.start(usage: args?["usage"] as? Bool == true)
        result(nil)
      case "read": result(self.read())
      case "stop": self.stop(); result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  private func start(usage: Bool) {
    stop()
    guard usage, NSApplication.shared.isActive else { return }
    enabled = true
    sessionActive = true
    screenAwake = true
    activeSince = Date()
    let center = NSWorkspace.shared.notificationCenter
    observers.append(center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
      guard let self = self, self.enabled, self.sessionActive, self.screenAwake else { return }
      // The notification's userInfo contains identity; never access it.
      let now = Date()
      self.prune(before: now.addingTimeInterval(-3600))
      if self.activationTimes.count < 10000 { self.activationTimes.append(now) }
    })
    observers.append(center.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.setScreenAwake(false) })
    observers.append(center.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.setScreenAwake(true) })
    observers.append(center.addObserver(forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.setSessionActive(false) })
    observers.append(center.addObserver(forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.setSessionActive(true) })
    observers.append(center.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in self?.setScreenAwake(false) })
    observers.append(center.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in self?.setScreenAwake(true) })
  }

  private func setScreenAwake(_ value: Bool) {
    finishInterval()
    screenAwake = value
    if enabled && screenAwake && sessionActive { activeSince = Date() }
  }

  private func setSessionActive(_ value: Bool) {
    finishInterval()
    sessionActive = value
    if enabled && screenAwake && sessionActive { activeSince = Date() }
  }

  private func finishInterval() {
    let now = Date()
    if let start = activeSince, now >= start { activeIntervals.append(DateInterval(start: start, end: now)) }
    activeSince = nil
    prune(before: now.addingTimeInterval(-3600))
  }

  private func prune(before cutoff: Date) {
    activationTimes.removeAll { $0 < cutoff }
    activeIntervals.removeAll { $0.end < cutoff }
  }

  private func read() -> [String: Any] {
    guard enabled else { return ["usageStatus": "paused", "motionStatus": "unsupported"] }
    let now = Date()
    let cutoff = now.addingTimeInterval(-3600)
    prune(before: cutoff)
    var seconds = activeIntervals.reduce(0.0) { $0 + max(0, $1.end.timeIntervalSince(max($1.start, cutoff))) }
    if let start = activeSince { seconds += max(0, now.timeIntervalSince(max(start, cutoff))) }
    return [
      "deviceSwitches": activationTimes.count,
      "activeMinutes": min(60, seconds / 60),
      "usageStatus": "session-only", "motionStatus": "unsupported",
      "possibleVehicle": false
    ]
  }

  private func stop() {
    enabled = false
    for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    observers.removeAll()
    activationTimes.removeAll()
    activeIntervals.removeAll()
    activeSince = nil
  }

  deinit {
    for observer in observers { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
    channel.setMethodCallHandler(nil)
  }
}
