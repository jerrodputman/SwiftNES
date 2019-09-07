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

/// Represents a device that provides random access memory to a bus.
final class RandomAccessMemoryDevice: AddressableReadWriteDevice {
    
    typealias MemoryType = [UInt8]

    
    // MARK: - Initializers
    
    /// Creates a new random access memory device with the specified address range.
    ///
    /// - parameter addressRange: The range of addresses that this device responds to.
    init(addressRange: CountableClosedRange<UInt16>) {
        self.addressRange = addressRange
        self.memory = Array<UInt8>(repeating: UInt8.zero, count: addressRange.count)
    }
    
    
    // MARK: - Accessing the device
    
    func respondsTo(_ address: UInt16) -> Bool {
        addressRange.contains(address)
    }
    
    func read(from address: UInt16) -> UInt8 {
        guard let addressIndex = addressRange.firstIndex(of: address) else { return 0 }
        
        let distance = addressRange.distance(from: addressRange.startIndex, to: addressIndex)
        return memory[distance]
    }
    
    func write(_ data: UInt8, to address: UInt16) {
        guard let addressIndex = addressRange.firstIndex(of: address) else { return }
        
        let distance = addressRange.distance(from: addressRange.startIndex, to: addressIndex)
        memory[distance] = data
    }
    
    
    // MARK: - Private
    
    private let addressRange: CountableClosedRange<UInt16>
    
    fileprivate var memory: MemoryType
}

extension RandomAccessMemoryDevice: Collection {
    typealias Index = MemoryType.Index
    typealias Element = MemoryType.Element
    
    var startIndex: Index { return memory.startIndex }
    var endIndex: Index { return memory.endIndex }
    
    // TODO: Use the read and write methods instead.
    subscript(index: Index) -> Iterator.Element {
        get { return memory[index] }
        set { memory[index] = newValue }
    }
    
    func index(after i: Index) -> Index {
        return memory.index(after: i)
    }
}

extension RandomAccessMemoryDevice: BidirectionalCollection {
    func index(before i: Index) -> Index {
        return memory.index(before: i)
    }
}

extension RandomAccessMemoryDevice: RandomAccessCollection { }

extension RandomAccessMemoryDevice: RangeReplaceableCollection {
    convenience init() {
        fatalError()
    }
    
    func replaceSubrange<C: Collection>(_ subrange: Range<Index>, with newElements: C) where Element == C.Element {
        memory.replaceSubrange(subrange, with: newElements)
    }
}
