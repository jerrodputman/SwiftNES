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

/// A class that represents a connection to a cartridge.
///
/// Instead of attaching the cartridge directly to the bus, a connector is used to allow for
/// runtime inserting and removal of the cartridge.
class CartridgeConnector: AddressableReadWriteDevice {
    
    // MARK: - Initializers
    
    /// Creates a catridge connector that responds to the specified address range.
    ///
    /// - parameter addressRange: The range of addresses that this connector responds to.
    init(addressRange: AddressRange) {
        self.addressRange = addressRange
    }
    
    
    // MARK: - Inserting and removing a cartridge
    
    /// The connected cartridge.
    var cartridge: Cartridge? = nil
    
    
    // MARK: - AddressableReadWriteDevice
    
    func respondsTo(_ address: Address) -> Bool {
        return addressRange.contains(address)
    }
    
    func read(from address: Address) -> Value {
        guard respondsTo(address) else { return 0 }
        
        return cartridge?.read(from: address) ?? 0
    }
    
    func write(_ value: Value, to address: Address) {
        guard respondsTo(address) else { return }
        
        cartridge?.write(value, to: address)
    }
    
    
    // MARK: - Private
    
    /// The range of addresses that this connector responds to.
    private let addressRange: AddressRange
}
