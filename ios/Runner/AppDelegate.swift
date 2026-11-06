import Flutter
import UIKit
import CoreMotion

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var deviceSignals: IOSDeviceSignals?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    deviceSignals = IOSDeviceSignals(messenger: engineBridge.applicationRegistrar.messenger())
  }
}

/// In-memory, opt-in summaries only. No location or Screen Time capability is
/// requested, and no raw activity samples are passed to Flutter or written.
private final class IOSDeviceSignals {
  private let channel: FlutterMethodChannel
  private var motion: CMMotionActivityManager?
  private var permissionManager: CMMotionActivityManager?
  private var observers: [NSObjectProtocol] = []
  private var motionEnabled = false
  private var sessionStarted: Date?
  private var generation = 0
  private var latestVehicle = false
  private var vehicleMinutes: Double?
  private var walkingMinutes: Double?
  private var summaryState = "awaiting-data"
  private var queryInFlight = false
  private var lastQueryAt: Date?

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "steady_through/device_signals", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "capabilities":
        result([
          "usageSupported": false, "usageGranted": false,
          "motionSupported": CMMotionActivityManager.isActivityAvailable(),
          "motionGranted": CMMotionActivityManager.isActivityAvailable() && CMMotionActivityManager.authorizationStatus() == .authorized,
          "platformNote": "iOS offers optional Core Motion summaries during this unlocked app session, up to 60 minutes. Motion history may be delayed or incomplete, and vehicle context does not identify a driver. Cross-app usage is unavailable: this preview has no Family Controls entitlement or Screen Time extensions."
        ])
      case "openUsageSettings": result(nil)
      case "requestMotionPermission": self.requestPermission(result)
      case "start":
        self.stop()
        guard UIApplication.shared.applicationState == .active else { result(nil); return }
        let args = call.arguments as? [String: Any]
        self.motionEnabled = args?["motion"] as? Bool == true
        if self.motionEnabled { self.startMotionIfAuthorized() }
        result(nil)
      case "read": self.read(result)
      case "stop": self.stop(); result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
    // A native backstop in addition to the Flutter vault lifecycle owner.
    let center = NotificationCenter.default
    observers.append(center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in self?.stop() })
    observers.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: .main) { [weak self] _ in self?.stop() })
    observers.append(center.addObserver(forName: UIApplication.protectedDataWillBecomeUnavailableNotification, object: nil, queue: .main) { [weak self] _ in self?.stop() })
  }

  private func requestPermission(_ result: @escaping FlutterResult) {
    guard CMMotionActivityManager.isActivityAvailable() else { result(false); return }
    switch CMMotionActivityManager.authorizationStatus() {
    case .authorized: result(true)
    case .denied, .restricted: result(false)
    case .notDetermined:
      guard permissionManager == nil else {
        result(FlutterError(code: "permission-pending", message: "A motion permission request is already open.", details: nil))
        return
      }
      // Core Motion has no standalone requestAuthorization method. A short query
      // triggers the OS consent prompt; discard every returned sample.
      let manager = CMMotionActivityManager()
      permissionManager = manager
      let now = Date()
      manager.queryActivityStarting(from: now.addingTimeInterval(-1), to: now, to: .main) { [weak self] _, _ in
        self?.permissionManager = nil
        result(CMMotionActivityManager.authorizationStatus() == .authorized)
      }
    @unknown default: result(false)
    }
  }

  private func startMotionIfAuthorized() {
    guard UIApplication.shared.applicationState == .active, motionEnabled, CMMotionActivityManager.isActivityAvailable(), CMMotionActivityManager.authorizationStatus() == .authorized else { return }
    // Construct Core Motion only for an opted-in, authorized active session.
    // Keep passive bridge registration and stop paths free of manager operations.
    let manager = CMMotionActivityManager()
    motion = manager
    sessionStarted = Date()
    let currentGeneration = generation
    manager.startActivityUpdates(to: .main) { [weak self] activity in
      guard let self = self, self.motionEnabled, self.generation == currentGeneration, let activity = activity else { return }
      // Core Motion emits changes, not a heartbeat. An unclassified update
      // provides no evidence that an earlier vehicle classification ended.
      guard activity.automotive || activity.walking || activity.running || activity.cycling || activity.stationary else { return }
      if activity.automotive {
        self.latestVehicle = true
      } else if activity.confidence == .medium || activity.confidence == .high {
        // A weak non-vehicle guess cannot clear conservative vehicle context.
        self.latestVehicle = false
      }
    }
  }

  private func read(_ result: @escaping FlutterResult) {
    var value: [String: Any] = ["usageStatus": "unsupported", "motionStatus": "paused", "possibleVehicle": false]
    guard motionEnabled else { result(value); return }
    guard CMMotionActivityManager.isActivityAvailable() else { value["motionStatus"] = "unsupported"; result(value); return }
    guard CMMotionActivityManager.authorizationStatus() == .authorized else {
      motion?.stopActivityUpdates()
      motion = nil
      latestVehicle = false
      vehicleMinutes = nil
      walkingMinutes = nil
      value["motionStatus"] = "permission-denied"
      result(value)
      return
    }
    guard let started = sessionStarted, let manager = motion else { value["motionStatus"] = "awaiting-data"; result(value); return }
    let now = Date()
    let cutoff = max(started, now.addingTimeInterval(-3600))
    value["motionStatus"] = summaryState
    if let minutes = vehicleMinutes { value["vehicleMinutes"] = minutes }
    if let minutes = walkingMinutes { value["walkingMinutes"] = minutes }
    if isCurrentVehicle() { value["motionStatus"] = "session-only"; value["possibleVehicle"] = true }
    // Core Motion queries can take minutes. Return current aggregate state now;
    // refresh it asynchronously so a slow history query never blocks session
    // stop, an Insights refresh, or the current possible-vehicle safety flag.
    result(value)
    guard !queryInFlight, lastQueryAt == nil || now.timeIntervalSince(lastQueryAt!) >= 15 else { return }
    queryInFlight = true
    lastQueryAt = now
    let currentGeneration = generation
    manager.queryActivityStarting(from: cutoff, to: now, to: .main) { [weak self] activities, error in
      guard let self = self, self.motionEnabled, self.generation == currentGeneration else { return }
      self.queryInFlight = false
      guard CMMotionActivityManager.authorizationStatus() == .authorized else {
        self.vehicleMinutes = nil
        self.walkingMinutes = nil
        self.summaryState = "permission-denied"
        self.motion?.stopActivityUpdates()
        self.motion = nil
        return
      }
      guard error == nil, let activities = activities, !activities.isEmpty else {
        self.vehicleMinutes = nil
        self.walkingMinutes = nil
        self.summaryState = "awaiting-data"
        return
      }
      let ordered = activities.sorted { $0.startDate < $1.startDate }
      var vehicleSeconds = 0.0
      var walkingSeconds = 0.0
      var usableSamples = 0
      for (index, activity) in ordered.enumerated() {
        guard activity.confidence != .low else { continue }
        let end = index + 1 < ordered.count ? min(now, ordered[index + 1].startDate) : now
        let start = max(cutoff, activity.startDate)
        let seconds = max(0, end.timeIntervalSince(start))
        // An unknown classification is missing evidence, not stationary time.
        guard activity.automotive || activity.walking || activity.running || activity.cycling || activity.stationary else { continue }
        usableSamples += 1
        if activity.automotive { vehicleSeconds += seconds }
        else if activity.walking { walkingSeconds += seconds }
      }
      self.summaryState = usableSamples > 0 ? "session-only" : "awaiting-data"
      if usableSamples > 0 {
        self.vehicleMinutes = min(60, vehicleSeconds / 60)
        self.walkingMinutes = min(60, walkingSeconds / 60)
      } else {
        self.vehicleMinutes = nil
        self.walkingMinutes = nil
      }
    }
  }

  private func isCurrentVehicle() -> Bool { motionEnabled && latestVehicle }

  private func stop() {
    generation += 1
    motionEnabled = false
    motion?.stopActivityUpdates()
    motion = nil
    sessionStarted = nil
    latestVehicle = false
    vehicleMinutes = nil
    walkingMinutes = nil
    summaryState = "awaiting-data"
    queryInFlight = false
    lastQueryAt = nil
  }

  deinit {
    motion?.stopActivityUpdates()
    motion = nil
    for observer in observers { NotificationCenter.default.removeObserver(observer) }
    channel.setMethodCallHandler(nil)
  }
}
