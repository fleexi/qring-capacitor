import { Wristband, type Metric } from 'capacitor-wristband';
const log = document.querySelector<HTMLPreElement>('#log')!;
const metric = () => (document.querySelector<HTMLSelectElement>('#metric')!.value as Metric);
const report = (label: string, value: unknown) => { log.textContent = `${label}: ${JSON.stringify(value, null, 2)}\n${log.textContent}`.slice(0, 30000); };
async function run(action: string) {
  switch (action) {
    case 'initialize': return Wristband.initialize({deviceKind: document.querySelector<HTMLSelectElement>('#kind')!.value as 'band'|'watch'|'ring'});
    case 'permissions': return Wristband.requestPermissions();
    case 'scan': return Wristband.startScan();
    case 'connect': return Wristband.connect({deviceId: document.querySelector<HTMLInputElement>('#device')!.value});
    case 'state': return Wristband.getState();
    case 'capabilities': return Wristband.getCapabilities();
    case 'battery': return Wristband.getBattery();
    case 'settings': return Wristband.getMeasurementSettings({metric: metric()});
    case 'write': {
      const interval=document.querySelector<HTMLInputElement>('#interval')!.value;
      return Wristband.setMeasurementSettings({metric: metric(),patch:{enabled:document.querySelector<HTMLInputElement>('#enabled')!.checked,...(interval?{intervalMinutes:Number(interval)}:{})}});
    }
    case 'history': return Wristband.getHistory({metric: metric(),startDay:0,days:7});
    case 'disconnect': return Wristband.disconnect();
    case 'reconnect': return Wristband.reconnect();
    case 'forget': return Wristband.forgetDevice();
  }
}
for (const button of document.querySelectorAll<HTMLButtonElement>('[data-action]')) button.onclick=()=>{const action=button.dataset.action!;void run(action).then(v=>report(action,v)).catch(e=>report(action,{code:e.code,message:e.message,data:e.data}));};
for(const name of ['connectionStateChanged','bluetoothStateChanged','historyBatch','syncProgress'] as const) void Wristband.addListener(name,event=>report(name,event));
void Wristband.addListener('scanResult',device=>{report('scanResult',device);const list=document.querySelector<HTMLDivElement>('#devices')!;let button=document.getElementById(device.deviceId) as HTMLButtonElement|null;if(!button){button=document.createElement('button');button.id=device.deviceId;button.onclick=()=>{document.querySelector<HTMLInputElement>('#device')!.value=device.deviceId;};list.append(button);}button.textContent=`${device.name??'BLE'} ${device.deviceId} (${device.rssi})`;});
