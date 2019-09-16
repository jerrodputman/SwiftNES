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

/// A class that represents the complete NES hardware.
final class NES {
    
    // MARK: - Initializers

    /// Creates a virtual NES.
    public init() {
        ppuCartridgeConnector = CartridgeConnector(addressRange: 0x0000...0x1fff)
        let ppuBus = Bus(addressableDevices: [ppuCartridgeConnector])
        ppu = PixelProcessingUnit(bus: ppuBus)
        
        ram = try! RandomAccessMemoryDevice(memorySize: 0x0800, addressRange: 0x0000...0x1fff)
        cpuCartridgeConnector = CartridgeConnector(addressRange: 0x8000...0xffff)
        let cpuBus = Bus(addressableDevices: [ram, ppu, cpuCartridgeConnector])
        cpu = MOS6502(bus: cpuBus)
    }

    
    // MARK: - The internal hardware of the NES
    
    /// The CPU.
    let cpu: MOS6502
    
    /// The CPU's RAM.
    let ram: RandomAccessMemoryDevice
    
    /// Connects a cartridge to the CPU bus.
    let cpuCartridgeConnector: CartridgeConnector
    
    /// The PPU.
    let ppu: PixelProcessingUnit
    
    /// Connects a cartridge to the PPU bus.
    let ppuCartridgeConnector: CartridgeConnector

    /// The cartridge, if it exists.
    public var cartridge: Cartridge? = nil {
        didSet {
            cpuCartridgeConnector.cartridge = cartridge
            ppuCartridgeConnector.cartridge = cartridge
        }
    }
    
    
    // MARK: - Updating the hardware

    public func advanceFrame() {
        repeat {
            clock()
        } while !ppu.isFrameComplete
    }
    
    public func reset() {
        cpu.reset()
    }
    
    func clock() {
        ppu.clock()
        
        if clockCount % 3 == 0 {
            cpu.clock()
        }
        
        clockCount += 1
    }
    

    // MARK: - Private
    
    private var clockCount: UInt32 = 0
}
