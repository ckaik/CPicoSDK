#ifndef CPICOSDK_BTSTACK_CONFIG_H
#define CPICOSDK_BTSTACK_CONFIG_H

// CPicoSDK's fixed BTstack configuration for the Radio_CYW43439_BLE combinations.
//
// The generator harness and the finalize harness each hold a copy of this file, and the two must
// stay byte-identical: these macros change BTstack struct layouts and which functions exist, so
// the header Swift imports and the C code that gets linked have to agree. Apps can't override it.
//
// ENABLE_BLE comes from linking pico_btstack_ble; don't define it here.

#ifndef ENABLE_BLE
#error "btstack_config.h is only for builds that link pico_btstack_ble."
#endif

// MARK: - Features

#define ENABLE_LE_PERIPHERAL
#define ENABLE_LE_CENTRAL
// Compiled in so the GATT server can answer reads and writes later; not part of the Swift API.
#define ENABLE_ATT_DELAYED_RESPONSE
#define ENABLE_LE_SECURE_CONNECTIONS
#define ENABLE_MICRO_ECC_FOR_LE_SECURE_CONNECTIONS
#define ENABLE_GATT_CLIENT_PAIRING

// Deliberately not defined: HAVE_MALLOC (every pool below is static), ENABLE_LE_SIGNED_WRITE,
// ENABLE_LE_PRIVACY_ADDRESS_RESOLUTION (SM resolves a bonded peer's RPA in software without it),
// ENABLE_LE_EXTENDED_ADVERTISING and ENABLE_GATT_CLIENT_SERVICE_CHANGED.

// MARK: - Buffers

// The CYW43 transport writes its 4-byte packet header in front of each outgoing packet and needs
// 4-aligned ACL chunks (btstack_hci_transport_cyw43.c #errors otherwise).
#define HCI_OUTGOING_PRE_BUFFER_SIZE 4
#define HCI_ACL_CHUNK_SIZE_ALIGNMENT 4
// LE Secure Connections needs at least 69 bytes (sm.c).
#define HCI_ACL_PAYLOAD_SIZE (255 + 4)

// MARK: - Pools

#define MAX_NR_HCI_CONNECTIONS 2
#define MAX_NR_GATT_CLIENTS 2
#define MAX_ATT_DB_SIZE 512
#define MAX_NR_LE_DEVICE_DB_ENTRIES 16
// Required by le_device_db_tlv.c.
#define NVM_NUM_DEVICE_DB_ENTRIES 16
// BTstack's own spelling ("NVN").
#define NVN_NUM_GATT_SERVER_CCC 64
#define MAX_NR_SM_LOOKUP_ENTRIES 3

// The remaining values are pico-examples' (pico_w/bt/standalone/btstack_config_common.h).
#define MAX_NR_WHITELIST_ENTRIES 16

// MARK: - CYW43 shared bus

// Limit the controller buffers BTstack uses, and enable Controller-to-Host flow control, so the
// CYW43 shared bus isn't overrun. hci.c requires all four HCI_HOST_* values once flow control is
// on, SCO ones included.
#define MAX_NR_CONTROLLER_ACL_BUFFERS 3
#define MAX_NR_CONTROLLER_SCO_PACKETS 3
#define ENABLE_HCI_CONTROLLER_TO_HOST_FLOW_CONTROL
#define HCI_HOST_ACL_PACKET_LEN (255 + 4)
#define HCI_HOST_ACL_PACKET_NUM 3
#define HCI_HOST_SCO_PACKET_LEN 120
#define HCI_HOST_SCO_PACKET_NUM 3

// MARK: - HAL

// The async_context run loop takes time from to_ms_since_boot.
#define HAVE_EMBEDDED_TIME_MS
// Map btstack_assert onto the Pico SDK's assert().
#define HAVE_ASSERT
#define HCI_RESET_RESEND_TIMEOUT_MS 1000
#define ENABLE_SOFTWARE_AES128
// pico_btstack_base always compiles hci_dump_embedded_stdout.c, which #errors without it. Nothing
// calls the dump unless an app installs it, so --gc-sections drops it.
#define ENABLE_PRINTF_HEXDUMP

#endif
