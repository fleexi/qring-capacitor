import { WebPlugin } from '@capacitor/core';
import type { WristbandPlugin } from './definitions.js';

export class WristbandWeb extends WebPlugin implements WristbandPlugin {
  private unsupportedPlatform(): never { throw Object.assign(new Error('Wristband requires iOS or Android'), {code:'UNSUPPORTED'}); }
  async initialize(..._args: Parameters<WristbandPlugin['initialize']>): ReturnType<WristbandPlugin['initialize']> { return this.unsupportedPlatform(); }
  async checkPermissions(..._args: Parameters<WristbandPlugin['checkPermissions']>): ReturnType<WristbandPlugin['checkPermissions']> { return this.unsupportedPlatform(); }
  async requestPermissions(..._args: Parameters<WristbandPlugin['requestPermissions']>): ReturnType<WristbandPlugin['requestPermissions']> { return this.unsupportedPlatform(); }
  async getState(..._args: Parameters<WristbandPlugin['getState']>): ReturnType<WristbandPlugin['getState']> { return this.unsupportedPlatform(); }
  async startScan(..._args: Parameters<WristbandPlugin['startScan']>): ReturnType<WristbandPlugin['startScan']> { return this.unsupportedPlatform(); }
  async stopScan(..._args: Parameters<WristbandPlugin['stopScan']>): ReturnType<WristbandPlugin['stopScan']> { return this.unsupportedPlatform(); }
  async connect(..._args: Parameters<WristbandPlugin['connect']>): ReturnType<WristbandPlugin['connect']> { return this.unsupportedPlatform(); }
  async disconnect(..._args: Parameters<WristbandPlugin['disconnect']>): ReturnType<WristbandPlugin['disconnect']> { return this.unsupportedPlatform(); }
  async reconnect(..._args: Parameters<WristbandPlugin['reconnect']>): ReturnType<WristbandPlugin['reconnect']> { return this.unsupportedPlatform(); }
  async forgetDevice(..._args: Parameters<WristbandPlugin['forgetDevice']>): ReturnType<WristbandPlugin['forgetDevice']> { return this.unsupportedPlatform(); }
  async getDeviceInfo(..._args: Parameters<WristbandPlugin['getDeviceInfo']>): ReturnType<WristbandPlugin['getDeviceInfo']> { return this.unsupportedPlatform(); }
  async getBattery(..._args: Parameters<WristbandPlugin['getBattery']>): ReturnType<WristbandPlugin['getBattery']> { return this.unsupportedPlatform(); }
  async getCapabilities(..._args: Parameters<WristbandPlugin['getCapabilities']>): ReturnType<WristbandPlugin['getCapabilities']> { return this.unsupportedPlatform(); }
  async getHistory(..._args: Parameters<WristbandPlugin['getHistory']>): ReturnType<WristbandPlugin['getHistory']> { return this.unsupportedPlatform(); }
  async syncHistory(..._args: Parameters<WristbandPlugin['syncHistory']>): ReturnType<WristbandPlugin['syncHistory']> { return this.unsupportedPlatform(); }
  async getMeasurementSettings(..._args: Parameters<WristbandPlugin['getMeasurementSettings']>): ReturnType<WristbandPlugin['getMeasurementSettings']> { return this.unsupportedPlatform(); }
  async setMeasurementSettings(..._args: Parameters<WristbandPlugin['setMeasurementSettings']>): ReturnType<WristbandPlugin['setMeasurementSettings']> { return this.unsupportedPlatform(); }
}
