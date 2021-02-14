import XCTest
@testable import SwiftNES

final class BusTests: XCTestCase {
    
    class MockDevice: AddressableReadWriteDevice {
        func read(from address: Address) -> Value { return values[Int(address)] }
        
        func write(_ data: Value, to address: Address) { values[Int(address)] = data }
        
        func respondsTo(_ address: Address) -> Bool { return address % 2 == 0 ? true : false }
        
        var values: [Value] = Array(repeating: 0x00, count: 0x10000)
    }
    
    func testRead() {
        let device1 = MockDevice()
        let device2 = MockDevice()
        
    }
    
    func testWrite() {
        
    }
    
    func testReadPerformance() throws {
        let devices = Array(repeating: MockDevice(), count: 20)
        let bus = try Bus(addressableDevices: devices)
        let addresses: [Address] = (0..<10000).map { _ in Address.random(in: 0x0000...0xffff) }
        
        measure {
            _ = addresses
                .map { address in
                    bus.read(from: address)
                }
        }
    }
    
    func testWritePerformance() throws {
        let devices = Array(repeating: MockDevice(), count: 20)
        let bus = try Bus(addressableDevices: devices)
        let addresses: [Address] = (0..<10000).map { _ in Address.random(in: 0x0000...0xffff) }

        measure {
            _ = addresses
                .map { address in
                    bus.write(Value(address & 0xff), to: address)
                }
        }
    }
    
    static var allTests = [
        ("testRead", testRead),
        ("testWrite", testWrite),
        ("testReadPerformance", testReadPerformance),
        ("testWritePerformance", testWritePerformance),
    ]
}
