import XCTest

@testable import UniPipe

var sigPipe: Int = 0

class UniPipeTests: XCTestCase {

	static var allTests = [
		("testPing", testPing),
		("testPlugRead", testPlugRead),
		("testPlugWrite", testPlugWrite),
		("testSigPipe", testSigPipe),
	]

	func testPing() {
		let ping: String
		do {
			let pipe = try UniPipe()
			let request = "ping"
			try pipe.write(request.data(using: .utf8)!)
			let response = try pipe.read(timeout: 0)
			guard let string = String(data: response, encoding: .utf8) else {
				throw UniPipeError.error(detail: "malformed data read")
			}
			ping = string
		} catch {
			print(error)
			ping = "error"
		}
		XCTAssert(ping == "ping")
	}

	func testPlugRead() {
		let result: String
		do {
			let pipe = try UniPipe()
			pipe.plug(keepWriteEnd: true)
			_ = try pipe.read(timeout: 0)
			result = ""
		} catch UniPipeError.error(let detail) {
			print(detail)
			result = detail
		} catch {
			print(error)
			result = ""
		}
		XCTAssert(result == "read end has been plugged")
	}

	func testPlugWrite() {
		let result: String
		do {
			let pipe = try UniPipe()
			pipe.plug(keepReadEnd: true)
			let request = "ping"
			try pipe.write(request.data(using: .utf8)!)
			result = ""
		} catch UniPipeError.error(let detail) {
			print(detail)
			result = detail
		} catch {
			print(error)
			result = ""
		}
		XCTAssert(result == "write end has been plugged")
	}

	func testSigPipe() {
		signal(SIGPIPE) { _ in sigPipe = 1 }
		do {
			let pipe = try UniPipe()
			pipe.plug(keepWriteEnd: true)
			let request = "ping"
			try pipe.write(request.data(using: .utf8)!)
		} catch {
			print(error)
		}
		XCTAssert(sigPipe == 1)
	}

}
