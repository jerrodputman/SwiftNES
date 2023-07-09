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

/// A class that emulates the behavior of the MOS Technology 6502 microprocessor.
final class MOS6502 {
    
    // MARK: - Initializers
    
    /// Creates a virtual CPU with the specified bus.
    ///
    /// - parameter bus: The bus that the CPU should use to communicate with other devices.
    init(bus: Bus) {
        self.bus = bus
    }
    
    
    // MARK: - Registers
    
    /// The accumulator.
    private(set) var a: Value = 0x00
    
    /// The x register.
    private(set) var x: Value = 0x00
    
    /// The y register.
    private(set) var y: Value = 0x00
    
    /// The stack pointer.
    private(set) var stkp: Value = 0x00
    
    /// The program counter.
    private(set) var pc: Address = 0x0000
    
    
    /// An option set that defines the bits of the Status register.
    struct Status: OptionSet {
        let rawValue: Value
        
        /// Carry the 1.
        static let carry = Status(rawValue: (1 << 0))
        
        /// Result is zero.
        static let resultIsZero = Status(rawValue: (1 << 1))
        
        /// Disable interrupts.
        static let disableInterrupts = Status(rawValue: (1 << 2))
        
        /// Decimal mode (not yet implemented).
        static let decimalMode = Status(rawValue: (1 << 3))
        
        /// Break.
        static let `break` = Status(rawValue: (1 << 4))
        
        /// Unused.
        static let unused = Status(rawValue: (1 << 5))
        
        /// Result contains overflowed value.
        static let resultIsOverflowed = Status(rawValue: (1 << 6))
        
        /// Result is negative.
        static let resultIsNegative = Status(rawValue: (1 << 7))
    }
    
    /// The status register.
    private(set) var status: Status = []
    
    
    // MARK: - External events
    
    /// Performs a single cycle of work on the CPU.
    func clock() {
        defer {
            // Decrement the number of cycles remaining in the current instruction.
            cyclesRemaining -= 1
            
            // Increment the global cycle count.
            totalCycleCount += 1
        }
        
        // We effectively do all of our work on the first cycle, and then wait the
        // predetermined amount of cycles that the instruction would normally take
        // to execute.
        guard cyclesRemaining == 0 else { return }
        
        // Read the next instruction byte. This 8-bit value is used to index the
        // instruction table to get the relevant information about how to implement
        // the instruction.
        opcode = bus[pc]
        
        // Always set the unused flag.
        status.insert(.unused)
        
        // Increment the program counter since we read the opcode byte.
        pc += 1
        
        // Get the instruction from the opcode.
        let instruction = MOS6502.instructions[Int(opcode)]
        
        // Get the minimum number of cycles for the instruction.
        cyclesRemaining = instruction.minimumCycleCount
        
        // Perform the operation.
        //
        // The address mode and operation may have altered the number of cycles this
        // instruction requires before it completes.
        cyclesRemaining += perform(instruction.operation, using: instruction.addressMode)
        
        // Always set the unused flag.
        status.insert(.unused)
    }
    
    /// Resets the CPU to a known state and sets the program counter to a predetermined address.
    ///
    /// - note: Startup code should be placed at `0xfffc`.
    func reset() {
        // Get the address to set the program counter to.
        // The address is contained at 0xfffc
        let resetAddress: Address = 0xfffc
        
        // Set the program counter.
        pc = Address(lo: bus[resetAddress + 0],
                     hi: bus[resetAddress + 1])
        
        // Reset registers.
        a = 0x00
        x = 0x00
        y = 0x00
        stkp = 0xfd
        status = .unused
        
        // Reset interrupts takes time.
        cyclesRemaining = 8
    }
    
    /// Interrupts execution and executes an instruction at a specified location.
    ///
    /// - note: Interrupt requests only happen if `status` does not contain the `.disableInterrupts` option.
    ///
    /// The current instruction is allowed to finish before the interrupt request is handled. When the interrupt request is
    /// handled, the current program counter and status register are stored on the stack. Then the program counter is
    /// set to `0xfffe`, where it will begin executing code.
    func irq() {
        guard !status.contains(.disableInterrupts) else { return }
        
        // Push the program counter to the stack.
        // The program counter is 16-bits, so we require 2 writes.
        bus[0x0100 + Address(stkp)] = pc.hi
        stkp -= 1
        bus[0x0100 + Address(stkp)] = pc.lo
        stkp -= 1
        
        // Push the status register to the stack.
        status.remove(.break)
        status.insert(.unused)
        status.insert(.disableInterrupts)
        bus[0x0100 + Address(stkp)] = status.rawValue
        stkp -= 1
        
        // Read the new program counter location from a specific address.
        let irqAddress: Address = 0xfffe
        pc = Address(lo: bus[irqAddress + 0],
                     hi: bus[irqAddress + 1])
        
        // Interrupt requests take time.
        cyclesRemaining = 7
    }
    
    /// Interrupts execution and Executes an instruction at a specified location,
    /// but cannot be disabled by the `status` register.
    func nmi() {
        // Push the program counter to the stack.
        // The program counter is 16-bits, so we require 2 writes.
        bus[0x0100 + Address(stkp)] = pc.hi
        stkp -= 1
        bus[0x0100 + Address(stkp)] = pc.lo
        stkp -= 1
        
        // Push the status register to the stack.
        status.remove(.break)
        status.insert(.unused)
        status.insert(.disableInterrupts)
        bus[0x0100 + Address(stkp)] = status.rawValue
        stkp -= 1
        
        // Read the new program counter location from a specific address.
        let nmiAddress: Address = 0xfffa
        pc = Address(lo: bus[nmiAddress + 0],
                     hi: bus[nmiAddress + 1])
        
        // Non-maskable interrupt requests take time.
        cyclesRemaining = 8
    }
    
    
    // MARK: - Utilities
    
    /// Whether or not the current instruction is complete.
    var isCurrentInstructionComplete: Bool { cyclesRemaining == 0 }
    
    /// The total number of cycles that have occurred since powering on the device.
    private(set) var totalCycleCount: Int = 0
    
