#pragma once

// Picks the compound header from the board traits that Package.swift forwards
// to CShims as defines. This mirrors the combination `#if` chain in
// CPicoSDK.swift. Don't pick by `__has_include`: the combination dependencies
// are OR-ed by trait, so other boards' headers are on the include path too.
// BLE combinations come before their Wi-Fi-only twins.
#if defined(Platform_RP2040) && defined(Variant_RP2040) && defined(Radio_None)
#include "CPicoSDK_pico.h"
#elif defined(Platform_RP2040) && defined(Variant_RP2040) && defined(Radio_CYW43439_BLE)
#include "CPicoSDK_pico_w_ble.h"
#elif defined(Platform_RP2040) && defined(Variant_RP2040) && defined(Radio_CYW43439)
#include "CPicoSDK_pico_w.h"
#elif defined(Variant_RP2350A) && defined(Radio_None)
#include "CPicoSDK_pico2.h"
#elif defined(Variant_RP2350A) && defined(Radio_CYW43439_BLE)
#include "CPicoSDK_pico2_w_ble.h"
#elif defined(Variant_RP2350A) && defined(Radio_CYW43439)
#include "CPicoSDK_pico2_w.h"
#elif defined(Variant_RP2350B) && defined(Radio_None)
#include "CPicoSDK_pimoroni_pico_plus2_rp2350.h"
#elif defined(Variant_RP2350B) && defined(Radio_CYW43439)
#include "CPicoSDK_pimoroni_pico_plus2_w_rp2350.h"
#else
#error "Invalid Variant + Radio combination."
#endif
