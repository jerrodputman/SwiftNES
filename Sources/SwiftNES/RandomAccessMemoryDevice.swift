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

/// Represents errors thrown by the device.
enum RandomAccessMemoryDeviceError: Error {
    /// The address range specified is not a multiple of the specified memory size.
    case addressRangeNotMultipleOfMemorySize(memorySize: UInt32, addressRange: CountableClosedRange<UInt16>)
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
    init(memorySize: UInt32, addressRange: AddressRange) throws {
        guard UInt32(addressRange.count) % memorySize == 0 else {
            throw RandomAccessMemoryDeviceError.addressRangeNotMultipleOfMemorySize(memorySize: memorySize, addressRange: addressRange)
        }
        
        self.memory = Array<Value>(repeating: Value.zero, count: Int(memorySize))
        self.addressRange = addressRange
    }
    
    /// Creates a new random access memory device with the specified address range.
    ///
    /// - parameter addressRange: The range of addresses that this device responds to.
    convenience init(addressRange: AddressRange) {
        try! self.init(memorySize: UInt32(addressRange.count), addressRange: addressRange)
    }
    
    
    // MARK: - Accessing the device
    
    func respondsTo(_ address: Address) -> Bool {
        addressRange.contains(address)
    }
    
    func read(from address: Address) -> Value {
        guard let addressIndex = addressRange.firstIndex(of: address) else { return 0 }
        
        let distance = addressRange.distance(from: addressRange.startIndex, to: addressIndex)
        return memory[distance & (memory.count - 1)]
    }
    
    func write(_ value: Value, to address: Address) {
        guard let addressIndex = addressRange.firstIndex(of: address) else { return }
        
        let distance = addressRange.distance(from: addressRange.startIndex, to: addressIndex)
        memory[distance & (memory.count - 1)] = value
    }
    
    
    // MARK: - Private
    
    /// The range of addresses that the device responds to.
    fileprivate let addressRange: AddressRange
    
    /// The memory of the device.
    fileprivate var memory: [Value]
}

extension RandomAccessMemoryDevice: Collection {
    typealias Index = Address
    typealias Element = Value
    
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
    
    func replaceSubrange<C: Collection>(_ subrange: Range<Address>, with newElements: C) where Element == C.Element {
        let lowerBound = Int(subrange.lowerBound) & (memory.count - 1)
        let upperBound = Int(subrange.upperBound) & (memory.count - 1)
        
        memory.replaceSubrange(lowerBound..<upperBound, with: newElements)
    }
}
