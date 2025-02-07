import Foundation

/// A model representing an internet radio stream.
public struct RadioStream: Equatable, Codable {
    public let name: String
    public let url: URL
    
    public init(name: String, url: URL) {
        self.name = name
        self.url = url
    }
}

/// Errors that might occur when parsing radio stream files.
public enum RadioStreamError: LocalizedError {
    case directoryNotFound(String)
    case fileReadFailed(String, underlying: Error)
    case invalidFormat(String)
    case noStreamsFound(String)
    
    public var errorDescription: String? {
        switch self {
        case .directoryNotFound(let path):
            return "Directory not found at path: \(path)"
        case .fileReadFailed(let path, let underlying):
            return "Failed to read file at \(path): \(underlying.localizedDescription)"
        case .invalidFormat(let message):
            return "Invalid format: \(message)"
        case .noStreamsFound(let fileName):
            return "No streams found in file: \(fileName)"
        }
    }
}

/// A provider that loads and parses radio stream data from m3u files.
///
/// This provider looks for m3u files in a directory (by default at
/// "External/internet-radio-streams" relative to the package root) and parses
/// each file for radio stream metadata.
///
/// The file is expected to start with the "#EXTM3U" header and then have pairs of lines:
/// - A metadata line beginning with "#EXTINF:" (e.g. `#EXTINF:-1,Example Radio`)
/// - A line with the stream URL.
public class RadioStreamProvider {
    
    /// The directory URL that contains the m3u files.
    private let streamsDirectory: URL
    
    /// Initializes the provider.
    /// - Parameter streamsDirectory: The directory where m3u files are stored.
    ///   If not provided, it defaults to a folder at "External/internet-radio-streams" relative to the current working directory.
    public init(streamsDirectory: URL? = nil) {
        if let dir = streamsDirectory {
            self.streamsDirectory = dir
        } else {
            let currentPath = FileManager.default.currentDirectoryPath
            self.streamsDirectory = URL(fileURLWithPath: currentPath)
                .appendingPathComponent("External")
                .appendingPathComponent("internet-radio-streams")
        }
    }
    
    /// Loads and parses all radio streams from available m3u files.
    ///
    /// - Returns: An array of `RadioStream` objects.
    /// - Throws: A `RadioStreamError` if the directory does not exist or if file reading/parsing fails.
    public func loadStreams() throws -> [RadioStream] {
        let fileManager = FileManager.default
        
        // Verify that the directory exists.
        guard fileManager.fileExists(atPath: streamsDirectory.path) else {
            throw RadioStreamError.directoryNotFound(streamsDirectory.path)
        }
        
        // Retrieve URLs for files in the directory and filter for those with a "m3u" extension.
        let fileURLs = try fileManager.contentsOfDirectory(at: streamsDirectory,
                                                           includingPropertiesForKeys: nil,
                                                           options: .skipsHiddenFiles)
            .filter { $0.pathExtension.lowercased() == "m3u" }
        
        var streams: [RadioStream] = []
        for fileURL in fileURLs {
            do {
                let fileStreams = try parseM3UFile(at: fileURL)
                streams.append(contentsOf: fileStreams)
            } catch {
                // Log the error and continue with other files.
                print("Error parsing file \(fileURL.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return streams
    }
    
    /// Parses an individual m3u file to extract radio streams.
    ///
    /// - Parameter fileURL: The URL of the m3u file.
    /// - Returns: An array of `RadioStream` objects parsed from the file.
    /// - Throws: A `RadioStreamError` if the file cannot be read or its format is invalid.
    private func parseM3UFile(at fileURL: URL) throws -> [RadioStream] {
        // Read file contents as a string.
        let content: String
        do {
            content = try String(contentsOf: fileURL, encoding: .utf8)
        } catch {
            throw RadioStreamError.fileReadFailed(fileURL.path, underlying: error)
        }
        
        // Split the file into non-empty lines, trimming whitespace and newlines.
        let lines = content
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        // Check that the file begins with the expected "#EXTM3U" header.
        guard let firstLine = lines.first, firstLine == "#EXTM3U" else {
            throw RadioStreamError.invalidFormat("File \(fileURL.lastPathComponent) does not start with the #EXTM3U header.")
        }
        
        var streams: [RadioStream] = []
        var index = 1  // Start after the header.
        
        // Iterate over the remaining lines.
        while index < lines.count {
            let currentLine = lines[index]
            
            // If the line starts with "#EXTINF:", expect a metadata line.
            if currentLine.hasPrefix("#EXTINF:") {
                // Split the metadata line on the first comma.
                let components = currentLine.split(separator: ",", maxSplits: 1, omittingEmptySubsequences: true)
                guard components.count == 2 else {
                    index += 1
                    continue
                }
                let streamName = String(components[1]).trimmingCharacters(in: .whitespaces)
                
                // The next non-empty line should be the URL.
                index += 1
                while index < lines.count && lines[index].isEmpty {
                    index += 1
                }
                guard index < lines.count else {
                    throw RadioStreamError.invalidFormat("No URL found for stream named \(streamName) in file \(fileURL.lastPathComponent).")
                }
                let urlString = lines[index]
                guard let streamURL = URL(string: urlString) else {
                    print("Warning: Invalid URL string \(urlString) for stream \(streamName) in file \(fileURL.lastPathComponent).")
                    index += 1
                    continue
                }
                streams.append(RadioStream(name: streamName, url: streamURL))
            }
            index += 1
        }
        
        if streams.isEmpty {
            throw RadioStreamError.noStreamsFound(fileURL.lastPathComponent)
        }
        return streams
    }
    
    // MARK: - Asynchronous API (Optional)
    
    /// Asynchronously loads and parses all radio streams.
    ///
    /// - Returns: An array of `RadioStream` objects.
    /// - Throws: A `RadioStreamError` if an error occurs.
    /// - Note: Requires iOS 15.0, macOS 12.0, or later.
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
