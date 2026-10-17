import CPicoSDK

/// Configuration for the embedded Swift concurrency scheduler.
///
/// Configure this from `EmbeddedAsyncApp.configure(with:)`, before the async app
/// enters `setup()`. `EmbeddedAsyncApp` reads the sealed configuration and
/// explicitly starts core1 after `setup()` completes.
public struct ConcurrencyConfiguration: Configuration {
    public static var id: String { "CPicoConcurrency-ConcurrencyConfiguration" }

    public let core1Enabled: Bool

    public init(core1Enabled: Bool = true) {
        self.core1Enabled = core1Enabled
    }
}

public extension Configurator {
    var core1Enabled: Bool {
        get {
            configurations(for: ConcurrencyConfiguration.self).last?.core1Enabled ?? true
        }
        set {
            configure(ConcurrencyConfiguration(core1Enabled: newValue))
        }
    }
}

public enum ConcurrencyRuntime {
    /// Starts core1 and attaches it to the Swift concurrency scheduler.
    ///
    /// `EmbeddedAsyncApp` calls this automatically after `setup()` when
    /// `core1Enabled` is true.
    /// Apps with a custom `@main` can call this after their CPicoSDK
    /// configuration has been sealed and before they expect work to run on
    /// core1.
    public static func startMulticore() {
        cshimsRuntimeScheduler.startMulticore()
    }

    /// Whether `startMulticore()` has started core1 for the scheduler.
    ///
    /// Becomes true on the first successful `startMulticore()` call and stays
    /// true. It stays false when core1 has no scheduler stack
    /// (`CPICOSDK_CORE1_STACK_SIZE_BYTES=0`) or when `startMulticore()` was only
    /// called from core1, because neither starts core1. Debug checks for
    /// core0-only, single-core APIs can trap once this is true.
    public static var isMulticoreStarted: Bool {
        cshimsRuntimeScheduler.isMulticoreStarted
    }
}
