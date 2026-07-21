import Darwin
import Foundation

enum FileContentRevision: Equatable {
    case missing
    case present(modifiedSeconds: Int64, modifiedNanoseconds: Int64, size: Int64)
}

enum FileState: Equatable {
    case missing
    case present(FileSnapshot)

    var contentRevision: FileContentRevision {
        switch self {
        case .missing:
            return .missing
        case .present(let snapshot):
            return .present(
                modifiedSeconds: snapshot.modifiedSeconds,
                modifiedNanoseconds: snapshot.modifiedNanoseconds,
                size: snapshot.size
            )
        }
    }

    var modifiedAt: Date? {
        guard case .present(let snapshot) = self else { return nil }
        return snapshot.modifiedAt
    }

    var permissions: mode_t {
        guard case .present(let snapshot) = self else { return 0o600 }
        return snapshot.permissions
    }

    var exists: Bool {
        guard case .present = self else { return false }
        return true
    }
}

struct FileSnapshot: Equatable {
    let modifiedSeconds: Int64
    let modifiedNanoseconds: Int64
    let size: Int64
    let permissions: mode_t

    var modifiedAt: Date {
        Date(
            timeIntervalSince1970: TimeInterval(modifiedSeconds)
                + TimeInterval(modifiedNanoseconds) / 1_000_000_000
        )
    }
}

enum POSIXFile {
    static func state(at url: URL) throws -> FileState {
        var fileInfo = stat()
        let result = url.path.withCString { path in
            stat(path, &fileInfo)
        }
        if result == 0 {
            return .present(
                FileSnapshot(
                    modifiedSeconds: Int64(fileInfo.st_mtimespec.tv_sec),
                    modifiedNanoseconds: Int64(fileInfo.st_mtimespec.tv_nsec),
                    size: Int64(fileInfo.st_size),
                    permissions: fileInfo.st_mode & 0o7777
                )
            )
        }
        if errno == ENOENT { return .missing }
        throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
    }
}

enum AtomicFileWriter {
    @discardableResult
    static func write(
        _ data: Data,
        to destination: URL,
        permissions: mode_t,
        beforeRename: () throws -> Bool
    ) throws -> Bool {
        let fileManager = FileManager.default
        let parent = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: parent, withIntermediateDirectories: true)

        let temporary = parent.appendingPathComponent(
            ".\(destination.lastPathComponent).skillbox-\(UUID().uuidString).tmp"
        )
        defer { try? fileManager.removeItem(at: temporary) }
        try data.write(to: temporary)

        let chmodResult = temporary.path.withCString { path in
            Darwin.chmod(path, permissions)
        }
        guard chmodResult == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }

        guard try beforeRename() else { return false }

        let renameResult = temporary.path.withCString { source in
            destination.path.withCString { target in
                Darwin.rename(source, target)
            }
        }
        guard renameResult == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        return true
    }
}
