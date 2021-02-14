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

import Foundation

/// Represents a bus that allows the CPU to read and write to various attached devices via memory address.
final class Bus {
    
    // MARK: - Initializers
    
    /// Initializes a bus with attached devices.
    ///
    /// - Parameters:
    ///     - addressableDevices: The devices that can be addressed via this bus.
    init(addressableDevices: [AddressableDevice]) {
        self.addressableDevices = addressableDevices
        
        self.addressableReadDevicesIndexSet = addressableDevices
            .enumerated()
            .compactMap { $1 as? AddressableReadDevice != nil ? $0 : nil }
            .reduce(into: IndexSet()) { $0.insert($1) }
        self.addressableWriteDevicesIndexSet = addressableDevices
            .enumerated()
            .compactMap { $1 as? AddressableReadDevice != nil ? $0 : nil }
            .reduce(into: IndexSet()) { $0.insert($1) }
    }
    
    
    // MARK: - Reading and writing
    
    /// Reads data from the specified address on the bus.
    ///
    /// - Note: If a device does not respond to the address, `0` will be returned.
    ///
    /// - Parameters:
    ///     - address: The address to read from.
    /// - Returns: The value that was read from a device on the bus.
    func read(from address: Address) -> Value {
        let deviceToReadFrom = addressableReadDevicesIndexSet
            .map { addressableDevices[$0] }
            .first(where: { $0.respondsTo(address) }) as? AddressableReadDevice
        
        return deviceToReadFrom?.read(from: address) ?? 0
    }

    /// Writes data to the specified address on the bus.
    ///
    /// - Note: If a device does not respond to the address, this method does nothing.
    ///
    /// - Parameters:
    ///     - value: The value to write to the bus.
    ///     - address: The address to write to.
    func write(_ value: Value, to address: Address) {
        let deviceToWriteTo = addressableWriteDevicesIndexSet
            .map { addressableDevices[$0] }
            .first(where: { $0.respondsTo(address) }) as? AddressableWriteDevice
        
        deviceToWriteTo?.write(value, to: address)
    }


    // MARK: - Private

    /// All of the addressable devices attached to the bus.
    private let addressableDevices: [AddressableDevice]

    /// A set of indices into the `addressableDevice` array where readable devices can be found.
    private let addressableReadDevicesIndexSet: IndexSet

    /// A set of indices into the `addressableDevice` array where writeable devices can be found.
    private let addressableWriteDevicesIndexSet: IndexSet
}
