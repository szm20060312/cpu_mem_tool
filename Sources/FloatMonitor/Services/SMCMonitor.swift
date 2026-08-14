import Foundation
import IOKit

/// SMC 温度读取器
/// 通过 IOServiceOpen + IOConnectCallStructMethod 直接与 AppleSMC 通信
final class SMCMonitor {
    private var conn: io_connect_t = 0

    /// 常见的 CPU 温度传感器 key（按优先级排列）
    private static let temperatureKeys = [
        "Tp09", "Tp0T", "Tp01", "Tp05", "Tp0D",
        "Tp0H", "Tp0L", "Tp0P", "Tp0X", "Tp0b",
    ]

    /// 温度合理性范围（°C）。
    /// Apple Silicon 上部分 Tp key 未接入实际传感器，会返回 2~4°C 之类的假数据，
    /// 直接平均会严重拉低显示值，因此只统计落在合理范围内的读数。
    private static let validTemperatureRange = 10.0...120.0

    init?() {
        var iterator: io_iterator_t = 0
        let matchingDict = IOServiceMatching("AppleSMC")
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matchingDict, &iterator)
        guard result == kIOReturnSuccess else { return nil }

        let device = IOIteratorNext(iterator)
        IOObjectRelease(iterator)
        guard device != 0 else { return nil }

        let openResult = IOServiceOpen(device, mach_task_self_, 0, &conn)
        IOObjectRelease(device)
        guard openResult == kIOReturnSuccess else { return nil }
    }

    deinit {
        if conn != 0 {
            _ = IOServiceClose(conn)
        }
    }

    /// 读取 CPU 温度（取所有可用传感器 key 的平均值）
    func cpuTemperature() -> Double? {
        var temperatures: [Double] = []
        for key in Self.temperatureKeys {
            if let value = readValue(key), Self.validTemperatureRange.contains(value) {
                temperatures.append(value)
            }
        }
        guard !temperatures.isEmpty else { return nil }
        return temperatures.reduce(0, +) / Double(temperatures.count)
    }

    // MARK: - Private

    private func readValue(_ key: String) -> Double? {
        guard conn != 0 else { return nil }

        var input = SMCKeyData()
        var output = SMCKeyData()

        input.key = fourCharCode(key)
        input.data8 = 9 // SMC_CMD_READ_KEYINFO

        var result = call(index: 2, input: &input, output: &output)
        guard result == kIOReturnSuccess else { return nil }

        let dataSize = output.keyInfo.dataSize
        let dataType = output.keyInfo.dataType

        input.keyInfo.dataSize = dataSize
        input.data8 = 5 // SMC_CMD_READ_BYTES
        result = call(index: 2, input: &input, output: &output)
        guard result == kIOReturnSuccess else { return nil }

        return parseValue(bytes: output.bytes, dataSize: dataSize, dataType: dataType)
    }

    private func parseValue(bytes: SMCBytes, dataSize: IOByteCount32, dataType: UInt32) -> Double? {
        guard dataSize > 0 else { return nil }

        let byteArray = smcBytesToArray(bytes)
        // 全零说明传感器不可用
        guard byteArray.contains(where: { $0 != 0 }) else { return nil }

        switch fourCharCodeToString(dataType) {
        case "sp78":
            return Double(Int(byteArray[0]) * 256 + Int(byteArray[1])) / 256.0
        case "sp87":
            return Double(Int(byteArray[0]) * 256 + Int(byteArray[1])) / 128.0
        case "sp96":
            return Double(Int(byteArray[0]) * 256 + Int(byteArray[1])) / 64.0
        case "ui16":
            return Double(UInt16(byteArray[0]) * 256 + UInt16(byteArray[1]))
        case "flt ":
            return Double(byteArray.withUnsafeBytes { $0.load(fromByteOffset: 0, as: Float.self) })
        default:
            return nil
        }
    }

    private func call(index: UInt8, input: inout SMCKeyData, output: inout SMCKeyData) -> kern_return_t {
        let inputSize = MemoryLayout<SMCKeyData>.stride
        var outputSize = MemoryLayout<SMCKeyData>.stride
        return IOConnectCallStructMethod(
            conn, UInt32(index),
            &input, inputSize,
            &output, &outputSize
        )
    }

    private func fourCharCode(_ str: String) -> UInt32 {
        str.utf8.reduce(0) { $0 << 8 | UInt32($1) }
    }

    private func fourCharCodeToString(_ code: UInt32) -> String {
        String(UnicodeScalar(code >> 24 & 0xFF) ?? " ") +
        String(UnicodeScalar(code >> 16 & 0xFF) ?? " ") +
        String(UnicodeScalar(code >> 8  & 0xFF) ?? " ") +
        String(UnicodeScalar(code       & 0xFF) ?? " ")
    }
}

// MARK: - SMC 数据结构

private typealias SMCBytes = (
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
    UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8
)

/// 将 32 元组转为数组（Swift 6 不支持 tuple extension，用函数代替）
private func smcBytesToArray(_ bytes: SMCBytes) -> [UInt8] {
    [bytes.0, bytes.1, bytes.2, bytes.3, bytes.4, bytes.5, bytes.6, bytes.7, bytes.8,
     bytes.9, bytes.10, bytes.11, bytes.12, bytes.13, bytes.14, bytes.15, bytes.16,
     bytes.17, bytes.18, bytes.19, bytes.20, bytes.21, bytes.22, bytes.23, bytes.24,
     bytes.25, bytes.26, bytes.27, bytes.28, bytes.29, bytes.30, bytes.31]
}

private struct SMCKeyData {
    struct KeyInfo {
        var dataSize: IOByteCount32 = 0
        var dataType: UInt32 = 0
        var dataAttributes: UInt8 = 0
    }

    var key: UInt32 = 0
    var vers = (
        major: CUnsignedChar(0), minor: CUnsignedChar(0),
        build: CUnsignedChar(0), reserved: CUnsignedChar(0),
        release: CUnsignedShort(0)
    )
    var pLimitData = (
        version: UInt16(0), length: UInt16(0),
        cpuPLimit: UInt32(0), gpuPLimit: UInt32(0), memPLimit: UInt32(0)
    )
    var keyInfo = KeyInfo()
    var padding: UInt16 = 0
    var result: UInt8 = 0
    var status: UInt8 = 0
    var data8: UInt8 = 0
    var data32: UInt32 = 0
    var bytes: SMCBytes = (
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,
        0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0
    )
}
