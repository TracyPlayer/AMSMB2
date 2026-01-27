# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AMSMB2 is a Swift library that wraps [libsmb2](https://github.com/sahlberg/libsmb2) to provide SMB2/3 file operations for Apple platforms (iOS 13+, macOS 10.15+, tvOS 14+, watchOS 6+, visionOS 1+) and Linux.

**License note:** The library must be linked dynamically due to libsmb2's LGPL v2.1 license requirements for App Store distribution.

## Build and Test Commands

```bash
# Build
swift build

# Run all tests
swift test

# Run a specific test
swift test --filter SMB2ManagerTests/testName

# Linux testing via Docker
make linuxtest              # Uses local volume mount
make cleanlinuxtest         # Clean Docker build
```

## Architecture

### Core Components

- **SMB2Manager** ([AMSMB2.swift](AMSMB2/AMSMB2.swift)) - Public API class, thread-safe, supports NSSecureCoding/Codable. Manages connection lifecycle and exposes all file operations (list, read, write, copy, move, delete).

- **SMB2Client** ([Context.swift](AMSMB2/Context.swift)) - Internal wrapper around libsmb2's `smb2_context`. Provides synchronous operations with thread-safe context access via `withThreadSafeContext()`.

- **SMB2FileHandle** ([FileHandle.swift](AMSMB2/FileHandle.swift)) - File handle abstraction for reading/writing. Supports various open modes (read, write, update, overwrite, create).

### Supporting Modules

- [Directory.swift](AMSMB2/Directory.swift) - Directory handle for enumeration
- [Stream.swift](AMSMB2/Stream.swift) - InputStream/OutputStream implementations for streaming I/O
- [Fsctl.swift](AMSMB2/Fsctl.swift) - FSCTL operations (server-side copy via IOCTL)
- [MSRPC.swift](AMSMB2/MSRPC.swift) - MS-RPC protocol for share enumeration
- [ObjCCompat.swift](AMSMB2/ObjCCompat.swift) - Objective-C compatibility layer with completion handler-based APIs

### Dependencies

- **libsmb2** - C library in `Dependencies/libsmb2/`, compiled as a Swift package target
- **swift-atomics** - Used in tests only

## Code Style

The project uses SwiftFormat (`.swiftformat`) and swift-format (`.swift-format`):
- 4-space indentation
- 100/132 character line length
- File headers with MIT license
- LF line endings