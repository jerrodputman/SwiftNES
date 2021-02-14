import XCTest
@testable import SwiftNES

final class SwiftNESTests: XCTestCase {
    var nes: NES!
    
    override func setUpWithError() throws {
        nes = try NES()
    }
    
    func testMultiply10By3() throws {
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
        let cartridge = try Cartridge(string: program)
        XCTAssert(cartridge.read(from: 0x8000) == 0xa2, "Program not loaded into cartridge")
        
        nes.cartridge = cartridge
        XCTAssertNotNil(nes.cartridge, "Cartridge not inserted")
        
        nes.cpu.core.reset()
        XCTAssert(nes.cpu.core.pc == 0x8000, "Reset did not place program counter to 0x8000")
        
        while nes.cpu.core.pc < 0x8000 + program.hexToUInt8.count {
            nes.cpu.core.clock()
        }
        
        XCTAssert(nes.ram[0x0000] == UInt8(10), "Value stored at 0x0000 was not 10")
        XCTAssert(nes.ram[0x0001] == UInt8(3), "Value stored at 0x0001 was not 3")
        XCTAssert(nes.ram[0x0002] == UInt8(30), "Result stored at 0x0002 was not 30")
        XCTAssert(nes.cpu.core.status.contains(.unused), "Status register did not contain U flag.")
        XCTAssert(nes.cpu.core.status.contains(.resultIsZero), "Status register did not contain Z flag")
        XCTAssert(!nes.cpu.core.status.contains(.carry), "Status register contains C flag")
        XCTAssert(!nes.cpu.core.status.contains(.disableInterrupts), "Status register contains I flag")
        XCTAssert(!nes.cpu.core.status.contains(.decimalMode), "Status register contains D flag")
        XCTAssert(!nes.cpu.core.status.contains(.break), "Status register contains B flag")
        XCTAssert(!nes.cpu.core.status.contains(.resultIsOverflowed), "Status register contains V flag")
        XCTAssert(!nes.cpu.core.status.contains(.resultIsNegative), "Status register contains N flag")
        XCTAssert(nes.cpu.core.totalCycleCount == 126, "Incorrect cycle count")
        
        print("Disassembly:")
        let disassembly = nes.cpu.core.disassemble(start: 0x8000, stop: 0x8000 + Address(program.hexToUInt8.count))
        for key in disassembly.keys.sorted() {
            guard let line = disassembly[key] else { continue }
            print(line)
        }
    }

    static var allTests = [
        ("testMultiply10By3", testMultiply10By3),
    ]
}
