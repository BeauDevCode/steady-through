package com.beaudevcode.steady_through

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class SessionMotionStateTest {
    @Test fun unknownBeforeFirstClassificationLeavesReadingMissing() {
        val state = SessionMotionState()
        assertFalse(state.accept(MotionConfidences(unknown = 100), observedAt = 1000, now = 1000))
        assertNull(state.read(now = 60000))
    }

    @Test fun lowOrInvalidConfidenceDoesNotInventAClassification() {
        for (sample in listOf(
            MotionConfidences(vehicle = 29, walking = 49, still = 49, running = 49, bicycle = 49, onFoot = 49),
            MotionConfidences(vehicle = 101, walking = -1, unknown = 100),
            MotionConfidences(tilting = 100),
        )) {
            val state = SessionMotionState()
            assertFalse(state.accept(sample, observedAt = 1000, now = 1000))
            assertNull(state.read(now = 2000))
        }
    }

    @Test fun vehicleContextSurvivesSilenceAndUnknownOrLowConfidenceUpdates() {
        val state = SessionMotionState()
        assertTrue(state.accept(MotionConfidences(vehicle = 80), observedAt = 1000, now = 1000))
        assertFalse(state.accept(MotionConfidences(unknown = 100), observedAt = 61000, now = 61000))
        assertFalse(state.accept(MotionConfidences(vehicle = 20, still = 40), observedAt = 91000, now = 91000))
        val reading = requireNotNull(state.read(now = 121000))
        assertTrue(reading.possibleVehicle)
        assertEquals(0.75, requireNotNull(reading.vehicleMinutes), 0.000001)
        assertEquals(0.0, requireNotNull(reading.walkingMinutes), 0.000001)
    }

    @Test fun tiltingAloneCannotClearEstablishedVehicleContext() {
        val state = SessionMotionState()
        state.accept(MotionConfidences(vehicle = 80), observedAt = 1000, now = 1000)
        assertFalse(state.accept(MotionConfidences(tilting = 100), observedAt = 61000, now = 61000))
        assertTrue(requireNotNull(state.read(now = 121000)).possibleVehicle)
    }

    @Test fun credibleKnownNonVehicleActivitiesReplaceVehicleContext() {
        for (replacement in listOf(
            MotionConfidences(walking = 50), MotionConfidences(still = 50),
            MotionConfidences(running = 50), MotionConfidences(bicycle = 50),
            MotionConfidences(onFoot = 50),
        )) {
            val state = SessionMotionState()
            state.accept(MotionConfidences(vehicle = 80), observedAt = 1000, now = 1000)
            assertTrue(state.accept(replacement, observedAt = 61000, now = 61000))
            assertFalse(requireNotNull(state.read(now = 62000)).possibleVehicle)
        }
    }

    @Test fun credibleVehicleSignalTakesConservativePriorityOverOtherActivities() {
        val state = SessionMotionState()
        assertTrue(state.accept(MotionConfidences(vehicle = 30, still = 100, walking = 100), observedAt = 1000, now = 1000))
        assertTrue(requireNotNull(state.read(now = 2000)).possibleVehicle)
    }

    @Test fun staleFutureAndOutOfOrderDeliveriesCannotReplaceKnownContext() {
        val state = SessionMotionState()
        state.accept(MotionConfidences(vehicle = 80), observedAt = 30000, now = 30000)
        assertFalse(state.accept(MotionConfidences(still = 100), observedAt = 20000, now = 40000))
        assertFalse(state.accept(MotionConfidences(still = 100), observedAt = 30000, now = 75001))
        assertFalse(state.accept(MotionConfidences(still = 100), observedAt = 80001, now = 80000))
        assertTrue(requireNotNull(state.read(now = 90000)).possibleVehicle)
        val empty = SessionMotionState()
        assertFalse(empty.accept(MotionConfidences(vehicle = 100), observedAt = 0, now = 45001))
        assertNull(empty.read(now = 45001))
    }

    @Test fun deliveryAtFortyFiveSecondFreshnessBoundaryIsAccepted() {
        val state = SessionMotionState()
        assertTrue(state.accept(MotionConfidences(vehicle = 80), observedAt = 0, now = 45000))
        assertTrue(requireNotNull(state.read(now = 45000)).possibleVehicle)
    }

    @Test fun durationEstimatesStopAtFortyFiveSecondsForEachKnownObservation() {
        val state = SessionMotionState()
        state.accept(MotionConfidences(vehicle = 80), observedAt = 0, now = 0)
        assertEquals(0.75, requireNotNull(state.read(now = 90000)?.vehicleMinutes), 0.000001)
        state.accept(MotionConfidences(walking = 80), observedAt = 120000, now = 120000)
        val reading = requireNotNull(state.read(now = 240000))
        assertEquals(0.75, requireNotNull(reading.vehicleMinutes), 0.000001)
        assertEquals(0.75, requireNotNull(reading.walkingMinutes), 0.000001)
        assertFalse(reading.possibleVehicle)
    }

    @Test fun expiredDurationWindowBecomesMissingWithoutClearingVehicleContext() {
        val state = SessionMotionState()
        state.accept(MotionConfidences(vehicle = 80), observedAt = 0, now = 0)
        val reading = requireNotNull(state.read(now = 3700000))
        assertTrue(reading.possibleVehicle)
        assertNull(reading.vehicleMinutes)
        assertNull(reading.walkingMinutes)
    }

    @Test fun durationWindowClipsIntervalsAtTheLastHourBoundary() {
        val state = SessionMotionState()
        state.accept(MotionConfidences(vehicle = 80), observedAt = 0, now = 0)
        state.accept(MotionConfidences(walking = 80), observedAt = 3600000, now = 3600000)
        val reading = requireNotNull(state.read(now = 3615000))
        assertEquals(0.5, requireNotNull(reading.vehicleMinutes), 0.000001)
        assertEquals(0.25, requireNotNull(reading.walkingMinutes), 0.000001)
    }

    @Test fun stoppingClearsContextAndAllDurationEvidence() {
        val state = SessionMotionState()
        state.accept(MotionConfidences(vehicle = 80), observedAt = 1000, now = 1000)
        state.clear()
        assertNull(state.read(now = 2000))
        assertFalse(state.accept(MotionConfidences(unknown = 100), observedAt = 3000, now = 3000))
        assertNull(state.read(now = 4000))
    }
}
