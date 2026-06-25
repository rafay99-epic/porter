import XCTest
@testable import PorterCore

/// Pins the auto-detect reconstruction: the kernel's `f_mntfromname`
/// (`//user@host/share`) → a clickable connection URL. `networkMounts()` itself
/// reads live system state, so it isn't unit-tested here; this covers the pure
/// transform it relies on.
final class MountedShareTests: XCTestCase {
    func testSMBURLReconstruction() {
        let smb = MountedShare(mountPoint: "/Volumes/media",
                               from: "//prometheus@192.168.100.215/media", fsType: "smbfs")
        XCTAssertEqual(smb.url, "smb://prometheus@192.168.100.215/media")
        XCTAssertEqual(smb.name, "media")
    }

    func testAFPURLReconstruction() {
        let afp = MountedShare(mountPoint: "/Volumes/backup", from: "//user@host/backup", fsType: "afpfs")
        XCTAssertEqual(afp.url, "afp://user@host/backup")
    }

    func testUnreconstructableTypesReturnNil() {
        // NFS reports `host:/export`, not `//…`; we don't fabricate a URL for it.
        let nfs = MountedShare(mountPoint: "/Volumes/x", from: "host:/export", fsType: "nfs")
        XCTAssertNil(nfs.url)
        XCTAssertEqual(nfs.name, "x")
    }
}
