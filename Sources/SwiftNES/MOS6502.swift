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
    
    init(bus: Bus) {
        self.bus = bus
    }
    
    
    // MARK: - Accessing the bus
    
    /// The bus that allows the CPU to read/write data from/to any bus-attached devices.
    let bus: Bus
    
    
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
        let instruction = instructions[Int(opcode)]
        
        // Get the number of cycles for the instruction.
        cyclesRemaining = instruction.cycleCount
        
        // Perform the operation.
        let additionalCycles = instruction.operation(instruction.addressMode)
        
        // The address mode and operation may have altered the number of cycles this
        // instruction requires before it completes.
        cyclesRemaining += additionalCycles
        
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
        status = [.unused]
        
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
    
    /// Disassembles the program into a human-readable format.
    ///
    /// - parameter start: The address to begin disassembling.
    /// - parameter stop: The address to stop disassembling.
    /// - returns: A dictionary that contains the address as keys and instructions as strings.
    func disassemble(start: UInt16, stop: UInt16) -> [UInt16: String] {
        fatalError("Not implemented!")
    }
    
    
    // MARK: - Private
    
    /// The working instruction byte.
    private var opcode: UInt8 = 0x00
    
    /// How many cycles the current instruction has remaining.
    private var cyclesRemaining: UInt8 = 0x00
    
    /// The total number of cycles that have occurred since powering on the device.
    private var totalCycleCount: UInt32 = 0
    
    
    private func fetch() -> UInt8 {
        return 0
    }
    
    
    private struct Instruction {
        let name: String
        let operation: ((_ addressMode: AddressMode) -> UInt8)
        let addressMode: AddressMode
        let cycleCount: UInt8
    }
    
    lazy private var instructions: [Instruction] = {
        return [
        Instruction(name: "BRK", operation: BRK, addressMode: .IMM, cycleCount: 7),
        Instruction(name: "ORA", operation: ORA, addressMode: .IZX, cycleCount: 6),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 8),
        Instruction(name: "???", operation: NOP, addressMode: .IMP, cycleCount: 3),
        Instruction(name: "ORA", operation: ORA, addressMode: .ZP0, cycleCount: 3),
        Instruction(name: "ASL", operation: ASL, addressMode: .ZP0, cycleCount: 5),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 5),
        Instruction(name: "PHP", operation: PHP, addressMode: .IMP, cycleCount: 3),
        Instruction(name: "ORA", operation: ORA, addressMode: .IMM, cycleCount: 2),
        Instruction(name: "ASL", operation: ASL, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: NOP, addressMode: .IMP, cycleCount: 4),
        Instruction(name: "ORA", operation: ORA, addressMode: .ABS, cycleCount: 4),
        Instruction(name: "ASL", operation: ASL, addressMode: .ABS, cycleCount: 6),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 6),

        Instruction(name: "BPL", operation: BPL, addressMode: .REL, cycleCount: 2),
        Instruction(name: "ORA", operation: ORA, addressMode: .IZY, cycleCount: 5),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 8),
        Instruction(name: "???", operation: NOP, addressMode: .IMP, cycleCount: 4),
        Instruction(name: "ORA", operation: ORA, addressMode: .ZPX, cycleCount: 4),
        Instruction(name: "ASL", operation: ASL, addressMode: .ZPX, cycleCount: 6),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 8),
        Instruction(name: "CLC", operation: CLC, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "ORA", operation: ORA, addressMode: .ABY, cycleCount: 4),
        Instruction(name: "???", operation: NOP, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 7),
        Instruction(name: "???", operation: NOP, addressMode: .IMP, cycleCount: 4),
        Instruction(name: "ORA", operation: ORA, addressMode: .ABX, cycleCount: 4),
        Instruction(name: "ASL", operation: ASL, addressMode: .ABX, cycleCount: 7),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 7),
        
        Instruction(name: "JSR", operation: JSR, addressMode: .ABS, cycleCount: 6),
        Instruction(name: "AND", operation: AND, addressMode: .IZX, cycleCount: 6),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 8),
        Instruction(name: "BIT", operation: BIT, addressMode: .ZP0, cycleCount: 3),
        Instruction(name: "AND", operation: AND, addressMode: .ZP0, cycleCount: 3),
        Instruction(name: "ROL", operation: ROL, addressMode: .ZP0, cycleCount: 5),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 5),
        Instruction(name: "PLP", operation: PLP, addressMode: .IMP, cycleCount: 4),
        Instruction(name: "AND", operation: AND, addressMode: .IMM, cycleCount: 2),
        Instruction(name: "ROL", operation: ROL, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "BIT", operation: BIT, addressMode: .ABS, cycleCount: 4),
        Instruction(name: "AND", operation: AND, addressMode: .ABS, cycleCount: 4),
        Instruction(name: "ROL", operation: ROL, addressMode: .ABS, cycleCount: 6),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 6),
        
        Instruction(name: "BMI", operation: BMI, addressMode: .REL, cycleCount: 2),
        Instruction(name: "AND", operation: AND, addressMode: .IZY, cycleCount: 5),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 8),
        Instruction(name: "???", operation: NOP, addressMode: .IMP, cycleCount: 4),
        Instruction(name: "AND", operation: AND, addressMode: .ZPX, cycleCount: 4),
        Instruction(name: "ROL", operation: ROL, addressMode: .ZPX, cycleCount: 6),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 6),
        Instruction(name: "SEC", operation: SEC, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "AND", operation: AND, addressMode: .ABY, cycleCount: 4),
        Instruction(name: "???", operation: NOP, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 7),
        Instruction(name: "???", operation: NOP, addressMode: .IMP, cycleCount: 4),
        Instruction(name: "AND", operation: AND, addressMode: .ABX, cycleCount: 4),
        Instruction(name: "ROL", operation: ROL, addressMode: .ABX, cycleCount: 7),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 7),
        
        Instruction(name: "RTI", operation: RTI, addressMode: .IMP, cycleCount: 6),
        Instruction(name: "EOR", operation: EOR, addressMode: .IZX, cycleCount: 6),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 8),
        Instruction(name: "???", operation: NOP, addressMode: .IMP, cycleCount: 3),
        Instruction(name: "EOR", operation: EOR, addressMode: .ZP0, cycleCount: 3),
        Instruction(name: "LSR", operation: LSR, addressMode: .ZP0, cycleCount: 5),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 5),
        Instruction(name: "PHA", operation: PHA, addressMode: .IMP, cycleCount: 3),
        Instruction(name: "EOR", operation: EOR, addressMode: .IMM, cycleCount: 2),
        Instruction(name: "LSR", operation: LSR, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "JMP", operation: JMP, addressMode: .ABS, cycleCount: 3),
        Instruction(name: "EOR", operation: EOR, addressMode: .ABS, cycleCount: 4),
        Instruction(name: "LSR", operation: LSR, addressMode: .ABS, cycleCount: 6),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 6),
        
        Instruction(name: "BVC", operation: BVC, addressMode: .REL, cycleCount: 2),
        Instruction(name: "EOR", operation: EOR, addressMode: .IZY, cycleCount: 5),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 8),
        Instruction(name: "???", operation: NOP, addressMode: .IMP, cycleCount: 4),
        Instruction(name: "EOR", operation: EOR, addressMode: .ZPX, cycleCount: 4),
        Instruction(name: "LSR", operation: LSR, addressMode: .ZPX, cycleCount: 6),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 6),
        Instruction(name: "CLI", operation: CLI, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "EOR", operation: EOR, addressMode: .ABY, cycleCount: 4),
        Instruction(name: "???", operation: NOP, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 7),
        Instruction(name: "???", operation: NOP, addressMode: .IMP, cycleCount: 4),
        Instruction(name: "EOR", operation: EOR, addressMode: .ABX, cycleCount: 4),
        Instruction(name: "LSR", operation: LSR, addressMode: .ABX, cycleCount: 7),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 7),
        
        Instruction(name: "RTS", operation: RTS, addressMode: .IMP, cycleCount: 6),
        Instruction(name: "ADC", operation: ADC, addressMode: .IZX, cycleCount: 6),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 8),
        Instruction(name: "???", operation: NOP, addressMode: .IMP, cycleCount: 3),
        Instruction(name: "ADC", operation: ADC, addressMode: .ZP0, cycleCount: 3),
        Instruction(name: "ROR", operation: ROR, addressMode: .ZP0, cycleCount: 5),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 5),
        Instruction(name: "PLA", operation: PLA, addressMode: .IMP, cycleCount: 4),
        Instruction(name: "ADC", operation: ADC, addressMode: .IMM, cycleCount: 2),
        Instruction(name: "ROR", operation: ROR, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "JMP", operation: JMP, addressMode: .IND, cycleCount: 5),
        Instruction(name: "ADC", operation: ADC, addressMode: .ABS, cycleCount: 4),
        Instruction(name: "ROR", operation: ROR, addressMode: .ABS, cycleCount: 6),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 6),
        
        Instruction(name: "BVS", operation: BVS, addressMode: .REL, cycleCount: 2),
        Instruction(name: "ADC", operation: ADC, addressMode: .IZY, cycleCount: 5),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 8),
        Instruction(name: "???", operation: NOP, addressMode: .IMP, cycleCount: 4),
        Instruction(name: "ADC", operation: ADC, addressMode: .ZPX, cycleCount: 4),
        Instruction(name: "ROR", operation: ROR, addressMode: .ZPX, cycleCount: 6),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 6),
        Instruction(name: "SEI", operation: SEI, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "ADC", operation: ADC, addressMode: .ABY, cycleCount: 4),
        Instruction(name: "???", operation: NOP, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 7),
        Instruction(name: "???", operation: NOP, addressMode: .IMP, cycleCount: 4),
        Instruction(name: "ADC", operation: ADC, addressMode: .ABX, cycleCount: 4),
        Instruction(name: "ROR", operation: ROR, addressMode: .ABX, cycleCount: 7),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 7),
        
        Instruction(name: "???", operation: NOP, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "STA", operation: STA, addressMode: .IZX, cycleCount: 6),
        Instruction(name: "???", operation: NOP, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 6),
        Instruction(name: "STY", operation: STY, addressMode: .ZP0, cycleCount: 3),
        Instruction(name: "STA", operation: STA, addressMode: .ZP0, cycleCount: 3),
        Instruction(name: "STX", operation: STX, addressMode: .ZP0, cycleCount: 3),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 3),
        Instruction(name: "DEY", operation: DEY, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: NOP, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "TXA", operation: TXA, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "STY", operation: STY, addressMode: .ABS, cycleCount: 4),
        Instruction(name: "STA", operation: STA, addressMode: .ABS, cycleCount: 4),
        Instruction(name: "STX", operation: STX, addressMode: .ABS, cycleCount: 4),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 4),
        
        Instruction(name: "BCC", operation: BCC, addressMode: .REL, cycleCount: 2),
        Instruction(name: "STA", operation: STA, addressMode: .IZY, cycleCount: 6),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 6),
        Instruction(name: "STY", operation: STY, addressMode: .ZPX, cycleCount: 4),
        Instruction(name: "STA", operation: STA, addressMode: .ZPX, cycleCount: 4),
        Instruction(name: "STX", operation: STX, addressMode: .ZPY, cycleCount: 4),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 4),
        Instruction(name: "TYA", operation: TYA, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "STA", operation: STA, addressMode: .ABY, cycleCount: 5),
        Instruction(name: "TXS", operation: TXS, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 5),
        Instruction(name: "???", operation: NOP, addressMode: .IMP, cycleCount: 5),
        Instruction(name: "STA", operation: STA, addressMode: .ABX, cycleCount: 5),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 5),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 5),
        
        Instruction(name: "LDY", operation: LDY, addressMode: .IMM, cycleCount: 2),
        Instruction(name: "LDA", operation: LDA, addressMode: .IZX, cycleCount: 6),
        Instruction(name: "LDX", operation: LDX, addressMode: .IMM, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 6),
        Instruction(name: "LDY", operation: LDY, addressMode: .ZP0, cycleCount: 3),
        Instruction(name: "LDA", operation: LDA, addressMode: .ZP0, cycleCount: 3),
        Instruction(name: "LDX", operation: LDX, addressMode: .ZP0, cycleCount: 3),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 3),
        Instruction(name: "TAY", operation: TAY, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "LDA", operation: LDA, addressMode: .IMM, cycleCount: 2),
        Instruction(name: "TAX", operation: TAX, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "LDY", operation: LDY, addressMode: .ABS, cycleCount: 4),
        Instruction(name: "LDA", operation: LDA, addressMode: .ABS, cycleCount: 4),
        Instruction(name: "LDX", operation: LDX, addressMode: .ABS, cycleCount: 4),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 4),
        
        Instruction(name: "BCS", operation: BCS, addressMode: .REL, cycleCount: 2),
        Instruction(name: "LDA", operation: LDA, addressMode: .IZY, cycleCount: 5),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 5),
        Instruction(name: "LDY", operation: LDY, addressMode: .ZPX, cycleCount: 4),
        Instruction(name: "LDA", operation: LDA, addressMode: .ZPX, cycleCount: 4),
        Instruction(name: "LDX", operation: LDX, addressMode: .ZPY, cycleCount: 4),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 4),
        Instruction(name: "CLV", operation: CLV, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "LDA", operation: LDA, addressMode: .ABY, cycleCount: 4),
        Instruction(name: "TSX", operation: TSX, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 4),
        Instruction(name: "LDY", operation: LDY, addressMode: .ABX, cycleCount: 4),
        Instruction(name: "LDA", operation: LDA, addressMode: .ABX, cycleCount: 4),
        Instruction(name: "LDX", operation: LDX, addressMode: .ABY, cycleCount: 4),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 4),
        
        Instruction(name: "CPY", operation: CPY, addressMode: .IMM, cycleCount: 2),
        Instruction(name: "CMP", operation: CMP, addressMode: .IZX, cycleCount: 6),
        Instruction(name: "???", operation: NOP, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 8),
        Instruction(name: "CPY", operation: LDY, addressMode: .ZP0, cycleCount: 3),
        Instruction(name: "CMP", operation: CMP, addressMode: .ZP0, cycleCount: 3),
        Instruction(name: "DEC", operation: DEC, addressMode: .ZP0, cycleCount: 5),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 5),
        Instruction(name: "INY", operation: INY, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "CMP", operation: CMP, addressMode: .IMM, cycleCount: 2),
        Instruction(name: "DEX", operation: DEX, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "CPY", operation: CPY, addressMode: .ABS, cycleCount: 4),
        Instruction(name: "CMP", operation: CMP, addressMode: .ABS, cycleCount: 4),
        Instruction(name: "DEC", operation: DEC, addressMode: .ABS, cycleCount: 6),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 6),
        
        Instruction(name: "BNE", operation: BNE, addressMode: .REL, cycleCount: 2),
        Instruction(name: "CMP", operation: CMP, addressMode: .IZY, cycleCount: 5),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 8),
        Instruction(name: "???", operation: NOP, addressMode: .IMP, cycleCount: 4),
        Instruction(name: "CMP", operation: CMP, addressMode: .ZPX, cycleCount: 4),
        Instruction(name: "DEC", operation: DEC, addressMode: .ZPX, cycleCount: 6),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 6),
        Instruction(name: "CLD", operation: CLD, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "CMP", operation: CMP, addressMode: .ABY, cycleCount: 4),
        Instruction(name: "NOP", operation: NOP, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 7),
        Instruction(name: "???", operation: NOP, addressMode: .IMP, cycleCount: 4),
        Instruction(name: "CMP", operation: CMP, addressMode: .ABX, cycleCount: 4),
        Instruction(name: "DEC", operation: DEC, addressMode: .ABX, cycleCount: 7),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 7),
        
        Instruction(name: "CPX", operation: CPX, addressMode: .IMM, cycleCount: 2),
        Instruction(name: "SBC", operation: SBC, addressMode: .IZX, cycleCount: 6),
        Instruction(name: "???", operation: NOP, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 8),
        Instruction(name: "CPX", operation: CPX, addressMode: .ZP0, cycleCount: 3),
        Instruction(name: "SBC", operation: SBC, addressMode: .ZP0, cycleCount: 3),
        Instruction(name: "INC", operation: INC, addressMode: .ZP0, cycleCount: 5),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 5),
        Instruction(name: "INX", operation: INX, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "SBC", operation: SBC, addressMode: .IMM, cycleCount: 2),
        Instruction(name: "NOP", operation: NOP, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: SBC, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "CPX", operation: CPX, addressMode: .ABS, cycleCount: 4),
        Instruction(name: "SBC", operation: SBC, addressMode: .ABS, cycleCount: 4),
        Instruction(name: "INC", operation: INC, addressMode: .ABS, cycleCount: 6),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 6),
        
        Instruction(name: "BEQ", operation: BEQ, addressMode: .REL, cycleCount: 2),
        Instruction(name: "SBC", operation: SBC, addressMode: .IZY, cycleCount: 5),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 8),
        Instruction(name: "???", operation: NOP, addressMode: .IMP, cycleCount: 4),
        Instruction(name: "SBC", operation: SBC, addressMode: .ZPX, cycleCount: 4),
        Instruction(name: "INC", operation: INC, addressMode: .ZPX, cycleCount: 6),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 6),
        Instruction(name: "SED", operation: SED, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "SBC", operation: SBC, addressMode: .ABY, cycleCount: 4),
        Instruction(name: "NOP", operation: NOP, addressMode: .IMP, cycleCount: 2),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 7),
        Instruction(name: "???", operation: NOP, addressMode: .IMP, cycleCount: 4),
        Instruction(name: "SBC", operation: SBC, addressMode: .ABX, cycleCount: 4),
        Instruction(name: "INC", operation: INC, addressMode: .ABX, cycleCount: 7),
        Instruction(name: "???", operation: XXX, addressMode: .IMP, cycleCount: 7),
    ]
    }()
}