    /// Disassembles the program into a human-readable format.
    ///
    /// - parameter start: The address to begin disassembling.
    /// - parameter stop: The address to stop disassembling.
    /// - returns: A dictionary that contains the address as keys and instructions as strings.
    func disassemble(start: Address, stop: Address) -> [Address: String] {
        var lines: [Address: String] = [:]
        var address = start
        
        while address <= stop {
            let lineAddress = Address(address)
            
            var line = "$\(String(format: "%04X", address)): "
            
            let opcode = bus[Address(address)]
            let instruction = Self.instructions[Int(opcode)]
            address &+= 1
            
            line += "\(instruction.name) "
            
            switch instruction.addressMode {
            case .IMP:
                break
            case .IMM:
                let value = bus[Address(address)]
                address &+= 1
                line += "#$\(String(format: "%02X", value))"
            case .ZP0:
                let lo = bus[Address(address)]
                address &+= 1
                line += "$\(String(format: "%02X", lo))"
            case .ZPX:
                let lo = bus[Address(address)]
                address &+= 1
                line += "$\(String(format: "%02X", lo)), X"
            case .ZPY:
                let lo = bus[Address(address)]
                address &+= 1
                line += "$\(String(format: "%02X", lo)), Y"
            case .IZX:
                let lo = bus[Address(address)]
                address &+= 1
                line += "($\(String(format: "%02X", lo))), X"
            case .IZY:
                let lo = bus[Address(address)]
                address &+= 1
                line += "($\(String(format: "%02X", lo))), Y"
            case .ABS:
                let lo = Address(bus[Address(address)])
                address &+= 1
                let hi = Address(bus[Address(address)])
                address &+= 1
                line += "$\(String(format: "%04X", ((hi << 8) | lo)))"
            case .ABX:
                let lo = Address(bus[Address(address)])
                address &+= 1
                let hi = Address(bus[Address(address)])
                address &+= 1
                line += "$\(String(format: "%04X", ((hi << 8) | lo))), X"
            case .ABY:
                let lo = Address(bus[Address(address)])
                address &+= 1
                let hi = Address(bus[Address(address)])
                address &+= 1
                line += "$\(String(format: "%04X", ((hi << 8) | lo))), Y"
            case .IND:
                let lo = Address(bus[Address(address)])
                address &+= 1
                let hi = Address(bus[Address(address)])
                address &+= 1
                line += "($\(String(format: "%04X", ((hi << 8) | lo))))"
            case .REL:
                let value = bus[Address(address)]
                address &+= 1
                line += "$\(String(format: "%02X", value)) [$\(String(format: "%04X", Address(Int32(address) + (value < 128 ? Int32(value) : Int32(value) - 256))))]"
            }
            
            line += " {\(instruction.addressMode.rawValue)}"
            
            lines[lineAddress] = line
        }
        
        return lines
    }
    
    
    // MARK: - Private
    
    /// The bus that allows the CPU to read/write data from/to any bus-attached devices.
    private let bus: Bus
    
    /// The working instruction byte.
    private(set) var opcode: UInt8 = 0x00
    
    /// How many cycles the current instruction has remaining.
    private var cyclesRemaining: UInt8 = 0x00
    
    
    /// Performs the specified operation using the specified address mode.
    ///
    /// - parameter operation: The operation to perform.
    /// - parameter addressMode: The address mode that the operation should use.
    /// - returns: The additional number of cycles that the operation needs to complete.
    private func perform(_ operation: Operation, using addressMode: AddressMode) -> UInt8 {
        let (address, crossedPageBoundary) = readAddress(using: addressMode)
        
        switch operation {
        case .ADC: return ADC(address, crossedPageBoundary)
        case .SBC: return SBC(address, crossedPageBoundary)
        case .AND: return AND(address, crossedPageBoundary)
        case .ASL: ASL(address, addressMode)
        case .BCS: return BCS(address)
        case .BCC: return BCC(address)
        case .BEQ: return BEQ(address)
        case .BNE: return BNE(address)
        case .BMI: return BMI(address)
        case .BPL: return BPL(address)
        case .BVS: return BVS(address)
        case .BVC: return BVC(address)
        case .BIT: BIT(address)
        case .BRK: BRK()
        case .CLC: CLC()
        case .CLD: CLD()
        case .CLI: CLI()
        case .CLV: CLV()
        case .CMP: return CMP(address, crossedPageBoundary)
        case .CPX: CPX(address)
        case .CPY: CPY(address)
        case .DEC: DEC(address)
        case .DEX: DEX()
        case .DEY: DEY()
        case .EOR: EOR(address)
        case .INC: INC(address)
        case .INX: INX()
        case .INY: INY()
        case .JMP: JMP(address)
        case .JSR: JSR(address)
        case .LDA: return LDA(address, crossedPageBoundary)
        case .LDX: return LDX(address, crossedPageBoundary)
        case .LDY: return LDY(address, crossedPageBoundary)
        case .LSR: LSR(address, addressMode)
        case .NOP: return NOP(crossedPageBoundary)
        case .ORA: return ORA(address, crossedPageBoundary)
        case .PHA: PHA()
        case .PHP: PHP()
        case .PLA: PLA()
        case .PLP: PLP()
        case .ROL: ROL(address, addressMode)
        case .ROR: ROR(address, addressMode)
        case .RTI: RTI()
        case .RTS: RTS()
        case .SEC: SEC()
        case .SED: SED()
        case .SEI: SEI()
        case .STA: STA(address)
        case .STX: STX(address)
        case .STY: STY(address)
        case .TAX: TAX()
        case .TAY: TAY()
        case .TSX: TSX()
        case .TXA: TXA()
        case .TYA: TYA()
        case .TXS: TXS()
            
        case .XXX:
            break
        }
        
        return 0
    }

