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

/// A class that emulates the behavior of the 2C02 pixel processing unit.
final class PixelProcessingUnit: AddressableDevice {
    
    // MARK: - Initializers
    
    /// Creates a virtual PPU with the specified bus.
    ///
    /// - parameter bus: The bus that the PPU should use to communicate with other devices.
    init(bus: Bus) {
        self.bus = bus
        self.objectAttributeMemory = Array(repeating: ObjectAttributeEntry(y: 0, tileId: 0, attribute: 0, x: 0), count: 64)
        
        scanlineSprites.reserveCapacity(8)
        spriteShifterPatternLo.reserveCapacity(8)
        spriteShifterPatternHi.reserveCapacity(8)
    }
    
    
    // MARK: - Registers
    
    /// An option set for the graphics control register.
    struct Control: OptionSet {
        var rawValue: Value
        
        static let nametableX = Control(rawValue: (1 << 0))
        static let nametableY = Control(rawValue: (1 << 1))
        static let yIncrementMode = Control(rawValue: (1 << 2))
        static let patternSprite = Control(rawValue: (1 << 3))
        static let patternBackground = Control(rawValue: (1 << 4))
        static let doubleSpriteHeight = Control(rawValue: (1 << 5))
        static let slaveMode = Control(rawValue: (1 << 6))
        static let enableNmi = Control(rawValue: (1 << 7))
    }
    
    /// An option set for the status report register.
    struct Status: OptionSet {
        var rawValue: Value
        
        static let spriteOverflow = Status(rawValue: (1 << 5))
        static let spriteZeroHit = Status(rawValue: (1 << 6))
        static let verticalBlank = Status(rawValue: (1 << 7))
    }
    
    /// An option set for the mask register.
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
    
    
    /// The graphics control register.
    private(set) var control: Control = Control(rawValue: 0)
    
    /// The status report register.
    private(set) var status: Status = Status(rawValue: 0)
    
    /// The mask register.
    private(set) var mask: Mask = Mask(rawValue: 0)
    
    /// The OAM address register.
    private(set) var oamAddress: UInt8 = 0
    
    
    /// The object attribute memory (OAM).
    private(set) var objectAttributeMemory: [ObjectAttributeEntry]
    
    
    var mirroringMode: Cartridge.MirroringMode = .horizontal

    /// Whether or not the non-maskable interrupt is triggered.
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
    
    /// The receiver of the video output.
    weak var videoReceiver: VideoReceiver?
    
    
    // MARK: - External events
    
