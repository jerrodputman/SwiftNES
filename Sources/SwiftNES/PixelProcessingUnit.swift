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

final class PixelProcessingUnit: AddressableReadWriteDevice {
    
    // MARK: - Initializers
    
    init(bus: Bus) {
        self.bus = bus
    }
    
    
    // MARK: - Registers
    
    struct Control: OptionSet {
        var rawValue: Value
        
        static let nametableX = Control(rawValue: (1 << 0))
        static let nametableY = Control(rawValue: (1 << 1))
        static let yIncrementMode = Control(rawValue: (1 << 2))
        static let patternSprite = Control(rawValue: (1 << 3))
        static let patternBackground = Control(rawValue: (1 << 4))
        static let spriteSize = Control(rawValue: (1 << 5))
        static let slaveMode = Control(rawValue: (1 << 6))
        static let enableNmi = Control(rawValue: (1 << 7))
    }
    
    struct Status: OptionSet {
        var rawValue: Value
        
        static let spriteOverflow = Status(rawValue: (1 << 5))
        static let spriteZeroHit = Status(rawValue: (1 << 6))
        static let verticalBlank = Status(rawValue: (1 << 7))
    }
    
    struct Mask: OptionSet {
        var rawValue: Value
        
        static let grayscale = Mask(rawValue: (1 << 0))
        static let renderBackgroundLeft = Mask(rawValue: (1 << 1))
        static let renderSpritesLeft = Mask(rawValue: (1 << 2))
        static let renderBackground = Mask(rawValue: (1 << 3))
        static let renderSprites = Mask(rawValue: (1 << 4))
        static let enhanceRed = Mask(rawValue: (1 << 5))
        static let enhanceGreen = Mask(rawValue: (1 << 6))
        static let enhanceBlue = Mask(rawValue: (1 << 7))
    }
    
    private(set) var control: Control = Control(rawValue: 0)
    private(set) var status: Status = Status(rawValue: 0)
    private(set) var mask: Mask = Mask(rawValue: 0)
    
    var mirroringMode: Cartridge.MirroringMode = .horizontal

    var nmi: Bool {
        get {
            defer { _nmi = false }
            return _nmi
        }
        set {
            _nmi = newValue
        }
    }
    
    private var _nmi = false
    
    
    // MARK: - Outputting video
    
    weak var videoReceiver: VideoReceiver?
    
    
    // MARK: - External events
    
