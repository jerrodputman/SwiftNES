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

/// An enumeration that defines the mapped addresses that can be returned by a mapper.
enum MappedAddress {
    /// The address could not be mapped.
    case none
    
    /// An address in program memory.
    case program(Address)
    
    /// An address in character memory.
    case character(Address)
}

/// An enumeration that defines common errors that can be thrown by mappers.
enum MapperError: Error {
    /// An invalid number of program memory banks was specified to the mapper.
    case invalidNumberOfProgramMemoryBanks(UInt8)
    
    /// An invalid number of character memory banks was specified to the mapper.
    case invalidNumberOfCharacterMemoryBanks(UInt8)
}

protocol Mapper {
    /// Creates the mapper with the specified number of program and character memory banks of the cartridge.
    ///
    /// - parameter programMemoryBanks: The number of program memory banks that the cartridge has.
    /// - parameter characterMemoryBanks: The number of character memory banks that the cartridge has.
    init(programMemoryBanks: UInt8, characterMemoryBanks: UInt8) throws
    
    /// Maps the specified address into an address in either program or character memory.
    ///
    /// - parameter address: The address to map.
    /// - returns: The mapped address.
    func map(_ address: Address) -> MappedAddress
}

extension Mapper {
    /// Whether or not the mapper responds to this address.
    ///
    /// - parameter address: The address.
    /// - returns: Whether or not the mapper responds to the address.
    @inlinable
    func respondsTo(_ address: Address) -> Bool {
        return isAddressingProgramMemory(address)
            || isAddressingCharacterMemory(address)
    }
    
    /// Returns whether or not the specified address is addressing program memory.
    ///
    /// - parameter address: The address.
    /// - returns: Whether or not the address is addressing program memory.
    @inlinable
    func isAddressingProgramMemory(_ address: Address) -> Bool {
        return (0x8000...0xffff).contains(address)
    }
    
    /// Returns whether or not the specified address is addressing character memory.
    ///
    /// - parameter address: The address.
    /// - returns: Whether or not the address is addressing character memory.
    @inlinable
    func isAddressingCharacterMemory(_ address: Address) -> Bool {
        return (0x0000...0x1fff).contains(address)
    }
}
