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

final class RP2A03G {
    
    // MARK: - Initializers
    
    /// Creates a virtual CPU with the specified bus.
    ///
    /// - parameter bus: The bus that the CPU should use to communicate with other devices.
    init(bus: Bus) {
        // TODO: Create the APU and connect it to the bus.
        // TODO: Create the DMA controller and connect it to the bus.
        self.core = MOS6502(bus: bus)
    }
    
    
    // MARK: - Hardware
    
    /// The 6502 core of the 2A03.
    let core: MOS6502
    
    //let apu: AudioProcessingUnit
    
    //var controlPad1: ControlPad?
    
    //var controlPad2: ControlPad?
}
