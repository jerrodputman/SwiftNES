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
public final class NES {
    
    // MARK: - Initializers

    /// Creates a virtual NES.
    public init() {
        ppuCartridgeConnector = CartridgeConnector(addressRange: 0x0000...0x1fff)
        nameTable = try! RandomAccessMemoryDevice(memorySize: 0x0800, addressRange: 0x2000...0x3eff)
        palette = try! RandomAccessMemoryDevice(memorySize: 0x20, addressRange: 0x3f00...0x3fff)
        let ppuBus = Bus(addressableDevices: [ppuCartridgeConnector, nameTable, palette])
        ppu = PixelProcessingUnit(bus: ppuBus)
        
        ram = try! RandomAccessMemoryDevice(memorySize: 0x0800, addressRange: 0x0000...0x1fff)
        cpuCartridgeConnector = CartridgeConnector(addressRange: 0x8000...0xffff)
        let cpuBus = Bus(addressableDevices: [ram, ppu, cpuCartridgeConnector])
        cpu = RP2A03G(bus: cpuBus)
    }

    
    // MARK: - The internal hardware of the NES
    
    /// The CPU.
    let cpu: RP2A03G
    
    /// The CPU's RAM.
    let ram: RandomAccessMemoryDevice
    
    /// Connects a cartridge to the CPU bus.
    let cpuCartridgeConnector: CartridgeConnector
    
    /// The PPU.
    let ppu: PixelProcessingUnit
    
    /// Connects a cartridge to the PPU bus.
    let ppuCartridgeConnector: CartridgeConnector

    /// The background "name table" memory.
    let nameTable: RandomAccessMemoryDevice
    
    /// The palette memory.
    let palette: RandomAccessMemoryDevice
    
    
    // MARK: - Connecting to the inputs of the hardware
    
    /// The cartridge, if it exists.
    public var cartridge: Cartridge? = nil {
        didSet {
            cpuCartridgeConnector.cartridge = cartridge
            ppuCartridgeConnector.cartridge = cartridge
            ppu.mirroringMode = cartridge?.mirroringMode ?? .horizontal
        }
    }
    
    
    // MARK: - Connecting to the outputs of the hardware
    
    public weak var videoReceiver: VideoReceiver? {
        didSet {
            ppu.videoReceiver = videoReceiver
        }
    }
    
    public weak var audioReceiver: AudioReceiver?
    
    
    // MARK: - Updating the hardware

    /// Updates the hardware with the specified elapsed time.
    ///
    /// - parameter elapsedTime: The elapsed time since the last update.
    public func update(elapsedTime: TimeInterval) {
        if residualTime > 0.0 {
            residualTime -= elapsedTime
        } else {
            residualTime += (1.0 / 60.0) - elapsedTime
            repeat { clock() } while !ppu.isFrameComplete
        }
    }
    
    /// Advances the hardware to the end of the current instruction.
    public func advanceInstruction() {
        repeat { clock() } while !cpu.core.isCurrentInstructionComplete
        
        // The CPU is clocked slower than the PPU, so clock the hardware
        // until the next instruction starts.
        repeat { clock() } while cpu.core.isCurrentInstructionComplete
    }
    
    /// Advances the hardware to the end of the current frame.
    public func advanceFrame() {
        repeat { clock() } while !ppu.isFrameComplete
        
        // Finish executing the current instruction.
        repeat { clock() } while !cpu.core.isCurrentInstructionComplete
    }
    
    /// Resets the hardware.
    public func reset() {
        clockCount = 0
        residualTime = 0.0
        
        let videoOutputParams = VideoOutputParameters(resolution: (width: 256, height: 240))
        videoReceiver?.setVideoOutputParameters(videoOutputParams)
        
        cpu.core.reset()
    }
    

    // MARK: - Private
    
    /// The total clock count since the hardware was reset.
    private var clockCount: UInt32 = 0
    
    /// The remaining residual time since the last update.
    private var residualTime: TimeInterval = 0


    /// Clocks the hardware.
    private func clock() {
        ppu.clock()
        
        if clockCount % 3 == 0 {
            cpu.core.clock()
        }
        
        if ppu.nmi {
            cpu.core.nmi()
        }
        
        clockCount += 1
    }
}