// MARK: - Address Modes

extension MOS6502 {
    enum AddressMode {
        /// Implied
        ///
        /// There is no additional data required for this instruction. The instruction
        /// does something very simple like like sets a status bit. However, we will
        /// target the accumulator, for instructions like PHA
        case IMP
        
        /// Immediate
        ///
        /// The instruction expects the next byte to be used as a value, so we'll prep
        /// the read address to point to the next byte
        case IMM
        
        /// Absolute
        ///
        /// A full 16-bit address is loaded and used
        case ABS
        
        /// Absolute with X Offset
        ///
        /// Fundamentally the same as absolute addressing, but the contents of the X Register
        /// is added to the supplied two byte address. If the resulting address changes
        /// the page, an additional clock cycle is required
        case ABX
        
        /// Absolute with Y Offset
        ///
        /// Fundamentally the same as absolute addressing, but the contents of the Y Register
        /// is added to the supplied two byte address. If the resulting address changes
        /// the page, an additional clock cycle is required
        case ABY
        
        /// Relative
        ///
        /// This address mode is exclusive to branch instructions. The address
        /// must reside within -128 to +127 of the branch instruction, i.e.
        /// you cant directly branch to any address in the addressable range.
        case REL
        
        /// Zero Page
        ///
        /// To save program bytes, zero page addressing allows you to absolutely address
        /// a location in first 0xFF bytes of address range. Clearly this only requires
        /// one byte instead of the usual two.
        case ZP0
        
