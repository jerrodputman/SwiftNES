import XCTest
@testable import SwiftNES

final class ControlPadTests: XCTestCase {

    func testNoInput() {
        let controlPad = ControlPad()
        
        XCTAssertFalse(controlPad.read())
        XCTAssertFalse(controlPad.read())
        XCTAssertFalse(controlPad.read())
        XCTAssertFalse(controlPad.read())
        XCTAssertFalse(controlPad.read())
        XCTAssertFalse(controlPad.read())
        XCTAssertFalse(controlPad.read())
        XCTAssertFalse(controlPad.read())
    }
    
    func testInput() {
        let controlPad = ControlPad()
        
        controlPad.pressedButtons = [.a, .up]
        // This is the value that will be read.
        controlPad.pressedButtons = [.b, .down]
        
        // Write to the control pad to poll the current state.
        controlPad.write(0)
        
        // This value will be ignored.
        controlPad.pressedButtons = [.start]
        
        XCTAssertFalse(controlPad.read()) // A
        XCTAssertTrue(controlPad.read())  // B
        XCTAssertFalse(controlPad.read()) // Select
        XCTAssertFalse(controlPad.read()) // Start
        XCTAssertFalse(controlPad.read()) // Up
        XCTAssertTrue(controlPad.read())  // Down
        XCTAssertFalse(controlPad.read()) // Left
        XCTAssertFalse(controlPad.read()) // Right
        
        controlPad.pressedButtons = .none
        
        XCTAssertFalse(controlPad.read()) // A
        XCTAssertFalse(controlPad.read()) // B
        XCTAssertFalse(controlPad.read()) // Select
        XCTAssertFalse(controlPad.read()) // Start
        XCTAssertFalse(controlPad.read()) // Up
        XCTAssertFalse(controlPad.read()) // Down
        XCTAssertFalse(controlPad.read()) // Left
        XCTAssertFalse(controlPad.read()) // Right
    }
}
