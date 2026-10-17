#pragma once

// Marker module for the Radio_CYW43439_BLE trait. CPicoSDK depends on it only
// when that trait is on, so `canImport(_CPicoSDK_BLE)` tells a dependent package
// whether BLE is available. It must stay declaration-free: the BTstack API comes
// from the `_CPicoSDK_*_ble` combination modules.
