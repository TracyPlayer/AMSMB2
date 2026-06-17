//
//  Extensions.swift
//  AMSMB2
//
//  Created by Amir Abbas on 2018/5/21.
//  Copyright © 2018 Mousavian. Distributed under MIT license.
//  All rights reserved.
//

import Foundation
import SMB2
#if canImport(System)
import System
#else
import SystemPackage
#endif

#if !canImport(Darwin)
let USEC_PER_SEC = 1_000_000
let NSEC_PER_SEC = 1_000_000_000
#endif

#if swift(<6.2)
public typealias SendableMetatype = Any
#endif

extension Optional {
    func unwrap() throws -> Wrapped {
        guard let self = self else {
            throw POSIXError(.noData, description: "Invalid/Empty data.")
        }
        return self
    }
}

extension Optional where Wrapped: SMB2Client {
    func unwrap() throws -> SMB2Client {
        guard let self = self, self.fileDescriptor.isValidSocket else {
            throw POSIXError(.socketNotConnected, description: "SMB2 server not connected.")
        }
        return self
    }
}

extension RawRepresentable where RawValue == UInt32 {
    init(_ rawValue: Int32) {
        self.init(rawValue: .init(bitPattern: rawValue))!
    }
}

extension RawRepresentable where RawValue == UInt16 {
    init(_ rawValue: Int16) {
        self.init(rawValue: .init(bitPattern: rawValue))!
    }
}

extension POSIXError {
    static func throwIfError<Number: SignedInteger>(_ result: Number, description: String?) throws {
        guard result < 0 else { return }
        let errno = Errno(rawValue: CInt(-result))
        let errorDesc = description.map { "Error code \(errno): \($0)" }
        throw POSIXError(errno, description: errorDesc)
    }
    
    public init(_ code: Errno, description: String?) {
        let description = description ?? code.description
        let userInfo: [String: Any] = [NSLocalizedDescriptionKey: description]
        self = POSIXError(.init(code), userInfo: userInfo)
    }
}

extension POSIXErrorCode {
    init(_ code: Errno) {
        self = POSIXErrorCode(rawValue: code.rawValue) ?? .ECANCELED
    }
}

/// The conformant must be able to be initialized with no arguments.
///
/// This is also known as the default initial value.
protocol EmptyInitializable {
    init()
}

/// Booleans can be initialized with no arguments and it would be `false` by default.
extension Bool: EmptyInitializable {}

extension Dictionary where Key == URLResourceKey {
    private func value<T>(forKey key: Key) -> T? {
        self[key] as? T
    }

    private func value<T: EmptyInitializable>(forKey key: Key) -> T {
        self[key] as? T ?? T()
    }

    public var name: String? {
        value(forKey: .nameKey)
    }

    public var path: String? {
        value(forKey: .pathKey)
    }

    public var fileResourceType: URLFileResourceType? {
        value(forKey: .fileResourceTypeKey)
    }

    public var isDirectory: Bool {
        value(forKey: .isDirectoryKey)
    }

    public var isRegularFile: Bool {
        value(forKey: .isRegularFileKey)
    }

    public var isSymbolicLink: Bool {
        value(forKey: .isSymbolicLinkKey)
    }

    public var fileSize: Int64? {
        value(forKey: .fileSizeKey)
    }

    public var attributeModificationDate: Date? {
        value(forKey: .attributeModificationDateKey)
    }

    public var contentModificationDate: Date? {
        value(forKey: .contentModificationDateKey)
    }

    public var contentAccessDate: Date? {
        value(forKey: .contentAccessDateKey)
    }

    public var creationDate: Date? {
        value(forKey: .creationDateKey)
    }
}

extension Array where Element == [URLResourceKey: any Sendable] {
    func sortedByPath(_ comparison: ComparisonResult) -> [[URLResourceKey: any Sendable]] {
        sorted {
            guard let firstPath = $0.path, let secPath = $1.path else {
                return false
            }
            return firstPath.localizedStandardCompare(secPath) == comparison
        }
    }

    var overallSize: Int64 {
        reduce(0) { result, value -> Int64 in
            guard value.isRegularFile else { return result }
            return result + (value.fileSize ?? 0)
        }
    }
}

