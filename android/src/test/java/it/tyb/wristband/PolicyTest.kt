package it.tyb.wristband
import org.junit.Assert.*
import org.junit.Test
import org.json.JSONObject
class PolicyTest {
    @Test fun staleAndDuplicateCallbacksCannotFinishNewOperation() {
        val gate=OperationGate(); val a=gate.begin()!!; assertNull(gate.begin()); gate.invalidate(); val b=gate.begin()!!
        assertFalse(gate.finish(a));assertTrue(gate.current(b));assertTrue(gate.finish(b));assertFalse(gate.finish(b))
    }
    @Test fun patchPreservesFalseAndRejectsInvalidValues() {
        assertNull(Policy.patchError(JSONObject().put("enabled",false)))
        for(json in listOf("{}", "{\"enabled\":1}", "{\"intervalMinutes\":2.5}", "{\"intervalMinutes\":null}", "{\"extra\":1}")) assertNotNull(Policy.patchError(JSONObject(json)))
    }
    @Test fun timeoutPreservesEarlierBatches() {
        val jobs=listOf("heartRate" to "2026-10-16", "hrv" to "2026-10-16")
        val prior=org.json.JSONArray().put(json("status" to "success", "records" to org.json.JSONArray().put(60)))
        val result=Policy.failedHistory(jobs,prior,"op","dev",error("TIMEOUT","timeout"))
        assertEquals("partial",result.getString("status"));assertEquals(2,result.getJSONArray("batches").length())
        assertEquals(60,result.getJSONArray("batches").getJSONObject(0).getJSONArray("records").getInt(0))
    }
    @Test fun indexedSamplesKeepGaps() {
        val records=numericRecords(listOf(0,60,0,72),"heartRate","2026-10-16",5)
        assertEquals(2,records.length());assertEquals(1,records.getJSONObject(0).getInt("sampleIndex"));assertFalse(records.getJSONObject(0).has("timestamp"))
    }
    @Test fun acknowledgedWriteMustMatchReadBack() {
        assertTrue(Policy.verificationMatches(JSONObject("{\"enabled\":false}"),JSONObject("{\"enabled\":false}")))
        assertFalse(Policy.verificationMatches(JSONObject("{\"enabled\":false}"),JSONObject("{\"enabled\":true}")))
        assertFalse(Policy.verificationMatches(JSONObject("{\"intervalMinutes\":5}"),JSONObject("{}")))
    }
    @Test fun frozenDatesTrackCalendarDays() {
        assertEquals(2,Policy.dayIndex(java.time.LocalDate.parse("2026-10-24"),java.time.LocalDate.parse("2026-10-26")))
        assertNull(Policy.dayIndex(java.time.LocalDate.parse("2026-10-16"),java.time.LocalDate.parse("2026-10-23")))
    }
    @Test fun dayWindowIsBounded() { assertTrue(Policy.validWindow(0,7));assertFalse(Policy.validWindow(1,7));assertFalse(Policy.validWindow(-1,1)) }
}
