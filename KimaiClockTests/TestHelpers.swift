import Foundation

nonisolated extension URLRequest {
    /// JSON body of a request. URLProtocol receives bodies as a stream, so `httpBody` alone is usually nil.
    var jsonBody: [String: Any]? {
        var data = httpBody
        if data == nil, let stream = httpBodyStream {
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 4096)
            var collected = Data()
            while stream.hasBytesAvailable {
                let read = stream.read(&buffer, maxLength: buffer.count)
                guard read > 0 else { break }
                collected.append(buffer, count: read)
            }
            data = collected
        }
        guard let data else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
