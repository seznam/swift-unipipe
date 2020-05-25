/*
 * Copyright 2017-2018 Seznam.cz, a.s.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/*
 * Author: Daniel Bilik (daniel.bilik@firma.seznam.cz)
 */

import Foundation
#if os(macOS) || os(iOS) || os(tvOS)
import Darwin
private let system_read = Darwin.read
private let system_write = Darwin.write
#elseif os(Linux)
import Glibc
private let system_read = Glibc.read
private let system_write = Glibc.write
#endif

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

	public init(nonblockReadEnd: Bool = true, nonblockWriteEnd: Bool = true) throws {
		if pipe(&fd) != 0 {
			throw UniPipeError.error(detail: "pipe() failed, \(String(validatingUTF8: strerror(errno)) ?? "")")
		}
		for i in fd {
			if i == fd[0], !nonblockReadEnd {
				continue
			} else if i == fd[1], !nonblockWriteEnd {
				continue
			}
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
		buffer.deallocate()
	}

	public func plug(keepReadEnd: Bool = false, keepWriteEnd: Bool = false) -> Void {
		if !keepReadEnd {
			close(fd[0])
			fd[0] = -1
		}
		if !keepWriteEnd {
			close(fd[1])
			fd[1] = -1
		}
	}

	public func read(min: Int = 1, max: Int? = nil, timeout: Int? = nil) throws -> Data {
		guard fd[0] != -1 else {
			throw UniPipeError.error(detail: "read end has been plugged")
		}
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
			rc = system_read(fd[0], buffer, limit)
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
		guard fd[1] != -1 else {
			throw UniPipeError.error(detail: "write end has been plugged")
		}
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
			rc = bufferLeft.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) -> Int in return system_write(fd[1], ptr.baseAddress, bytesLeft) }
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
