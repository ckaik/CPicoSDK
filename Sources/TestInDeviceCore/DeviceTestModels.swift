import Foundation

public enum DeviceTestHarnessError: Error, CustomStringConvertible, Equatable {
    case missingMetadataBlock(String)
    case invalidMetadata(String)
    case noCallableTests(String)
    case unsupportedSwiftTestingSyntax(String)
    case asyncTestRequiresConcurrency(String)
    case processFailed(command: String, status: Int32, output: String)
    case missingTool(String)
    case missingArtifact(String)

    public var description: String {
        switch self {
        case .missingMetadataBlock(let path):
            return "missing //% metadata block in \(path)"
        case .invalidMetadata(let message):
            return "invalid metadata: \(message)"
        case .noCallableTests(let path):
            return "no top-level no-argument test functions found in \(path)"
        case .unsupportedSwiftTestingSyntax(let path):
            return "Swift Testing syntax is not supported by this embedded harness yet: \(path)"
        case .asyncTestRequiresConcurrency(let name):
            return "async test '\(name)' requires metadata concurrency: true"
        case .processFailed(let command, let status, let output):
            return "command failed with status \(status): \(command)\n\(output)"
        case .missingTool(let name):
            return "required tool not found: \(name)"
        case .missingArtifact(let name):
            return "required build artifact not found: \(name)"
        }
    }
}

public struct DeviceTestMetadata: Equatable {
    public var name: String
    public var timeoutMilliseconds: Int
    public var buildType: DeviceBuildType
    public var concurrency: Bool
    public var traits: TraitSelection
    public var swiftDefines: [String]
    public var alternatives: [DeviceTestAlternative]
    public var expectations: DeviceExpectations

    public init(
        name: String,
        timeoutMilliseconds: Int = 5_000,
        buildType: DeviceBuildType = .debug,
        concurrency: Bool = false,
        traits: TraitSelection = TraitSelection(),
        swiftDefines: [String] = [],
        alternatives: [DeviceTestAlternative] = [],
        expectations: DeviceExpectations = DeviceExpectations()
    ) {
        self.name = name
        self.timeoutMilliseconds = timeoutMilliseconds
        self.buildType = buildType
        self.concurrency = concurrency
        self.traits = traits
        self.swiftDefines = swiftDefines
        self.alternatives = alternatives
        self.expectations = expectations
    }
}

public struct DeviceTestAlternative: Equatable {
    public var name: String
    public var timeoutMilliseconds: Int?
    public var buildType: DeviceBuildType?
    public var concurrency: Bool?
    public var traits: TraitSelection
    public var swiftDefines: [String]

    public init(
        name: String,
        timeoutMilliseconds: Int? = nil,
        buildType: DeviceBuildType? = nil,
        concurrency: Bool? = nil,
        traits: TraitSelection = TraitSelection(),
        swiftDefines: [String] = []
    ) {
        self.name = name
        self.timeoutMilliseconds = timeoutMilliseconds
        self.buildType = buildType
        self.concurrency = concurrency
        self.traits = traits
        self.swiftDefines = swiftDefines
    }
}

public enum DeviceBuildType: String, CaseIterable, Equatable {
    case debug = "Debug"
    case release = "Release"
    case releaseWithDebugInfo = "RelWithDebInfo"
    case minimumSizeRelease = "MinSizeRel"

    public init(metadataValue: String) throws {
        switch metadataValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "debug":
            self = .debug
        case "release":
            self = .release
        case "relwithdebinfo", "relwithdebuginfo":
            self = .releaseWithDebugInfo
        case "minsizerel", "minimumsizerelease":
            self = .minimumSizeRelease
        default:
            throw DeviceTestHarnessError.invalidMetadata(
                "unknown buildType '\(metadataValue)'; expected Debug, Release, RelWithDebInfo, or MinSizeRel"
            )
        }
    }

    public var swiftConfiguration: String {
        switch self {
        case .debug:
            return "debug"
        case .release, .releaseWithDebugInfo, .minimumSizeRelease:
            return "release"
        }
    }
}

public struct TraitSelection: Equatable {
    public var add: [String]
    public var remove: [String]

    public init(add: [String] = [], remove: [String] = []) {
        self.add = add
        self.remove = remove
    }

    public static let defaultTraits = DeviceTestTarget.rp2350.defaultTraits

    public func resolvedTraits(defaultTraits: [String] = Self.defaultTraits) -> [String] {
        var result = defaultTraits
        for removed in remove {
            result.removeAll { $0 == removed }
        }
        for added in add where !result.contains(added) {
            if added.hasPrefix("StdIO_") {
                result.removeAll { $0.hasPrefix("StdIO_") }
            }
            for prefix in DeviceTestTarget.boardDefiningTraitPrefixes where added.hasPrefix(prefix) {
                result.removeAll { $0.hasPrefix(prefix) }
            }
            result.append(added)
        }
        if !result.contains(where: { $0.hasPrefix("StdIO_") }) {
            result.append("StdIO_RTT")
        }
        return result
    }
}

public enum DeviceTestTarget: String, CaseIterable, Equatable {
    case rp2040
    case rp2350
    case picoW = "pico_w"
    case pico2W = "pico2_w"

    public static let boardDefiningTraitPrefixes = [
        "Platform_",
        "Variant_",
        "Radio_",
    ]

    public init(argument: String) throws {
        switch argument.lowercased() {
        case "rp2040", "pico":
            self = .rp2040
        case "rp2350", "pico2":
            self = .rp2350
        case "pico_w":
            self = .picoW
        case "pico2_w":
            self = .pico2W
        default:
            throw DeviceTestHarnessError.invalidMetadata(
                "unknown device target '\(argument)'; expected rp2040, rp2350, pico_w or pico2_w"
            )
        }
    }