extension Array where Element == SMB2Share {
    func map(enumerateHidden: Bool) -> [(name: String, comment: String)] {
        var shares = self
        if enumerateHidden {
            shares = shares.filter { $0.props.type == .diskTree }
        } else {
            shares = shares.filter { !$0.props.isHidden && $0.props.type == .diskTree }
        }
        return shares.map { ($0.name, $0.comment) }
    }
}

extension RangeExpression where Bound: FixedWidthInteger {
    var int64Range: Range<Int64> {
        let range: Range<Bound> = relative(to: 0..<Bound.max)
        let lower = Int64(exactly: range.lowerBound) ?? (Int64.max - 1)
        let upper = Int64(exactly: range.upperBound) ?? Int64.max
        return lower..<upper
    }
}

extension Date {
    init(_ timespec: timespec) {
        self.init(
            timeIntervalSince1970: TimeInterval(timespec.tv_sec) + TimeInterval(
                timespec.tv_nsec / 1000
            ) / TimeInterval(USEC_PER_SEC)
        )
    }
}

extension timespec {
    init(_ date: Date) {
        let interval = date.timeIntervalSince1970
        self.init(tv_sec: .init(interval), tv_nsec: Int(interval.truncatingRemainder(dividingBy: 1) * Double(NSEC_PER_SEC)))
    }
}

extension Data {
    init<T: FixedWidthInteger>(value: T) {
        var value = value.littleEndian
        let bytes = Swift.withUnsafeBytes(of: &value) { Array($0) }
        self.init(bytes)
    }

    mutating func append<T: FixedWidthInteger>(value: T) {
        append(Data(value: value))
    }

    init(value uuid: UUID) {
        self.init([
            uuid.uuid.3, uuid.uuid.2, uuid.uuid.1, uuid.uuid.0,
            uuid.uuid.5, uuid.uuid.4, uuid.uuid.7, uuid.uuid.6,
            uuid.uuid.8, uuid.uuid.9, uuid.uuid.10, uuid.uuid.11,
            uuid.uuid.12, uuid.uuid.13, uuid.uuid.14, uuid.uuid.15,
        ])
    }

    mutating func append(value uuid: UUID) {
        append(Data(value: uuid))
    }

    func scanValue<T: FixedWidthInteger>(offset: Int, as _: T.Type) -> T? {
        guard count >= offset + MemoryLayout<T>.size else { return nil }
        return T(littleEndian: withUnsafeBytes { $0.load(fromByteOffset: offset, as: T.self) })
    }

    func scanInt<T: FixedWidthInteger & SendableMetatype>(offset: Int, as _: T.Type) -> Int? {
        scanValue(offset: offset, as: T.self).map(Int.init)
    }
}

extension CharacterSet {
    static let pathSeparator = CharacterSet(charactersIn: "/\\")
}

extension String {
    var trimmedPath: String {
        trimmingCharacters(in: .pathSeparator)
    }
    
    func appendingPath(_ component: String, isDirectory: Bool = false) -> String {
        var result = self
        if result.hasSuffix("/") || result.hasSuffix("\\") {
            result.removeLast()
        }
        result = self + "/" + component.trimmedPath
        if isDirectory, !result.hasSuffix("/") {
            result += "/"
        }
        return result
    }
    
    var pathComponents: (dirName: String, fileName: String) {
        guard let slashIndex = lastIndex(where: { $0 == "/" || $0 == "\\" }) else {
            return ("", self)
        }
        let dirName = String(self[startIndex..<slashIndex])
        let fileName = String(self[index(after: slashIndex)...]).trimmedPath
        return (dirName, fileName)
    }
}

func asyncHandler(_ continuation: CheckedContinuation<Void, any Error>) -> @Sendable (_ error: (any Error)?) -> Void {
    { error in
        if let error = error {
            continuation.resume(throwing: error)
            return
        }
        continuation.resume(returning: ())
    }
}

func asyncHandler<T: Sendable>(_ continuation: CheckedContinuation<T, any Error>)
    -> @Sendable (Result<T, any Error>) -> Void
{
    { result in
        continuation.resume(with: result)
    }
}
