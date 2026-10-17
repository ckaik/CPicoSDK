//% -- test yaml
//% name: MulticoreStartedQuery
//% timeout: 6s
//% concurrency: true
//% traits:
//%   add: [StdIO_RTT]
//% expect:
//%   durationMs:
//%     min: 0
//%     max: 6000
//% -----------

import CPicoSDK
import CPicoConcurrency

/// Goal: `ConcurrencyRuntime.isMulticoreStarted` reports the scheduler's core1
/// latch, so debug checks that must trap once multicore is live can rely on it.
/// The device test runner does not start core1, so the query starts out false,
/// flips to true when `startMulticore()` launches core1, and stays true across a
/// repeated start.
func multicoreStartedQueryFollowsStartMulticore() async throws {
    let startedBefore = ConcurrencyRuntime.isMulticoreStarted
    print("multicore-started before=\(startedBefore)")
    try deviceExpect(!startedBefore, "multicore reported started before startMulticore()")

    ConcurrencyRuntime.startMulticore()

    let startedAfter = ConcurrencyRuntime.isMulticoreStarted
    print("multicore-started after=\(startedAfter)")
    try deviceExpect(startedAfter, "multicore not reported started after startMulticore()")

    ConcurrencyRuntime.startMulticore()

    try deviceExpect(ConcurrencyRuntime.isMulticoreStarted, "multicore not reported started after a repeated startMulticore()")
}
