package com.beaudevcode.steady_through

/** Pure values only: no Android types, device identity, locations or raw traces. */
internal data class MotionConfidences(
    val vehicle: Int = 0,
    val walking: Int = 0,
    val still: Int = 0,
    val running: Int = 0,
    val bicycle: Int = 0,
    val onFoot: Int = 0,
    val unknown: Int = 0,
    val tilting: Int = 0,
)

internal enum class MotionClassification { VEHICLE, WALKING, OTHER }

internal object MotionClassifier {
    fun classify(sample: MotionConfidences): MotionClassification? = when {
        // Conservative possible-vehicle context wins over overlapping classes.
        sample.vehicle in 30..100 -> MotionClassification.VEHICLE
        sample.walking in 50..100 -> MotionClassification.WALKING
        sample.still in 50..100 || sample.running in 50..100 ||
            sample.bicycle in 50..100 || sample.onFoot in 50..100 -> MotionClassification.OTHER
        // UNKNOWN, TILTING, invalid or low confidences supply no known class.
        else -> null
    }
}

internal data class MotionAggregateReading(
    val vehicleMinutes: Double?,
    val walkingMinutes: Double?,
    val possibleVehicle: Boolean,
)

/**
 * One explicit collector session. Safety context and duration estimates have
 * different lifetimes: a known vehicle class lasts until a known replacement
 * or clear(), while each duration estimate is capped at 45 seconds. Silence,
 * unknown readings and tilting cannot establish that vehicle movement ended.
 */
internal class SessionMotionState {
    private var classification: MotionClassification? = null
    private var acceptedAt: Long? = null
    private var sampleAt: Long? = null
    private val intervals = mutableListOf<MotionInterval>()

    fun accept(sample: MotionConfidences, observedAt: Long, now: Long): Boolean {
        if (observedAt < 0L || now < observedAt || now - observedAt > freshnessMillis) return false
        if (sampleAt?.let { observedAt <= it } == true) return false
        if (acceptedAt?.let { now < it } == true) return false
        val next = MotionClassifier.classify(sample) ?: return false
        finishInterval(now)
        classification = next
        acceptedAt = now
        sampleAt = observedAt
        return true
    }

    fun read(now: Long): MotionAggregateReading? {
        val current = classification ?: return null
        val cutoff = now - windowMillis
        prune(cutoff)
        var vehicleMs = 0L
        var walkingMs = 0L
        var observedMs = 0L
        for (interval in intervals) {
            val duration = clippedDuration(interval.start, interval.end, cutoff, now)
            observedMs += duration
            if (interval.classification == MotionClassification.VEHICLE) vehicleMs += duration
            if (interval.classification == MotionClassification.WALKING) walkingMs += duration
        }
        acceptedAt?.let { start ->
            val duration = clippedDuration(start, minOf(now, start + freshnessMillis), cutoff, now)
            observedMs += duration
            if (current == MotionClassification.VEHICLE) vehicleMs += duration
            if (current == MotionClassification.WALKING) walkingMs += duration
        }
        val hasWindowEvidence = observedMs > 0L || acceptedAt?.let { it in cutoff..now } == true
        return MotionAggregateReading(
            vehicleMinutes = if (hasWindowEvidence) (vehicleMs / 60000.0).coerceIn(0.0, 60.0) else null,
            walkingMinutes = if (hasWindowEvidence) (walkingMs / 60000.0).coerceIn(0.0, 60.0) else null,
            possibleVehicle = current == MotionClassification.VEHICLE,
        )
    }

    fun clear() {
        classification = null
        acceptedAt = null
        sampleAt = null
        intervals.clear()
    }

    private fun finishInterval(now: Long) {
        val start = acceptedAt ?: return
        val previous = classification ?: return
        val end = minOf(now, start + freshnessMillis)
        if (end > start) intervals.add(MotionInterval(start, end, previous))
        prune(now - windowMillis)
    }

    private fun prune(cutoff: Long) { intervals.removeAll { it.end < cutoff } }

    private fun clippedDuration(start: Long, end: Long, cutoff: Long, now: Long): Long =
        maxOf(0L, minOf(end, now) - maxOf(start, cutoff))

    private data class MotionInterval(val start: Long, val end: Long, val classification: MotionClassification)

    private companion object {
        const val freshnessMillis = 45000L
        const val windowMillis = 3600000L
    }
}
