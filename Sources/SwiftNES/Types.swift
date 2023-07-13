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

/// Represents an address within the addressable range of the NES.
public typealias Address = UInt16

/// A range within the complete addressable range of the NES.
public typealias AddressRange = CountableClosedRange<UInt16>

/// The type of data that can be bussed around on the NES.
public typealias Value = UInt8


extension Address {
    init(lo: UInt8, hi: UInt8) {
        self = (UInt16(hi) << 8) | UInt16(lo)
    }
    
    var lo: Value { Value(self & 0x00ff) }
    
    var hi: Value { Value((self >> 8) & 0x00ff) }
    
    func mirrored(after logicalEnd: UInt16, within range: AddressRange) -> Address? {
        guard range.contains(self) else { return nil }
        
        return range.lowerBound + (self & logicalEnd)
    }
}