    func clock() {

        func incrementScrollX() {
            guard mask.contains(.renderBackground) || mask.contains(.renderSprites) else { return }
            
            if vramAddress.coarseX == 31 {
                vramAddress.coarseX = 0
                vramAddress.nametableX = ~vramAddress.nametableX
            } else {
                vramAddress.coarseX += 1
            }
        }
        
        func incrementScrollY() {
            guard mask.contains(.renderBackground) || mask.contains(.renderSprites) else { return }
            
            if vramAddress.fineY < 7 {
                vramAddress.fineY += 1
            } else {
                vramAddress.fineY = 0
                if vramAddress.coarseY == 29 {
                    vramAddress.coarseY = 0
                    vramAddress.nametableY = ~vramAddress.nametableY
                } else if vramAddress.coarseY == 31 {
                    vramAddress.coarseY = 0
                } else {
                    vramAddress.coarseY += 1
                }
            }
        }
        
        func transferAddressX() {
            guard mask.contains(.renderBackground) || mask.contains(.renderSprites) else { return }

            vramAddress.nametableX = tramAddress.nametableX
            vramAddress.coarseX = tramAddress.coarseX
        }
        
        func transferAddressY() {
            guard mask.contains(.renderBackground) || mask.contains(.renderSprites) else { return }

            vramAddress.fineY = tramAddress.fineY
            vramAddress.nametableY = tramAddress.nametableY
            vramAddress.coarseY = tramAddress.coarseY
        }
        
        func loadBackgroundShifters() {
            bgShiftPatternLo = (bgShiftPatternLo & 0xff00) | UInt16(bgNextTileLSB)
            bgShiftPatternHi = (bgShiftPatternHi & 0xff00) | UInt16(bgNextTileMSB)
            bgShiftAttributeLo = (bgShiftAttributeLo & 0xff00) | ((bgNextTileAttribute & 0b01) > 0 ? 0xff : 0x00)
            bgShiftAttributeHi = (bgShiftAttributeHi & 0xff00) | ((bgNextTileAttribute & 0b10) > 0 ? 0xff : 0x00)
        }
        
        func updateShifters() {
            guard mask.contains(.renderBackground) else { return }
            
            bgShiftPatternLo <<= 1
            bgShiftPatternHi <<= 1
            bgShiftAttributeLo <<= 1
            bgShiftAttributeHi <<= 1
        }
        
        switch scanline {
        case -1..<240:
            if scanline == 0 && cycle == 0 {
                cycle = 1
            }
            
            if scanline == -1 && cycle == 1 {
                // This is the start of a new frame, so clear the vertical blank flag.
                status.remove(.verticalBlank)
            }
            
            if (cycle >= 2 && cycle < 258) || (cycle >= 321 && cycle < 338) {
                updateShifters()
                
                switch (cycle - 1) % 8 {
                case 0:
                    loadBackgroundShifters()
                    
                    let address = 0x2000 | (vramAddress.rawValue & 0x0fff)
                    bgNextTileId = bus.read(from: mirroredAddress(address))
                    
                case 2:
                    let address = 0x23c0 | (vramAddress.nametableY << 11) | (vramAddress.nametableX << 10) | ((vramAddress.coarseY >> 2) << 3) | (vramAddress.coarseX >> 2)
                    bgNextTileAttribute = bus.read(from: mirroredAddress(address))
                    if (vramAddress.coarseY & 0x02) > 0 { bgNextTileAttribute >>= 4 }
                    if (vramAddress.coarseX & 0x02) > 0 { bgNextTileAttribute >>= 2 }
                    bgNextTileAttribute &= 0x03
                    
                case 4:
                    let address = ((control.contains(.patternBackground) ? 1 : 0) << 12) + (UInt16(bgNextTileId) << 4) + vramAddress.fineY + 0
                    bgNextTileLSB = bus.read(from: mirroredAddress(address))

                case 6:
                    let address = ((control.contains(.patternBackground) ? 1 : 0) << 12) + (UInt16(bgNextTileId) << 4) + vramAddress.fineY + 8
                    bgNextTileMSB = bus.read(from: mirroredAddress(address))

                case 7:
                    incrementScrollX()

                default:
                    break
                }
            }
            
            if cycle == 256 {
                incrementScrollY()
            }
            
            if cycle == 257 {
                loadBackgroundShifters()
                transferAddressX()
            }
            
            if cycle == 338 || cycle == 340 {
                let address = 0x2000 | (vramAddress.rawValue & 0x0fff)
                bgNextTileId = bus.read(from: mirroredAddress(address))
            }
            
            if scanline == -1 && cycle >= 280 && cycle < 305 {
                transferAddressY()
            }
            
        case 241..<261:
            if scanline == 241 && cycle == 1 {
                status.insert(.verticalBlank)
                
                if control.contains(.enableNmi) {
                    nmi = true
                }
            }
            

        default:
            break
        }
        
        
        var bgPalette: UInt8 = 0
        var bgPixel: UInt8 = 0
        
        if mask.contains(.renderBackground) {
            let bitMux: UInt16 = 0x8000 >> fineX
            
            let pixelLo: UInt8 = (bgShiftPatternLo & bitMux) > 0 ? 1 : 0
            let pixelHi: UInt8 = (bgShiftPatternHi & bitMux) > 0 ? 1 : 0
            bgPixel = (pixelHi << 1) | pixelLo

            let paletteLo: UInt8 = (bgShiftAttributeLo & bitMux) > 0 ? 1 : 0
            let paletteHi: UInt8 = (bgShiftAttributeHi & bitMux) > 0 ? 1 : 0
            bgPalette = (paletteHi << 1) | paletteLo
        }
        
        videoReceiver?.setPixel(atX: Int(cycle - 1), y: Int(scanline), withColor: color(fromPalette: bgPalette, index: bgPixel).rawValue)
        
        isFrameComplete = false
        cycle = Self.cycleRange.index(after: cycle)
        
        if !Self.cycleRange.contains(cycle) {
            cycle = Self.cycleRange.lowerBound
            scanline = Self.scanlineRange.index(after: scanline)
            
            if !Self.scanlineRange.contains(scanline) {
                scanline = Self.scanlineRange.lowerBound
                isFrameComplete = true
            }
        }
    }
    