    /// Performs a single cycle of work on the PPU.
    func clock() {

        func incrementScrollX() {
            guard mask.contains(.renderBackground)
                || mask.contains(.renderSprites) else { return }
            
            if vramAddress.coarseX == 31 {
                vramAddress.coarseX = 0
                vramAddress.nametableX = vramAddress.nametableX == 0 ? 1 : 0
            } else {
                vramAddress.coarseX += 1
            }
        }
        
        func incrementScrollY() {
            guard mask.contains(.renderBackground)
                || mask.contains(.renderSprites) else { return }
            
            if vramAddress.fineY < 7 {
                vramAddress.fineY += 1
            } else {
                vramAddress.fineY = 0
                if vramAddress.coarseY == 29 {
                    vramAddress.coarseY = 0
                    vramAddress.nametableY = vramAddress.nametableY == 0 ? 1 : 0
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
            if mask.contains(.renderBackground) {
                bgShiftPatternLo <<= 1
                bgShiftPatternHi <<= 1
                bgShiftAttributeLo <<= 1
                bgShiftAttributeHi <<= 1
            }
            
            if mask.contains(.renderSprites) && cycle >= 1 && cycle < 258 {
                for scanlineSpriteIndex in 0..<scanlineSprites.count {
                    if scanlineSprites[scanlineSpriteIndex].x > 0 {
                        scanlineSprites[scanlineSpriteIndex].x -= 1
                    } else {
                        spriteShifterPatternLo[scanlineSpriteIndex] = spriteShifterPatternLo[scanlineSpriteIndex] << 1
                        spriteShifterPatternHi[scanlineSpriteIndex] = spriteShifterPatternHi[scanlineSpriteIndex] << 1
                    }
                }
            }
        }
        
        if scanline == -1
            && cycle == 1 {
            // This is the start of a new frame, so clear the vertical blank,
            // sprite zero hit, and sprite overflow flags.
            status.remove(.verticalBlank)
            status.remove(.spriteZeroHit)
            status.remove(.spriteOverflow)
            
            spriteShifterPatternLo = Array(repeating: 0, count: 8)
            spriteShifterPatternHi = Array(repeating: 0, count: 8)
        }
        
        if scanline == -1
            && cycle >= 280
            && cycle < 305 {
            transferAddressY()
        }
        
        if scanline == 0
            && cycle == 0 {
            cycle = 1
        }
        
        if (-1..<240).contains(scanline) {
            // Background rendering.
            if (2..<258).contains(cycle)
                || (321..<338).contains(cycle) {
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
            
            if cycle == 338
                || cycle == 340 {
                let address = Self.nametableAddressRange.lowerBound | (vramAddress.rawValue & 0x0fff)
                bgNextTileId = bus.read(from: mirroredAddress(address))
            }
            
            
            // Sprite rendering.
            if cycle == 257 && scanline >= 0 {
                // Reset list of sprites on this scanline.
                scanlineSprites.removeAll(keepingCapacity: true)
                
                // Reset sprite zero hit flag.
                spriteZeroHitPossible = false
                
                // Loop through each entry in the OAM.
                for (index, entry) in objectAttributeMemory.enumerated() {
                    let diff: Int16 = (Int16(scanline) - Int16(entry.y))
                    
                    // Check if the sprite is within this scanline.
                    if diff >= 0 && diff < (control.contains(.doubleSpriteHeight) ? 16 : 8) {
                        // If we haven't added the maximum number of sprites to our `scanlineSprites` array,
                        // then add the entry to the list of sprites for this scanline. Otherwise, set
                        // the `.spriteOverflow` status flag.
                        if scanlineSprites.count < 8 {
                            scanlineSprites.append(entry)

                            // If this is sprite zero, then mark that sprite-0 hit is possible.
                            if index == 0 {
                                spriteZeroHitPossible = true
                            }
                        } else {
                            status.insert(.spriteOverflow)
                            break
                        }
                    }
                }
            }
            
            if cycle == 340 {
                // Reset sprite shifters on this scanline.
                spriteShifterPatternLo = Array(repeating: 0, count: 8)
                spriteShifterPatternHi = Array(repeating: 0, count: 8)

                for (index, entry) in scanlineSprites.enumerated() {
                    let spritePatternAddressLo, spritePatternAddressHi: UInt16
                    var spritePatternBitsLo, spritePatternBitsHi: UInt8
                    
                    if !control.contains(.doubleSpriteHeight) {
                        // 8-pixel high sprites.
                        if (entry.attribute & 0x80) == 0 {
                            // Sprite NOT flipped vertically.
                            spritePatternAddressLo = (UInt16(control.contains(.patternSprite) ? 1 : 0) << 12)
                                | (UInt16(entry.tileId) << 4)
                                | UInt16(bitPattern: scanline - Int16(entry.y))
                        } else {
                            // Sprite flipped vertically.
                            spritePatternAddressLo = (UInt16(control.contains(.patternSprite) ? 1 : 0) << 12)
                                | (UInt16(entry.tileId) << 4)
                                | (7 &- UInt16(bitPattern: scanline - Int16(entry.y)))
                        }
                    } else {
                        // 16-pixel high sprites.
                        if (entry.attribute & 0x80) == 0 {
                            // Sprite NOT flipped vertically.
                            if scanline - Int16(entry.y) < 8 {
                                // Top 8 rows of the sprite.
                                spritePatternAddressLo = ((UInt16(entry.tileId) & 0x01) << 12)
                                | ((UInt16(entry.tileId) & 0xfe) << 4)
                                | ((UInt16(bitPattern: scanline - Int16(entry.y))) & 0x07)
                            } else {
                                // Bottom 8 rows of the sprite.
                                spritePatternAddressLo = ((UInt16(entry.tileId) & 0x01) << 12)
                                | (((UInt16(entry.tileId) & 0xfe) + 1) << 4)
                                | ((UInt16(bitPattern: scanline - Int16(entry.y))) & 0x07)
                            }
                        } else {
                            // Sprite flipped vertically.
                            if scanline - Int16(entry.y) < 8 {
                                // Top 8 rows of the sprite.
                                spritePatternAddressLo = ((UInt16(entry.tileId) & 0x01) << 12)
                                | ((UInt16(entry.tileId) & 0xfe) << 4)
                                | (7 &- ((UInt16(bitPattern: scanline - Int16(entry.y))) & 0x07))
                            } else {
                                // Bottom 8 rows of the sprite.
                                spritePatternAddressLo = ((UInt16(entry.tileId) & 0x01) << 12)
                                | (((UInt16(entry.tileId) & 0xfe) + 1) << 4)
                                | (7 &- ((UInt16(bitPattern: scanline - Int16(entry.y))) & 0x07))
                            }
                        }
                    }
                    
                    // The pattern address for the high bitplane.
                    spritePatternAddressHi = spritePatternAddressLo + 8
                    
                    // Get the bits of the low and high bitplanes.
                    spritePatternBitsLo = bus.read(from: spritePatternAddressLo)
                    spritePatternBitsHi = bus.read(from: spritePatternAddressHi)
                    
                    if (entry.attribute & 0x40) > 0 {
                        spritePatternBitsLo = spritePatternBitsLo.bitSwapped
                        spritePatternBitsHi = spritePatternBitsHi.bitSwapped
                    }
                    
                    spriteShifterPatternLo[index] = spritePatternBitsLo
                    spriteShifterPatternHi[index] = spritePatternBitsHi
                }
            }
        }
        
        if scanline == 241
            && cycle == 1 {
            status.insert(.verticalBlank)
            
            if control.contains(.enableNmi) {
                nmi = true
            }
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
        
        var fgPixel: UInt8 = 0
        var fgPalette: UInt8 = 0
        var fgPriority: UInt8 = 0
        
        if mask.contains(.renderSprites) {
            spriteZeroBeingRendered = false
            
            for (index, entry) in scanlineSprites.enumerated() {
                if entry.x == 0 {
                    let pixelLo: UInt8 = (spriteShifterPatternLo[index] & 0x80) > 0 ? 1 : 0
                    let pixelHi: UInt8 = (spriteShifterPatternHi[index] & 0x80) > 0 ? 1 : 0
                    fgPixel = (pixelHi << 1) | pixelLo
                    
                    fgPalette = (entry.attribute & 0x03) + 0x04
                    fgPriority = (entry.attribute & 0x20) == 0 ? 1 : 0
                    
                    // If the sprite pixel isn't transparent, then break out as we've found
                    // a pixel we can (potentially) draw.
                    if fgPixel != 0 {
                        // Mark if we're rendering sprite zero.
                        if index == 0 {
                            spriteZeroBeingRendered = true
                        }
                        
                        break
                    }
                }
            }
        }
        
        var pixel: UInt8 = 0
        var palette: UInt8 = 0
        
        if bgPixel == 0 && fgPixel == 0 {
            // Background pixel is transparent.
            // Sprite pixel is transparent.
            // Select the "transparent" color.
            pixel = 0x00
            palette = 0x00
        } else if bgPixel == 0 && fgPixel > 0 {
            // Background pixel is transparent.
            // Sprite pixel is visible.
            // Select the sprite pixel.
            pixel = fgPixel
            palette = fgPalette
        } else if bgPixel > 0 && fgPixel == 0 {
            // Background pixel is visible.
            // Foreground pixel is transparent.
            // Select the background pixel.
            pixel = bgPixel
            palette = bgPalette
        } else {
            if fgPriority > 0 {
                pixel = fgPixel
                palette = fgPalette
            } else {
                pixel = bgPixel
                palette = bgPalette
            }
            
            if spriteZeroHitPossible && spriteZeroBeingRendered {
                if mask.contains([.renderBackground, .renderSprites]) {
                    if mask.isDisjoint(with: [.renderBackgroundLeft, .renderSpritesLeft]) {
                        if cycle >= 9 && cycle < 258 {
                            status.insert(.spriteZeroHit)
                        }
                    } else {
                        if cycle >= 1 && cycle < 258 {
                            status.insert(.spriteZeroHit)
                        }
                    }
                }
            }
        }
        
        let bgColor = color(fromPalette: palette, index: pixel)
        videoReceiver?.setPixel(atX: Int(cycle - 1),
                                y: Int(scanline),
                                withColor: bgColor.rawValue)
        
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
    
    /// Whether or not the current frame is complete.
    private(set) var isFrameComplete: Bool = false
    
    
    // MARK: - AddressableReadWriteDevice
    
    let addressRange: AddressRange = RegisterAddress.range
    
    func read(from address: Address) -> Value {
        guard let register = RegisterAddress(address: address) else { return 0 }
        
        switch register {
        case .control, .mask, .oamAddress, .scroll, .ppuAddress:
            // Cannot be read from.
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
            
        case .oamData:
            return objectAttributeMemory.withUnsafeBytes { pointer in
                pointer[Int(oamAddress)]
            }

        case .ppuData:
            // Reading data from the PPU is delayed by one cycle.
            // Grab the previously stored value from the buffer and return it
            // while reading the data.
            var data = ppuDataBuffer
            ppuDataBuffer = bus.read(from: mirroredAddress(vramAddress.rawValue))
            
            // Except for palette data, which is returned immediately.
            if Self.paletteAddressRange.contains(vramAddress.rawValue) {
                data = ppuDataBuffer
            }
            
            // Automatically increment the address based on the increment mode.
            vramAddress.rawValue += control.contains(.yIncrementMode) ? 32 : 1
            
            return data
        }
        
        return 0
    }
    
    func write(_ value: Value, to address: Address) {
        guard let register = RegisterAddress(address: address) else { return }
        
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
            oamAddress = value
            
        case .oamData:
            objectAttributeMemory.withUnsafeMutableBytes { pointer in
                pointer[Int(oamAddress)] = value
            }

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
    
    /// An enumeration of the addresses of the PPU registers available on the CPU's bus.
    private enum RegisterAddress: Address {
        case control = 0x2000
        case mask
        case status
        case oamAddress
        case oamData
        case scroll
        case ppuAddress
        case ppuData
        
        
        init?(address: Address) {
            guard let mirroredAddress = address.mirrored(after: 0x7, within: Self.range),
                let registerAddress = RegisterAddress(rawValue: mirroredAddress) else { return nil }
            
            self = registerAddress
        }
        
        static let range: AddressRange = 0x2000...0x3fff
    }
    
    /// The address range where nametable memory is located on the PPU's bus.
    private static let nametableAddressRange: AddressRange = 0x2000...0x3eff
    
    /// The address range where palette memory is located on the PPU's bus.
    private static let paletteAddressRange: AddressRange = 0x3f00...0x3fff
    
    /// The range of cycles per scanline.
    private static let cycleRange: Range<Int16> = 0..<341
    
    /// The range of scanlines per frame.
    private static let scanlineRange: Range<Int16> = -1..<261
    
    /// The PPU's bus.
    private let bus: Bus
    
    /// The current scanline.
    private var scanline: Int16 = 0
    
    /// The current cycle of the current scanline.
    private var cycle: Int16 = 0
    
    enum AddressLatch {
        case high
        case low
    }
    
    private var ppuAddressLatch: AddressLatch = .high
    private var ppuDataBuffer: Value = 0
    private var ppuAddress: Address = 0x0
    
    private struct ScrollRegister {
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
    
    private var vramAddress: ScrollRegister = ScrollRegister(rawValue: 0)
    private var tramAddress: ScrollRegister = ScrollRegister(rawValue: 0)
    private var fineX: UInt8 = 0
    
    private var bgNextTileId: UInt8 = 0
    private var bgNextTileAttribute: UInt8 = 0
    private var bgNextTileLSB: UInt8 = 0
    private var bgNextTileMSB: UInt8 = 0
    
    private var bgShiftPatternLo: UInt16 = 0
    private var bgShiftPatternHi: UInt16 = 0
    private var bgShiftAttributeLo: UInt16 = 0
    private var bgShiftAttributeHi: UInt16 = 0
    
    private var scanlineSprites: [ObjectAttributeEntry] = []
    private var spriteShifterPatternLo: [UInt8] = []
    private var spriteShifterPatternHi: [UInt8] = []
    
    private var spriteZeroHitPossible = false
    private var spriteZeroBeingRendered = false
    
    
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
                    return 0x2400 | (address & 0x0fff)
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
                        let pixel = ((tileLSB & 0x01) << 1) | (tileMSB & 0x01)
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
        let address = Self.paletteAddressRange.lowerBound + (UInt16(palette) << 2) + UInt16(index)
        let colorIndex = Int(bus.read(from: mirroredAddress(address)) & 0x3f)
        
        return Self.colors[colorIndex]
    }
}

extension PixelProcessingUnit: DirectMemoryAccessableWriteDevice {
    func dmaWrite(_ value: Value, to oamAddress: UInt8) {
        objectAttributeMemory.withUnsafeMutableBytes { pointer in
            pointer[Int(oamAddress)] = value
        }
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

extension UInt8 {
    /// Returns a "bit-swapped" value.
    ///
    /// A value of `0b10110000` becomes `0b00001101`.
    var bitSwapped: UInt8 {
        var b = self
        b = ((b & 0xf0) >> 4) | ((b & 0x0f) << 4)
        b = ((b & 0xcc) >> 2) | ((b & 0x33) << 2)
        b = ((b & 0xaa) >> 1) | ((b & 0x55) << 1)
        return b
    }
}
