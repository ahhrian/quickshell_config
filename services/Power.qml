pragma Singleton

import Quickshell
import QtQuick
import Quickshell.Services.UPower

import "../shared"

Singleton {
  id: root

  readonly property var device: UPower.displayDevice
  readonly property string battery: device ? Math.round(device.percentage * 100) + "%" : "N.A"
  readonly property bool isCharging: device ? (
    device.state === UPowerDeviceState.Charging ||
    device.state === UPowerDeviceState.PendingCharge ||
    (!UPower.onBattery && device.state === UPowerDeviceState.FullyCharged)
  ) : false
  readonly property string icon: iconName()
  readonly property color color: getColor()

  readonly property color red_indicator: Theme.colors.red
  readonly property color yellow_indicator: Theme.colors.yellow
  readonly property color default_color: "#ffffff"
  
  function iconName() {
    if (device) {
      var charge = Math.round(device.percentage * 100)

      if (isCharging) {
        if (charge >= 95 || device.state === UPowerDeviceState.FullyCharged) {
          return "battery_charging_full"
        }
        if (charge >= 85) {
          return "battery_charging_90"
        }
        if (charge >= 70) {
          return "battery_charging_80"
        }
        if (charge >= 55) {
          return "battery_charging_60"
        }
        if (charge >= 40) {
          return "battery_charging_50"
        }
        if (charge >= 25) {
          return "battery_charging_30"
        }
        return "battery_charging_20"
      }

      // Every 15% is a new icon. Below 15% use alert icon, above 90% use full icon
      // Using Google Material Symbols
      var num = Math.floor((charge - 1) / 15) + 1;

      if (charge > 90) {
        // return "battery_android_full"
        return "battery_full"
      }

      if (charge < 15) {
        // return "battery_android_alert"
        return "battery_alert"
      }

      // return "battery_android_" + num
      return "battery_" + num + "_bar"
    }
    // return "battery_android_question"
    return "battery_unknown"
  }

  function getColor() {
    if (device) {
      var charge = Math.round(device.percentage * 100)

      if (charge < 15) {
        return red_indicator
      }
      if (charge <= 30) {
        return yellow_indicator
      }
      return default_color
    }
    return default_color
  }
}