        /// Zero Page with X Offset
        ///
        /// Fundamentally the same as Zero Page addressing, but the contents of the X Register
        /// is added to the supplied single byte address. This is useful for iterating through
        /// ranges within the first page.
        case ZPX
        
        /// Zero Page with Y Offset
        ///
        /// Fundamentally the same as Zero Page addressing, but the contents of the Y Register
        /// is added to the supplied single byte address. This is useful for iterating through
        /// ranges within the first page.
        case ZPY
        
        /// Indirect
        ///
        /// The supplied 16-bit address is read to get the actual 16-bit address. This is
        /// instruction is unusual in that it has a bug in the hardware! To emulate its
        /// function accurately, we also need to emulate this bug. If the low byte of the
        /// supplied address is 0xFF, then to read the high byte of the actual address
        /// we need to cross a page boundary. This doesnt actually work on the chip as
        /// designed, instead it wraps back around in the same page, yielding an
        /// invalid actual address
        case IND
        
        /// Indirect X
        ///
        /// The supplied 8-bit address is offset by X Register to index
        /// a location in page 0x00. The actual 16-bit address is read
        /// from this location
        case IZX
        
        /// Indirect Y
        ///
        /// The supplied 8-bit address indexes a location in page 0x00. From
        /// here the actual 16-bit address is read, and the contents of
        /// Y Register is added to it to offset it. If the offset causes a
        /// change in page then an additional clock cycle is required.
        case IZY
    }
    