    public var board: String {
        switch self {
        case .rp2040:
            return "pico"
        case .rp2350:
            return "pico2"
        case .picoW:
            return "pico_w"
        case .pico2W:
            return "pico2_w"
        }
    }

    /// The CPicoSDK combination (`BOARD`) a test with these resolved traits builds against.
    /// `Radio_CYW43439_BLE` selects the board's `_ble` combination, which shares its Pico SDK board.
    public func board(forTraits traits: [String]) -> String {
        traits.contains(Self.bleRadioTrait) ? "\(board)_ble" : board
    }

    public var hasCYW43439Radio: Bool {
        switch self {
        case .rp2040, .rp2350:
            return false
        case .picoW, .pico2W:
            return true
        }
    }

    /// Why this target can't run the test, or `nil` when it can.
    public func skipReason(for metadata: DeviceTestMetadata) -> String? {
        if metadata.concurrency && !supportsConcurrency {
            return "target \(rawValue) does not support concurrency"
        }

        if metadata.traits.add.contains(Self.bleRadioTrait) && !hasCYW43439Radio {
            return "target \(rawValue) has no CYW43439 radio for \(Self.bleRadioTrait)"
        }

        return nil
    }

    static let bleRadioTrait = "Radio_CYW43439_BLE"

    public var openOCDTargetConfig: String {
        switch self {
        case .rp2040, .picoW:
            return "target/rp2040.cfg"
        case .rp2350, .pico2W:
            return "target/rp2350.cfg"
        }
    }

    public var rttMemorySize: UInt32 {
        switch self {
        case .rp2040, .picoW:
            return 0x40000
        case .rp2350, .pico2W:
            return 0x80000
        }
    }

    public var swiftPMTriple: String {
        switch self {
        case .rp2040, .picoW:
            return "armv6m-none-none-eabi"
        case .rp2350, .pico2W:
            return "armv7em-none-none-eabi"
        }
    }

    public var supportsConcurrency: Bool {
        switch self {
        case .rp2040, .picoW:
            return false
        case .rp2350, .pico2W:
            return true
        }
    }

    public var defaultTraits: [String] {
        switch self {
        case .rp2040:
            return [
                "BootStage2_W25Q080",
                "StdIO_RTT",
                "Platform_RP2040",
                "Variant_RP2040",
                "Radio_None",
            ]
        case .picoW:
            return [
                "BootStage2_W25Q080",
                "StdIO_RTT",
                "Platform_RP2040",
                "Variant_RP2040",
                "Radio_CYW43439",
            ]
        case .rp2350:
            return [
                "BootStage2_W25Q080",
                "StdIO_RTT",
                "Platform_RP2350",
                "Variant_RP2350A",
                "Radio_None",
            ]
        case .pico2W:
            return [
                "BootStage2_W25Q080",
                "StdIO_RTT",
                "Platform_RP2350",
                "Variant_RP2350A",
                "Radio_CYW43439",
            ]
        }
    }
}

public struct DeviceExpectations: Equatable {
    public var stdout: StdoutExpectation?
    public var duration: DurationExpectation?

    public init(stdout: StdoutExpectation? = nil, duration: DurationExpectation? = nil) {
        self.stdout = stdout
        self.duration = duration
    }
}

public struct StdoutExpectation: Equatable {
    public var equals: String?
    public var contains: String?
    public var regex: String?

    public init(equals: String? = nil, contains: String? = nil, regex: String? = nil) {
        self.equals = equals
        self.contains = contains
        self.regex = regex
    }
}

public struct DurationExpectation: Equatable {
    public var minMilliseconds: Int?
    public var maxMilliseconds: Int?

    public init(minMilliseconds: Int? = nil, maxMilliseconds: Int? = nil) {
        self.minMilliseconds = minMilliseconds
        self.maxMilliseconds = maxMilliseconds
    }
}

public struct DeviceTestFunction: Equatable {
    public var name: String
    public var isAsync: Bool
    public var isThrowing: Bool

    public init(name: String, isAsync: Bool, isThrowing: Bool) {
        self.name = name
        self.isAsync = isAsync
        self.isThrowing = isThrowing
    }
}

public struct DeviceTestSource: Equatable {
    public var fileURL: URL
    public var source: String
    public var metadata: DeviceTestMetadata
    public var functions: [DeviceTestFunction]

    public init(fileURL: URL, source: String, metadata: DeviceTestMetadata, functions: [DeviceTestFunction]) {
        self.fileURL = fileURL
        self.source = source
        self.metadata = metadata
        self.functions = functions
    }
}

public struct GeneratedPackage: Equatable {
    public var packageDirectory: URL
    public var elfURL: URL
    public var productName: String
    /// The CPicoSDK combination the package builds against; exported as `BOARD`.
    public var board: String
    public var inputsChanged: Bool

    public init(packageDirectory: URL, elfURL: URL, productName: String, board: String, inputsChanged: Bool = true) {
        self.packageDirectory = packageDirectory
        self.elfURL = elfURL
        self.productName = productName
        self.board = board
        self.inputsChanged = inputsChanged
    }
}

public struct DeviceTestEvaluation: Equatable {
    public var passed: Bool
    public var reason: String?

    public init(passed: Bool, reason: String? = nil) {
        self.passed = passed
        self.reason = reason
    }
}

public struct DeviceFunctionDuration: Equatable {
    public var name: String
    public var durationMilliseconds: Int
    public var passed: Bool

    public init(name: String, durationMilliseconds: Int, passed: Bool = true) {
        self.name = name
        self.durationMilliseconds = durationMilliseconds
        self.passed = passed
    }
}
