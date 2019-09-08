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

enum RandomAccessMemoryDeviceError: Error {
    case addressRangeNotMultipleOfMemorySize
}

/// Represents a device that provides random access memory to a bus.
final class RandomAccessMemoryDevice: AddressableReadWriteDevice {
    
    // MARK: - Initializers
    
    /// Creates a new random access memory device with the specified memory size and address range.
    ///
    /// - note: If `addressRange` is larger than `memorySize`, the memory will be mirrored across the
    /// available range. For example, if the memory size is `0x7f` but the address range is from `0x00...0xff`,
    /// then the memory accessed starting at `0x80` will be the start of the memory.
    ///
    /// - parameter memorySize: The size of the memory of the device.
    /// - parameter addressRange: The range of addresses that this device responds to. The size must be
    /// a multiple of `memorySize`.
    init(memorySize: UInt32, addressRange: CountableClosedRange<UInt16>) throws {
        guard UInt32(addressRange.count) % memorySize == 0 else {
            throw RandomAccessMemoryDeviceError.addressRangeNotMultipleOfMemorySize
        }
        
        self.memory = Array<UInt8>(repeating: UInt8.zero, count: Int(memorySize))
        self.addressRange = addressRange
    }
    
    /// Creates a new random access memory device with the specified address range.
    ///
    /// - parameter addressRange: The range of addresses that this device responds to.
    convenience init(addressRange: CountableClosedRange<UInt16>) {
        try! self.init(memorySize: UInt32(addressRange.count), addressRange: addressRange)
    }
    
    
    // MARK: - Accessing the device
    
    func respondsTo(_ address: UInt16) -> Bool {
        addressRange.contains(address)
    }
    
    func read(from address: UInt16) -> UInt8 {
        guard let addressIndex = addressRange.firstIndex(of: address) else { return 0 }
        
        let distance = addressRange.distance(from: addressRange.startIndex, to: addressIndex)
        // TODO: Handle mirroring.
        return memory[distance]
    }
    
    func write(_ data: UInt8, to address: UInt16) {
        guard let addressIndex = addressRange.firstIndex(of: address) else { return }
        
        let distance = addressRange.distance(from: addressRange.startIndex, to: addressIndex)
        // TODO: Handle mirroring.
        memory[distance & (memory.count - 1)] = data
    }
    
    
    // MARK: - Private
    
    /// The range of addresses that the device responds to.
    fileprivate let addressRange: CountableClosedRange<UInt16>
    
    /// The memory of the device.
    fileprivate var memory: [UInt8]
}

extension RandomAccessMemoryDevice: Collection {
    typealias Index = UInt16
    typealias Element = UInt8
    
    var startIndex: Index { return addressRange.lowerBound }
    var endIndex: Index { return addressRange.upperBound }
    
    subscript(index: Index) -> Iterator.Element {
        get { return read(from: index) }
        set { write(newValue, to: index) }
    }
    
    func index(after i: Index) -> Index {
        return i + 1
    }
}

extension RandomAccessMemoryDevice: BidirectionalCollection {
    func index(before i: Index) -> Index {
        return i - 1
    }
}

extension RandomAccessMemoryDevice: RandomAccessCollection { }

extension RandomAccessMemoryDevice: RangeReplaceableCollection {
    convenience init() {
        fatalError()
    }
    
    func replaceSubrange<C: Collection>(_ subrange: Range<UInt16>, with newElements: C) where Element == C.Element {
        let lowerBound = Int(subrange.lowerBound)
        let upperBound = Int(subrange.upperBound)
        
        memory.replaceSubrange(lowerBound..<upperBound, with: newElements)
    }
}