    private func readAddress(using addressMode: AddressMode) -> (address: UInt16, bytesRead: UInt16, crossedPageBoundary: Bool) {
        switch addressMode {
        case .IMP:
            return (pc, 0, false)
            
        case .IMM:
            return (pc, 1, false)
            
        case .ABS:
            let lo = UInt16(bus.read(from: pc))
            let hi = UInt16(bus.read(from: pc + 1))
            let address = (hi << 8) | lo
            
            return (address, 2, false)
            
        case .ABX:
            let lo = UInt16(bus.read(from: pc))
            let hi = UInt16(bus.read(from: pc + 1))
            var address = (hi << 8) | lo
            address += UInt16(x)
            let crossedPageBoundary = (address & 0xff00) != (hi << 8)
            
            return (address, 2, crossedPageBoundary)
            
        case .ABY:
            let lo = UInt16(bus.read(from: pc))
            let hi = UInt16(bus.read(from: pc + 1))
            var address = (hi << 8) | lo
            address += UInt16(y)
            let crossedPageBoundary = (address & 0xff00) != (hi << 8)
            
            return (address, 2, crossedPageBoundary)
            
        case .REL:
            var relativeAddress = UInt16(bus.read(from: pc))
            if (relativeAddress & 0x80) > 0 {
                relativeAddress |= 0xFF00;
            }
            return (relativeAddress, 1, false)
            
        case .ZP0:
            var address = UInt16(bus.read(from: pc))
            address &= 0x00ff
            return (address, 1, false)
            
        case .ZPX:
            var address = UInt16(bus.read(from: pc + UInt16(x)))
            address &= 0x00ff
            return (address, 1, false)
            
        case .ZPY:
            var address = UInt16(bus.read(from: pc + UInt16(y)))
            address &= 0x00ff
            return (address, 1, false)
            
        case .IND:
            let ptrLo = UInt16(bus.read(from: pc))
            let ptrHi = UInt16(bus.read(from: pc + 1))
            let ptr = (ptrHi << 8) | ptrLo

            let address: UInt16
            if (ptrLo == 0x00ff) { // Simulate page boundary hardware bug.
                address = (UInt16(bus.read(from: ptr & 0xff00)) << 8) | UInt16(bus.read(from: ptr + 0))
            } else {
                address = (UInt16(bus.read(from: ptr + 1)) << 8) | UInt16(bus.read(from: ptr + 0))
            }
            
            return (address, 2, false)

        case .IZX:
            let ptr = UInt16(bus.read(from: pc))
            let lo = UInt16(bus.read(from: (ptr + UInt16(x)) & 0x00ff))
            let hi = UInt16(bus.read(from: (ptr + UInt16(x) + 1) & 0xff00))
            let address = (hi << 8) | lo
            
            return (address, 1, false)

        case .IZY:
            let ptr = UInt16(bus.read(from: pc))
            let lo = UInt16(bus.read(from: ptr & 0x00ff))
            let hi = UInt16(bus.read(from: (ptr + 1) & 0xff00))
            var address = (hi << 8) | lo
            address += UInt16(y)
            let crossedPageBoundary = (address & 0xff00) != (hi << 8)
            
            return (address, 1, crossedPageBoundary)
        }
    }
}


