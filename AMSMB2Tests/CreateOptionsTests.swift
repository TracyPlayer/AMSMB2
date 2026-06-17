//
//  CreateOptionsTests.swift
//  AMSMB2
//
//  Created by Amir Abbas on 2026/4/22.
//  Copyright © 2026 Mousavian. Distributed under MIT license.
//  All rights reserved.
//

import XCTest
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif
@testable import AMSMB2

final class CreateOptionsTests: XCTestCase {
    func testO_SYNCAloneEmitsNoIntermediateBuffering() {
        let opts = SMB2FileHandle.CreateOptions(flags: O_RDONLY | O_SYNC)
        XCTAssertTrue(opts.contains(.noIntermediateBuffering),
                      "O_SYNC on a non-directory open should set .noIntermediateBuffering")
        XCTAssertFalse(opts.contains(.directoryFile))
    }

    func testO_DIRECTORYAloneSetsDirectoryFileWithoutBuffering() {
        let opts = SMB2FileHandle.CreateOptions(flags: O_RDONLY | O_DIRECTORY)
        XCTAssertTrue(opts.contains(.directoryFile))
        XCTAssertFalse(opts.contains(.noIntermediateBuffering))
    }

    func testO_SYNCWithO_DIRECTORYSuppressesNoIntermediateBuffering() {
        // The whole point of this fix: callers may pass O_RDONLY | O_SYNC
        // and then OR in O_DIRECTORY after a stat result; the resulting
        // CreateOptions must NOT include .noIntermediateBuffering or
        // Windows will reject the CREATE.
        let opts = SMB2FileHandle.CreateOptions(flags: O_RDONLY | O_SYNC | O_DIRECTORY)
        XCTAssertTrue(opts.contains(.directoryFile),
                      "O_DIRECTORY should still set .directoryFile")
        XCTAssertFalse(opts.contains(.noIntermediateBuffering),
                       "O_SYNC must not set .noIntermediateBuffering when O_DIRECTORY is also set (MS-FSCC §2.1.5.1)")
    }

    func testO_SYMLINKSetsOpenReparsePoint() {
        let opts = SMB2FileHandle.CreateOptions(flags: O_RDONLY | O_SYMLINK)
        XCTAssertTrue(opts.contains(.openReparsePoint))
        XCTAssertFalse(opts.contains(.directoryFile))
    }
}
