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

final class Mapper002: Mapper {
    init(programMemoryBanks: UInt8, characterMemoryBanks: UInt8) throws {
        // This mapper does not allow zero program memory banks.
        guard 1...255 ~= programMemoryBanks else {
            throw MapperError.invalidNumberOfProgramMemoryBanks(programMemoryBanks)
        }
        
        // This mapper only allows 0 or 1 character memory bank.
        guard 0...1 ~= characterMemoryBanks else {
            throw MapperError.invalidNumberOfCharacterMemoryBanks(characterMemoryBanks)
        }
        
        self.programMemoryBanks = programMemoryBanks
        self.characterMemoryBanks = characterMemoryBanks
    }
    
    func read(from address: Address) -> MapperResult {
        switch address {
        case 0x8000...0xbfff:
            return .program(UInt32(bankSelectLo) * 0x4000 + (UInt32(address) & 0x3fff))
        case 0xc000...0xffff:
            return .program(UInt32(bankSelectHi) * 0x4000 + (UInt32(address) & 0x3fff))
        case Self.characterMemoryAddressRange:
            return .character(UInt32(address))
        default:
            return .none
        }
    }
    
    func write(_ data: Value, to address: Address) -> MapperResult {
        switch address {
        case Self.programMemoryAddressRange:
            bankSelectLo = (data & 0x0f)
            return .none
        case Self.characterMemoryAddressRange where characterMemoryBanks == 0:
            // Use as RAM if memory banks are 0.
            return .character(UInt32(address))
        default:
            return .none
        }
    }
    
    func reset() {
        bankSelectLo = 0
        bankSelectHi = programMemoryBanks - 1
    }
    
    var mirroringMode: Cartridge.MirroringMode? { nil }
    
    
    // MARK: - Private
    
    /// The number of program memory banks that the cartridge has.
    private let programMemoryBanks: UInt8
    
    /// The number of character memory banks that the cartridge has.
    private let characterMemoryBanks: UInt8
    
    /// The selected low program memory bank.
    private var bankSelectLo: UInt8 = 0x00
    
    /// The selected high program memory bank.
    private var bankSelectHi: UInt8 = 0x00
}
