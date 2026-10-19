import Foundation

public struct TestFailure: Error, CustomStringConvertible {
    public let message: String
    public let file: StaticString
    public let line: UInt

    public init(_ message: String, file: StaticString = #fileID, line: UInt = #line) {
        self.message = message
        self.file = file
        self.line = line
    }

    public var description: String {
        let detail = message.isEmpty ? "expectation failed" : message
        return "\(file):\(line): \(detail)"
    }
}

/// Throwing replacement for `assert`: reports a failure to the runner instead of
/// trapping the whole process, and is never compiled out under `-O`.
public func expect(
    _ condition: @autoclosure () throws -> Bool,
    _ message: @autoclosure () -> String = "",
    file: StaticString = #fileID,
    line: UInt = #line
) throws {
    guard try condition() else {
        throw TestFailure(message(), file: file, line: line)
    }
}
