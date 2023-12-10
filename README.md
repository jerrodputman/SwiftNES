# SwiftNES
![CI](https://github.com/jerrodputman/SwiftNES/actions/workflows/RunTests-macOS.yml/badge.svg)

An NES emulator written in [Swift](https://www.swift.org).

This emulator is designed to be used as a pluggable component of a frontend application, and therefore does not actually produce an executable. The [SwiftEmu](https://github.com/jerrodputman/SwiftEmu) sample application can be used as a convenient, no frills frontend for the emulator.

## Goal
The goal of this project was to learn more about how the internals of the NES works, how to write an emulator, and how to do it all in my personal favorite programming language, Swift.

The design of the emulator tries to mimic the actual components of the NES hardware. For example, an instance of the `ControlPad` needs to be connected to one of the two `ControllerConnector` properties on the `NES` hardware instance; a `Cartridge` is connected to a `CartridgeConnector`; there's a `Bus` component which all of the hardware components are attached to (including `RandomAccessMemory` devices and the `PixelProcessingUnit`).

## Status
This emulator is a small side project that I play around with from time to time. With that said, here are some of the things that are complete and some that are not.

- [x] 6502 CPU (registers, instruction set) minus decimal mode - not cycle accurate
- [x] Pixel processing unit (sprites, background)
- [x] Control pad
- [x] Cartridges with support for mappers
- [x] Video output (to a delegate "video receiver")
- [ ] Audio output (to a delegate "audio receiver")

### Mappers implemented
- 000
- 002

### Supported platforms
The emulator has been tested using the [SwiftEmu](https://github.com/jerrodputman/SwiftEmu) frontend on:
- macOS Ventura
- Ubuntu 22.04 LTS

though the emulator should be able to run wherever Swift is supported as a target.

# Usage
Feel free to use the [SwiftEmu](https://github.com/jerrodputman/SwiftEmu) sample application to try out the emulator, or place it in your own project using Swift Package Manager.

```swift
// swift-tools-version:5.8

import PackageDescription

let package = Package(
    name: "YourPackageName",
    dependencies: [
        .package(url: "https://github.com/jerrodputman/SwiftNES.git", branch: "main")
    ],
    targets: [
        .target(
            name: "YourTargetName",
            dependencies: [
                "SwiftNES"
            ])
    ]
)
```

You then need to create the hardware instance, plug in all of the necessary components, and reset the system:
```swift
import SwiftNES

let hardware = NES()

let controlPad = ControlPad()
hardware.controller1 = controlPad

let cartridgeData = try Data(...)
let cartridge = try Cartridge(data: cartridgeData)
hardware.cartridge = cartridge

hardware.videoReceiver = someVideoReceiverDelegate
hardware.audioReciver = someAudioReceiverDelegate

hardware.reset()
```

Then update the hardware every frame:
```swift
hardware.update(elapsedTime: deltaTime)
```

The video output will be sent a pixel at a time via the `VideoReceiver` protocol. Audio is not currently implemented.
