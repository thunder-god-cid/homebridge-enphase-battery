// index.js
const fetch = require('node-fetch');

let Service, Characteristic;

class EnphaseBatteryPlugin {
  constructor(log, config, api) {
    this.log = log;
    this.config = config;
    this.api = api;

    // Configuration
    this.name = config.name || 'Enphase Battery';
    this.systemId = config.systemId;
    this.apiKey = config.apiKey;
    this.accessToken = config.accessToken;
    
    // API endpoints
    this.apiBase = 'https://api.enphaseenergy.com/api/v4';
    
    // Required checks
    if (!this.systemId || !this.apiKey || !this.accessToken) {
      this.log.error('Missing required configuration. Please check your config.json');
      return;
    }

    // Initialize services when loaded
    this.api.on('didFinishLaunching', () => {
      this.initializeServices();
      this.startPolling();
    });
  }

  initializeServices() {
    // Create battery service
    this.batteryService = new Service.BatteryService(this.name);

    // Battery Level Characteristic
    this.batteryService
      .getCharacteristic(Characteristic.BatteryLevel)
      .onGet(this.getBatteryLevel.bind(this));

    // Charging State Characteristic
    this.batteryService
      .getCharacteristic(Characteristic.ChargingState)
      .onGet(this.getChargingState.bind(this));

    // Status Low Battery Characteristic
    this.batteryService
      .getCharacteristic(Characteristic.StatusLowBattery)
      .onGet(this.getLowBatteryStatus.bind(this));
  }

  startPolling() {
    // Poll every 5 minutes
    setInterval(async () => {
      try {
        await this.updateBatteryStatus();
      } catch (error) {
        this.log.error('Error updating battery status:', error);
      }
    }, 5 * 60 * 1000);
  }

  async updateBatteryStatus() {
    try {
      const response = await fetch(
        `${this.apiBase}/systems/${this.systemId}/telemetry/battery`,
        {
          headers: {
            'Authorization': `Bearer ${this.accessToken}`,
            'key': this.apiKey
          }
        }
      );

      if (!response.ok) {
        throw new Error(`API response: ${response.status}`);
      }

      const data = await response.json();
      
      // Update battery level
      if (data.intervals && data.intervals.length > 0) {
        const lastInterval = data.intervals[data.intervals.length - 1];
        if (lastInterval.soc && lastInterval.soc.percent !== undefined) {
          this.currentBatteryLevel = lastInterval.soc.percent;
          this.batteryService.updateCharacteristic(
            Characteristic.BatteryLevel,
            this.currentBatteryLevel
          );
        }
        
        // Update charging state based on charge/discharge values
        if (lastInterval.charge && lastInterval.discharge) {
          const isCharging = lastInterval.charge.enwh > 0;
          const isDischarging = lastInterval.discharge.enwh > 0;
          
          let chargingState = Characteristic.ChargingState.NOT_CHARGING;
          if (isCharging) {
            chargingState = Characteristic.ChargingState.CHARGING;
          }
          
          this.batteryService.updateCharacteristic(
            Characteristic.ChargingState,
            chargingState
          );
        }
      }
    } catch (error) {
      this.log.error('Error fetching battery status:', error);
      throw error;
    }
  }

  async getBatteryLevel() {
    try {
      await this.updateBatteryStatus();
      return this.currentBatteryLevel;
    } catch (error) {
      this.log.error('Error getting battery level:', error);
      throw new this.api.hap.HapStatusError(this.api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE);
    }
  }

  async getChargingState() {
    try {
      await this.updateBatteryStatus();
      return this.currentChargingState;
    } catch (error) {
      this.log.error('Error getting charging state:', error);
      throw new this.api.hap.HapStatusError(this.api.hap.HAPStatus.SERVICE_COMMUNICATION_FAILURE);
    }
  }

  async getLowBatteryStatus() {
    // Consider battery low if less than 20%
    return this.currentBatteryLevel < 20 
      ? Characteristic.StatusLowBattery.BATTERY_LEVEL_LOW 
      : Characteristic.StatusLowBattery.BATTERY_LEVEL_NORMAL;
  }

  getServices() {
    return [this.batteryService];
  }
}

module.exports = (api) => {
  Service = api.hap.Service;
  Characteristic = api.hap.Characteristic;
  
  api.registerAccessory('homebridge-enphase-battery', 'EnphaseBattery', EnphaseBatteryPlugin);
};
