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
    private(set) var a: UInt8 = 0x00
    
    /// The x register.
    private(set) var x: UInt8 = 0x00
    
    /// The y register.
    private(set) var y: UInt8 = 0x00
    
    /// The stack pointer.
    private(set) var stkp: UInt8 = 0x00
    
    /// The program counter.
    private(set) var pc: UInt16 = 0x0000
    
    
    /// An option set that defines the bits of the Status register.
    struct Status: OptionSet {
        let rawValue: UInt8
        
        /// Carry the 1.
        static let carry = Status(rawValue: (1 << 0))
        
        /// Result is zero.
        static let resultIsZero = Status(rawValue: (1 << 1))
        
        /// Disable interrupts.
        static let disableInterrupts = Status(rawValue: (1 << 2))
        
        /// Decimal mode (not implemented).
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
        
        guard cyclesRemaining == 0 else { return }
        
        // Read the next instruction byte. This 8-bit value is used to index the
        // instruction table to get the relevant information about how to implement
        // the instruction.
        opcode = bus.read(from: pc)
        
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
    
    /// Forces the CPU into a known state.
    ///
    /// This is hard-wired inside the CPU. The registers are set to 0x00, the
    /// status register is cleared except for unused bit which remains at 1.
    /// An absolute address is read from location 0xFFFC which contains a second
    /// address that the program counter is set to. This allows the programmer
    /// to jump to a known and programmable location in the memory to start
    /// executing from. Typically the programmer would set the value at location
    /// 0xFFFC at compile time.
    func reset() {
        // Get the address to set the program counter to.
        // The address is contained at 0xfffc
        let resetAddress: UInt16 = 0xfffc
        let lo = UInt16(bus.read(from: resetAddress + 0))
        let hi = UInt16(bus.read(from: resetAddress + 1))
        
        // Set the program counter.
        pc = (hi << 8) | lo
        
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
    /// Interrupt requests only happen if the `status` does not contain the
    /// `.disableInterrupts` option. IRQs can happen at any time, but the current
    /// instruction is allowed to finish before the IRQ is handled.
    ///
    /// When ready, the current program counter is stored on the stack. Then the
    /// current status register is stored on the stack. When the routine
    /// that services the interrupt has finished, the status register
    /// and program counter can be restored to how they where before it
    /// occurred. This is impemented by the "RTI" instruction. Once the IRQ
    /// has happened, in a similar way to a reset, a programmable address
    /// is read form hard coded location 0xFFFE, which is subsequently
    /// set to the program counter.
    func irq() {
        guard !status.contains(.disableInterrupts) else { return }
        
        // Push the program counter to the stack.
        // The program counter is 16-bits, so we require 2 writes.
        bus.write(UInt8((pc >> 8) & 0x00ff), to: 0x0100 + UInt16(stkp))
        stkp -= 1
        bus.write(UInt8(pc & 0x00ff), to: 0x0100 + UInt16(stkp))
        stkp -= 1
        
        // Push the status register to the stack.
        status.remove(.break)
        status.insert(.unused)
        status.insert(.disableInterrupts)
        bus.write(status.rawValue, to: 0x0100 + UInt16(stkp))
        stkp -= 1
        
        // Read the new program counter location from a specific address.
        let irqAddress: UInt16 = 0xfffe
        let lo = UInt16(bus.read(from: irqAddress + 0))
        let hi = UInt16(bus.read(from: irqAddress + 1))
        pc = (hi << 8) | lo
        
        // Interrupt requests take time.
        cyclesRemaining = 7
    }
    
    /// Interrupts execution and Executes an instruction at a specified location,
    /// but cannot be disabled by the `status` register.
    func nmi() {
        // Push the program counter to the stack.
        // The program counter is 16-bits, so we require 2 writes.
        bus.write(UInt8((pc >> 8) & 0x00ff), to: 0x0100 + UInt16(stkp))
        stkp -= 1
        bus.write(UInt8(pc & 0x00ff), to: 0x0100 + UInt16(stkp))
        stkp -= 1
        
        // Push the status register to the stack.
        status.remove(.break)
        status.insert(.unused)
        status.insert(.disableInterrupts)
        bus.write(status.rawValue, to: 0x0100 + UInt16(stkp))
        stkp -= 1
        
        // Read the new program counter location from a specific address.
        let nmiAddress: UInt16 = 0xfffa
        let lo = UInt16(bus.read(from: nmiAddress + 0))
        let hi = UInt16(bus.read(from: nmiAddress + 1))
        pc = (hi << 8) | lo
        
        // Non-maskable interrupt requests take time.
        cyclesRemaining = 8
    }
    
    
    // MARK: - Utilities
    
    /// Whether or not the current instruction is complete.
    var isCurrentInstructionComplete: Bool {
        cyclesRemaining == 0
    }
    
    /// The total number of cycles that have occurred since powering on the device.
    private(set) var totalCycleCount: UInt32 = 0
    
    /// Disassembles the program into a human-readable format.
    ///
    /// - parameter start: The address to begin disassembling.
    /// - parameter stop: The address to stop disassembling.
    /// - returns: A dictionary that contains the address as keys and instructions as strings.
    func disassemble(start: UInt16, stop: UInt16) -> [UInt16: String] {
        fatalError("Not implemented!")
    }
    
    
    // MARK: - Private
    
    /// The bus that allows the CPU to read/write data from/to any bus-attached devices.
    private let bus: Bus
    
    /// The working instruction byte.
    private var opcode: UInt8 = 0x00
    
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
        case .CPX: return CPX(address, crossedPageBoundary)
        case .CPY: return CPY(address, crossedPageBoundary)
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
    private struct Instruction {
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
    }
    
    /// An array of all of the possible instructions that the CPU can perform.
    ///
    /// The array can be indexed via an `Opcode`.
    static private var instructions: [Instruction] = {
        return [
            Instruction("BRK", .BRK, .IMM, 7),
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

            Instruction("BPL", .BPL, .REL, 2),
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
        
            Instruction("JSR", .JSR, .ABS, 6),
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
        
            Instruction("BMI", .BMI, .REL, 2),
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
        
            Instruction("RTI", .RTI, .IMP, 6),
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
        
            Instruction("BVC", .BVC, .REL, 2),
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
        
            Instruction("RTS", .RTS, .IMP, 6),
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
        
            Instruction("BVS", .BVS, .REL, 2),
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
        
            Instruction("???", .NOP, .IMP, 2),
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
        
            Instruction("BCC", .BCC, .REL, 2),
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
        
            Instruction("LDY", .LDY, .IMM, 2),
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
        
            Instruction("BCS", .BCS, .REL, 2),
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
        
            Instruction("CPY", .CPY, .IMM, 2),
            Instruction("CMP", .CMP, .IZX, 6),
            Instruction("???", .NOP, .IMP, 2),
            Instruction("???", .XXX, .IMP, 8),
            Instruction("CPY", .LDY, .ZP0, 3),
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
        
            Instruction("BNE", .BNE, .REL, 2),
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
        
            Instruction("CPX", .CPX, .IMM, 2),
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
        
            Instruction("BEQ", .BEQ, .REL, 2),
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

    private func ADC(_ address: UInt16, _ crossedPageBoundary: Bool) -> UInt8 {
        let fetchedValue = bus.read(from: address)
        let temp = UInt16(a) + UInt16(fetchedValue) + UInt16(status.contains(.carry) ? 1 : 0)
        status.setOptions(.carry, enabled: temp > 255)
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0)
        status.setOptions(.resultIsOverflowed, enabled: ((~(UInt16(a) ^ UInt16(fetchedValue) & (UInt16(a) ^ UInt16(temp)))) & 0x0080) > 0)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x80) > 0)
        a = UInt8(temp & 0x00ff)
        
        return crossedPageBoundary ? 1 : 0
    }
    
    private func SBC(_ address: UInt16, _ crossedPageBoundary: Bool) -> UInt8 {
        let fetchedValue = UInt16(bus.read(from: address))
        let temp = UInt16(a) + fetchedValue + UInt16(status.contains(.carry) ? 1 : 0)
        status.setOptions(.carry, enabled: (temp & 0xff00) > 0)
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0)
        status.setOptions(.resultIsOverflowed, enabled: ((temp ^ UInt16(a)) & (temp ^ fetchedValue) & 0x0080) > 0)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x0080) > 0)
        a = UInt8(temp & 0x00ff)

        return crossedPageBoundary ? 1 : 0
    }
    
    private func AND(_ address: UInt16, _ crossedPageBoundary: Bool) -> UInt8 {
        let fetchedValue = bus.read(from: address)
        a = a & fetchedValue
        status.setOptions(.resultIsZero, enabled: a == 0x00)
        status.setOptions(.resultIsNegative, enabled: a == 0x80)
        
        return crossedPageBoundary ? 1 : 0
    }
    
    private func ASL(_ address: UInt16, _ addressMode: AddressMode) {
        let fetchedValue = UInt16(bus.read(from: address))
        let temp = fetchedValue << 1
        status.setOptions(.carry, enabled: (temp & 0xff00) > 0)
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0x00)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x80) > 0)
        
        if addressMode == .IMP {
            a = UInt8(fetchedValue & 0x00ff)
        } else {
            bus.write(UInt8(fetchedValue & 0x00ff), to: address)
        }
    }
    
    
    private func BCS(_ relativeAddress: UInt16) -> UInt8 {
        guard status.contains(.carry) else { return 0 }
        return BXX(relativeAddress)
    }
    
    private func BCC(_ relativeAddress: UInt16) -> UInt8 {
        guard !status.contains(.carry) else { return 0 }
        return BXX(relativeAddress)
    }
    
    private func BEQ(_ relativeAddress: UInt16) -> UInt8 {
        guard status.contains(.resultIsZero) else { return 0 }
        return BXX(relativeAddress)
    }
    
    private func BNE(_ relativeAddress: UInt16) -> UInt8 {
        guard !status.contains(.resultIsZero) else { return 0 }
        return BXX(relativeAddress)
    }
    
    private func BMI(_ relativeAddress: UInt16) -> UInt8 {
        guard status.contains(.resultIsNegative) else { return 0 }
        return BXX(relativeAddress)
    }
    
    private func BPL(_ relativeAddress: UInt16) -> UInt8 {
        guard !status.contains(.resultIsNegative) else { return 0 }
        return BXX(relativeAddress)
    }
    
    private func BVS(_ relativeAddress: UInt16) -> UInt8 {
        guard status.contains(.resultIsOverflowed) else { return 0 }
        return BXX(relativeAddress)
    }
    
    private func BVC(_ relativeAddress: UInt16) -> UInt8 {
        guard !status.contains(.resultIsOverflowed) else { return 0 }
        return BXX(relativeAddress)
    }
    
    private func BXX(_ relativeAddress: UInt16) -> UInt8 {
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
    
    
    private func BIT(_ address: UInt16) {
        let fetchedValue = bus.read(from: address)
        let temp = a & fetchedValue
        status.setOptions(.resultIsZero, enabled: (temp & 0x00FF) == 0x00)
        status.setOptions(.resultIsNegative, enabled: (temp & (1 << 7)) > 0)
        status.setOptions(.resultIsOverflowed, enabled: (temp & (1 << 6)) > 0)
    }
    
    private func BRK() {
        pc += 1
        
        status.insert(.disableInterrupts)
        bus.write(UInt8((pc >> 8) & 0x00FF), to: 0x0100 + UInt16(stkp))
        stkp -= 1
        bus.write(UInt8(pc & 0x00FF), to: 0x0100 + UInt16(stkp));
        stkp -= 1

        status.insert(.break)
        bus.write(status.rawValue, to: 0x0100 + UInt16(stkp))
        stkp -= 1
        status.remove(.break)

        pc = UInt16(bus.read(from: 0xfffe)) | (UInt16(bus.read(from: 0xffff)) << 8)
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
    
    
    private func CMP(_ address: UInt16, _ crossedPageBoundary: Bool) -> UInt8 {
        let fetchedValue = bus.read(from: address)
        let temp = UInt16(a) - UInt16(fetchedValue)
        status.setOptions(.carry, enabled: a >= fetchedValue)
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0x0000)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x0080) > 0)
        
        return crossedPageBoundary ? 1 : 0
    }
    
    private func CPX(_ address: UInt16, _ crossedPageBoundary: Bool) -> UInt8 {
        let fetchedValue = bus.read(from: address)
        let temp = UInt16(x) - UInt16(fetchedValue)
        status.setOptions(.carry, enabled: x >= fetchedValue)
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0x0000)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x0080) > 0)
        
        return crossedPageBoundary ? 1 : 0
    }

    private func CPY(_ address: UInt16, _ crossedPageBoundary: Bool) -> UInt8 {
        let fetchedValue = bus.read(from: address)
        let temp = UInt16(y) - UInt16(fetchedValue)
        status.setOptions(.carry, enabled: y >= fetchedValue)
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0x0000)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x0080) > 0)
        
        return crossedPageBoundary ? 1 : 0
    }
    
    
    private func DEC(_ address: UInt16) {
        let fetchedValue = bus.read(from: address)
        let temp = fetchedValue - 1
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0x0000)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x0080) > 0)
    }
    
    private func DEX() {
        x -= 1
        status.setOptions(.resultIsZero, enabled: x == 0x00)
        status.setOptions(.resultIsNegative, enabled: (x & 0x80) > 0)
    }

    private func DEY() {
        y -= 1
        status.setOptions(.resultIsZero, enabled: y == 0x00)
        status.setOptions(.resultIsNegative, enabled: (y & 0x80) > 0)
    }
    
    
    private func EOR(_ address: UInt16) {
        let fetchedValue = bus.read(from: address)
        a = a ^ fetchedValue
        status.setOptions(.resultIsZero, enabled: a == 0x00)
        status.setOptions(.resultIsNegative, enabled: (a & 0x80) > 0)
    }
    
    
    private func INC(_ address: UInt16) {
        let fetchedValue = bus.read(from: address)
        let temp = fetchedValue + 1
        bus.write(temp, to: address)
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0x0000)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x0080) > 0)
    }
    
    private func INX() {
        x += 1
        status.setOptions(.resultIsZero, enabled: x == 0x00)
        status.setOptions(.resultIsNegative, enabled: (x & 0x80) > 0)
    }

    private func INY() {
        y += 1
        status.setOptions(.resultIsZero, enabled: y == 0x00)
        status.setOptions(.resultIsNegative, enabled: (y & 0x80) > 0)
    }

    
    private func JMP(_ address: UInt16) {
        pc = address
    }
    
    private func JSR(_ address: UInt16) {
        pc -= 1
        
        bus.write(UInt8((pc >> 8) & 0x00ff), to: 0x0100 + UInt16(stkp))
        stkp -= 1
        bus.write(UInt8(pc & 0x00ff), to: 0x0100 + UInt16(stkp))
        stkp -= 1
        
        pc = address
    }
    
    
    private func LDA(_ address: UInt16, _ crossedPageBoundary: Bool) -> UInt8 {
        let fetchedValue = bus.read(from: address)
        a = fetchedValue
        status.setOptions(.resultIsZero, enabled: a == 0x00)
        status.setOptions(.resultIsNegative, enabled: (a & 0x80) > 0)

        return crossedPageBoundary ? 1 : 0
    }
    
    private func LDX(_ address: UInt16, _ crossedPageBoundary: Bool) -> UInt8 {
        let fetchedValue = bus.read(from: address)
        x = fetchedValue
        status.setOptions(.resultIsZero, enabled: x == 0x00)
        status.setOptions(.resultIsNegative, enabled: (x & 0x80) > 0)

        return crossedPageBoundary ? 1 : 0
    }

    private func LDY(_ address: UInt16, _ crossedPageBoundary: Bool) -> UInt8 {
        let fetchedValue = bus.read(from: address)
        y = fetchedValue
        status.setOptions(.resultIsZero, enabled: y == 0x00)
        status.setOptions(.resultIsNegative, enabled: (y & 0x80) > 0)

        return crossedPageBoundary ? 1 : 0
    }
    
    
    private func LSR(_ address: UInt16, _ addressMode: AddressMode) {
        let fetchedValue = bus.read(from: address)
        status.setOptions(.carry, enabled: (fetchedValue & 0x0001) > 0)
        let temp = fetchedValue >> 1
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0x0000)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x0080) > 0)
        
        if addressMode == .IMP {
            a = UInt8(temp & 0x00ff)
        } else {
            bus.write(UInt8(temp & 0x00ff), to: address)
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
    
    private func ORA(_ address: UInt16, _ crossedPageBoundary: Bool) -> UInt8 {
        let fetchedValue = bus.read(from: address)
        a = a | fetchedValue
        status.setOptions(.resultIsZero, enabled: a == 0x00)
        status.setOptions(.resultIsNegative, enabled: (a & 0x80) > 0)

        return crossedPageBoundary ? 1 : 0
    }
    
    private func PHA() {
        bus.write(a, to: 0x0100 + UInt16(stkp))
        stkp -= 1
    }
    
    private func PHP() {
        status.insert(.break)
        status.insert(.unused)
        bus.write(status.rawValue, to: 0x0100 + UInt16(stkp))
        status.remove(.break)
        status.remove(.unused)
        stkp -= 1
    }
    
    private func PLA() {
        stkp += 1
        a = bus.read(from: 0x0100 + UInt16(stkp))
        status.setOptions(.resultIsZero, enabled: a == 0x00)
        status.setOptions(.resultIsNegative, enabled: (a & 0x80) > 0)
    }
    
    private func PLP() {
        stkp += 1
        status = Status(rawValue: bus.read(from: 0x0100 + UInt16(stkp)))
        status.insert(.unused)
    }
    
    private func ROL(_ address: UInt16, _ addressMode: AddressMode) {
        let fetchedValue = bus.read(from: address)
        let temp = UInt16(fetchedValue << 1) | (status.contains(.carry) ? 1 : 0)
        status.setOptions(.carry, enabled: (temp & 0xff00) > 0)
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0x0000)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x0080) > 0)
        
        if addressMode == .IMP {
            a = UInt8(temp & 0x00ff)
        } else {
            bus.write(UInt8(temp & 0x00ff), to: address)
        }
    }
    
    private func ROR(_ address: UInt16, _ addressMode: AddressMode) {
        let fetchedValue = bus.read(from: address)
        let temp = (UInt16(status.contains(.carry) ? 1 : 0) << 7) | (UInt16(fetchedValue) >> 1)
        status.setOptions(.carry, enabled: (fetchedValue & 0x01) > 0)
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0x00)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x0080) > 0)
        
        if addressMode == .IMP {
            a = UInt8(temp & 0x00ff)
        } else {
            bus.write(UInt8(temp * 0x00ff), to: address)
        }
    }
    
    private func RTI() {
        // We assume IMP address mode.
        stkp += 1
        status = Status(rawValue: bus.read(from: 0x0100 + UInt16(stkp)))
        status.remove(.break)
        status.remove(.unused)

        stkp += 1
        pc = UInt16(bus.read(from: 0x0100 + UInt16(stkp)))
        stkp += 1
        pc |= UInt16(bus.read(from: 0x0100 + UInt16(stkp))) << 8
    }
    
    private func RTS() {
        // We assume IMP address mode.
        stkp += 1
        pc = UInt16(bus.read(from: 0x0100 + UInt16(stkp)))
        stkp += 1
        pc |= UInt16(bus.read(from: 0x0100 + UInt16(stkp))) << 8

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
    
    private func STA(_ address: UInt16) {
        bus.write(a, to: address)
    }
    
    private func STX(_ address: UInt16) {
        bus.write(x, to: address)
    }
    
    private func STY(_ address: UInt16) {
        bus.write(y, to: address)
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
        status.setOptions(.resultIsZero, enabled: y == 0x00)
        status.setOptions(.resultIsNegative, enabled: (y & 0x80) > 0)
    }
    
    private func TXA() {
        a = x
        status.setOptions(.resultIsZero, enabled: y == 0x00)
        status.setOptions(.resultIsNegative, enabled: (y & 0x80) > 0)
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
    private enum AddressMode {
        case IMP, IMM, ABS, ABX, ABY, REL, ZP0, ZPX, ZPY, IND, IZX, IZY
    }
    
    private typealias ReadAddressResult = (address: UInt16, crossedPageBoundary: Bool)

    /// Implied
    ///
    /// There is no additional data required for this instruction. The instruction
    /// does something very simple like like sets a status bit. However, we will
    /// target the accumulator, for instructions like PHA
    private func IMP() -> ReadAddressResult {
        return (pc, false)
    }
    
    /// Immediate
    ///
    /// The instruction expects the next byte to be used as a value, so we'll prep
    /// the read address to point to the next byte
    private func IMM() -> ReadAddressResult {
        let address = pc
        pc += 1
        
        return (address, false)
    }
    
    /// Absolute
    ///
    /// A full 16-bit address is loaded and used.
    private func ABS() -> ReadAddressResult {
        let lo = UInt16(bus.read(from: pc))
        pc += 1
        let hi = UInt16(bus.read(from: pc))
        pc += 1
        
        let address = (hi << 8) | lo

        return (address, false)
    }
    
    /// Absolute with X Offset
    ///
    /// Fundamentally the same as absolute addressing, but the contents of the X Register
    /// is added to the supplied two byte address. If the resulting address changes
    /// the page, an additional clock cycle is required
    private func ABX() -> ReadAddressResult {
        let lo = UInt16(bus.read(from: pc))
        pc += 1
        let hi = UInt16(bus.read(from: pc))
        pc += 1
        
        var address = (hi << 8) | lo
        address += UInt16(x)
        
        let crossedPageBoundary = (address & 0xff00) != (hi << 8)
        
        return (address, crossedPageBoundary)
    }
    
    /// Absolute with Y Offset
    ///
    /// Fundamentally the same as absolute addressing, but the contents of the Y Register
    /// is added to the supplied two byte address. If the resulting address changes
    /// the page, an additional clock cycle is required
    private func ABY() -> ReadAddressResult {
        let lo = UInt16(bus.read(from: pc))
        pc += 1
        let hi = UInt16(bus.read(from: pc))
        pc += 1
        
        var address = (hi << 8) | lo
        address += UInt16(y)
        
        let crossedPageBoundary = (address & 0xff00) != (hi << 8)
        
        return (address, crossedPageBoundary)
    }
    
    /// Relative
    ///
    /// This address mode is exclusive to branch instructions. The address
    /// must reside within -128 to +127 of the branch instruction, i.e.
    /// you cant directly branch to any address in the addressable range.
    private func REL() -> ReadAddressResult {
        var relativeAddress = UInt16(bus.read(from: pc))
        pc += 1
        
        if (relativeAddress & 0x80) > 0 {
            relativeAddress |= 0xFF00;
        }
        
        return (relativeAddress, false)
    }
    
    /// Zero Page
    ///
    /// To save program bytes, zero page addressing allows you to absolutely address
    /// a location in first 0xFF bytes of address range. Clearly this only requires
    /// one byte instead of the usual two.
    private func ZP0() -> ReadAddressResult {
        var address = UInt16(bus.read(from: pc))
        address &= 0x00ff
        pc += 1
        
        return (address, false)
    }
    
    /// Zero Page with X Offset
    ///
    /// Fundamentally the same as Zero Page addressing, but the contents of the X Register
    /// is added to the supplied single byte address. This is useful for iterating through
    /// ranges within the first page.
    private func ZPX() -> ReadAddressResult {
        var address = UInt16(bus.read(from: pc + UInt16(x)))
        address &= 0x00ff
        pc += 1
        
        return (address, false)
    }
    
    /// Zero Page with Y Offset
    ///
    /// Fundamentally the same as Zero Page addressing, but the contents of the Y Register
    /// is added to the supplied single byte address. This is useful for iterating through
    /// ranges within the first page.
    private func ZPY() -> ReadAddressResult {
        var address = UInt16(bus.read(from: pc + UInt16(y)))
        address &= 0x00ff
        pc += 1
        
        return (address, false)
    }
    
    /// Indirect
    ///
    /// The supplied 16-bit address is read to get the actual 16-bit address. This is
    /// instruction is unusual in that it has a bug in the hardware! To emulate its
    /// function accurately, we also need to emulate this bug. If the low byte of the
    /// supplied address is 0xFF, then to read the high byte of the actual address
    /// we need to cross a page boundary. This doesnt actually work on the chip as
    /// designed, instead it wraps back around in the same page, yielding an
    /// invalid actual address
    private func IND() -> ReadAddressResult {
        let ptrLo = UInt16(bus.read(from: pc))
        pc += 1
        let ptrHi = UInt16(bus.read(from: pc))
        pc += 1
        
        let ptr = (ptrHi << 8) | ptrLo

        let address: UInt16
        if (ptrLo == 0x00ff) { // Simulate page boundary hardware bug.
            address = (UInt16(bus.read(from: ptr & 0xff00)) << 8) | UInt16(bus.read(from: ptr + 0))
        } else {
            address = (UInt16(bus.read(from: ptr + 1)) << 8) | UInt16(bus.read(from: ptr + 0))
        }
        
        return (address, false)
    }
    
    /// Indirect X
    ///
    /// The supplied 8-bit address is offset by X Register to index
    /// a location in page 0x00. The actual 16-bit address is read
    /// from this location
    private func IZX() -> ReadAddressResult {
        let ptr = UInt16(bus.read(from: pc))
        pc += 1
        
        let lo = UInt16(bus.read(from: (ptr + UInt16(x)) & 0x00ff))
        let hi = UInt16(bus.read(from: (ptr + UInt16(x) + 1) & 0xff00))
        let address = (hi << 8) | lo
        
        return (address, false)
    }
    
    /// Indirect Y
    ///
    /// The supplied 8-bit address indexes a location in page 0x00. From
    /// here the actual 16-bit address is read, and the contents of
    /// Y Register is added to it to offset it. If the offset causes a
    /// change in page then an additional clock cycle is required.
    private func IZY() -> ReadAddressResult {
        let ptr = UInt16(bus.read(from: pc))
        pc += 1
        
        let lo = UInt16(bus.read(from: ptr & 0x00ff))
        let hi = UInt16(bus.read(from: (ptr + 1) & 0xff00))
        
        var address = (hi << 8) | lo
        address += UInt16(y)
        
        let crossedPageBoundary = (address & 0xff00) != (hi << 8)
        
        return (address, crossedPageBoundary)
    }
}


extension OptionSet {
    mutating func setOptions(_ options: Self, enabled: Bool) {
        if enabled {
            formUnion(options)
        } else {
            subtract(options)
        }
    }
}