    private(set) var isFrameComplete: Bool = false
    
    
    // MARK: - AddressableReadWriteDevice
    
    func respondsTo(_ address: Address) -> Bool {
        return Self.addressRange.contains(address)
    }
    
    func read(from address: Address) -> Value {
        guard let addressIndex = Self.addressRange.firstIndex(of: address) else { return 0 }
        
        let distance = Self.addressRange.distance(from: Self.addressRange.startIndex, to: addressIndex)
        
        guard let register = Register(rawValue: distance) else { return 0 }
        
        switch register {
        case .control:
            break
        case .mask:
            break
        case .status:
            // Only the first 3 bits are read from the `status` register, and the
            // remaining bits are filled with noise, likely from the last data
            // that was stored in the data buffer.
            let data = (status.rawValue & 0xe0) | (ppuDataBuffer & 0x1f)
            
            // Reading from the status register clears the `verticalBlank` flag.
            status.remove(.verticalBlank)
            
            // Reading from the status register also resets the `ppuAddressLatch`.
            ppuAddressLatch = .high
            
            return data
            
        case .oamAddress:
            break
        case .oamData:
            break
        case .scroll:
            break
        case .ppuAddress:
            // Cannot be read from.
            break
        case .ppuData:
            // Reading data from the PPU is delayed by one cycle.
            // Grab the previously stored value from the buffer and return it
            // while reading the data.
            var data = ppuDataBuffer
            ppuDataBuffer = bus.read(from: mirroredAddress(vramAddress.rawValue))
            
            // Except for palette data, which is returned immediately.
            if (0x3f00...0x3fff).contains(vramAddress.rawValue) {
                data = ppuDataBuffer
            }
            
            // Automatically increment the address based on the increment mode.
            vramAddress.rawValue += control.contains(.yIncrementMode) ? 32 : 1
            
            return data
        }
        
        return 0
    }
    
    func write(_ value: Value, to address: Address) {
        guard let addressIndex = Self.addressRange.firstIndex(of: address) else { return }

        let distance = Self.addressRange.distance(from: Self.addressRange.startIndex, to: addressIndex)
        
        guard let register = Register(rawValue: distance) else { return }
        
        switch register {
        case .control:
            control.rawValue = value
            tramAddress.nametableX = control.contains(.nametableX) ? 1 : 0
            tramAddress.nametableY = control.contains(.nametableY) ? 1 : 0
        case .mask:
            mask.rawValue = value
        case .status:
            // Cannot be written to.
            break
        case .oamAddress:
            break
        case .oamData:
            break
        case .scroll:
            switch ppuAddressLatch {
            case .high:
                fineX = value & 0x07
                tramAddress.coarseX = UInt16(value) >> 3
                ppuAddressLatch = .low
            case .low:
                tramAddress.fineY = UInt16(value) & 0x07
                tramAddress.coarseY = UInt16(value) >> 3
                ppuAddressLatch = .high
            }
            break
        case .ppuAddress:
            switch ppuAddressLatch {
            case .high:
                tramAddress.rawValue = (tramAddress.rawValue & 0x00ff) | (Address(value & 0x3f) << 8)
                ppuAddressLatch = .low
            case .low:
                tramAddress.rawValue = (tramAddress.rawValue & 0xff00) | Address(value)
                vramAddress = tramAddress
                ppuAddressLatch = .high
            }
        case .ppuData:
            bus.write(value, to: mirroredAddress(vramAddress.rawValue))
            vramAddress.rawValue += control.contains(.yIncrementMode) ? 32 : 1
        }
    }
    
    
    // MARK: - Private
    
