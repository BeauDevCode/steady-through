package com.beaudevcode.steady_through

import android.Manifest
import android.app.AppOpsManager
import android.app.KeyguardManager
import android.app.PendingIntent
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import android.os.SystemClock
import android.provider.Settings
import com.google.android.gms.common.ConnectionResult
import com.google.android.gms.common.GoogleApiAvailability
import com.google.android.gms.location.ActivityRecognition
import com.google.android.gms.location.ActivityRecognitionResult
import com.google.android.gms.location.DetectedActivity
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

class MainActivity : FlutterActivity() {
    private var signalsForeground = false
    private var usageEnabled = false
    private var motionEnabled = false
    private var sessionGeneration = 0
    private var motionIntent: PendingIntent? = null
    private var motionAction: String? = null
    private var motionState = "paused"
    private var permissionResult: MethodChannel.Result? = null
    private val sessionMotion = SessionMotionState()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "steady_through/device_signals")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "capabilities" -> result.success(mapOf(
                        "usageSupported" to true,
                        "usageGranted" to hasUsagePermission(),
                        "motionSupported" to hasMotionSupport(),
                        "motionGranted" to (hasMotionSupport() && hasMotionPermission()),
                        "platformNote" to "Android usage shows observed app switches and foreground minutes within the last 60 minutes; incomplete OS event history can undercount. Motion is uncertain, session-only, and requires Google Play services. No app identities or locations leave this adapter."
                    ))
                    "openUsageSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                            result.success(null)
                        } catch (_: Exception) {
                            result.error("settings-unavailable", "Usage access settings are unavailable.", null)
                        }
                    }
                    "requestMotionPermission" -> requestMotionPermission(result)
                    "start" -> {
                        stopSignals()
                        // A queued Flutter start must not resurrect collection
                        // after a native pause, permission dialog or stop.
                        if (signalsForeground && !isDeviceLocked()) {
                            usageEnabled = call.argument<Boolean>("usage") == true
                            motionEnabled = call.argument<Boolean>("motion") == true
                            if (motionEnabled) startMotion()
                        }
                        result.success(null)
                    }
                    "read" -> result.success(readSignals())
                    "stop" -> { stopSignals(); result.success(null) }
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasUsagePermission(): Boolean {
        val ops = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        } else {
            @Suppress("DEPRECATION")
            ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun hasMotionSupport(): Boolean =
        GoogleApiAvailability.getInstance().isGooglePlayServicesAvailable(this) == ConnectionResult.SUCCESS

    private fun hasMotionPermission(): Boolean = Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
        checkSelfPermission(Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED

    private fun requestMotionPermission(result: MethodChannel.Result) {
        if (!hasMotionSupport()) { result.success(false); return }
        if (hasMotionPermission()) { result.success(true); return }
        if (permissionResult != null) {
            result.error("permission-pending", "A motion permission request is already open.", null)
            return
        }
        permissionResult = result
        requestPermissions(arrayOf(Manifest.permission.ACTIVITY_RECOGNITION), motionPermissionCode)
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == motionPermissionCode) {
            permissionResult?.success(grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED)
            permissionResult = null
        }
    }

    private fun startMotion() {
        if (!signalsForeground || isDeviceLocked()) {
            motionEnabled = false
            motionState = "paused"
            return
        }
        if (!hasMotionSupport()) { motionState = "unsupported"; return }
        if (!hasMotionPermission()) { motionState = "permission-denied"; return }
        val generation = sessionGeneration
        val action = "$packageName.SESSION_ACTIVITY.$generation"
        motionAction = action
        val intent = Intent(this, MotionReceiver::class.java).setAction(action)
        val flags = PendingIntent.FLAG_UPDATE_CURRENT or
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) PendingIntent.FLAG_MUTABLE else 0
        val pending = PendingIntent.getBroadcast(this, generation, intent, flags)
        motionIntent = pending
        receiverOwner = WeakReference(this)
        motionState = "awaiting-data"
        try {
            ActivityRecognition.getClient(this).requestActivityUpdates(15000L, pending)
                .addOnSuccessListener {
                    // Registration can finish after lock/stop. Remove that exact session request.
                    if (generation != sessionGeneration || !motionEnabled) removeMotionRequest(pending)
                }
                .addOnFailureListener {
                    if (generation == sessionGeneration) {
                        motionState = if (hasMotionPermission()) "unavailable" else "permission-denied"
                    }
                    removeMotionRequest(pending)
                }
        } catch (_: SecurityException) {
            motionState = "permission-denied"
            removeMotionRequest(pending)
        }
    }

    private fun acceptMotion(intent: Intent) {
        if (!signalsForeground || !motionEnabled || intent.action != motionAction || !hasMotionPermission() || isDeviceLocked()) return
        val observation = ActivityRecognitionResult.extractResult(intent) ?: return
        val now = SystemClock.elapsedRealtime()
        val sample = MotionConfidences(
            vehicle = observation.getActivityConfidence(DetectedActivity.IN_VEHICLE),
            walking = observation.getActivityConfidence(DetectedActivity.WALKING),
            still = observation.getActivityConfidence(DetectedActivity.STILL),
            running = observation.getActivityConfidence(DetectedActivity.RUNNING),
            bicycle = observation.getActivityConfidence(DetectedActivity.ON_BICYCLE),
            onFoot = observation.getActivityConfidence(DetectedActivity.ON_FOOT),
            unknown = observation.getActivityConfidence(DetectedActivity.UNKNOWN),
            tilting = observation.getActivityConfidence(DetectedActivity.TILTING),
        )
        // Freshness, ordering and known-class checks are pure and unit tested.
        // An unknown result leaves awaiting-data or an established class intact.
        if (sessionMotion.accept(sample, observation.elapsedRealtimeMillis, now)) {
            motionState = "session-only"
        }
    }

    private fun readSignals(): Map<String, Any?> {
        if (!signalsForeground || isDeviceLocked()) { stopSignals(); return mapOf("usageStatus" to "paused", "motionStatus" to "paused") }
        val value = mutableMapOf<String, Any?>(
            "usageStatus" to if (usageEnabled) "awaiting-data" else "paused",
            "motionStatus" to if (motionEnabled) motionState else "paused",
            "possibleVehicle" to false
        )
        if (usageEnabled) readUsage(value)
        if (motionEnabled) {
            if (!hasMotionPermission()) {
                motionIntent?.let { removeMotionRequest(it) }
                motionIntent = null
                sessionMotion.clear()
                motionState = "permission-denied"
                value["motionStatus"] = motionState
            } else if (motionState == "session-only") {
                val reading = sessionMotion.read(SystemClock.elapsedRealtime())
                if (reading == null) {
                    value["motionStatus"] = "awaiting-data"
                } else {
                    value["possibleVehicle"] = reading.possibleVehicle
                    value["vehicleMinutes"] = reading.vehicleMinutes
                    value["walkingMinutes"] = reading.walkingMinutes
                }
            }
        }
        return value
    }

    @Suppress("DEPRECATION")
    private fun readUsage(value: MutableMap<String, Any?>) {
        if (!hasUsagePermission()) { value["usageStatus"] = "permission-denied"; return }
        try {
            val manager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val now = System.currentTimeMillis()
            val cutoff = now - 3600000L
            val events = manager.queryEvents(cutoff, now)
            if (events == null) { value["usageStatus"] = "unavailable"; return }
            val event = UsageEvents.Event()
            var lastPackage: String? = null
            var foregroundPackage: String? = null
            var activeSince: Long? = null
            var observedForeground = false
            var activeMs = 0L
            var switches = 0
            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                val time = event.timeStamp.coerceIn(cutoff, now)
                when (event.eventType) {
                    UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                        // Identity exists only in these transient local variables to
                        // deduplicate activity resumes. Never return, log or persist it.
                        val nextPackage = event.packageName ?: continue
                        if (lastPackage != null && lastPackage != nextPackage) switches++
                        lastPackage = nextPackage
                        foregroundPackage = nextPackage
                        if (activeSince == null) activeSince = time
                        observedForeground = true
                    }
                    UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                        if (foregroundPackage == event.packageName) {
                            activeSince?.let { activeMs += maxOf(0L, time - it) }
                            activeSince = null
                            foregroundPackage = null
                        }
                    }
                    UsageEvents.Event.SCREEN_NON_INTERACTIVE, UsageEvents.Event.KEYGUARD_SHOWN -> {
                        activeSince?.let { activeMs += maxOf(0L, time - it) }
                        activeSince = null
                        foregroundPackage = null
                    }
                }
            }
            if (!observedForeground) { value["usageStatus"] = "awaiting-data"; return }
            activeSince?.let { activeMs += maxOf(0L, now - it) }
            value["deviceSwitches"] = switches.coerceIn(0, 10000)
            value["activeMinutes"] = (activeMs / 60000.0).coerceIn(0.0, 60.0)
            value["usageStatus"] = "last-hour"
        } catch (_: SecurityException) {
            value["usageStatus"] = "permission-denied"
        } catch (_: Exception) {
            value["usageStatus"] = "unavailable"
        }
    }

    private fun isDeviceLocked(): Boolean =
        (getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager).isDeviceLocked

    private fun removeMotionRequest(pending: PendingIntent) {
        try {
            ActivityRecognition.getClient(this).removeActivityUpdates(pending)
                .addOnCompleteListener { pending.cancel() }
        } catch (_: SecurityException) {
            pending.cancel()
        }
    }

    private fun stopSignals() {
        sessionGeneration++
        usageEnabled = false
        motionEnabled = false
        receiverOwner = null
        motionAction = null
        motionIntent?.let { removeMotionRequest(it) }
        motionIntent = null
        motionState = "paused"
        sessionMotion.clear()
    }

    override fun onResume() {
        super.onResume()
        signalsForeground = true
    }

    override fun onPause() {
        signalsForeground = false
        stopSignals()
        super.onPause()
    }

    override fun onStop() { signalsForeground = false; stopSignals(); super.onStop() }
    override fun onDestroy() {
        signalsForeground = false
        stopSignals()
        permissionResult?.success(false)
        permissionResult = null
        super.onDestroy()
    }

    class MotionReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            receiverOwner?.get()?.acceptMotion(intent)
        }
    }

    companion object {
        private const val motionPermissionCode = 8312
        private var receiverOwner: WeakReference<MainActivity>? = null
    }
}
