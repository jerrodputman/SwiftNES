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
    
    /// Creates a bus with attached devices.
    ///
    /// - parameter addressableDevices: The devices that can be addressed via this bus.
    init(addressableDevices: [AddressableDevice]) {
        self.addressableDevices = addressableDevices
    }
    
    
    // MARK: - Reading and writing
    
    /// Read from or write to an address on the bus.
    ///
    /// - parameter address: The address to read/write from.
    /// - returns: The value that was read from a device on the bus.
    subscript(address: Address) -> Value {
        get { read(from: address) }
        set { write(newValue, to: address) }
    }
    
    /// Reads data from a device on the bus.
    ///
    /// - note: If a device does not respond to the address, `0` will be returned.
    ///
    /// - parameter address: The address to read from.
    /// - returns: The value that was read from a device on the bus.
    func read(from address: Address) -> Value {
        guard let deviceToReadFrom = addressableDevices
            .first(where: { $0.respondsTo(address) })
            as? AddressableReadDevice else { return 0 }
        
        return deviceToReadFrom.read(from: address)
    }
    
    /// Writes data to a device on the bus.
    ///
    /// - note: If a device does not respond to the address, this method does nothing.
    ///
    /// - parameter value: The value to write to the bus.
    /// - parameter address: The address to write to.
    func write(_ value: Value, to address: Address) {
        guard let deviceToWriteTo = addressableDevices
            .first(where: { $0.respondsTo(address) })
            as? AddressableWriteDevice else { return }

        deviceToWriteTo.write(value, to: address)
    }
    
    
    // MARK: - Private

    /// All attached devices on the bus.
    private let addressableDevices: [AddressableDevice]
}
