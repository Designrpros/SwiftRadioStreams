import Foundation

public struct RadioStream: Equatable, Codable {
    public let name: String
    public let url: URL

    public init(name: String, url: URL) {
        self.name = name
        self.url = url
    }
}

public enum RadioStreamError: Error, LocalizedError {
    case directoryNotFound(String)
    case fileReadFailed(String, Error)
    case invalidFormat(String)
    
    public var errorDescription: String? {
        switch self {
        case .directoryNotFound(let path):
            return "Directory not found at path: \(path)"
        case .fileReadFailed(let path, let underlying):
            return "Failed to read file at \(path): \(underlying.localizedDescription)"
        case .invalidFormat(let message):
            return "Invalid format: \(message)"
        }
    }
}

public class RadioStreamProvider {
    public let streamsDirectory: URL
    
    /// Initializes the provider.
    /// - Parameter streamsDirectory: Optional override of the streams directory.
    ///   If not provided, it will attempt to locate the "internet-radio-streams" folder in the package bundle.
    public init(streamsDirectory: URL? = nil) {
        if let dir = streamsDirectory {
            self.streamsDirectory = dir
            print("Using provided streamsDirectory: \(self.streamsDirectory.path)")
        } else {
            // Attempt to locate the "internet-radio-streams" folder in the package resources.
            guard let resourceURL = Bundle.module.url(forResource: "internet-radio-streams", withExtension: nil) else {
                fatalError("Resource 'internet-radio-streams' not found in Bundle.module")
            }
            self.streamsDirectory = resourceURL
            print("Using streamsDirectory from Bundle.module: \(self.streamsDirectory.path)")
        }
    }
    
    public func loadStreams() throws -> [RadioStream] {
        var streams: [RadioStream] = []
        let fileManager = FileManager.default
        
        print("Checking existence of directory: \(streamsDirectory.path)")
        guard fileManager.fileExists(atPath: streamsDirectory.path) else {
            print("Directory not found at: \(streamsDirectory.path)")
            throw RadioStreamError.directoryNotFound("Directory not found at path: \(streamsDirectory.path)")
        }
        
        let files = try fileManager.contentsOfDirectory(atPath: streamsDirectory.path)
        print("Found files: \(files)")
        
        let m3uFiles = files.filter { $0.lowercased().hasSuffix(".m3u") }
        print("Filtered m3u files: \(m3uFiles)")
        
        for fileName in m3uFiles {
            let fileURL = streamsDirectory.appendingPathComponent(fileName)
            print("Parsing file: \(fileURL.path)")
            do {
                let fileStreams = try parseM3UFile(at: fileURL)
                streams.append(contentsOf: fileStreams)
            } catch {
                print("Error parsing \(fileName): \(error)")
            }
        }
        
        if streams.isEmpty {
            throw RadioStreamError.invalidFormat("No streams found in file(s) at \(streamsDirectory.lastPathComponent)")
        }
        return streams
    }
    
    private func parseM3UFile(at fileURL: URL) throws -> [RadioStream] {
        let content: String
        do {
            content = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            throw RadioStreamError.fileReadFailed(fileURL.path, error)
        }
        
        let lines = content
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        guard let firstLine = lines.first, firstLine == "#EXTM3U" else {
            throw RadioStreamError.invalidFormat("File \(fileURL.lastPathComponent) does not start with the #EXTM3U header.")
        }
        
        var streams: [RadioStream] = []
        var index = 1
        
        while index < lines.count {
            let line = lines[index]
            if line.hasPrefix("#EXTINF:") {
                let components = line.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: true)
                guard components.count == 2 else {
                    print("Skipping malformed metadata line: \(line)")
                    index += 1
                    continue
                }
                let streamName = String(components[1]).trimmingCharacters(in: .whitespaces)
                
                index += 1
                while index < lines.count && lines[index].isEmpty {
                    index += 1
                }
                if index < lines.count, let streamURL = URL(string: lines[index]) {
                    streams.append(RadioStream(name: streamName, url: streamURL))
                } else {
                    print("Warning: No valid URL found for stream named \(streamName) in file \(fileURL.lastPathComponent)")
                }
            }
            index += 1
        }
        return streams
    }
    
    // Async version using Swift concurrency (iOS 15+/macOS 12+)
    @available(iOS 15.0, macOS 12.0, *)
    public func loadStreamsAsync() async throws -> [RadioStream] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let streams = try self.loadStreams()
                    continuation.resume(returning: streams)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
