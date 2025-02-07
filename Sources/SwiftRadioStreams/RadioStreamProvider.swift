// Always define Bundle.module via a fallback for environments where it isn’t synthesized.
private class DummyBundle {}
extension Bundle {
    static var module: Bundle {
        return Bundle(for: DummyBundle.self)
    }
}

import Foundation

public struct RadioStream: Equatable, Codable {
    public let name: String
    public let url: URL

    public init(name: String, url: URL) {
        self.name = name
        self.url = url
        print("RadioStream initialized: \(name) at \(url.absoluteString)")
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
    ///   If not provided, it will attempt to locate the "internet-radio-streams" folder using one of several methods:
    ///   1. Try Bundle.module.
    ///   2. Otherwise, try Bundle.main.
    ///   3. Finally, fall back to a relative path based on the current directory.
    public init(streamsDirectory: URL? = nil) {
        if let dir = streamsDirectory {
            self.streamsDirectory = dir
            print("Using provided streamsDirectory: \(self.streamsDirectory.path)")
        } else {
            var resourceURL: URL? = nil
            
            print("Attempting to locate resource using Bundle.module...")
            resourceURL = Bundle.module.url(forResource: "internet-radio-streams", withExtension: nil)
            
            if resourceURL == nil {
                print("Bundle.module did not yield resource. Trying Bundle.main...")
                resourceURL = Bundle.main.url(forResource: "internet-radio-streams", withExtension: nil)
            }
            
            if resourceURL == nil {
                let currentPath = FileManager.default.currentDirectoryPath
                let fallbackURL = URL(fileURLWithPath: currentPath)
                    .appendingPathComponent("External")
                    .appendingPathComponent("internet-radio-streams")
                print("Bundle.main did not yield resource. Constructed fallback URL: \(fallbackURL.path)")
                if FileManager.default.fileExists(atPath: fallbackURL.path) {
                    resourceURL = fallbackURL
                }
            }
            
            guard let foundResourceURL = resourceURL else {
                fatalError("Resource 'internet-radio-streams' not found using any method.")
            }
            self.streamsDirectory = foundResourceURL
            print("Using streamsDirectory: \(self.streamsDirectory.path)")
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
        
        print("Listing files in directory...")
        let files = try fileManager.contentsOfDirectory(atPath: streamsDirectory.path)
        print("Directory listing (\(files.count) files): \(files)")
        
        let m3uFiles = files.filter { $0.lowercased().hasSuffix(".m3u") }
        print("Filtered m3u files (\(m3uFiles.count) found): \(m3uFiles)")
        
        for fileName in m3uFiles {
            let fileURL = streamsDirectory.appendingPathComponent(fileName)
            print("Attempting to parse file: \(fileURL.path)")
            do {
                let fileStreams = try parseM3UFile(at: fileURL)
                print("Parsed \(fileStreams.count) streams from \(fileName)")
                streams.append(contentsOf: fileStreams)
            } catch {
                print("Error parsing \(fileName): \(error)")
            }
        }
        
        if streams.isEmpty {
            print("No streams found in directory: \(streamsDirectory.lastPathComponent)")
            throw RadioStreamError.invalidFormat("No streams found in file(s) at \(streamsDirectory.lastPathComponent)")
        }
        print("Total streams loaded: \(streams.count)")
        return streams
    }
    
    private func parseM3UFile(at fileURL: URL) throws -> [RadioStream] {
        print("Reading file at path: \(fileURL.path)")
        let content: String
        do {
            content = try String(contentsOf: fileURL, encoding: .utf8)
            print("Successfully read file: \(fileURL.lastPathComponent) (\(content.count) characters)")
        } catch {
            print("Error reading file: \(fileURL.lastPathComponent)")
            throw RadioStreamError.fileReadFailed(fileURL.path, error)
        }
        
        let lines = content
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        print("File \(fileURL.lastPathComponent) contains \(lines.count) non-empty lines.")
        
        guard let firstLine = lines.first, firstLine == "#EXTM3U" else {
            print("File \(fileURL.lastPathComponent) missing required header (#EXTM3U).")
            throw RadioStreamError.invalidFormat("File \(fileURL.lastPathComponent) does not start with the #EXTM3U header.")
        }
        
        var streams: [RadioStream] = []
        var index = 1
        
        while index < lines.count {
            let line = lines[index]
            if line.hasPrefix("#EXTINF:") {
                print("Found metadata line: \(line)")
                let components = line.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: true)
                guard components.count == 2 else {
                    print("Skipping malformed metadata line: \(line)")
                    index += 1
                    continue
                }
                let streamName = String(components[1]).trimmingCharacters(in: .whitespaces)
                print("Extracted stream name: \(streamName)")
                
                index += 1
                while index < lines.count && lines[index].isEmpty {
                    print("Skipping empty line at index \(index)")
                    index += 1
                }
                if index < lines.count, let streamURL = URL(string: lines[index]) {
                    print("Extracted stream URL: \(streamURL.absoluteString)")
                    streams.append(RadioStream(name: streamName, url: streamURL))
                } else {
                    print("Warning: No valid URL found for stream named \(streamName) in file \(fileURL.lastPathComponent)")
                }
            }
            index += 1
        }
        print("Finished parsing file \(fileURL.lastPathComponent), found \(streams.count) streams.")
        return streams
    }
    
    @available(iOS 15.0, macOS 12.0, *)
    public func loadStreamsAsync() async throws -> [RadioStream] {
        print("Starting asynchronous stream loading...")
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    print("Error: RadioStreamProvider was deallocated during async load.")
                    continuation.resume(throwing: RadioStreamError.invalidFormat("Self was deallocated"))
                    return
                }
                do {
                    let streams = try self.loadStreams()
                    print("Asynchronous load complete. Loaded \(streams.count) streams.")
                    continuation.resume(returning: streams)
                } catch {
                    print("Error during asynchronous stream load: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

#if swift(>=5.6)
extension RadioStreamProvider: @unchecked Sendable {}
#endif
