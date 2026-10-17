import type { PluginListenerHandle } from '@capacitor/core';
export type Metric = 'heartRate' | 'bloodOxygen' | 'hrv' | 'stress' | 'steps' | 'sleep';
export type DeviceKind = 'band' | 'watch' | 'ring';
export type Support = 'supported' | 'unsupported' | 'unknown';
export type WristbandErrorCode = 'NOT_INITIALIZED' | 'PERMISSION_DENIED' | 'BLUETOOTH_OFF' | 'DEVICE_NOT_FOUND' | 'NOT_CONNECTED' | 'UNSUPPORTED' | 'CAPABILITY_UNKNOWN' | 'INVALID_ARGUMENT' | 'BUSY' | 'TIMEOUT' | 'CANCELLED' | 'DISCONNECTED' | 'SDK_ERROR' | 'WRITE_VERIFICATION_FAILED';
export interface ErrorDetails { code: WristbandErrorCode; message: string; operation?: string; vendorCode?: string; writeAcknowledged?: boolean; requestedDate?: string; returnedDate?: string }
export interface OperationSupport { support: Support; reason?: string }
export interface FieldCapability extends OperationSupport { readable: boolean; writable: boolean; min?: number; max?: number; step?: number; allowedValues?: number[] }
export interface MetricCapability { history: OperationSupport; settings: { enabled: FieldCapability; intervalMinutes: FieldCapability } }
export interface DeviceCapabilities { metrics: Record<Metric, MetricCapability> }
export interface DeviceInfo { deviceId: string; name?: string; mac?: string; firmware?: string; hardware?: string; deviceKind: DeviceKind }
export interface Battery { level: number; charging?: boolean }
export interface WristbandState { bluetooth: 'unknown' | 'on' | 'off' | 'unauthorized' | 'unsupported'; connection: 'disconnected' | 'connecting' | 'initializing' | 'ready'; scanning: boolean; deviceId?: string; operationId?: string }
export interface Permissions { bluetooth: 'prompt' | 'prompt-with-rationale' | 'granted' | 'denied'; location?: 'prompt' | 'prompt-with-rationale' | 'granted' | 'denied' }
export interface SettingsPatch { enabled?: boolean; intervalMinutes?: number }
export interface MeasurementSettings { metric: Metric; enabled?: boolean; intervalMinutes?: number; source: 'device'; readAt: number; capabilities: MetricCapability['settings'] }
export interface SettingsResult { verification: 'readBack' | 'acknowledged'; settings?: MeasurementSettings }
export type RecordSource = 'scheduled';
export interface RecordBase { date: string; source: RecordSource; timestamp?: number; utcOffsetMinutes?: number; timestampSource?: 'sdk' | 'reconstructed' }
export interface NumericRecord extends RecordBase { metric: Exclude<Metric,'steps'|'sleep'>; value: number; unit: 'bpm' | '%' | 'vendor'; sampleIndex: number; intervalMinutes?: number }
export interface StepsRecord extends RecordBase { metric: 'steps'; sampleIndex?: number; intervalMinutes?: number; steps: number; distanceMeters: number }
export interface SleepRecord extends RecordBase { metric: 'sleep'; start?: number; end?: number; durationSeconds: number; nap: boolean; phases: { stage: 'awake'|'light'|'deep'|'rem'|'unknown'; start?: number; end?: number; durationSeconds: number }[] }
export type HealthRecord = NumericRecord | StepsRecord | SleepRecord;
export interface HistoryOptions { metric: Metric; startDay: number; days: number }
export interface HistoryBatch { operationId: string; deviceId: string; batchIndex: number; metric: Metric; date: string; status: 'success'|'error'; records: HealthRecord[]; error?: ErrorDetails }
export interface HistoryResult { operationId: string; deviceId: string; status:'success'|'partial'|'failed'; batches: HistoryBatch[] }
export type SyncResult = HistoryResult;
export interface SyncOptions { metrics: Metric[]; startDay: number; days: number }
export interface WristbandEvents {
  bluetoothStateChanged: { bluetooth: WristbandState['bluetooth'] };
  scanResult: { deviceId: string; name?: string; rssi: number };
  scanStopped: { reason: 'requested'|'timeout'|'connecting'|'bluetoothOff' };
  connectionStateChanged: WristbandState;
  historyBatch: HistoryBatch;
  syncProgress: { operationId: string; deviceId: string; completed: number; total: number };
}
export interface WristbandPlugin {
  initialize(options: { deviceKind: DeviceKind; debug?: boolean }): Promise<WristbandState>;
  checkPermissions(): Promise<Permissions>;
  requestPermissions(): Promise<Permissions>;
  getState(): Promise<WristbandState>;
  startScan(options?: {timeoutMs?: number}): Promise<void>;
  stopScan(): Promise<void>;
  connect(options: {deviceId: string; timeoutMs?: number}): Promise<DeviceInfo>;
  disconnect(): Promise<void>;
  reconnect(options?: {timeoutMs?: number}): Promise<DeviceInfo>;
  forgetDevice(): Promise<void>;
  getDeviceInfo(): Promise<DeviceInfo>;
  getBattery(): Promise<Battery>;
  getCapabilities(): Promise<DeviceCapabilities>;
  getHistory(options: HistoryOptions): Promise<HistoryResult>;
  syncHistory(options: SyncOptions): Promise<SyncResult>;
  getMeasurementSettings(options: {metric: Metric}): Promise<MeasurementSettings>;
  setMeasurementSettings(options: {metric: Metric; patch: SettingsPatch}): Promise<SettingsResult>;
  addListener<E extends keyof WristbandEvents>(event: E, listener: (event: WristbandEvents[E]) => void): Promise<PluginListenerHandle>;
  removeAllListeners(): Promise<void>;
}
