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
protocol AddressableDevice: AnyObject {
    /// The address range of the device.
    var addressRange: AddressRange { get }
}

/// A protocol that describes a device that is addressable on a system bus and can be read from.
protocol AddressableReadDevice: AddressableDevice {
    /// Reads from the addressable device at the specified address.
    ///
    /// - Parameters:
    ///     - address: The address to read from.
    /// - Returns: The value stored at the address.
    func read(from address: Address) -> Value
}

/// A protocol that describes a device that is addressable on a system bus and can be written to.
protocol AddressableWriteDevice: AddressableDevice {
    /// Writes data to the addressable device at the specified address.
    ///
    /// - Parameters:
    ///     - data: The data to be written.
    ///     - address: The address to write to.
    func write(_ data: Value, to address: Address)
}

/// A protocol that describes a device that is addressable on a system bus and can be read from or written to.
protocol AddressableReadWriteDevice: AddressableReadDevice, AddressableWriteDevice { }
