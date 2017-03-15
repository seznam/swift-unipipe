import Foundation
import Glibc

public enum UniPipeError: Error {
	case error(detail: String)
}

public class UniPipe {

	public var readEnd: Int32 {
		return fd[0]
	}
	public var writeEnd: Int32 {
		return fd[1]
	}

	private var fd: [Int32] = [ -1, -1 ]
	private var buffer: UnsafeMutablePointer<UInt8>
	private let bufferSize = 8192

	public init() throws {
		if pipe(&fd) != 0 {
			throw UniPipeError.error(detail: "pipe() failed, \(String(validatingUTF8: strerror(errno)) ?? "")")
		}
		for i in fd {
			let flags = fcntl(i, F_GETFL)
			guard flags != -1, fcntl(i, F_SETFL, flags | O_NONBLOCK) != -1 else {
				throw UniPipeError.error(detail: "fcntl() failed, \(String(validatingUTF8: strerror(errno)) ?? "")")
			}
          }
		buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
	}

	deinit {
		for i in fd {
			if i != -1 {
				close(i)
			}
		}
		buffer.deallocate(capacity: bufferSize)
	}

	public func plug(keepReadEnd: Bool = false, keepWriteEnd: Bool = false) -> Void {
		var closefd = [Int]()
		if !keepReadEnd {
			closefd.append(0)
		}
		if !keepWriteEnd {
			closefd.append(1)
		}
		for i in closefd {
			if i > 0 {
				close(fd[i])
				fd[i] = -1
			}
		}
	}

	public func read(min: Int = 1, max: Int? = nil, timeout: Int? = nil) throws -> Data {
		var timelimit: Int?
		if let t = timeout {
			timelimit = time(nil) + t
		}
		var rc: Int = 0
		var data = Data()
		while rc == 0 {
			var limit = bufferSize
			if let m = max, (m - data.count) < bufferSize {
				limit = m - data.count
			}
			rc = Glibc.read(fd[0], buffer, limit)
			if rc == -1 {
				if errno != EINTR && errno != EAGAIN {
					let errstr = String(validatingUTF8: strerror(errno)) ?? ""
					throw UniPipeError.error(detail: "pipe read failed, \(errstr)")
				}
				rc = 0
			}
			data.append(buffer, count: rc)
			if let m = max, data.count >= m {
				break
			} else if max == nil, rc == bufferSize {
				rc = 0
			} else if data.count >= min {
				break
			}
			if let t = timelimit, t < time(nil) {
				break
			}
			usleep(5000)
		}
		return data
	}

	public func write(_ buffer: Data, timeout: Int? = nil) throws -> Void {
		var timelimit: Int?
		if let t = timeout {
			timelimit = time(nil) + t
		}
		var bytesLeft = buffer.count
		var rc: Int
		while bytesLeft > 0 {
			if let t = timelimit, t < time(nil) {
				throw UniPipeError.error(detail: "timeout")
			}
			let rangeLeft = Range(uncheckedBounds: (lower: buffer.index(buffer.startIndex, offsetBy: (buffer.count - bytesLeft)), upper: buffer.endIndex))
			let bufferLeft = buffer.subdata(in: rangeLeft)
			rc = bufferLeft.withUnsafeBytes { return Glibc.write(fd[1], $0, bytesLeft) }
			if rc == -1 {
				if errno != EINTR && errno != EAGAIN {
					let errstr = String(validatingUTF8: strerror(errno)) ?? ""
					throw UniPipeError.error(detail: "pipe write failed, \(errstr)")
				}
			} else {
				bytesLeft = bytesLeft - rc
			}
			if bytesLeft > 0 {
				usleep(5000)
			}
		}
	}

}
