import XCTest
@testable import SwiftNES

final class SwiftNESTests: XCTestCase {
    var nes: NES!
    
    override func setUp() {
        nes = NES()
    }
    
    func testMultiply10By3() {
        // Load Program (assembled at https://www.masswerk.at/6502/assembler.html)
        /*
            *=$8000
            LDX #10
            STX $0000
            LDX #3
            STX $0001
            LDY $0000
            LDA #0
            CLC
            loop
            ADC $0001
            DEY
            BNE loop
            STA $0002
            NOP
            NOP
            NOP
        */
        let program = "A2 0A 8E 00 00 A2 03 8E 01 00 AC 00 00 A9 00 18 6D 01 00 88 D0 FA 8D 02 00 EA EA EA"
            .hexToUInt8
        nes.ram.replaceSubrange(0x8000..<(0x8000+program.count), with: program)

        nes.ram[0xfffc] = 0x00
        nes.ram[0xfffd] = 0x80
        
        nes.cpu.reset()
        XCTAssert(nes.cpu.pc == 0x8000, "Reset did not place program counter to 0x8000")
        
        while nes.cpu.pc < 0x801a {
            nes.cpu.clock()
        }
        
        XCTAssert(nes.ram[0x0000] == UInt8(10), "Value stored at 0x0000 was not 10")
        XCTAssert(nes.ram[0x0001] == UInt8(3), "Value stored at 0x0001 was not 3")
        XCTAssert(nes.ram[0x0002] == UInt8(30), "Result stored at 0x0002 was not 30")
        XCTAssert(nes.cpu.totalCycleCount == 124, "Incorrect cycle count")
    }

    static var allTests = [
        ("testMultiply10By3", testMultiply10By3),
    ]
}

extension String {
    
    var hexToUInt8: [UInt8] {
        let allowedCharacters = CharacterSet(charactersIn: "01234567890ABCDEF")
        let filteredCharacters = self.unicodeScalars.filter { allowedCharacters.contains($0) }
        
        var bytes = [UInt8]()
        bytes.reserveCapacity(filteredCharacters.count / 2)

        // It is a lot faster to use a lookup map instead of strtoul
        let map: [UInt8] = [
          0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, // 01234567
          0x08, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 89:;<=>?
          0x00, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x00, // @ABCDEFG
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  // HIJKLMNO
        ]

        // Grab two characters at a time, map them and turn it into a byte
        var currentIndex = filteredCharacters.startIndex
        while currentIndex != filteredCharacters.endIndex {
            let index1 = Int(filteredCharacters[currentIndex].value & 0x1F ^ 0x10)
            currentIndex = filteredCharacters.index(after: currentIndex)
            let index2 = Int(filteredCharacters[currentIndex].value & 0x1F ^ 0x10)
            currentIndex = filteredCharacters.index(after: currentIndex)
            
            bytes.append(map[index1] << 4 | map[index2])
        }
        
        return bytes
    }
}
