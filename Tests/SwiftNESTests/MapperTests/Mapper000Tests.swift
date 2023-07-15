import XCTest
@testable import SwiftNES

final class Mapper000Tests: XCTestCase {

    func testInit() {
        let _ = XCTAssertNoThrow(try Mapper000(programMemoryBanks: 1, characterMemoryBanks: 1))
        let _ = XCTAssertNoThrow(try Mapper000(programMemoryBanks: 2, characterMemoryBanks: 1))
        let _ = XCTAssertThrowsError(try Mapper000(programMemoryBanks: 0, characterMemoryBanks: 0))
        let _ = XCTAssertThrowsError(try Mapper000(programMemoryBanks: 3, characterMemoryBanks: 0))
        let _ = XCTAssertThrowsError(try Mapper000(programMemoryBanks: 1, characterMemoryBanks: 0))
        let _ = XCTAssertThrowsError(try Mapper000(programMemoryBanks: 1, characterMemoryBanks: 2))
    }
    
    func testRead1ProgramBank() throws {
        let mapper = try Mapper000(programMemoryBanks: 1, characterMemoryBanks: 1)
        mapper.reset()
        
        XCTAssertEqual(mapper.read(from: 0x8000), .program(0x0000))
        XCTAssertEqual(mapper.read(from: 0x8001), .program(0x0001))
        XCTAssertEqual(mapper.read(from: 0xbfff), .program(0x3fff))
        XCTAssertEqual(mapper.read(from: 0xc000), .program(0x0000))
        XCTAssertEqual(mapper.read(from: 0xc001), .program(0x0001))
        XCTAssertEqual(mapper.read(from: 0xffff), .program(0x3fff))
        XCTAssertEqual(mapper.read(from: 0x0000), .character(0x0000))
        XCTAssertEqual(mapper.read(from: 0x0001), .character(0x0001))
        XCTAssertEqual(mapper.read(from: 0x1fff), .character(0x1fff))
        XCTAssertEqual(mapper.read(from: 0x2000), .none)
    }

    func testRead2ProgramBanks() throws {
        let mapper = try Mapper000(programMemoryBanks: 2, characterMemoryBanks: 1)
        mapper.reset()

        XCTAssertEqual(mapper.read(from: 0x8000), .program(0x0000))
        XCTAssertEqual(mapper.read(from: 0x8001), .program(0x0001))
        XCTAssertEqual(mapper.read(from: 0xbfff), .program(0x3fff))
        XCTAssertEqual(mapper.read(from: 0xc000), .program(0x4000))
        XCTAssertEqual(mapper.read(from: 0xc001), .program(0x4001))
        XCTAssertEqual(mapper.read(from: 0xffff), .program(0x7fff))
        XCTAssertEqual(mapper.read(from: 0x0000), .character(0x0000))
        XCTAssertEqual(mapper.read(from: 0x0001), .character(0x0001))
        XCTAssertEqual(mapper.read(from: 0x1fff), .character(0x1fff))
        XCTAssertEqual(mapper.read(from: 0x2000), .none)
    }

    func testWrite() throws {
        let mapper = try Mapper000(programMemoryBanks: 1, characterMemoryBanks: 1)
        mapper.reset()

        XCTAssertEqual(mapper.write(1, to: 0x8000), .none)
        XCTAssertEqual(mapper.write(1, to: 0x8001), .none)
        XCTAssertEqual(mapper.write(1, to: 0xbfff), .none)
        XCTAssertEqual(mapper.write(1, to: 0xc000), .none)
        XCTAssertEqual(mapper.write(1, to: 0xc001), .none)
        XCTAssertEqual(mapper.write(1, to: 0xffff), .none)
        XCTAssertEqual(mapper.write(1, to: 0x0000), .none)
        XCTAssertEqual(mapper.write(1, to: 0x0001), .none)
        XCTAssertEqual(mapper.write(1, to: 0x1fff), .none)
        XCTAssertEqual(mapper.write(1, to: 0x2000), .none)
    }
    
    func testReset() throws {
        let mapper = try Mapper000(programMemoryBanks: 1, characterMemoryBanks: 1)
        mapper.reset()
        
        // Mapper has no internal state.
    }
    
    func testMirroringMode() throws {
        let mapper = try Mapper000(programMemoryBanks: 1, characterMemoryBanks: 1)
        mapper.reset()

        XCTAssertNil(mapper.mirroringMode)
    }
}