    /// Reads the address from the current program counter location using the specified address mode.
    ///
    /// - note: This method may update the program counter.
    ///
    /// - parameter addressMode: The address mode to use.
    /// - returns: A `ReadAddressResult` which contains the address that was read and whether or not the read crossed a page boundary.
    private func readAddress(using addressMode: AddressMode) -> ReadAddressResult {
        switch addressMode {
        case .IMP:  return IMP()
        case .IMM:  return IMM()
        case .ABS:  return ABS()
        case .ABX:  return ABX()
        case .ABY:  return ABY()
        case .REL:  return REL()
        case .ZP0:  return ZP0()
        case .ZPX:  return ZPX()
        case .ZPY:  return ZPY()
        case .IND:  return IND()
        case .IZX:  return IZX()
        case .IZY:  return IZY()
        }
    }
}


// MARK: - Instructions

extension MOS6502 {
    /// A structure representing a single instruction to be performed by the CPU.
    private struct Instruction: CustomDebugStringConvertible {
        /// The assembly mnemonic used for the instruction.
        let name: String
        
        /// The `Operation` to perform for this instruction.
        let operation: Operation
        
        /// The `AddressMode` that the operation should use while performing the instruction.
        let addressMode: AddressMode
        
        /// The minimum number of cycles that the instruction requires to complete.
        let minimumCycleCount: UInt8

        
        /// Creates a new instruction.
        init(_ name: String, _ operation: Operation, _ addressMode: AddressMode, _ minimumCycleCount: UInt8) {
            self.name = name
            self.operation = operation
            self.addressMode = addressMode
            self.minimumCycleCount = minimumCycleCount
        }
        
        var debugDescription: String {
            return "Instruction: \(name); address mode: \(addressMode); cycles: \(minimumCycleCount)"
        }
    }
    
