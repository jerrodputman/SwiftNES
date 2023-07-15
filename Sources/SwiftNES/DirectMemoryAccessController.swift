// MIT License
//
// Copyright (c) 2023 Jerrod Putman
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

/// Errors that are thrown by the ``DirectMemoryAccessController``.
enum DirectMemoryAccessControllerError: Error {
    /// The ``DirectMemoryAccessController/readDevice`` was not assigned.
    case readDeviceNotAssigned
    
    /// The ``DirectMemoryAccessController/writeDevice`` was not assigned.
    case writeDeviceNotAssigned
}

/// Represents a device that the ``DirectMemoryAccessController`` reads from.
protocol DirectMemoryAccessableReadDevice: AnyObject {
    /// Reads a value from the device at the specified address.
    ///
    /// - Parameter address: The ``Address`` of the device to read from.
    /// - Returns: The ``Value`` stored at the address on the device.
    func dmaRead(from address: Address) -> Value
}

/// Represents a device that the ``DirectMemoryAccessController`` writes to.
protocol DirectMemoryAccessableWriteDevice: AnyObject {
    /// Writes a value to the device at the specified address.
    ///
    /// - Parameter value: The ``Value`` to write to the device.
    /// - Parameter address: The 8-bit address to write to on the device.
    func dmaWrite(_ value: Value, to address: UInt8)
}

/// Represents the direct memory access controller of the NES.
final class DirectMemoryAccessController: AddressableWriteDevice {
    
    // MARK: - Initializers
    
    /// Initializes the controller.
    ///
    /// - Parameter address: The ``Address`` where the controller can be written to.
    init(address: Address) {
        self.addressRange = address...address
        
        self.page = 0
        self.address = 0
        self.data = 0
    }
    
    
    // MARK: - Getting the status of the controller
    
    /// Whether or not a DMA transfer is in progress.
    private(set) var isTransferInProgress = false
    
    
    // MARK: - Transferring data
    
    /// The device to read from during transfers.
    weak var readDevice: (any DirectMemoryAccessableReadDevice)?
    
    /// The device to write to during transfers.
    weak var writeDevice: (any DirectMemoryAccessableWriteDevice)?
    
    /// Clocks the controller.
    ///
    /// - Parameter cycleCount: The current cycle count of the hardware.
    /// - Returns: Whether or not a transfer is in progress.
    /// - Throws: A ``DirectMemoryAccessControllerError``.
    func clock(cycleCount: UInt) throws -> Bool {
        guard isTransferInProgress else { return false }
        
        guard let readDevice else { throw DirectMemoryAccessControllerError.readDeviceNotAssigned }
        guard let writeDevice else { throw DirectMemoryAccessControllerError.writeDeviceNotAssigned }
        
        if syncCycle {
            if cycleCount % 2 == 1 {
                syncCycle = false
            }
        } else {
            if cycleCount % 2 == 0 {
                data = readDevice.dmaRead(from: UInt16(lo: address, hi: page))
            } else {
                writeDevice.dmaWrite(data, to: address)
                address &+= 1
                
                if address == 0 {
                    isTransferInProgress = false
                    syncCycle = true
                }
            }
        }
        
        return true
    }
    
    
    // MARK: - AddressableWriteDevice
    
    let addressRange: AddressRange
    
    func write(_ data: Value, to address: Address) {
        page = data
        self.address = 0
        isTransferInProgress = true
    }
    
    
    // MARK: - Private
    
    /// The page of memory where the current DMA transfer is occurring.
    private var page: UInt8
    
    /// The address of memory, offset from the page, where the current DMA transfer is occurring.
    private var address: UInt8
    
    /// The data that is currently being moved from the CPU to the PPU.
    private var data: Value
    
    /// Whether or not the transfer should wait for synchronization.
    private var syncCycle = true
}
