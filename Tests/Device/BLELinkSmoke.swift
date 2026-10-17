//% -- test yaml
//% name: BLELinkSmoke
//% timeout: 10s
//% concurrency: false
//% traits:
//%   add: [StdIO_RTT, Radio_CYW43439_BLE]
//% expect:
//%   stdout:
//%     contains: "hci-state=working\n"
//%   durationMs:
//%     min: 0
//%     max: 10000
//% -----------

import CPicoSDK

// The marker module comes with Radio_CYW43439_BLE, which is how PicoBluetooth gates itself.
#if !canImport(_CPicoSDK_BLE)
    #error("Radio_CYW43439_BLE didn't make _CPicoSDK_BLE importable.")
#endif

/// Goal: a Radio_CYW43439_BLE build links the CYW43 arch in poll mode together with the BTstack LE
/// host (HCI, L2CAP, SM, ATT server and its runtime DB, GATT client, the TLV device DB) and the
/// CYW43 HCI transport. On a board, `cyw43_arch_init()` also starts BTstack, and after
/// `hci_power_control(HCI_POWER_ON)` polling brings HCI to `HCI_STATE_WORKING`. Only W targets run
/// it; the harness skips it elsewhere.
func bleLinkSmokeReachesHCIWorking() throws {
    try deviceExpect(cyw43_arch_init() == 0, "cyw43_arch_init failed")
    defer { cyw43_arch_deinit() }

    // cyw43_arch_init wires the flash-bank TLV into the LE device DB, sized by btstack_config.h.
    let deviceDBCapacity = le_device_db_max_count()
    print("le-device-db capacity=\(deviceDBCapacity)")
    try deviceExpect(deviceDBCapacity == 16, "LE device DB doesn't use NVM_NUM_DEVICE_DB_ENTRIES 16")

    l2cap_init()
    sm_init()
    att_db_util_init()
    att_server_init(att_db_util_get_address(), nil, nil)
    gatt_client_init()

    try deviceExpect(hci_power_control(HCI_POWER_ON) == 0, "hci_power_control(HCI_POWER_ON) failed")

    // The controller powers up lazily inside the transport, so HCI only gets there while we poll.
    let deadline = make_timeout_time_ms(5_000)
    while hci_get_state() != HCI_STATE_WORKING && !time_reached(deadline) {
        cyw43_arch_poll()
        cyw43_arch_wait_for_work_until(make_timeout_time_ms(10))
    }

    let working = hci_get_state() == HCI_STATE_WORKING
    print("hci-state=\(working ? "working" : "not working")")
    try deviceExpect(working, "HCI didn't reach HCI_STATE_WORKING within 5 s")

    hci_power_control(HCI_POWER_OFF)
}
