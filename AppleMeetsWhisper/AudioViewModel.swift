//
//  AudioViewModel.swift
//  AppleMeetsWhisper
//
//  Created by Arnav Singhal on 14/07/24.
//

import Foundation
import AudioKit
import SwiftWhisper

class AudioViewModel {
    
    func extractTextFromAudio(_ audioURL: URL, completionHandler: @escaping (Result<String, Error>) ->Void) {
        let modelURL = Bundle.main.url(forResource: "tiny", withExtension: "bin")!
        let whisper = Whisper(fromFileURL: modelURL)
        convertAudioFileToPCMArray(fileURL: audioURL) { result in
            switch result {
                case .success(let success):
                    Task {
                        do {
                            let segments = try await whisper.transcribe(audioFrames: success)
                            completionHandler(.success(segments.map(\.text).joined()))
                        } catch {
                            completionHandler(.failure(error))
                        }
                    }
                case .failure(let failure):
                    completionHandler(.failure(failure))
            }
        }
    }
    
    func convertAudioFileToPCMArray(fileURL: URL, completionHandler: @escaping (Result<[Float], Error>) ->Void) {
        var options = FormatConverter.Options()
        options.format = .wav
        options.sampleRate = 16000
        options.bitDepth = 16
        options.channels = 1
        options.isInterleaved = false
        
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        let converter = FormatConverter(inputURL: fileURL, outputURL: tempURL, options: options)
        converter.start { error in
            if let error {
                completionHandler(.failure(error))
                return
            }
            
            let data = try! Data(contentsOf: tempURL)
            
            let floats = stride(from: 44, to: data.count, by: 2).map {
                return data[$0..<$0 + 2].withUnsafeBytes {
                    let short = Int16(littleEndian: $0.load(as: Int16.self))
                    return max(-1.0, min(Float(short) / 32767.0, 1.0))
                }
            }
            
            try? FileManager.default.removeItem(at: tempURL)
            
            completionHandler(.success(floats))
        }
    }
    
}
