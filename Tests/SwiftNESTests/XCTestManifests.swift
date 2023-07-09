import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(SwiftNESTests.allTests),
        testCase(BusTests.allTests),
    ]
}
#endif
