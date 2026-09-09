package dev.michaelishri.soup

import org.junit.Assert.*
import org.junit.Test

class BrowserReturnTest {
    @Test fun returnsAfterTabOpensAndAcknowledgesOnlyOnResume() {
        var launches = 0
        var result: Boolean? = null
        val flow = BrowserReturn { launches++ }
        flow.begin()
        flow.onStopped()
        flow.requestReturn { result = it }
        assertEquals(1, launches)
        assertNull(result)
        flow.onResumed()
        assertEquals(true, result)
        flow.onStopped()
        assertEquals(1, launches)
    }

    @Test fun completionBeforeTabOpensWaitsForStop() {
        var launches = 0
        var result: Boolean? = null
        val flow = BrowserReturn { launches++ }
        flow.begin()
        flow.requestReturn { result = it }
        flow.onResumed()
        assertEquals(0, launches)
        assertNull(result)
        flow.onStopped()
        assertEquals(1, launches)
        flow.onResumed()
        assertEquals(true, result)
    }

    @Test fun manuallyClosedTabDoesNotLaunchAnotherActivity() {
        var launches = 0
        var result: Boolean? = null
        val flow = BrowserReturn { launches++ }
        flow.begin()
        flow.onStopped()
        flow.onResumed()
        flow.requestReturn { result = it }
        assertEquals(0, launches)
        assertEquals(true, result)
        flow.begin()
        flow.onStopped()
        flow.requestReturn { result = it }
        assertEquals(1, launches)
    }

    @Test fun cancellationInvalidatesPendingReturn() {
        var launches = 0
        var result: Boolean? = null
        val flow = BrowserReturn { launches++ }
        flow.begin()
        flow.requestReturn { result = it }
        flow.cancel()
        flow.onStopped()
        flow.onResumed()
        assertEquals(0, launches)
        assertEquals(false, result)
    }

    @Test fun launchErrorsAreReportedInsteadOfSilentSuccess() {
        var result: Boolean? = null
        val flow = BrowserReturn { throw IllegalStateException("no activity") }
        flow.begin()
        flow.onStopped()
        flow.requestReturn { result = it }
        assertEquals(false, result)
    }

    @Test fun timedOutReturnCannotAcknowledgeLaterSession() {
        val results = mutableListOf<Boolean>()
        val flow = BrowserReturn {}
        flow.begin()
        flow.onStopped()
        flow.requestReturn { results.add(it) }
        flow.cancel()
        flow.onResumed()
        flow.begin()
        flow.onStopped()
        flow.requestReturn { results.add(it) }
        flow.onResumed()
        assertEquals(listOf(false, true), results)
    }
}
