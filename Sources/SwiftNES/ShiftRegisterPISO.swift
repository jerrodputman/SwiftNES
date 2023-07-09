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

/// Represents a PISO (parallel in, serial out) shift register.
struct ShiftRegisterPISO<Size: FixedWidthInteger & UnsignedInteger> {
    /// Initializes the shift register.
    ///
    /// - Parameter value: The initial value of the register.
    init(value: Size = 0) {
        self.value = value
    }
    
    /// Loads the register with a value.
    ///
    /// - Parameter value: The value.
    mutating func input(_ value: Size) {
        self.value = value
    }
    
    /// Outputs the value a bit at a time.
    mutating func output() -> Bool {
        // Grab the most significant bit from the shift register.
        // If the bit is set, then the button is being pressed.
        let isMSBSet = value.leadingZeroBitCount == 0
        
        // Shift the register one bit to the left.
        value = value << 1

        // Return the previously captured bit value.
        return isMSBSet
    }
    
    private var value: Size
}