    /// An array of all of the possible instructions that the CPU can perform.
    ///
    /// The array can be indexed via an `Opcode`.
    static private var instructions: [Instruction] = {
        return [
            Instruction("BRK", .BRK, .IMM, 7), // 0x00
            Instruction("ORA", .ORA, .IZX, 6),
            Instruction("???", .XXX, .IMP, 2),
            Instruction("???", .XXX, .IMP, 8),
            Instruction("???", .NOP, .IMP, 3),
            Instruction("ORA", .ORA, .ZP0, 3),
            Instruction("ASL", .ASL, .ZP0, 5),
            Instruction("???", .XXX, .IMP, 5),
            Instruction("PHP", .PHP, .IMP, 3),
            Instruction("ORA", .ORA, .IMM, 2),
            Instruction("ASL", .ASL, .IMP, 2),
            Instruction("???", .XXX, .IMP, 2),
            Instruction("???", .NOP, .IMP, 4),
            Instruction("ORA", .ORA, .ABS, 4),
            Instruction("ASL", .ASL, .ABS, 6),
            Instruction("???", .XXX, .IMP, 6),

            Instruction("BPL", .BPL, .REL, 2), // 0x10
            Instruction("ORA", .ORA, .IZY, 5),
            Instruction("???", .XXX, .IMP, 2),
            Instruction("???", .XXX, .IMP, 8),
            Instruction("???", .NOP, .IMP, 4),
            Instruction("ORA", .ORA, .ZPX, 4),
            Instruction("ASL", .ASL, .ZPX, 6),
            Instruction("???", .XXX, .IMP, 8),
            Instruction("CLC", .CLC, .IMP, 2),
            Instruction("ORA", .ORA, .ABY, 4),
            Instruction("???", .NOP, .IMP, 2),
            Instruction("???", .XXX, .IMP, 7),
            Instruction("???", .NOP, .IMP, 4),
            Instruction("ORA", .ORA, .ABX, 4),
            Instruction("ASL", .ASL, .ABX, 7),
            Instruction("???", .XXX, .IMP, 7),
        
            Instruction("JSR", .JSR, .ABS, 6), // 0x20
            Instruction("AND", .AND, .IZX, 6),
            Instruction("???", .XXX, .IMP, 2),
            Instruction("???", .XXX, .IMP, 8),
            Instruction("BIT", .BIT, .ZP0, 3),
            Instruction("AND", .AND, .ZP0, 3),
            Instruction("ROL", .ROL, .ZP0, 5),
            Instruction("???", .XXX, .IMP, 5),
            Instruction("PLP", .PLP, .IMP, 4),
            Instruction("AND", .AND, .IMM, 2),
            Instruction("ROL", .ROL, .IMP, 2),
            Instruction("???", .XXX, .IMP, 2),
            Instruction("BIT", .BIT, .ABS, 4),
            Instruction("AND", .AND, .ABS, 4),
            Instruction("ROL", .ROL, .ABS, 6),
            Instruction("???", .XXX, .IMP, 6),
        
            Instruction("BMI", .BMI, .REL, 2), // 0x30
            Instruction("AND", .AND, .IZY, 5),
            Instruction("???", .XXX, .IMP, 2),
            Instruction("???", .XXX, .IMP, 8),
            Instruction("???", .NOP, .IMP, 4),
            Instruction("AND", .AND, .ZPX, 4),
            Instruction("ROL", .ROL, .ZPX, 6),
            Instruction("???", .XXX, .IMP, 6),
            Instruction("SEC", .SEC, .IMP, 2),
            Instruction("AND", .AND, .ABY, 4),
            Instruction("???", .NOP, .IMP, 2),
            Instruction("???", .XXX, .IMP, 7),
            Instruction("???", .NOP, .IMP, 4),
            Instruction("AND", .AND, .ABX, 4),
            Instruction("ROL", .ROL, .ABX, 7),
            Instruction("???", .XXX, .IMP, 7),
        
            Instruction("RTI", .RTI, .IMP, 6), // 0x40
            Instruction("EOR", .EOR, .IZX, 6),
            Instruction("???", .XXX, .IMP, 2),
            Instruction("???", .XXX, .IMP, 8),
            Instruction("???", .NOP, .IMP, 3),
            Instruction("EOR", .EOR, .ZP0, 3),
            Instruction("LSR", .LSR, .ZP0, 5),
            Instruction("???", .XXX, .IMP, 5),
            Instruction("PHA", .PHA, .IMP, 3),
            Instruction("EOR", .EOR, .IMM, 2),
            Instruction("LSR", .LSR, .IMP, 2),
            Instruction("???", .XXX, .IMP, 2),
            Instruction("JMP", .JMP, .ABS, 3),
            Instruction("EOR", .EOR, .ABS, 4),
            Instruction("LSR", .LSR, .ABS, 6),
            Instruction("???", .XXX, .IMP, 6),
        
            Instruction("BVC", .BVC, .REL, 2), // 0x50
            Instruction("EOR", .EOR, .IZY, 5),
            Instruction("???", .XXX, .IMP, 2),
            Instruction("???", .XXX, .IMP, 8),
            Instruction("???", .NOP, .IMP, 4),
            Instruction("EOR", .EOR, .ZPX, 4),
            Instruction("LSR", .LSR, .ZPX, 6),
            Instruction("???", .XXX, .IMP, 6),
            Instruction("CLI", .CLI, .IMP, 2),
            Instruction("EOR", .EOR, .ABY, 4),
            Instruction("???", .NOP, .IMP, 2),
            Instruction("???", .XXX, .IMP, 7),
            Instruction("???", .NOP, .IMP, 4),
            Instruction("EOR", .EOR, .ABX, 4),
            Instruction("LSR", .LSR, .ABX, 7),
            Instruction("???", .XXX, .IMP, 7),
        
            Instruction("RTS", .RTS, .IMP, 6), // 0x60
            Instruction("ADC", .ADC, .IZX, 6),
            Instruction("???", .XXX, .IMP, 2),
            Instruction("???", .XXX, .IMP, 8),
            Instruction("???", .NOP, .IMP, 3),
            Instruction("ADC", .ADC, .ZP0, 3),
            Instruction("ROR", .ROR, .ZP0, 5),
            Instruction("???", .XXX, .IMP, 5),
            Instruction("PLA", .PLA, .IMP, 4),
            Instruction("ADC", .ADC, .IMM, 2),
            Instruction("ROR", .ROR, .IMP, 2),
            Instruction("???", .XXX, .IMP, 2),
            Instruction("JMP", .JMP, .IND, 5),
            Instruction("ADC", .ADC, .ABS, 4),
            Instruction("ROR", .ROR, .ABS, 6),
            Instruction("???", .XXX, .IMP, 6),
        
            Instruction("BVS", .BVS, .REL, 2), // 0x70
            Instruction("ADC", .ADC, .IZY, 5),
            Instruction("???", .XXX, .IMP, 2),
            Instruction("???", .XXX, .IMP, 8),
            Instruction("???", .NOP, .IMP, 4),
            Instruction("ADC", .ADC, .ZPX, 4),
            Instruction("ROR", .ROR, .ZPX, 6),
            Instruction("???", .XXX, .IMP, 6),
            Instruction("SEI", .SEI, .IMP, 2),
            Instruction("ADC", .ADC, .ABY, 4),
            Instruction("???", .NOP, .IMP, 2),
            Instruction("???", .XXX, .IMP, 7),
            Instruction("???", .NOP, .IMP, 4),
            Instruction("ADC", .ADC, .ABX, 4),
            Instruction("ROR", .ROR, .ABX, 7),
            Instruction("???", .XXX, .IMP, 7),
        
            Instruction("???", .NOP, .IMP, 2), // 0x80
            Instruction("STA", .STA, .IZX, 6),
            Instruction("???", .NOP, .IMP, 2),
            Instruction("???", .XXX, .IMP, 6),
            Instruction("STY", .STY, .ZP0, 3),
            Instruction("STA", .STA, .ZP0, 3),
            Instruction("STX", .STX, .ZP0, 3),
            Instruction("???", .XXX, .IMP, 3),
            Instruction("DEY", .DEY, .IMP, 2),
            Instruction("???", .NOP, .IMP, 2),
            Instruction("TXA", .TXA, .IMP, 2),
            Instruction("???", .XXX, .IMP, 2),
            Instruction("STY", .STY, .ABS, 4),
            Instruction("STA", .STA, .ABS, 4),
            Instruction("STX", .STX, .ABS, 4),
            Instruction("???", .XXX, .IMP, 4),
        
            Instruction("BCC", .BCC, .REL, 2), // 0x90
            Instruction("STA", .STA, .IZY, 6),
            Instruction("???", .XXX, .IMP, 2),
            Instruction("???", .XXX, .IMP, 6),
            Instruction("STY", .STY, .ZPX, 4),
            Instruction("STA", .STA, .ZPX, 4),
            Instruction("STX", .STX, .ZPY, 4),
            Instruction("???", .XXX, .IMP, 4),
            Instruction("TYA", .TYA, .IMP, 2),
            Instruction("STA", .STA, .ABY, 5),
            Instruction("TXS", .TXS, .IMP, 2),
            Instruction("???", .XXX, .IMP, 5),
            Instruction("???", .NOP, .IMP, 5),
            Instruction("STA", .STA, .ABX, 5),
            Instruction("???", .XXX, .IMP, 5),
            Instruction("???", .XXX, .IMP, 5),
        
            Instruction("LDY", .LDY, .IMM, 2), // 0xA0
            Instruction("LDA", .LDA, .IZX, 6),
            Instruction("LDX", .LDX, .IMM, 2),
            Instruction("???", .XXX, .IMP, 6),
            Instruction("LDY", .LDY, .ZP0, 3),
            Instruction("LDA", .LDA, .ZP0, 3),
            Instruction("LDX", .LDX, .ZP0, 3),
            Instruction("???", .XXX, .IMP, 3),
            Instruction("TAY", .TAY, .IMP, 2),
            Instruction("LDA", .LDA, .IMM, 2),
            Instruction("TAX", .TAX, .IMP, 2),
            Instruction("???", .XXX, .IMP, 2),
            Instruction("LDY", .LDY, .ABS, 4),
            Instruction("LDA", .LDA, .ABS, 4),
            Instruction("LDX", .LDX, .ABS, 4),
            Instruction("???", .XXX, .IMP, 4),
        
            Instruction("BCS", .BCS, .REL, 2), // 0xB0
            Instruction("LDA", .LDA, .IZY, 5),
            Instruction("???", .XXX, .IMP, 2),
            Instruction("???", .XXX, .IMP, 5),
            Instruction("LDY", .LDY, .ZPX, 4),
            Instruction("LDA", .LDA, .ZPX, 4),
            Instruction("LDX", .LDX, .ZPY, 4),
            Instruction("???", .XXX, .IMP, 4),
            Instruction("CLV", .CLV, .IMP, 2),
            Instruction("LDA", .LDA, .ABY, 4),
            Instruction("TSX", .TSX, .IMP, 2),
            Instruction("???", .XXX, .IMP, 4),
            Instruction("LDY", .LDY, .ABX, 4),
            Instruction("LDA", .LDA, .ABX, 4),
            Instruction("LDX", .LDX, .ABY, 4),
            Instruction("???", .XXX, .IMP, 4),
        
            Instruction("CPY", .CPY, .IMM, 2), // 0xC0
            Instruction("CMP", .CMP, .IZX, 6),
            Instruction("???", .NOP, .IMP, 2),
            Instruction("???", .XXX, .IMP, 8),
            Instruction("CPY", .CPY, .ZP0, 3),
            Instruction("CMP", .CMP, .ZP0, 3),
            Instruction("DEC", .DEC, .ZP0, 5),
            Instruction("???", .XXX, .IMP, 5),
            Instruction("INY", .INY, .IMP, 2),
            Instruction("CMP", .CMP, .IMM, 2),
            Instruction("DEX", .DEX, .IMP, 2),
            Instruction("???", .XXX, .IMP, 2),
            Instruction("CPY", .CPY, .ABS, 4),
            Instruction("CMP", .CMP, .ABS, 4),
            Instruction("DEC", .DEC, .ABS, 6),
            Instruction("???", .XXX, .IMP, 6),
        
            Instruction("BNE", .BNE, .REL, 2), // 0xD0
            Instruction("CMP", .CMP, .IZY, 5),
            Instruction("???", .XXX, .IMP, 2),
            Instruction("???", .XXX, .IMP, 8),
            Instruction("???", .NOP, .IMP, 4),
            Instruction("CMP", .CMP, .ZPX, 4),
            Instruction("DEC", .DEC, .ZPX, 6),
            Instruction("???", .XXX, .IMP, 6),
            Instruction("CLD", .CLD, .IMP, 2),
            Instruction("CMP", .CMP, .ABY, 4),
            Instruction("NOP", .NOP, .IMP, 2),
            Instruction("???", .XXX, .IMP, 7),
            Instruction("???", .NOP, .IMP, 4),
            Instruction("CMP", .CMP, .ABX, 4),
            Instruction("DEC", .DEC, .ABX, 7),
            Instruction("???", .XXX, .IMP, 7),
        
            Instruction("CPX", .CPX, .IMM, 2), // 0xE0
            Instruction("SBC", .SBC, .IZX, 6),
            Instruction("???", .NOP, .IMP, 2),
            Instruction("???", .XXX, .IMP, 8),
            Instruction("CPX", .CPX, .ZP0, 3),
            Instruction("SBC", .SBC, .ZP0, 3),
            Instruction("INC", .INC, .ZP0, 5),
            Instruction("???", .XXX, .IMP, 5),
            Instruction("INX", .INX, .IMP, 2),
            Instruction("SBC", .SBC, .IMM, 2),
            Instruction("NOP", .NOP, .IMP, 2),
            Instruction("???", .SBC, .IMP, 2),
            Instruction("CPX", .CPX, .ABS, 4),
            Instruction("SBC", .SBC, .ABS, 4),
            Instruction("INC", .INC, .ABS, 6),
            Instruction("???", .XXX, .IMP, 6),
        
            Instruction("BEQ", .BEQ, .REL, 2), // 0xF0
            Instruction("SBC", .SBC, .IZY, 5),
            Instruction("???", .XXX, .IMP, 2),
            Instruction("???", .XXX, .IMP, 8),
            Instruction("???", .NOP, .IMP, 4),
            Instruction("SBC", .SBC, .ZPX, 4),
            Instruction("INC", .INC, .ZPX, 6),
            Instruction("???", .XXX, .IMP, 6),
            Instruction("SED", .SED, .IMP, 2),
            Instruction("SBC", .SBC, .ABY, 4),
            Instruction("NOP", .NOP, .IMP, 2),
            Instruction("???", .XXX, .IMP, 7),
            Instruction("???", .NOP, .IMP, 4),
            Instruction("SBC", .SBC, .ABX, 4),
            Instruction("INC", .INC, .ABX, 7),
            Instruction("???", .XXX, .IMP, 7),
        ]
    }()
}


