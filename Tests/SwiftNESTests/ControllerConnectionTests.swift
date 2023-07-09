import XCTest
@testable import SwiftNES

final class ControllerConnectionTests: XCTestCase {

    func testNoController() {
        let connector = ControllerConnector(address: 0x1000)
        
        connector.write(1, to: 0x1000)
        XCTAssertNotEqual(connector.read(from: 0x1000), 1) // A
        XCTAssertNotEqual(connector.read(from: 0x1000), 1) // B
        XCTAssertNotEqual(connector.read(from: 0x1000), 1) // Select
        XCTAssertNotEqual(connector.read(from: 0x1000), 1) // Start
        XCTAssertNotEqual(connector.read(from: 0x1000), 1) // Up
        XCTAssertNotEqual(connector.read(from: 0x1000), 1) // Down
        XCTAssertNotEqual(connector.read(from: 0x1000), 1) // Left
        XCTAssertNotEqual(connector.read(from: 0x1000), 1) // Right
    }
    
    func testController() {
        let connector = ControllerConnector(address: 0x1000)
        
        let controlPad = ControlPad()
        connector.controller = controlPad
        
        controlPad.pressedButtons = [.a, .up]
        connector.write(1, to: 0x1000)
        XCTAssertEqual(connector.read(from: 0x1000), 1)     // A
        XCTAssertNotEqual(connector.read(from: 0x1000), 1)  // B
        XCTAssertNotEqual(connector.read(from: 0x1000), 1)  // Select
        XCTAssertNotEqual(connector.read(from: 0x1000), 1)  // Start
        XCTAssertEqual(connector.read(from: 0x1000), 1)     // Up
        XCTAssertNotEqual(connector.read(from: 0x1000), 1)  // Down
        XCTAssertNotEqual(connector.read(from: 0x1000), 1)  // Left
        XCTAssertNotEqual(connector.read(from: 0x1000), 1)  // Right
        
        controlPad.pressedButtons = [.b]
        connector.write(1, to: 0x1000)
        XCTAssertNotEqual(connector.read(from: 0x1000), 1)  // A
        XCTAssertEqual(connector.read(from: 0x1000), 1)     // B
        XCTAssertNotEqual(connector.read(from: 0x1000), 1)  // Select
        XCTAssertNotEqual(connector.read(from: 0x1000), 1)  // Start
        XCTAssertNotEqual(connector.read(from: 0x1000), 1)  // Up
        XCTAssertNotEqual(connector.read(from: 0x1000), 1)  // Down
        XCTAssertNotEqual(connector.read(from: 0x1000), 1)  // Left
        XCTAssertNotEqual(connector.read(from: 0x1000), 1)  // Right
    }
}
