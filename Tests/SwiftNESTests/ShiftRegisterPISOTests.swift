import XCTest
@testable import SwiftNES

final class ShiftRegisterPISOTests: XCTestCase {

    func testSingleValue() {
        var register = ShiftRegisterPISO<UInt8>()
        
        register.input(0b10101010)
        XCTAssertTrue(register.output())
        XCTAssertFalse(register.output())
        XCTAssertTrue(register.output())
        XCTAssertFalse(register.output())
        XCTAssertTrue(register.output())
        XCTAssertFalse(register.output())
        XCTAssertTrue(register.output())
        XCTAssertFalse(register.output())
    }
    
    func testNoValue() {
        var register = ShiftRegisterPISO<UInt8>()
        
        XCTAssertFalse(register.output())
        XCTAssertFalse(register.output())
        XCTAssertFalse(register.output())
        XCTAssertFalse(register.output())
        XCTAssertFalse(register.output())
        XCTAssertFalse(register.output())
        XCTAssertFalse(register.output())
        XCTAssertFalse(register.output())
    }
    
    func testOverOutput() {
        var register = ShiftRegisterPISO<UInt8>()
        
        register.input(0b10101010)
        XCTAssertTrue(register.output())
        XCTAssertFalse(register.output())
        XCTAssertTrue(register.output())
        XCTAssertFalse(register.output())
        XCTAssertTrue(register.output())
        XCTAssertFalse(register.output())
        XCTAssertTrue(register.output())
        XCTAssertFalse(register.output())
        XCTAssertFalse(register.output())
        XCTAssertFalse(register.output())
        XCTAssertFalse(register.output())
        XCTAssertFalse(register.output())
    }
    
    func testChangeValueDuringOutput() {
        var register = ShiftRegisterPISO<UInt8>()
        
        register.input(0b10101010)
        XCTAssertTrue(register.output())
        XCTAssertFalse(register.output())
        XCTAssertTrue(register.output())
        XCTAssertFalse(register.output())

        register.input(0b11110001)
        XCTAssertTrue(register.output())
        XCTAssertTrue(register.output())
        XCTAssertTrue(register.output())
        XCTAssertTrue(register.output())
        XCTAssertFalse(register.output())
        XCTAssertFalse(register.output())
        XCTAssertFalse(register.output())
        XCTAssertTrue(register.output())
    }
    
    func testLargeRegister() {
        var register = ShiftRegisterPISO<UInt32>()
        
        register.input(0xAAAAAAAA)
        XCTAssertTrue(register.output())
        XCTAssertFalse(register.output())
        XCTAssertTrue(register.output())
        XCTAssertFalse(register.output())
        XCTAssertTrue(register.output())
        XCTAssertFalse(register.output())
        XCTAssertTrue(register.output())
        XCTAssertFalse(register.output())
        XCTAssertTrue(register.output())
        XCTAssertFalse(register.output())
        XCTAssertTrue(register.output())
        XCTAssertFalse(register.output())
        XCTAssertTrue(register.output())
        XCTAssertFalse(register.output())
        XCTAssertTrue(register.output())
        XCTAssertFalse(register.output())
        XCTAssertTrue(register.output())
        XCTAssertFalse(register.output())
        XCTAssertTrue(register.output())
        XCTAssertFalse(register.output())
        XCTAssertTrue(register.output())
        XCTAssertFalse(register.output())
        XCTAssertTrue(register.output())
        XCTAssertFalse(register.output())
        XCTAssertTrue(register.output())
        XCTAssertFalse(register.output())
        XCTAssertTrue(register.output())
        XCTAssertFalse(register.output())
        XCTAssertTrue(register.output())
        XCTAssertFalse(register.output())
        XCTAssertTrue(register.output())
        XCTAssertFalse(register.output())

        XCTAssertFalse(register.output())
        XCTAssertFalse(register.output())
        XCTAssertFalse(register.output())
        XCTAssertFalse(register.output())
    }
}
