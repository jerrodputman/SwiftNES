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

extension String {
    
    /// Converts a string that contains hexadecimal information into an array of bytes.
    var hexToUInt8: [UInt8] {
        let allowedCharacters = CharacterSet(charactersIn: "01234567890ABCDEF")
        let filteredCharacters = self.unicodeScalars.filter { allowedCharacters.contains($0) }
        
        var bytes = [UInt8]()
        bytes.reserveCapacity(filteredCharacters.count / 2)

        // It is a lot faster to use a lookup map instead of strtoul
        let map: [UInt8] = [
          0x00, 0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, // 01234567
          0x08, 0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, // 89:;<=>?
          0x00, 0x0a, 0x0b, 0x0c, 0x0d, 0x0e, 0x0f, 0x00, // @ABCDEFG
          0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00  // HIJKLMNO
        ]

        // Grab two characters at a time, map them and turn it into a byte
        var currentIndex = filteredCharacters.startIndex
        while currentIndex != filteredCharacters.endIndex {
            let index1 = Int(filteredCharacters[currentIndex].value & 0x1F ^ 0x10)
            currentIndex = filteredCharacters.index(after: currentIndex)
            let index2 = Int(filteredCharacters[currentIndex].value & 0x1F ^ 0x10)
            currentIndex = filteredCharacters.index(after: currentIndex)
            
            bytes.append(map[index1] << 4 | map[index2])
        }
        
        return bytes
    }
}
