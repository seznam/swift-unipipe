![](https://img.shields.io/badge/Swift-5.2-orange.svg?style=flat)
![macOS](https://img.shields.io/badge/os-macOS-green.svg?style=flat)
![Linux](https://img.shields.io/badge/os-linux-green.svg?style=flat)
![Apache 2](https://img.shields.io/badge/license-Apache2-blue.svg?style=flat)
![Build Status](https://travis-ci.com/seznam/swift-unipipe.svg?branch=master)

# UniPipe

Let parts of your swift application talk to each other via pipe(2)s.

## Usage

Communicate inside a process:

```swift
import Foundation
import UniPipe

var pipe: UniPipe?

func reader() -> Void {
	if let data = try? pipe?.read(timeout: 2) {
		let response = String(data: data!, encoding: .utf8)
		print(response)
	}
}

func writer() -> Void {
	let request = "ping"
	try? pipe?.write(request.data(using: .utf8)!)
}

do {
	pipe = try UniPipe()
	if #available(OSX 10.12, *) {
		_ = Thread(block: reader).start()
		_ = Thread(block: writer).start()
	}
	sleep(2)
} catch UniPipeError.error(let detail) {
	print(detail)
}
```

Talk to a subprocess:

```swift
import UniPipe

#if os(macOS) || os(iOS) || os(tvOS)
import Darwin
private let system_fork = Darwin.fork
#elseif os(Linux)
import Glibc
private let system_fork = Glibc.fork
#endif

let request = try UniPipe()
let response = try UniPipe()
let pid = system_fork()
if pid == 0 {
	request.plug(keepWriteEnd: true)
	response.plug(keepReadEnd: true)
	let message = "hello, my child"
	try request.write(message.data(using: .utf8)!)
	let data = try response.read(timeout: 3)
	print("child responded: \(String(data: data, encoding: .utf8))")
} else if pid > 0 {
	request.plug(keepReadEnd: true)
	response.plug(keepWriteEnd: true)
	let data = try request.read(timeout: 3)
	print("parent says: \(String(data: data, encoding: .utf8))")
	let message = "hi, my parent"
	try response.write(message.data(using: .utf8)!)
} else {
	let errstr = String(validatingUTF8: strerror(errno)) ?? "unknown error"
	print("failed to fork(), \(errstr)")
}
```

## Credits

Written by [Daniel Fojt](https://github.com/danielfojt/), copyright [Seznam.cz](https://onas.seznam.cz/en/), licensed under the terms of the Apache License 2.0.
