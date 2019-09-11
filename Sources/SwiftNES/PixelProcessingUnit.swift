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

class PixelProcessingUnit: AddressableReadWriteDevice {
    
    // MARK: - Initializers
    
    init(bus: Bus) {
        self.bus = bus
    }
    
    
    // MARK: - AddressableReadWriteDevice
    
    func respondsTo(_ address: Address) -> Bool {
        return Self.addressRange.contains(address)
    }
    
    func read(from address: Address) -> Value {
        guard let addressIndex = Self.addressRange.firstIndex(of: address) else { return 0 }

        let distance = Self.addressRange.distance(from: Self.addressRange.startIndex, to: addressIndex)
        // TODO: Read from the PPU.
        return 0
    }
    
    func write(_ value: Value, to address: Address) {
        guard let addressIndex = Self.addressRange.firstIndex(of: address) else { return }

        let distance = Self.addressRange.distance(from: Self.addressRange.startIndex, to: addressIndex)
        // TODO: Write to the PPU.
    }
    
    
    // MARK: - Private
    
    private let bus: Bus
    
    private static let addressRange: AddressRange = 0x2000...0x3fff
}
