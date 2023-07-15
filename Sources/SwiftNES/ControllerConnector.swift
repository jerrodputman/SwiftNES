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

/// A controller that can be connected to a ``ControllerConnector``.
public protocol Controller: AnyObject {
    /// Reads a single bit from the controller.
    ///
    /// - Returns: Whether or not the most significant bit of the controller is set.
    func read() -> Bool
    
    /// Writes the value to the controller.
    ///
    /// - Parameter data: The data to write to the controller.
    func write(_ data: Value)
}

/// A device that allows a controller to be connected to the NES.
final class ControllerConnector: AddressableReadWriteDevice {
    
    // MARK: - Initializers
    
    /// Initializes the controller connector with the specified port.
    init(address: Address) {
        self.addressRange = address...address
    }
    
    
    // MARK: - Attaching a controller to the connector
    
    /// The controller that is attached to this connector.
    var controller: (any Controller)? = nil
    
    
    // MARK: - AddressableReadWriteDevice
    
    let addressRange: AddressRange
    
    func read(from address: Address) -> Value {
        guard let controller else { return 0 }
        
        return controller.read() ? 1 : 0
    }
    
    func write(_ data: Value, to address: Address) {
        controller?.write(data)
    }
}
