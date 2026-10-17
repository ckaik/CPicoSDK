// Publishes where BTstack's flash bank lives, as this build's C preprocessor sees it, so that
// FinalizeBinaryPlugin can reject images that reach it (FlashGuardTool). Only BLE builds compile this
// file.
//
// The values become absolute ELF symbols: they take no space in the image, and they survive
// --gc-sections even though the function that emits them is discarded. The region runs from the
// bank to the end of flash, which also covers the RP2350-E10 erratum sector that the SDK leaves free
// above the bank when PICO_RP2350_A2_SUPPORTED is set.

#include "hardware/regs/addressmap.h"
#include "pico/btstack_flash_bank.h"

_Static_assert(
    PICO_FLASH_BANK_STORAGE_OFFSET + PICO_FLASH_BANK_TOTAL_SIZE <= PICO_FLASH_SIZE_BYTES,
    "BTstack's flash bank must lie inside flash"
);

#define CPICOSDK_ABSOLUTE_SYMBOL(name, value) \
    __asm__(".globl " #name "\n\t.set " #name ", %c0" :: "i"(value))

__attribute__((used)) static void cpicosdk_btstack_flash_guard_symbols(void) {
    CPICOSDK_ABSOLUTE_SYMBOL(__cpicosdk_btstack_flash_reserved_start, XIP_BASE + PICO_FLASH_BANK_STORAGE_OFFSET);
    CPICOSDK_ABSOLUTE_SYMBOL(__cpicosdk_btstack_flash_reserved_end, XIP_BASE + PICO_FLASH_SIZE_BYTES);
}