// MARK: - Operations

extension MOS6502 {
    private enum Operation {
        case ADC, SBC, AND, ASL, BCS, BCC, BEQ, BNE, BMI, BPL, BVS, BVC, BIT, BRK
        case CLC, CLD, CLI, CLV, CMP, CPX, CPY, DEC, DEX, DEY, EOR, INC, INX, INY
        case JMP, JSR, LDA, LDX, LDY, LSR, NOP, ORA, PHA, PHP, PLA, PLP, ROL, ROR
        case RTI, RTS, SEC, SED, SEI, STA, STX, STY, TAX, TAY, TSX, TXA, TYA, TXS
        
        case XXX
    }

    private func ADC(_ address: Address, _ crossedPageBoundary: Bool) -> UInt8 {
        let fetchedValue = bus[address]
        let temp = UInt16(a) + UInt16(fetchedValue) + UInt16(status.contains(.carry) ? 1 : 0)
        status.setOptions(.carry, enabled: temp > 255)
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0)
        status.setOptions(.resultIsOverflowed, enabled: ((~(UInt16(a) ^ UInt16(fetchedValue)) & (UInt16(a) ^ temp)) & 0x0080) > 0)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x80) > 0)
        a = Value(temp & 0x00ff)
        
        return crossedPageBoundary ? 1 : 0
    }
    
    private func SBC(_ address: Address, _ crossedPageBoundary: Bool) -> UInt8 {
        let fetchedValue = UInt16(bus[address]) ^ 0x00ff
        let temp = UInt16(a) + fetchedValue + UInt16(status.contains(.carry) ? 1 : 0)
        status.setOptions(.carry, enabled: (temp & 0xff00) > 0)
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0)
        status.setOptions(.resultIsOverflowed, enabled: ((temp ^ UInt16(a)) & (temp ^ fetchedValue) & 0x0080) > 0)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x0080) > 0)
        a = Value(temp & 0x00ff)

        return crossedPageBoundary ? 1 : 0
    }
    
    private func AND(_ address: Address, _ crossedPageBoundary: Bool) -> UInt8 {
        let fetchedValue = bus[address]
        a = a & fetchedValue
        status.setOptions(.resultIsZero, enabled: a == 0x00)
        status.setOptions(.resultIsNegative, enabled: (a & 0x80) > 0)
        
        return crossedPageBoundary ? 1 : 0
    }
    
    private func ASL(_ address: Address, _ addressMode: AddressMode) {
        let fetchedValue = (addressMode != .IMP) ? UInt16(bus[address]) : UInt16(a)
        let temp = fetchedValue << 1
        status.setOptions(.carry, enabled: (temp & 0xff00) > 0)
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0x00)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x80) > 0)
        
        if addressMode == .IMP {
            a = Value(temp & 0x00ff)
        } else {
            bus[address] = Value(temp & 0x00ff)
        }
    }
    
    
    private func BCS(_ relativeAddress: Address) -> UInt8 {
        guard status.contains(.carry) else { return 0 }
        return BXX(relativeAddress)
    }
    
    private func BCC(_ relativeAddress: Address) -> UInt8 {
        guard !status.contains(.carry) else { return 0 }
        return BXX(relativeAddress)
    }
    
    private func BEQ(_ relativeAddress: Address) -> UInt8 {
        guard status.contains(.resultIsZero) else { return 0 }
        return BXX(relativeAddress)
    }
    
    private func BNE(_ relativeAddress: Address) -> UInt8 {
        guard !status.contains(.resultIsZero) else { return 0 }
        return BXX(relativeAddress)
    }
    
    private func BMI(_ relativeAddress: Address) -> UInt8 {
        guard status.contains(.resultIsNegative) else { return 0 }
        return BXX(relativeAddress)
    }
    
    private func BPL(_ relativeAddress: Address) -> UInt8 {
        guard !status.contains(.resultIsNegative) else { return 0 }
        return BXX(relativeAddress)
    }
    
    private func BVS(_ relativeAddress: Address) -> UInt8 {
        guard status.contains(.resultIsOverflowed) else { return 0 }
        return BXX(relativeAddress)
    }
    
    private func BVC(_ relativeAddress: Address) -> UInt8 {
        guard !status.contains(.resultIsOverflowed) else { return 0 }
        return BXX(relativeAddress)
    }
    
    private func BXX(_ relativeAddress: Address) -> UInt8 {
        let address = pc &+ relativeAddress
        
        defer {
            pc = address
        }
        
        if ((address & 0xff00) != (pc & 0xff00)) {
            return 2
        } else {
            return 1
        }
    }
    
    
    private func BIT(_ address: Address) {
        let fetchedValue = bus[address]
        let temp = a & fetchedValue
        status.setOptions(.resultIsZero, enabled: (temp & 0x00FF) == 0x00)
        status.setOptions(.resultIsNegative, enabled: (fetchedValue & (1 << 7)) > 0)
        status.setOptions(.resultIsOverflowed, enabled: (fetchedValue & (1 << 6)) > 0)
    }
    
    private func BRK() {
        pc += 1
        
        status.insert(.disableInterrupts)
        bus[0x0100 + Address(stkp)] = pc.hi
        stkp &-= 1
        bus[0x0100 + Address(stkp)] = pc.lo
        stkp &-= 1

        status.insert(.break)
        bus[0x0100 + Address(stkp)] = status.rawValue
        stkp &-= 1
        status.remove(.break)

        pc = Address(lo: bus[0xfffe],
                     hi: bus[0xffff])
    }
    
    
    private func CLC() {
        status.remove(.carry)
    }
    
    private func CLD() {
        status.remove(.decimalMode)
    }
    
    private func CLI() {
        status.remove(.disableInterrupts)
    }
    
    private func CLV() {
        status.remove(.resultIsOverflowed)
    }
    
    
    private func CMP(_ address: Address, _ crossedPageBoundary: Bool) -> UInt8 {
        let fetchedValue = bus[address]
        let temp = UInt16(a) &- UInt16(fetchedValue)
        status.setOptions(.carry, enabled: a >= fetchedValue)
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0x0000)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x0080) > 0)
        
        return crossedPageBoundary ? 1 : 0
    }
    
    private func CPX(_ address: Address) {
        let fetchedValue = bus[address]
        let temp = UInt16(x) &- UInt16(fetchedValue)
        status.setOptions(.carry, enabled: x >= fetchedValue)
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0x0000)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x0080) > 0)
    }

    private func CPY(_ address: Address) {
        let fetchedValue = bus[address]
        let temp = UInt16(y) &- UInt16(fetchedValue)
        status.setOptions(.carry, enabled: y >= fetchedValue)
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0x0000)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x0080) > 0)
    }
    
    
    private func DEC(_ address: Address) {
        let fetchedValue = bus[address]
        let temp = fetchedValue &- 1
        bus[address] = UInt8(temp & 0x00ff)
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0x0000)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x0080) > 0)
    }
    
    private func DEX() {
        x &-= 1
        status.setOptions(.resultIsZero, enabled: x == 0x00)
        status.setOptions(.resultIsNegative, enabled: (x & 0x80) > 0)
    }

    private func DEY() {
        y &-= 1
        status.setOptions(.resultIsZero, enabled: y == 0x00)
        status.setOptions(.resultIsNegative, enabled: (y & 0x80) > 0)
    }
    
    
    private func EOR(_ address: Address) {
        let fetchedValue = bus[address]
        a = a ^ fetchedValue
        status.setOptions(.resultIsZero, enabled: a == 0x00)
        status.setOptions(.resultIsNegative, enabled: (a & 0x80) > 0)
    }
    
    
    private func INC(_ address: Address) {
        let fetchedValue = bus[address]
        let temp = fetchedValue &+ 1
        bus[address] = temp
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0x0000)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x0080) > 0)
    }
    
    private func INX() {
        x &+= 1
        status.setOptions(.resultIsZero, enabled: x == 0x00)
        status.setOptions(.resultIsNegative, enabled: (x & 0x80) > 0)
    }

    private func INY() {
        y &+= 1
        status.setOptions(.resultIsZero, enabled: y == 0x00)
        status.setOptions(.resultIsNegative, enabled: (y & 0x80) > 0)
    }

    
    private func JMP(_ address: Address) {
        pc = address
    }
    
    private func JSR(_ address: Address) {
        pc -= 1
        
        bus[0x0100 + Address(stkp)] = pc.hi
        stkp &-= 1
        bus[0x0100 + Address(stkp)] = pc.lo
        stkp &-= 1
        
        pc = address
    }
    
    
    private func LDA(_ address: Address, _ crossedPageBoundary: Bool) -> UInt8 {
        let fetchedValue = bus[address]
        a = fetchedValue
        status.setOptions(.resultIsZero, enabled: a == 0x00)
        status.setOptions(.resultIsNegative, enabled: (a & 0x80) > 0)

        return crossedPageBoundary ? 1 : 0
    }
    
    private func LDX(_ address: Address, _ crossedPageBoundary: Bool) -> UInt8 {
        let fetchedValue = bus[address]
        x = fetchedValue
        status.setOptions(.resultIsZero, enabled: x == 0x00)
        status.setOptions(.resultIsNegative, enabled: (x & 0x80) > 0)

        return crossedPageBoundary ? 1 : 0
    }

    private func LDY(_ address: Address, _ crossedPageBoundary: Bool) -> UInt8 {
        let fetchedValue = bus[address]
        y = fetchedValue
        status.setOptions(.resultIsZero, enabled: y == 0x00)
        status.setOptions(.resultIsNegative, enabled: (y & 0x80) > 0)

        return crossedPageBoundary ? 1 : 0
    }
    
    
    private func LSR(_ address: Address, _ addressMode: AddressMode) {
        let fetchedValue = (addressMode != .IMP) ? UInt16(bus[address]) : UInt16(a)
        status.setOptions(.carry, enabled: (fetchedValue & 0x0001) > 0)
        let temp = UInt16(fetchedValue) >> 1
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0x0000)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x0080) > 0)
        
        if addressMode == .IMP {
            a = Value(temp & 0x00ff)
        } else {
            bus[address] = Value(temp & 0x00ff)
        }
    }
    
    private func NOP(_ crossedPageBoundary: Bool) -> UInt8 {
        switch opcode {
        case 0x1c, 0x3c, 0x5c, 0x7c, 0xdc, 0xfc:
            return crossedPageBoundary ? 1 : 0
        default:
            return 0
        }
    }
    
    private func ORA(_ address: Address, _ crossedPageBoundary: Bool) -> UInt8 {
        let fetchedValue = bus[address]
        a = a | fetchedValue
        status.setOptions(.resultIsZero, enabled: a == 0x00)
        status.setOptions(.resultIsNegative, enabled: (a & 0x80) > 0)

        return crossedPageBoundary ? 1 : 0
    }
    
    private func PHA() {
        bus[0x0100 + UInt16(stkp)] = a
        stkp &-= 1
    }
    
    private func PHP() {
        status.insert(.break)
        status.insert(.unused)
        bus[0x0100 + Address(stkp)] = status.rawValue
        status.remove(.break)
        status.remove(.unused)
        stkp &-= 1
    }
    
    private func PLA() {
        stkp &+= 1
        a = bus[0x0100 + Address(stkp)]
        status.setOptions(.resultIsZero, enabled: a == 0x00)
        status.setOptions(.resultIsNegative, enabled: (a & 0x80) > 0)
    }
    
    private func PLP() {
        stkp &+= 1
        status = Status(rawValue: bus[0x0100 + Address(stkp)])
        status.insert(.unused)
    }
    
    private func ROL(_ address: Address, _ addressMode: AddressMode) {
        let fetchedValue = (addressMode != .IMP) ? UInt16(bus[address]) : UInt16(a)
        let temp = (UInt16(fetchedValue) << 1) | (status.contains(.carry) ? 1 : 0)
        status.setOptions(.carry, enabled: (temp & 0xff00) > 0)
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0x0000)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x0080) > 0)
        
        if addressMode == .IMP {
            a = Value(temp & 0x00ff)
        } else {
            bus[address] = Value(temp & 0x00ff)
        }
    }
    
    private func ROR(_ address: Address, _ addressMode: AddressMode) {
        let fetchedValue = (addressMode != .IMP) ? UInt16(bus[address]) : UInt16(a)
        let temp = (UInt16(status.contains(.carry) ? 1 : 0) << 7) | (UInt16(fetchedValue) >> 1)
        status.setOptions(.carry, enabled: (fetchedValue & 0x01) > 0)
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0x00)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x0080) > 0)
        
        if addressMode == .IMP {
            a = Value(temp & 0x00ff)
        } else {
            bus[address] = Value(temp & 0x00ff)
        }
    }
    
    private func RTI() {
        // We assume IMP address mode.
        stkp &+= 1
        status = Status(rawValue: bus[0x0100 + Address(stkp)])
        status.remove(.break)
        status.remove(.unused)

        stkp &+= 1
        pc = Address(bus[0x0100 + Address(stkp)])
        stkp &+= 1
        pc |= Address(bus[0x0100 + Address(stkp)]) << 8
    }
    
    private func RTS() {
        // We assume IMP address mode.
        stkp &+= 1
        pc = Address(bus[0x0100 + Address(stkp)])
        stkp &+= 1
        pc |= Address(bus[0x0100 + Address(stkp)]) << 8

        pc += 1
    }
    
    private func SEC() {
        status.insert(.carry)
    }
    
    private func SED() {
        status.insert(.decimalMode)
    }
    
    private func SEI() {
        status.insert(.disableInterrupts)
    }
    
    private func STA(_ address: Address) {
        bus[address] = a
    }
    
    private func STX(_ address: Address) {
        bus[address] = x
    }
    
    private func STY(_ address: Address) {
        bus[address] = y
    }
    
    private func TAX() {
        x = a
        status.setOptions(.resultIsZero, enabled: x == 0x00)
        status.setOptions(.resultIsNegative, enabled: (x & 0x80) > 0)
    }
    
    private func TAY() {
        y = a
        status.setOptions(.resultIsZero, enabled: y == 0x00)
        status.setOptions(.resultIsNegative, enabled: (y & 0x80) > 0)
    }
    
    private func TSX() {
        x = stkp
        status.setOptions(.resultIsZero, enabled: x == 0x00)
        status.setOptions(.resultIsNegative, enabled: (x & 0x80) > 0)
    }
    
    private func TXA() {
        a = x
        status.setOptions(.resultIsZero, enabled: a == 0x00)
        status.setOptions(.resultIsNegative, enabled: (a & 0x80) > 0)
    }
    
    private func TYA() {
        a = y
        status.setOptions(.resultIsZero, enabled: a == 0x00)
        status.setOptions(.resultIsNegative, enabled: (a & 0x80) > 0)
    }
    
    private func TXS() {
        stkp = x
    }
}

