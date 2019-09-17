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

final class Mapper000: Mapper {
    
    // MARK: - Mapper
    
    required init(programMemoryBanks: UInt8, characterMemoryBanks: UInt8) throws {
        // This mapper only allows 1 or 2 program memory banks.
        guard (1...2).contains(programMemoryBanks) else {
            throw MapperError.invalidNumberOfProgramMemoryBanks(programMemoryBanks)
        }
        
        // This mapper only allows 1 character memory bank.
        guard characterMemoryBanks == 1 else {
            throw MapperError.invalidNumberOfCharacterMemoryBanks(characterMemoryBanks)
        }
        
        self.programMemoryBanks = programMemoryBanks
        // Character memory bank switching not supported by this mapper.
    }

    func map(_ address: Address) -> MappedAddress {
        if isAddressingProgramMemory(address) {
            // For a single bank, the 16 KB memory is mirrored across the second bank.
            let mappedAddress = address & ((programMemoryBanks > 1) ? 0x7fff : 0x3fff)
            return .program(mappedAddress)
        } else if isAddressingCharacterMemory(address) {
            return .character(address)
        } else {
            return .none
        }
    }

    
    // MARK: - Private
    
    /// The number of program memory banks that the cartridge has.
    private let programMemoryBanks: UInt8
}
