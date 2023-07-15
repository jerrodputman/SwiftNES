import XCTest
@testable import SwiftNES

final class Mapper002Tests: XCTestCase {
    
    func testInit() throws {
        let _ = XCTAssertNoThrow(try Mapper002(programMemoryBanks: 1, characterMemoryBanks: 1))
        let _ = XCTAssertNoThrow(try Mapper002(programMemoryBanks: 2, characterMemoryBanks: 1))
        let _ = XCTAssertThrowsError(try Mapper002(programMemoryBanks: 0, characterMemoryBanks: 0))
        let _ = XCTAssertNoThrow(try Mapper002(programMemoryBanks: 3, characterMemoryBanks: 0))
        let _ = XCTAssertNoThrow(try Mapper002(programMemoryBanks: 1, characterMemoryBanks: 0))
        let _ = XCTAssertThrowsError(try Mapper002(programMemoryBanks: 1, characterMemoryBanks: 2))

    }
    
    func testRead() throws {
        let mapper = try Mapper002(programMemoryBanks: 8, characterMemoryBanks: 1)
        mapper.reset()

        XCTAssertEqual(mapper.read(from: 0x8000), .program(0x00000))
        XCTAssertEqual(mapper.read(from: 0x8001), .program(0x00001))
        XCTAssertEqual(mapper.read(from: 0xbfff), .program(0x03fff))
        XCTAssertEqual(mapper.read(from: 0xc000), .program(0x1c000))
        XCTAssertEqual(mapper.read(from: 0xc001), .program(0x1c001))
        XCTAssertEqual(mapper.read(from: 0xffff), .program(0x1ffff))
    }
    
    func testBankSelect() throws {
        let mapper = try Mapper002(programMemoryBanks: 8, characterMemoryBanks: 1)
        mapper.reset()
        XCTAssertEqual(mapper.read(from: 0x8000), .program(0x00000))
        
        XCTAssertEqual(mapper.write(0x1, to: 0x8000), .none)
        XCTAssertEqual(mapper.read(from: 0x8000), .program(0x04000))
        XCTAssertEqual(mapper.read(from: 0xc000), .program(0x1c000))
        
        XCTAssertEqual(mapper.write(0x2, to: 0x8000), .none)
        XCTAssertEqual(mapper.read(from: 0x8000), .program(0x08000))
        XCTAssertEqual(mapper.read(from: 0xc000), .program(0x1c000))

        XCTAssertEqual(mapper.write(0x3, to: 0x8000), .none)
        XCTAssertEqual(mapper.read(from: 0x8000), .program(0x0c000))
        XCTAssertEqual(mapper.read(from: 0xc000), .program(0x1c000))

        XCTAssertEqual(mapper.write(0x6, to: 0x8000), .none)
        XCTAssertEqual(mapper.read(from: 0x8000), .program(0x18000))
        XCTAssertEqual(mapper.read(from: 0xc000), .program(0x1c000))
    }
    
    func testWriteToCharacterROM() throws {
        let mapper = try Mapper002(programMemoryBanks: 8, characterMemoryBanks: 1)
        mapper.reset()
        
        XCTAssertEqual(mapper.write(0xff, to: 0x0000), .none)
        XCTAssertEqual(mapper.write(0xff, to: 0x0001), .none)
        XCTAssertEqual(mapper.write(0xff, to: 0x1fff), .none)
    }
    
    func testWriteToCharacterRAM() throws {
        let mapper = try Mapper002(programMemoryBanks: 8, characterMemoryBanks: 0)
        mapper.reset()
        
        XCTAssertEqual(mapper.write(0xff, to: 0x0000), .character(0x0000))
        XCTAssertEqual(mapper.write(0xff, to: 0x0001), .character(0x0001))
        XCTAssertEqual(mapper.write(0xff, to: 0x1fff), .character(0x1fff))
    }
    
    func testReset() throws {
        let mapper = try Mapper002(programMemoryBanks: 8, characterMemoryBanks: 1)
        mapper.reset()
        XCTAssertEqual(mapper.read(from: 0x8000), .program(0x00000))
        XCTAssertEqual(mapper.read(from: 0xc000), .program(0x1c000))
        
        let _ = mapper.write(0x1, to: 0x8000)
        XCTAssertEqual(mapper.read(from: 0x8000), .program(0x04000))
        XCTAssertEqual(mapper.read(from: 0xc000), .program(0x1c000))
        
        mapper.reset()
        XCTAssertEqual(mapper.read(from: 0x8000), .program(0x00000))
        XCTAssertEqual(mapper.read(from: 0xc000), .program(0x1c000))
    }
    
    func testMirroringMode() throws {
        let mapper = try Mapper002(programMemoryBanks: 1, characterMemoryBanks: 1)
        XCTAssertNil(mapper.mirroringMode)
    }
}