    private enum Register: Int {
        case control
        case mask
        case status
        case oamAddress
        case oamData
        case scroll
        case ppuAddress
        case ppuData
    }
    
    private let bus: Bus
    
    private var cycle: Int16 = 0
    private var scanline: Int16 = 0
    
    enum AddressLatch {
        case high
        case low
    }
    
    private var ppuAddressLatch: AddressLatch = .high
    private var ppuDataBuffer: Value = 0
    private var ppuAddress: Address = 0x0
    
    private struct Loopy {
        var rawValue: Address
        
        var coarseX: UInt16 {
            get { return rawValue & 0x1f }
            set { rawValue = (rawValue & 0xffe0) | (newValue & 0x1f)  }
        }
        
        var coarseY: UInt16 {
            get { return (rawValue & 0x3e0) >> 5 }
            set { rawValue = (rawValue & 0xfc1f) | ((newValue << 5) & 0x3e0) }
        }
        
        var nametableX: UInt16 {
            get { return (rawValue & 0x400) > 0 ? 1 : 0 }
            set { rawValue = (rawValue & 0xfbff) | (newValue > 0 ? 0x400 : 0x000) }
        }
        
        var nametableY: UInt16 {
            get { return (rawValue & 0x800) > 0 ? 1 : 0 }
            set { rawValue = (rawValue & 0xf7ff) | (newValue > 0 ? 0x800 : 0x000) }
        }
        
        var fineY: UInt16 {
            get { return (rawValue & 0x7000) >> 12 }
            set { rawValue = (rawValue & 0x8fff) | ((newValue << 12) & 0x7000) }
        }
    }
    
    private var vramAddress: Loopy = Loopy(rawValue: 0)
    private var tramAddress: Loopy = Loopy(rawValue: 0)
    private var fineX: UInt8 = 0
    
    private var bgNextTileId: UInt8 = 0
    private var bgNextTileAttribute: UInt8 = 0
    private var bgNextTileLSB: UInt8 = 0
    private var bgNextTileMSB: UInt8 = 0
    
    private var bgShiftPatternLo: UInt16 = 0
    private var bgShiftPatternHi: UInt16 = 0
    private var bgShiftAttributeLo: UInt16 = 0
    private var bgShiftAttributeHi: UInt16 = 0
    
    private static let addressRange: AddressRange = 0x2000...0x3fff
    private static let cycleRange: Range<Int16> = 0..<341
    private static let scanlineRange: Range<Int16> = -1..<261
    
    
    private func mirroredAddress(_ address: Address) -> Address {
        switch address {
        case 0x2000...0x3eff:
            switch mirroringMode {
            case .horizontal:
                switch address {
                case 0x2000...0x23ff, 0x2400...0x27ff:
                    return 0x2000 | (address & 0x03ff)
                case 0x2800...0x2bff, 0x2c00...0x2fff:
                    return 0x2400 | (address & 0x03ff)
                default:
                    return address
                }
                
            case .vertical:
                switch address {
                case 0x2000...0x23ff, 0x2800...0x2bff:
                    return 0x2000 | (address & 0x03ff)
                case 0x2400...0x27ff, 0x2c00...0x2fff:
                    return 0x2800 | (address & 0x0fff)
                default:
                    return address
                }
            }
            
        case 0x3f00...0x3fff:
            var address = address
            address &= 0xff1f
            if address == 0x3f10 { address = 0x3f00 }
            if address == 0x3f14 { address = 0x3f04 }
            if address == 0x3f18 { address = 0x3f08 }
            if address == 0x3f1c { address = 0x3f0c }
            return address
            
        default:
            return address
        }
    }
    
