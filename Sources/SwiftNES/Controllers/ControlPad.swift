// MIT License
//
// Copyright (c) 2023 Jerrod Putman
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

/// A class that represents an NES Control Pad (NES-004).
public final class ControlPad: Controller {
    
    // MARK: - Initializers
    
    /// Initializes the control pad.
    public init() {
        self.pressedButtons = .none
        self.shiftRegister = .init()
    }
    
    
    // MARK: - Buttons
    
    /// An option set that represents all of the possible buttons that can be presed on the control pad.
    public struct Buttons: OptionSet {
        public var rawValue: UInt8
        
        public static let right = Buttons(rawValue: (1 << 0))
        public static let left = Buttons(rawValue: (1 << 1))
        public static let down = Buttons(rawValue: (1 << 2))
        public static let up = Buttons(rawValue: (1 << 3))
        public static let start = Buttons(rawValue: (1 << 4))
        public static let select = Buttons(rawValue: (1 << 5))
        public static let b = Buttons(rawValue: (1 << 6))
        public static let a = Buttons(rawValue: (1 << 7))
        
        public static let none = Buttons([])
        
        
        public init(rawValue: UInt8) {
            self.rawValue = rawValue
        }
    }
    
    /// The buttons that are currently pressed.
    public var pressedButtons: Buttons
    
    
    // MARK: - Controller
    
    public func read() -> Bool {
        shiftRegister.output()
    }
    
    public func write(_ data: Value) {
        // Move the current button state into the shift register.
        shiftRegister.input(pressedButtons.rawValue)
    }
    
    
    // MARK: - Private
    
    /// A shift register where the button state can be read bit-by-bit.
    private var shiftRegister: ShiftRegisterPISO<UInt8>
}
