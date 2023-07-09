import XCTest

import SwiftNESTests

var tests = [XCTestCaseEntry]()
tests += SwiftNESTests.allTests()
tests += BusTests.allTests()
XCTMain(tests)
