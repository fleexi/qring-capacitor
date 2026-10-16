import { test } from 'node:test';
import assert from 'node:assert/strict';
import { WristbandWeb } from '../src/web.js';
import type { WristbandPlugin } from '../src/definitions.js';
test('web operations reject with the common UNSUPPORTED code', async () => {
  const plugin = new WristbandWeb();
  await assert.rejects(plugin.getBattery(), {code: 'UNSUPPORTED'});
  await assert.rejects(plugin.getMeasurementSettings({metric:'hrv'}), {code:'UNSUPPORTED'});
});
function contract(plugin: WristbandPlugin) {
  void plugin.initialize({deviceKind:'band'});
  void plugin.setMeasurementSettings({metric:'heartRate',patch:{enabled:false}});
  // @ts-expect-error arbitrary metrics are forbidden
  void plugin.getHistory({metric:'glucose',startDay:0,days:7});
  // @ts-expect-error arbitrary modes are forbidden
  void plugin.startMeasurement({metric:'heartRate',mode:'forever'});
  // @ts-expect-error raw vendor keys are forbidden
  void plugin.setMeasurementSettings({metric:'hrv',patch:{calibrate:3}});
}
void contract;
