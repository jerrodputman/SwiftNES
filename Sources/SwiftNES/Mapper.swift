// MIT License
//
// Copyright (c) 2023 Jerrod Putman
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

/// An enumeration that defines the result of a mapper operation.
enum MapperResult: Equatable {
    /// The mapper returned an offset into program memory.
    case program(UInt32)
    
    /// The mapper returned an offset into character memory.
    case character(UInt32)
    
    /// The mapper returned a value.
    case value(Value)
    
    /// The mapper did not return a result.
    case none
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
    /// - Parameter programMemoryBanks: The number of program memory banks that the cartridge has.
    /// - Parameter characterMemoryBanks: The number of character memory banks that the cartridge has.
    init(programMemoryBanks: UInt8, characterMemoryBanks: UInt8) throws
    
    /// Maps the address to be read.
    ///
    /// - Parameter address: The ``Address`` to be read.
    /// - Returns: The ``MappedResult`` of the read.
    func read(from address: Address) -> MapperResult
    
    /// Maps the address to be written to.
    ///
    /// - Parameter data: The ``Value`` to be written to the address.
    /// - Parameter address: The ``Address`` to be written to.
    /// - Returns: The ``MappedResult`` of the write.
    func write(_ data: Value, to address: Address) -> MapperResult
    
    /// Resets the mapper.
    func reset()
    
    /// The mirroring mode returned by the mapper.
    var mirroringMode: Cartridge.MirroringMode? { get }
}

extension Mapper {
    /// The ``AddressRange`` of program memory in a ``Cartridge``.
    static var programMemoryAddressRange: AddressRange { 0x8000...0xffff }

    /// The ``AddressRange`` of character memory in a ``Cartridge``.
    static var characterMemoryAddressRange: AddressRange { 0x0000...0x1fff }
}
