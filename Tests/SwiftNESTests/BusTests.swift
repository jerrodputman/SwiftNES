import XCTest
@testable import SwiftNES

final class BusTests: XCTestCase {
    
    class MockDevice: AddressableReadWriteDevice {
        let addressRange: AddressRange = 0x0000...0xffff
        
        func read(from address: Address) -> Value { return values[Int(address)] }
        
        func write(_ data: Value, to address: Address) { values[Int(address)] = data }
        
        var values: [Value] = Array(repeating: 0x00, count: 0x10000)
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
        ("testReadPerformance", testReadPerformance),
        ("testWritePerformance", testWritePerformance),
    ]
}
