// MIT License
//
// Copyright (c) 2019 Jerrod Putman
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

/// Represents a bus that allows the CPU to read and write to various attached devices via memory address.
final class Bus {
    
    // MARK: - Initializers
    
    /// Initializes a bus with attached devices.
    ///
    /// - Parameters:
    ///     - addressableDevices: The ``AddressableDevice``s that can be addressed via the bus.
    init(addressableDevices: [any AddressableDevice]) throws {
        // TODO: Verify that there are no overlapping devices.
        
        let addressableReadDevices = addressableDevices.compactMap { $0 as? AddressableReadDevice }
        let addressableWriteDevices = addressableDevices.compactMap { $0 as? AddressableWriteDevice }
        
        self.addressableReadDeviceRanges = addressableReadDevices.map(\.addressRange)
        self.addressableWriteDeviceRanges = addressableWriteDevices.map(\.addressRange)
        self.addressableReadDevices = addressableReadDevices
        self.addressableWriteDevices = addressableWriteDevices
    }
    
    
    // MARK: - Reading and writing
    
    /// Read from or write to an address on the bus.
    ///
    /// - Parameters:
    ///     - address: The ``Address`` to read from or write to.
    /// - Returns: The ``Value`` that was read from a device on the bus.
    subscript(address: Address) -> Value {
        get { read(from: address) }
        set { write(newValue, to: address) }
    }
    
    /// Reads data from the specified address on the bus.
    ///
    /// - Note: If a device does not respond to the address, `0` will be returned.
    ///
    /// - Parameters:
    ///     - address: The ``Address`` to read from.
    /// - Returns: The ``Value`` that was read from a device on the bus.
    func read(from address: Address) -> Value {
        guard let deviceToReadFromIndex = addressableReadDeviceRanges
            .firstIndex(where: { $0.contains(address) }) else { return 0 }
        
        let deviceToReadFrom = addressableReadDevices[deviceToReadFromIndex]
        
        return deviceToReadFrom.read(from: address)
    }

    /// Writes data to the specified address on the bus.
    ///
    /// - Note: If a device does not respond to the address, this method does nothing.
    ///
    /// - Parameters:
    ///     - value: The ``Value`` to write to the bus.
    ///     - address: The ``Address`` to write to.
    func write(_ value: Value, to address: Address) {
        guard let deviceToWriteToIndex = addressableWriteDeviceRanges
            .firstIndex(where: { $0.contains(address) }) else { return }
        
        let deviceToWriteTo = addressableWriteDevices[deviceToWriteToIndex]
        
        deviceToWriteTo.write(value, to: address)
    }


    // MARK: - Private

    /// The ranges of the ``AddressableReadDevice``s attached to the bus.
    private let addressableReadDeviceRanges: [AddressRange]
  
    /// The ranges of the ``AddressableWriteDevice``s attached to the bus.
    private let addressableWriteDeviceRanges: [AddressRange]
    
    /// All of the ``AddressableReadDevice``s attached to the bus.
    private let addressableReadDevices: [any AddressableReadDevice]

    /// All of the ``AddressableWriteDevice``s attached to the bus.
    private let addressableWriteDevices: [any AddressableWriteDevice]
}

extension Bus: DirectMemoryAccessableReadDevice {
    func dmaRead(from address: Address) -> Value {
        read(from: address)
    }
}