// MARK: - Address Modes

extension MOS6502 {
    private enum AddressMode: String, CustomDebugStringConvertible {
        case IMP, IMM, ABS, ABX, ABY, REL, ZP0, ZPX, ZPY, IND, IZX, IZY
        
        var debugDescription: String {
            return rawValue
        }
    }
    
    private typealias ReadAddressResult = (address: Address, crossedPageBoundary: Bool)

    /// Implied
    ///
    /// There is no additional data required for this instruction.
    private func IMP() -> ReadAddressResult {
        return (pc, false)
    }
    
    /// Immediate
    ///
    /// The next byte is used as a value.
    private func IMM() -> ReadAddressResult {
        let address = pc
        pc += 1
        
        return (address, false)
    }
    
    /// Absolute
    ///
    /// A full 16-bit address is loaded and used.
    private func ABS() -> ReadAddressResult {
        let address = Address(lo: bus[pc + 0],
                              hi: bus[pc + 1])
        pc += 2

        return (address, false)
    }
    
    /// Absolute with X Offset
    ///
    /// The same as `ABS`, but the value of the `x` register is added to the address.
    private func ABX() -> ReadAddressResult {
        let lo = bus[pc + 0]
        let hi = bus[pc + 1]
        pc += 2

        var address = Address(lo: lo, hi: hi)
        address += Address(x)
        
        let crossedPageBoundary = (address & 0xff00) != (hi << 8)
        
        return (address, crossedPageBoundary)
    }
    