    private func patternTable(at index: UInt8, palette: UInt8) -> [Color] {
        
        var patternTable: [Color] = .init(repeating: Color(0, 0, 0), count: 128 * 128)
        
        for tileY: Int in 0..<16 {
            for tileX: Int in 0..<16 {
                let byteOffset = UInt16(tileY) * 256 + UInt16(tileX) * 16
                
                for row: Int in 0..<8 {
                    var tileLSB = bus.read(from: UInt16(index) * 0x1000 + byteOffset + UInt16(row) + 0)
                    var tileMSB = bus.read(from: UInt16(index) * 0x1000 + byteOffset + UInt16(row) + 8)
                    
                    for column: Int in 0..<8 {
                        let pixel = (tileLSB & 0x01) + (tileMSB & 0x01)
                        tileLSB >>= 1
                        tileMSB >>= 1
                        
                        patternTable[(tileY * 8 + row) * 128 + (tileX * 8 + (7 - column))] = color(fromPalette: palette, index: pixel)
                    }
                }
            }
        }
        
        return patternTable
    }
    
    private func color(fromPalette palette: UInt8, index: UInt8) -> Color {
        let address = 0x3f00 + (UInt16(palette) << 2) + UInt16(index)
        let colorIndex = Int(bus.read(from: mirroredAddress(address)) & 0x3f)
        
        return Self.colors[colorIndex]
    }
}
 
extension PixelProcessingUnit {
    private struct Color {
        let rawValue: UInt32
        
        init(_ r: UInt8, _ g: UInt8, _ b: UInt8) {
            rawValue = (0xff << 24) + (UInt32(r) << 16) + (UInt32(g) << 8) + UInt32(b)
        }
    }

    private static let colors: [Color] = [Color(84, 84, 84), // 0x0
                                          Color(0, 30, 116),
                                          Color(8, 16, 144),
                                          Color(48, 0, 136),
                                          Color(68, 0, 100),
                                          Color(92, 0, 48),
                                          Color(84, 4, 0),
                                          Color(60, 24, 0),
                                          Color(32, 42, 0),
                                          Color(8, 58, 0),
                                          Color(0, 64, 0),
                                          Color(0, 60, 0),
                                          Color(0, 50, 60),
                                          Color(0, 0, 0),
                                          Color(0, 0, 0),
                                          Color(0, 0, 0),

                                          Color(152, 150, 152), // 0x10
                                          Color(8, 76, 196),
                                          Color(48, 50, 236),
                                          Color(92, 30, 228),
                                          Color(136, 20, 176),
                                          Color(160, 20, 100),
                                          Color(152, 34, 32),
                                          Color(120, 60, 0),
                                          Color(84, 90, 0),
                                          Color(40, 114, 0),
                                          Color(8, 124, 0),
                                          Color(0, 118, 40),
                                          Color(0, 102, 120),
                                          Color(0, 0, 0),
                                          Color(0, 0, 0),
                                          Color(0, 0, 0),

                                          Color(236, 238, 236), // 0x20
                                          Color(76, 154, 236),
                                          Color(120, 124, 236),
                                          Color(176, 98, 236),
                                          Color(228, 84, 236),
                                          Color(236, 88, 180),
                                          Color(236, 106, 100),
                                          Color(212, 136, 32),
                                          Color(160, 170, 0),
                                          Color(116, 196, 0),
                                          Color(76, 208, 32),
                                          Color(56, 204, 108),
                                          Color(56, 180, 204),
                                          Color(60, 60, 60),
                                          Color(0, 0, 0),
                                          Color(0, 0, 0),

                                          Color(236, 238, 236), // 0x30
                                          Color(168, 204, 236),
                                          Color(188, 188, 236),
                                          Color(212, 178, 236),
                                          Color(236, 174, 236),
                                          Color(236, 174, 212),
                                          Color(236, 180, 176),
                                          Color(228, 196, 144),
                                          Color(204, 210, 120),
                                          Color(180, 222, 120),
                                          Color(168, 226, 144),
                                          Color(152, 226, 180),
                                          Color(160, 214, 228),
                                          Color(160, 162, 160),
                                          Color(0, 0, 0),
                                          Color(0, 0, 0)]
}
