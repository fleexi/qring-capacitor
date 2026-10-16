import { registerPlugin } from '@capacitor/core';
import type { WristbandPlugin } from './definitions.js';
export const Wristband = registerPlugin<WristbandPlugin>('Wristband', {
  web: () => import('./web.js').then(m => new m.WristbandWeb()),
});
export * from './definitions.js';
