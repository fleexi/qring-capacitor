package it.tyb.wristband
import org.json.*
import com.oudmon.ble.base.bluetooth.BleOperateManager
import com.oudmon.ble.base.communication.rsp.*
import com.oudmon.ble.base.communication.bigData.*
import com.oudmon.ble.base.communication.entity.BleStepDetails
import com.oudmon.ble.base.bean.SleepDisplay
import java.time.LocalDate
// Match iOS: local daily slots, earliest offset for repeated hours, no invented gap times.
internal fun indexedTimestamp(index:Int,date:String,interval:Int):JSONObject? {
    val minutes = index.toLong() * interval
    if (interval <= 0 || minutes !in 0L until 1440L) return null
    val local = LocalDate.parse(date).atStartOfDay().plusMinutes(minutes)
    val zone = java.time.ZoneId.systemDefault()
    val offset = zone.rules.getValidOffsets(local).firstOrNull() ?: return null
    return json("timestamp" to local.toInstant(offset).toEpochMilli(),
        "utcOffsetMinutes" to offset.totalSeconds / 60,"timestampSource" to "reconstructed")
}
internal fun numericRecords(values:List<Number>?,metric:String,date:String,interval:Int=0):JSONArray=JSONArray().apply{
    // Fixed history cadence confirmed for the integrated wristband.
    val samplingInterval = when (metric) { "hrv" -> 30; "stress" -> 30; else -> interval }
    val timed = samplingInterval > 0
    values?.forEachIndexed { index, value ->
        if (value.toDouble().isFinite() && value.toDouble() > 0) {
            val record = json("metric" to metric,"date" to date,"source" to "scheduled",
                "value" to value,"unit" to Policy.unit(metric),"sampleIndex" to index,
                "intervalMinutes" to samplingInterval.takeIf { timed })
            if (timed) indexedTimestamp(index,date,samplingInterval)?.let { fields ->
                fields.keys().forEach { key -> record.put(key,fields.get(key)) }
            }
            put(record)
        }
    }
}
// HRVRsp.getArray()/getHrvArray() expand readings onto 288 daily 5-minute slots.
// Convert that SDK grid to the common 48-slot, 30-minute history contract.
internal fun hrvRecords(values:List<Number>?,date:String):JSONArray {
    val slotsPerReading = 30 / 5
    val normalized = values?.chunked(slotsPerReading)?.map { slots ->
        require(slots.drop(1).none { it.toDouble().isFinite() && it.toDouble() > 0 }) {
            "HRV SDK sample is outside the expected 30-minute grid"
        }
        slots.first()
    }
    return numericRecords(normalized,"hrv",date)
}
internal fun sdkTimestamp(seconds:Long):JSONObject {
    val instant = java.time.Instant.ofEpochSecond(seconds)
    val offset = java.time.ZoneId.systemDefault().rules.getOffset(instant)
    return json("timestamp" to instant.toEpochMilli(),"utcOffsetMinutes" to offset.totalSeconds / 60,
        "timestampSource" to "sdk")
}
internal fun stepRecords(values:List<BleStepDetails>,date:String):JSONArray=JSONArray().apply {
    values.filter { it.walkSteps > 0 || it.distance > 0 }.forEach { sample ->
        val record = json("metric" to "steps","date" to date,"source" to "scheduled",
            "steps" to sample.walkSteps,"distanceMeters" to sample.distance,
            "sampleIndex" to sample.timeIndex,"intervalMinutes" to 15)
        indexedTimestamp(sample.timeIndex,date,15)?.let { fields ->
            fields.keys().forEach { key -> record.put(key,fields.get(key)) }
        }
        put(record)
    }
}
// SDK sleepStart/sleepEnd are Unix seconds; preserve dates across midnight.
internal fun sleepRecords(r:SleepDisplay?,date:String):JSONArray=JSONArray().apply {
    fun add(phases:List<SleepDisplay.SleepDataBean>?,nap:Boolean) {
        if (phases.isNullOrEmpty()) return
        val mapped = JSONArray()
        for (sample in phases) {
            // SleepDataBean codes confirmed in the bundled SDK and paired device exports.
            val stage = when(sample.type) { 1->"deep"; 2->"light"; 3->"awake"; 4->"rem"; else->"unknown" }
            val phase = json("stage" to stage,"durationSeconds" to (sample.sleepEnd-sample.sleepStart).coerceAtLeast(0))
            if (sample.sleepStart > 0 && sample.sleepEnd > sample.sleepStart) {
                phase.put("start",sample.sleepStart*1000).put("end",sample.sleepEnd*1000)
            }
            mapped.put(phase)
        }
        val record = json("metric" to "sleep","date" to date,"source" to "scheduled","nap" to nap,
            "durationSeconds" to phases.sumOf { (it.sleepEnd-it.sleepStart).coerceAtLeast(0) },"phases" to mapped)
        if (phases.all { it.sleepStart > 0 && it.sleepEnd > it.sleepStart }) {
            val start = phases.minOf { it.sleepStart }
            record.put("start",start*1000).put("end",phases.maxOf { it.sleepEnd }*1000)
            val fields = sdkTimestamp(start)
            fields.keys().forEach { key -> record.put(key,fields.get(key)) }
        }
        put(record)
    }
    add(r?.list,false)
    add(r?.napList,true)
}
internal fun WristbandSession.readDay(m:String,day:Int,date:String,done:Reply){
    val state=metricCapability(m).getJSONObject("history").getString("support");if(state!="supported"){done(null,error(if(state=="unknown")"CAPABILITY_UNKNOWN"else "UNSUPPORTED","History support unavailable"));return}
    if(day !in 0..6){done(null,error("INVALID_ARGUMENT","Frozen date outside device retention"));return}
    val reply=once(done)
    fun <T> callback(mapper:(T)->JSONArray)=object:BleOperateManager.HealthDataCallback<T>{
        override fun onSuccess(data:T){main.post{try{reply(json("records" to mapper(data)),null)}catch(e:Exception){reply(null,error("SDK_ERROR","Malformed history: ${e.message}"))}}}
        override fun onError(code:Int,message:String?){reply(null,error("SDK_ERROR",message?:"History failed").put("vendorCode",code.toString()))}
    }
    when(m){
        "heartRate"->ble.getHeartRate(day,callback<ReadHeartRateRsp>{r->numericRecords(r.array?:r.getmHeartRateArray()?.map{it.toInt() and 255},m,date,r.interval)})
        "bloodOxygen"->ble.getBloodOxygen(day,callback<BloodOxygenEntity>{r->numericRecords(r.array,m,date,r.interval)})
        "hrv"->ble.getHrv(day,callback<HRVRsp>{r->hrvRecords(r.array?:r.hrvArray?.map{it.toInt() and 255},date)})
        "stress"->ble.getPressure(day,callback<PressureRsp>{r->numericRecords(r.array?:r.pressureArray?.map{it.toInt() and 255},m,date)})
        "steps"->ble.getStepDetail(day,callback<List<BleStepDetails>>{values->stepRecords(values,date)})
        "sleep"->ble.getSleep(day,callback<SleepDisplay?>{r->sleepRecords(r,date)})
    }
}
internal fun WristbandSession.history(metrics:List<String>,start:Int,days:Int){
    val anchor=LocalDate.now();val token=gate.token!!;val device=deviceId!!;val batches=JSONArray()
    val jobs=metrics.flatMap{m->(start until start+days).map{d->Triple(m,d,anchor.minusDays(d.toLong()).toString())}}
    historyFailure={e->Policy.failedHistory(jobs.map{it.first to it.third},batches,token,device,e)}
    fun next(index:Int){
        if(!gate.current(token))return
        if(index==jobs.size){val errors=(0 until batches.length()).count{batches.getJSONObject(it).getString("status")=="error"};complete(json("operationId" to token,"deviceId" to device,"status" to if(errors==0)"success"else if(errors==batches.length())"failed"else "partial","batches" to batches));return}
        val(m,day,date)=jobs[index]
        val adjusted=Policy.dayIndex(LocalDate.parse(date),LocalDate.now())?:-1
        readDay(m,adjusted,date){result,e->val b=json("operationId" to token,"deviceId" to device,"batchIndex" to index,"metric" to m,"date" to date,"status" to if(e==null)"success"else "error","records" to (result?.optJSONArray("records")?:JSONArray()),"error" to e)
            batches.put(b);emit("historyBatch",b);emit("syncProgress",json("operationId" to token,"deviceId" to device,"completed" to index+1,"total" to jobs.size));next(index+1)
        }
    };next(0)
}