    /// Absolute with Y Offset
    ///
    /// The same as `ABS`, but the value of the `y` register is added to the address.
    private func ABY() -> ReadAddressResult {
        let lo = bus[pc + 0]
        let hi = bus[pc + 1]
        pc += 2

        var address = Address(lo: lo, hi: hi)
        address &+= Address(y)
        
        let crossedPageBoundary = (address & 0xff00) != (hi << 8)
        
        return (address, crossedPageBoundary)
    }
    
    /// Relative
    ///
    /// The read address is used as a relative offset to the current address of the program counter.
    private func REL() -> ReadAddressResult {
        var relativeAddress = Address(bus[pc])
        pc += 1
        
        if (relativeAddress & 0x80) > 0 {
            relativeAddress |= 0xFF00;
        }
        
        return (relativeAddress, false)
    }
    
    /// Zero Page
    ///
    /// Allows addressing an absolute address in the first `0xff` bytes of the address range using
    /// only a single byte.
    private func ZP0() -> ReadAddressResult {
        var address = Address(bus[pc])
        address &= 0x00ff
        pc += 1
        
        return (address, false)
    }
    
    /// Zero Page with X Offset
    ///
    /// Allows addressing an absolute address in the first `0xff` bytes of the address range using
    /// the value of the `x` register.
    private func ZPX() -> ReadAddressResult {
        var address = Address(bus[pc] &+ x)
        address &= 0x00ff
        pc += 1
        
        return (address, false)
    }
    
