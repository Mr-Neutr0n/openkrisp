import XCTest
@testable import LabVoice

@MainActor final class AudioHelperStreamingTests: XCTestCase {
    private func run(_ code: String, limit: Int, row: @escaping (String) -> Void) async throws -> HelperExit {
        let child = SystemAudioHelperChild(url: URL(fileURLWithPath: "/usr/bin/python3"), outputMode: .streaming(maxLineBytes: limit))
        var event: HelperExit?
        try child.launch(arguments: ["-c", code], line: row, exit: { event = $0 })
        let drained = await child.waitForExit(timeoutNanoseconds: 15_000_000_000)
        if !drained { child.terminate(); _ = await child.waitForExit(timeoutNanoseconds: 2_000_000_000) }
        XCTAssertTrue(drained)
        return try XCTUnwrap(event)
    }
    func testManyLargeLinesExceedCollectedBudgetWithoutRetainingHistory() async throws {
        var rows = 0, longest = 0
        let event = try await run("import sys\nfor _ in range(8):\n sys.stdout.write('{\\\"payload\\\":\\\"'+'a'*400000+'\\\"}\\n')\nsys.stdout.flush()", limit: 614400) { rows += 1; longest = max(longest, $0.utf8.count) }
        XCTAssertEqual(rows, 8); XCTAssertGreaterThan(longest, 65_536)
        XCTAssertTrue(event.output.isEmpty); XCTAssertTrue(event.diagnostic.isEmpty); XCTAssertEqual(event.status, 0)
    }
    func testOversizedOrInvalidUTF8LineNeverPublishesSuffixAsEvent() async throws {
        for code in ["import sys\nsys.stdout.write('x'*2048+'\\n{\\\"valid\\\":true}\\n');sys.stdout.flush()", "import sys\nsys.stdout.buffer.write(b'\\xff\\n{}\\n');sys.stdout.flush()"] {
            var rows = 0
            let event = try await run(code, limit: 1024) { _ in rows += 1 }
            XCTAssertEqual(rows, 0); XCTAssertFalse(event.diagnostic.isEmpty); XCTAssertTrue(event.output.isEmpty)
        }
    }
    func testUnterminatedLineIsReportedAsUnclean() async throws {
        var rows = 0
        let event = try await run("import sys\nsys.stdout.write('{}');sys.stdout.flush()", limit: 1024) { _ in rows += 1 }
        XCTAssertEqual(rows, 0); XCTAssertTrue(event.diagnostic.contains("incomplete line"))
    }
}
