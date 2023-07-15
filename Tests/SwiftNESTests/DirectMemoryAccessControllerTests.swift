import XCTest
@testable import SwiftNES

final class DirectMemoryAccessControllerTests: XCTestCase {
    
    class MockReadDevice: DirectMemoryAccessableReadDevice {
        func dmaRead(from address: Address) -> Value {
            return 0
        }
    }
    
    class MockWriteDevice: DirectMemoryAccessableWriteDevice {
        func dmaWrite(_ value: Value, to address: UInt8) {
            
        }
    }

    var dmaController: DirectMemoryAccessController!
    var readDevice: MockReadDevice!
    var writeDevice: MockWriteDevice!
    
    override func setUp() async throws {
        dmaController = .init(address: 0x1000)
        readDevice = .init()
        writeDevice = .init()
        
        dmaController.readDevice = readDevice
        dmaController.writeDevice = writeDevice
    }
}
