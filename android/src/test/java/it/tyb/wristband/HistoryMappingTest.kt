package it.tyb.wristband

import com.oudmon.ble.base.bean.SleepDisplay
import org.junit.Assert.*
import org.junit.Test

class HistoryMappingTest {
    @Test fun missingSleepDayProducesNoRecords() {
        // Java SDK callbacks can return null despite Kotlin's non-null mapper type.
        assertEquals(0, sleepRecords(SleepDisplay::class.java.cast(null), "2026-10-17").length())
    }

    @Test fun sleepWithoutPhasesProducesNoRecords() {
        assertEquals(0, sleepRecords(SleepDisplay(), "2026-10-17").length())
    }

    @Test fun sleepAndNapsKeepTheirPhasesAndTimestamps() {
        val sleep = SleepDisplay().apply {
            list = listOf(SleepDisplay.SleepDataBean(1_792_188_000L, 1_792_191_600L, 5))
            napList = listOf(SleepDisplay.SleepDataBean(1_792_224_000L, 1_792_225_800L, 2))
        }
        val records = sleepRecords(sleep, "2026-10-17")
        assertEquals(2, records.length())
        val night = records.getJSONObject(0)
        assertFalse(night.getBoolean("nap"))
        assertEquals("2026-10-17", night.getString("date"))
        assertEquals(1_792_188_000_000L, night.getLong("start"))
        assertEquals(1_792_191_600_000L, night.getLong("end"))
        assertEquals(3600L, night.getLong("durationSeconds"))
        assertEquals("deep", night.getJSONArray("phases").getJSONObject(0).getString("stage"))
        val nap = records.getJSONObject(1)
        assertTrue(nap.getBoolean("nap"))
        assertEquals(1800L, nap.getLong("durationSeconds"))
        assertEquals("light", nap.getJSONArray("phases").getJSONObject(0).getString("stage"))
    }
}
