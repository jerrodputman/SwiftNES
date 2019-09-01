//
//  NES.swift
//  SwiftNES
//
//  Created by Jerrod Putman on 8/30/19.
//  Copyright © 2019 Jerrod Putman. All rights reserved.
//

import Foundation

final class NES {
    
    let cpu: MOS6502
    let ram: RandomAccessMemoryDevice
    
    
    init() {
        ram = RandomAccessMemoryDevice(addressRange: 0x0000...0xffff)
        let bus = Bus(addressableDevices: [ram])
        cpu = MOS6502(bus: bus)
    }
}
