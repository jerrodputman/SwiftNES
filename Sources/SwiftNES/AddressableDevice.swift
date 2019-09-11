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

/// A protocol that describes a device that is addressable on a system bus.
protocol AddressableDevice: class {
    /// Returns whether or not the device responds to the specified address.
    ///
    /// - parameter address: The address.
    /// - returns: Whether or not the device responds to the address.
    func respondsTo(_ address: Address) -> Bool
}

/// A protocol that describes a device that is addressable on a system bus and can be read from.
protocol AddressableReadDevice: AddressableDevice {
    /// Reads from the addressable device at the specified address.
    ///
    /// - parameter address: The address to read from.
    /// - returns: The value stored at the address.
    func read(from address: Address) -> Value
}

/// A protocol that describes a device that is addressable on a system bus and can be written to.
protocol AddressableWriteDevice: AddressableDevice {
    /// Writes data to the addressable device at the specified address.
    ///
    /// - parameter data: The data to be written.
    /// - parameter address: The address to write to.
    func write(_ data: Value, to address: Address)
}

/// A protocol that describes a device that is addressable on a system bus and can be read from or written to.
protocol AddressableReadWriteDevice: AddressableReadDevice, AddressableWriteDevice { }
