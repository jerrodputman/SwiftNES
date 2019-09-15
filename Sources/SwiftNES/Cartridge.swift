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

/// An enumeration that defines the types of errors a cartridge can throw.
enum CartridgeError: Error {
    /// The data was not in the `iNES` format.
    case invalidDataFormat
    
    /// The mapper has not yet been implemented.
    case mapperNotImplemented(UInt8)
}

/// A class that represents a cartridge that can be inserted into the NES.
class Cartridge {
    
    // MARK: - Initializers
    
    /// Creates a cartridge with the specified data.
    ///
    /// - note: The data should be in the `iNES` format.
    ///
    /// - parameter data: The data that should be held by the cartridge.
    /// - parameter programStartAddress: Forces the starting address to a specified value.
    ///     This is typically only used for testing purposes, as all cartridges should have their program start
    ///     address set.
    init(data: Data, programStartAddress: Address? = nil) throws {
        var dataLocation = 0
        
        // Read the 16-byte header.
        let header = try Header(data: data)
        dataLocation += 16
        
        // Skip the "trainer" if it exists.
        if (header.mapper1 & 0x04) > 0 {
            dataLocation += 512
        }
        
        // TODO: Handle other file types.
        let programMemoryBanks = header.prgRomChunks
        let programMemorySize = 0x4000 * Int(programMemoryBanks)
        
        guard data.count >= dataLocation + programMemorySize else {
            throw CartridgeError.invalidDataFormat
        }
        
        programMemory = [Value](data[dataLocation..<dataLocation + programMemorySize])
        dataLocation += programMemorySize
        
        let characterMemoryBanks = header.chrRomChunks
        let characterMemorySize = 0x2000 * Int(characterMemoryBanks)

        guard data.count >= dataLocation + characterMemorySize else {
            throw CartridgeError.invalidDataFormat
        }
        
        characterMemory = [Value](data[dataLocation..<dataLocation + characterMemorySize])
        dataLocation += characterMemorySize

        // Extract the mapper ID.
        let mapperId = ((header.mapper2 >> 4) << 4) | (header.mapper1 >> 4)
        
        // Find the associated mapper type.
        guard let mapperType = Self.mapperTypes[mapperId] else {
            throw CartridgeError.mapperNotImplemented(mapperId)
        }
        
        // Create and store the mapper.
        mapper = try mapperType.init(programMemoryBanks: programMemoryBanks, characterMemoryBanks: characterMemoryBanks)
        
        // If a program start address was specified, write it to the cartridge.
        if let programStartAddress = programStartAddress {
            write(UInt8(programStartAddress & 0x00ff), to: 0xfffc)
            write(UInt8(programStartAddress >> 8), to: 0xfffd)
        }
    }
    
    /// Creates a cartridge from a program string.
    ///
    /// - parameter string: A string containing program code. The program code must be compiled object
    /// code in hexadecimal format.
    init(string: String) throws {
        programMemory = [Value](repeating: 0, count: 0x4000)
        characterMemory = []
        mapper = try Self.mapperTypes[0]!.init(programMemoryBanks: 1, characterMemoryBanks: 1)
        
        let programCode = string.hexToUInt8
        programMemory.replaceSubrange(0..<programCode.count, with: programCode)
        programMemory[0x3ffc] = 0x00
        programMemory[0x3ffd] = 0x80
    }
    
    
    // MARK: - Reading and writing
    
    /// Reads from the specified address in the cartridge.
    ///
    /// - parameter address: The address to read from. This address will be mapped by the `mapper`.
    /// - returns: The data at the specified address.
    func read(from address: Address) -> Value {
        let mappedAddress = mapper.map(address)
        
        switch mappedAddress {
        case .program(let address):
            return programMemory[Int(address)]
        case .character(let address):
            return characterMemory[Int(address)]
        case .none:
            return 0
        }
    }
    
    /// Writes to the specified address on the cartridge.
    ///
    /// - parameter value: The value to write.
    /// - parameter address: The address to write to. This address will be mapped by the `mapper`.
    func write(_ value: Value, to address: Address) {
        let mappedAddress = mapper.map(address)
        
        switch mappedAddress {
        case .program(let address):
            programMemory[Int(address)] = value
        case .character(let address):
            characterMemory[Int(address)] = value
        case .none:
            break
        }
    }
    

    // MARK: - Private
    
    /// The program memory of the cartridge.
    private var programMemory: [Value]
    
    /// The character memory of the cartridge.
    private var characterMemory: [Value]
    
    /// The catridge's mapper.
    private let mapper: Mapper
    
    
    /// The types of mappers that are found in a cartridge.
    // TODO: If all of the mapper types are ever implemented, this should be an array.
    private static let mapperTypes: [UInt8: Mapper.Type] = [
        0: Mapper000.self
    ]
    
    
    /// A structure defining the header of an `iNES` format file.
    private struct Header {
        let name: [CChar]
        let prgRomChunks: UInt8
        let chrRomChunks: UInt8
        let mapper1: UInt8
        let mapper2: UInt8
        let prgRamSize: UInt8
        let tvSystem1: UInt8
        let tvSystem2: UInt8
        let unused: [CChar]
        
        init(data: Data) throws {
            /// Ensure the data we're reading at least has enough room for the header.
            guard data.count >= 16 else {
                throw CartridgeError.invalidDataFormat
            }
            
            name = [CChar(data[0]), CChar(data[1]), CChar(data[2]), CChar(data[3])]
            
            /// The name should be "NES" followed by an MS-DOS EOF. Otherwise, this is an invalid file format.
            guard name[0] == 0x4e, name[1] == 0x45, name[2] == 0x53, name[3] == 0x1a else {
                throw CartridgeError.invalidDataFormat
            }
            
            prgRomChunks = data[4]
            chrRomChunks = data[5]
            mapper1 = data[6]
            mapper2 = data[7]
            prgRamSize = data[8]
            tvSystem1 = data[9]
            tvSystem2 = data[10]
            unused = [CChar(data[11]), CChar(data[12]), CChar(data[13]), CChar(data[14]), CChar(data[15])]
        }
    }
}