    /// Zero Page with Y Offset
    ///
    /// Allows addressing an absolute address in the first `0xff` bytes of the address range using
    /// the value of the `y` register.
    private func ZPY() -> ReadAddressResult {
        var address = Address(bus[pc] &+ y)
        address &= 0x00ff
        pc += 1
        
        return (address, false)
    }
    
    /// Indirect
    ///
    /// Reads an address that points to another address where the actual value is stored.
    private func IND() -> ReadAddressResult {
        let ptrLo = bus[pc + 0]
        let ptrHi = bus[pc + 1]
        pc += 2

        let ptr = Address(lo: ptrLo, hi: ptrHi)

        let address: UInt16
        if (ptrLo == 0x00ff) { // Simulate page boundary hardware bug.
            address = Address(lo: bus[ptr + 0], hi: bus[ptr & 0xff00])
        } else {
            address = Address(lo: bus[ptr + 0], hi: bus[ptr + 1])
        }
        
        return (address, false)
    }
    
    /// Indirect X
    ///
    /// The 8-bit address is offset by the value of the `x` register to index a location in the first page.
    private func IZX() -> ReadAddressResult {
        let ptr = Address(bus[pc])
        pc += 1
        
        let lo = bus[(ptr + Address(x)) & 0x00ff]
        let hi = bus[(ptr + Address(x) + 1) & 0x00ff]
        let address = Address(lo: lo, hi: hi)
        
        return (address, false)
    }
    
    /// Indirect Y
    ///
    /// The 8-bit address is indexes a location in the first page. The value in the `y` register are used to
    /// offset this address.
    private func IZY() -> ReadAddressResult {
        let ptr = Address(bus[pc])
        pc += 1
        
        let lo = bus[ptr & 0x00ff]
        let hi = bus[(ptr + 1) & 0x00ff]
        
        var address = Address(lo: lo, hi: hi)
        address &+= Address(y)
        
        let crossedPageBoundary = (address & 0xff00) != (hi << 8)
        
        return (address, crossedPageBoundary)
    }
}