// MARK: - Operations

extension MOS6502 {
    
    private func ADC(_ addressMode: AddressMode) -> UInt8 {
        let (address, bytesRead, crossedPageBoundary) = readAddress(using: addressMode)

        pc += bytesRead

        let fetchedValue = bus.read(from: address)
        let temp = UInt16(a) + UInt16(fetchedValue) + UInt16(status.contains(.carry) ? 1 : 0)
        status.setOptions(.carry, enabled: temp > 255)
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0)
        status.setOptions(.resultIsOverflowed, enabled: ((~(UInt16(a) ^ UInt16(fetchedValue) & (UInt16(a) ^ UInt16(temp)))) & 0x0080) > 0)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x80) > 0)
        a = UInt8(temp & 0x00ff)
        
        return crossedPageBoundary ? 1 : 0
    }
    
    private func SBC(_ addressMode: AddressMode) -> UInt8 {
        let (address, bytesRead, crossedPageBoundary) = readAddress(using: addressMode)

        pc += bytesRead

        let fetchedValue = UInt16(bus.read(from: address))
        let temp = UInt16(a) + fetchedValue + UInt16(status.contains(.carry) ? 1 : 0)
        status.setOptions(.carry, enabled: (temp & 0xff00) > 0)
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0)
        status.setOptions(.resultIsOverflowed, enabled: ((temp ^ UInt16(a)) & (temp ^ fetchedValue) & 0x0080) > 0)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x0080) > 0)
        a = UInt8(temp & 0x00ff)

        return crossedPageBoundary ? 1 : 0
    }
    
    private func AND(_ addressMode: AddressMode) -> UInt8 {
        let (address, bytesRead, crossedPageBoundary) = readAddress(using: addressMode)

        pc += bytesRead

        let fetchedValue = bus.read(from: address)
        a = a & fetchedValue
        status.setOptions(.resultIsZero, enabled: a == 0x00)
        status.setOptions(.resultIsNegative, enabled: a == 0x80)
        
        return crossedPageBoundary ? 1 : 0
    }
    
    private func ASL(_ addressMode: AddressMode) -> UInt8 {
        let (address, bytesRead, _) = readAddress(using: addressMode)
        
        pc += bytesRead

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
        
        return 0
    }
    
    
    private func BCS(_ addressMode: AddressMode) -> UInt8 {
        guard status.contains(.carry) else { return 0 }
        return BXX(addressMode)
    }
    
    private func BCC(_ addressMode: AddressMode) -> UInt8 {
        guard !status.contains(.carry) else { return 0 }
        return BXX(addressMode)
    }
    
    private func BEQ(_ addressMode: AddressMode) -> UInt8 {
        guard status.contains(.resultIsZero) else { return 0 }
        return BXX(addressMode)
    }
    
    private func BNE(_ addressMode: AddressMode) -> UInt8 {
        guard !status.contains(.resultIsZero) else { return 0 }
        return BXX(addressMode)
    }
    
    private func BMI(_ addressMode: AddressMode) -> UInt8 {
        guard status.contains(.resultIsNegative) else { return 0 }
        return BXX(addressMode)
    }
    
    private func BPL(_ addressMode: AddressMode) -> UInt8 {
        guard !status.contains(.resultIsNegative) else { return 0 }
        return BXX(addressMode)
    }
    
    private func BVS(_ addressMode: AddressMode) -> UInt8 {
        guard status.contains(.resultIsOverflowed) else { return 0 }
        return BXX(addressMode)
    }
    
    private func BVC(_ addressMode: AddressMode) -> UInt8 {
        guard !status.contains(.resultIsOverflowed) else { return 0 }
        return BXX(addressMode)
    }
    
    private func BXX(_ addressMode: AddressMode) -> UInt8 {
        let (relativeAddress, bytesRead, _) = readAddress(using: addressMode)
        pc += bytesRead
        
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
    
    
    private func BIT(_ addressMode: AddressMode) -> UInt8 {
        let (address, bytesRead, _) = readAddress(using: addressMode)
        
        pc += bytesRead
        
        let fetchedValue = bus.read(from: address)
        let temp = a & fetchedValue
        status.setOptions(.resultIsZero, enabled: (temp & 0x00FF) == 0x00)
        status.setOptions(.resultIsNegative, enabled: (temp & (1 << 7)) > 0)
        status.setOptions(.resultIsOverflowed, enabled: (temp & (1 << 6)) > 0)
        
        return 0
    }
    
    private func BRK(_ addressMode: AddressMode) -> UInt8 {
        let (_, bytesRead, _) = readAddress(using: addressMode)

        pc += 1 + bytesRead
        
        status.setOptions(.disableInterrupts, enabled: true)
        bus.write(UInt8((pc >> 8) & 0x00FF), to: 0x0100 + UInt16(stkp))
        stkp -= 1
        bus.write(UInt8(pc & 0x00FF), to: 0x0100 + UInt16(stkp));
        stkp -= 1

        status.setOptions(.break, enabled: true)
        bus.write(status.rawValue, to: 0x0100 + UInt16(stkp))
        stkp -= 1
        status.setOptions(.break, enabled: false)

        pc = UInt16(bus.read(from: 0xfffe)) | (UInt16(bus.read(from: 0xffff)) << 8)
        
        return 0
    }
    
    
    private func CLC(_ addressMode: AddressMode) -> UInt8 {
        // We assume IMP address mode.
        status.setOptions(.carry, enabled: false)
        return 0
    }
    
    private func CLD(_ addressMode: AddressMode) -> UInt8 {
        // We assume IMP address mode.
        status.setOptions(.decimalMode, enabled: false)
        return 0
    }
    
    private func CLI(_ addressMode: AddressMode) -> UInt8 {
        // We assume IMP address mode.
        status.setOptions(.disableInterrupts, enabled: false)
        return 0
    }
    
    private func CLV(_ addressMode: AddressMode) -> UInt8 {
        // We assume IMP address mode.
        status.setOptions(.resultIsOverflowed, enabled: false)
        return 0
    }
    
    
    private func CMP(_ addressMode: AddressMode) -> UInt8 {
        let (address, bytesRead, crossedPageBoundary) = readAddress(using: addressMode)

        pc += bytesRead

        let fetchedValue = bus.read(from: address)
        let temp = UInt16(a) - UInt16(fetchedValue)
        status.setOptions(.carry, enabled: a >= fetchedValue)
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0x0000)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x0080) > 0)
        
        return crossedPageBoundary ? 1 : 0
    }
    
    private func CPX(_ addressMode: AddressMode) -> UInt8 {
        let (address, bytesRead, crossedPageBoundary) = readAddress(using: addressMode)

        pc += bytesRead

        let fetchedValue = bus.read(from: address)
        let temp = UInt16(x) - UInt16(fetchedValue)
        status.setOptions(.carry, enabled: x >= fetchedValue)
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0x0000)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x0080) > 0)
        
        return crossedPageBoundary ? 1 : 0
    }

    private func CPY(_ addressMode: AddressMode) -> UInt8 {
        let (address, bytesRead, crossedPageBoundary) = readAddress(using: addressMode)

        pc += bytesRead

        let fetchedValue = bus.read(from: address)
        let temp = UInt16(y) - UInt16(fetchedValue)
        status.setOptions(.carry, enabled: y >= fetchedValue)
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0x0000)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x0080) > 0)
        
        return crossedPageBoundary ? 1 : 0
    }
    
    
    private func DEC(_ addressMode: AddressMode) -> UInt8 {
        let (address, bytesRead, _) = readAddress(using: addressMode)

        pc += bytesRead

        let fetchedValue = bus.read(from: address)
        let temp = fetchedValue - 1
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0x0000)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x0080) > 0)
        
        return 0
    }
    
    private func DEX(_ addressMode: AddressMode) -> UInt8 {
        // We assume IMP address mode.
        x -= 1
        status.setOptions(.resultIsZero, enabled: x == 0x00)
        status.setOptions(.resultIsNegative, enabled: (x & 0x80) > 0)
        return 0
    }

    private func DEY(_ addressMode: AddressMode) -> UInt8 {
        // We assume IMP address mode.
        y -= 1
        status.setOptions(.resultIsZero, enabled: y == 0x00)
        status.setOptions(.resultIsNegative, enabled: (y & 0x80) > 0)
        return 0
    }
    
    
    private func EOR(_ addressMode: AddressMode) -> UInt8 {
        let (address, bytesRead, _) = readAddress(using: addressMode)

        pc += bytesRead

        let fetchedValue = bus.read(from: address)
        a = a ^ fetchedValue
        status.setOptions(.resultIsZero, enabled: a == 0x00)
        status.setOptions(.resultIsNegative, enabled: (a & 0x80) > 0)
        
        return 0
    }
    
    
    private func INC(_ addressMode: AddressMode) -> UInt8 {
        let (address, bytesRead, _) = readAddress(using: addressMode)

        pc += bytesRead

        let fetchedValue = bus.read(from: address)
        let temp = fetchedValue + 1
        bus.write(temp, to: address)
        status.setOptions(.resultIsZero, enabled: (temp & 0x00ff) == 0x0000)
        status.setOptions(.resultIsNegative, enabled: (temp & 0x0080) > 0)

        return 0
    }
    
    private func INX(_ addressMode: AddressMode) -> UInt8 {
        // We assume IMP address mode.
        x += 1
        status.setOptions(.resultIsZero, enabled: x == 0x00)
        status.setOptions(.resultIsNegative, enabled: (x & 0x80) > 0)
        return 0
    }

    private func INY(_ addressMode: AddressMode) -> UInt8 {
        // We assume IMP address mode.
        y += 1
        status.setOptions(.resultIsZero, enabled: y == 0x00)
        status.setOptions(.resultIsNegative, enabled: (y & 0x80) > 0)
        return 0
    }

    
    private func JMP(_ addressMode: AddressMode) -> UInt8 {
        let (address, _, _) = readAddress(using: addressMode)
        pc = address
        return 0
    }
    
    private func JSR(_ addressMode: AddressMode) -> UInt8 {
        let (address, bytesRead, _) = readAddress(using: addressMode)
        
        pc += bytesRead
        pc -= 1
        
        bus.write(UInt8((pc >> 8) & 0x00ff), to: 0x0100 + UInt16(stkp))
        stkp -= 1
        bus.write(UInt8(pc & 0x00ff), to: 0x0100 + UInt16(stkp))
        stkp -= 1
        
        pc = address
        
        return 0
    }
    
    
    private func LDA(_ addressMode: AddressMode) -> UInt8 {
        let (address, bytesRead, crossedPageBoundary) = readAddress(using: addressMode)
        
        pc += bytesRead
        
        let fetchedValue = bus.read(from: address)
        a = fetchedValue
        status.setOptions(.resultIsZero, enabled: a == 0x00)
        status.setOptions(.resultIsNegative, enabled: (a & 0x80) > 0)

        return crossedPageBoundary ? 1 : 0
    }
    
    private func LDX(_ addressMode: AddressMode) -> UInt8 {
        let (address, bytesRead, crossedPageBoundary) = readAddress(using: addressMode)
        
        pc += bytesRead
        
        let fetchedValue = bus.read(from: address)
        x = fetchedValue
        status.setOptions(.resultIsZero, enabled: x == 0x00)
        status.setOptions(.resultIsNegative, enabled: (x & 0x80) > 0)

        return crossedPageBoundary ? 1 : 0
    }

    private func LDY(_ addressMode: AddressMode) -> UInt8 {
        let (address, bytesRead, crossedPageBoundary) = readAddress(using: addressMode)
        
        pc += bytesRead
        
        let fetchedValue = bus.read(from: address)
        y = fetchedValue
        status.setOptions(.resultIsZero, enabled: y == 0x00)
        status.setOptions(.resultIsNegative, enabled: (y & 0x80) > 0)

        return crossedPageBoundary ? 1 : 0
    }
    
    
    private func LSR(_ addressMode: AddressMode) -> UInt8 {
        let (address, bytesRead, _) = readAddress(using: addressMode)
        
        pc += bytesRead

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
        
        return 0
    }
    
    private func NOP(_ addressMode: AddressMode) -> UInt8 {
        let (_, bytesRead, crossedPageBoundary) = readAddress(using: addressMode)

        pc += bytesRead
        
        switch opcode {
        case 0x1c, 0x3c, 0x5c, 0x7c, 0xdc, 0xfc:
            return crossedPageBoundary ? 1 : 0
        default:
            return 0
        }
    }
    
    private func ORA(_ addressMode: AddressMode) -> UInt8 {
        let (address, bytesRead, crossedPageBoundary) = readAddress(using: addressMode)
        
        pc += bytesRead

        let fetchedValue = bus.read(from: address)
        a = a | fetchedValue
        status.setOptions(.resultIsZero, enabled: a == 0x00)
        status.setOptions(.resultIsNegative, enabled: (a & 0x80) > 0)

        return crossedPageBoundary ? 1 : 0
    }
    
    private func PHA(_ addressMode: AddressMode) -> UInt8 {
        // We assume IMP address mode.
        bus.write(a, to: 0x0100 + UInt16(stkp))
        stkp -= 1
        return 0
    }
    
    private func PHP(_ addressMode: AddressMode) -> UInt8 {
        // We assume IMP address mode.
        status.setOptions([.break, .unused], enabled: true)
        bus.write(status.rawValue, to: 0x0100 + UInt16(stkp))
        status.setOptions([.break, .unused], enabled: false)
        stkp -= 1
        return 0
    }
    
    private func PLA(_ addressMode: AddressMode) -> UInt8 {
        // We assume IMP address mode.
        stkp += 1
        a = bus.read(from: 0x0100 + UInt16(stkp))
        status.setOptions(.resultIsZero, enabled: a == 0x00)
        status.setOptions(.resultIsNegative, enabled: (a & 0x80) > 0)
        
        return 0
    }
    
    private func PLP(_ addressMode: AddressMode) -> UInt8 {
        // We assume IMP address mode.
        stkp += 1
        status = Status(rawValue: bus.read(from: 0x0100 + UInt16(stkp)))
        status.setOptions(.unused, enabled: true)
        return 0
    }
    
    private func ROL(_ addressMode: AddressMode) -> UInt8 {
        let (address, bytesRead, _) = readAddress(using: addressMode)
        
        pc += bytesRead

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

        return 0
    }
    
    private func ROR(_ addressMode: AddressMode) -> UInt8 {
        let (address, bytesRead, _) = readAddress(using: addressMode)
        
        pc += bytesRead

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

        return 0
    }
    
    private func RTI(_ addressMode: AddressMode) -> UInt8 {
        // We assume IMP address mode.
        stkp += 1
        status = Status(rawValue: bus.read(from: 0x0100 + UInt16(stkp)))
        status.setOptions([.break, .unused], enabled: false)

        stkp += 1
        pc = UInt16(bus.read(from: 0x0100 + UInt16(stkp)))
        stkp += 1
        pc |= UInt16(bus.read(from: 0x0100 + UInt16(stkp))) << 8
        
        return 0
    }
    
    private func RTS(_ addressMode: AddressMode) -> UInt8 {
        // We assume IMP address mode.
        stkp += 1
        pc = UInt16(bus.read(from: 0x0100 + UInt16(stkp)))
        stkp += 1
        pc |= UInt16(bus.read(from: 0x0100 + UInt16(stkp))) << 8

        pc += 1
        
        return 0
    }
    
    private func SEC(_ addressMode: AddressMode) -> UInt8 {
        // We assume IMP address mode.
        status.setOptions(.carry, enabled: true)
        return 0
    }
    
    private func SED(_ addressMode: AddressMode) -> UInt8 {
        // We assume IMP address mode.
        status.setOptions(.decimalMode, enabled: true)
        return 0
    }
    
    private func SEI(_ addressMode: AddressMode) -> UInt8 {
        // We assume IMP address mode.
        status.setOptions(.disableInterrupts, enabled: true)
        return 0
    }
    
    private func STA(_ addressMode: AddressMode) -> UInt8 {
        let (address, bytesRead, _) = readAddress(using: addressMode)
        pc += bytesRead
        bus.write(a, to: address)
        return 0
    }
    
    private func STX(_ addressMode: AddressMode) -> UInt8 {
        let (address, bytesRead, _) = readAddress(using: addressMode)
        pc += bytesRead
        bus.write(x, to: address)
        return 0
    }
    
    private func STY(_ addressMode: AddressMode) -> UInt8 {
        let (address, bytesRead, _) = readAddress(using: addressMode)
        pc += bytesRead
        bus.write(y, to: address)
        return 0
    }
    
    private func TAX(_ addressMode: AddressMode) -> UInt8 {
        // We assume IMP address mode.
        x = a
        status.setOptions(.resultIsZero, enabled: x == 0x00)
        status.setOptions(.resultIsNegative, enabled: (x & 0x80) > 0)
        return 0
    }
    
    private func TAY(_ addressMode: AddressMode) -> UInt8 {
        // We assume IMP address mode.
        y = a
        status.setOptions(.resultIsZero, enabled: y == 0x00)
        status.setOptions(.resultIsNegative, enabled: (y & 0x80) > 0)
        return 0
    }
    
    private func TSX(_ addressMode: AddressMode) -> UInt8 {
        // We assume IMP address mode.
        x = stkp
        status.setOptions(.resultIsZero, enabled: y == 0x00)
        status.setOptions(.resultIsNegative, enabled: (y & 0x80) > 0)
        return 0
    }
    
    private func TXA(_ addressMode: AddressMode) -> UInt8 {
        // We assume IMP address mode.
        a = x
        status.setOptions(.resultIsZero, enabled: y == 0x00)
        status.setOptions(.resultIsNegative, enabled: (y & 0x80) > 0)
        return 0
    }
    
    private func TYA(_ addressMode: AddressMode) -> UInt8 {
        // We assume IMP address mode.
        a = y
        status.setOptions(.resultIsZero, enabled: a == 0x00)
        status.setOptions(.resultIsNegative, enabled: (a & 0x80) > 0)
        return 0
    }
    
    private func TXS(_ addressMode: AddressMode) -> UInt8 {
        // We assume IMP address mode.
        stkp = x
        return 0
    }
    
    private func XXX(_ addressMode: AddressMode) -> UInt8 {
        return 0
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
