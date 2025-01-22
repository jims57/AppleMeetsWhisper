//
//  AudioViewModel.swift
//  AppleMeetsWhisper
//
//  Created by Arnav Singhal on 14/07/24.
//

import Foundation
import AudioKit
import SwiftWhisper
import AVFoundation

class AudioViewModel: NSObject, ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var audioFile: AVAudioFile?
    private let audioSession = AVAudioSession.sharedInstance()
    private var inputNode: AVAudioInputNode?
    
    @Published var isRecording = false
    private var recordingURL: URL?
    
    override init() {
        super.init()
        #if targetEnvironment(simulator)
        print("Running in Simulator - Audio functionality may be limited")
        #endif
    }
    
    private func setupAudioSession() throws {
        // Reset the audio session first
        try? audioSession.setActive(false)
        
        // Configure audio session with basic settings
        try audioSession.setCategory(.playAndRecord)
        try audioSession.setActive(true)
        
        // Wait for the session to be fully activated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.setupAudioEngine()
        }
    }
    
    private func setupAudioEngine() {
        do {
            // Clean up any existing engine
            audioEngine?.stop()
            audioEngine = nil
            
            // Create new audio engine
            audioEngine = AVAudioEngine()
            inputNode = audioEngine?.inputNode
            
            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            recordingURL = documentsPath.appendingPathComponent("recording.wav")
            
            // Use a simpler audio format
            let recordingFormat = AVAudioFormat(standardFormatWithSampleRate: 16000, channels: 1)!
            
            // Create audio file
            audioFile = try AVAudioFile(forWriting: recordingURL!,
                                      settings: recordingFormat.settings)
            
            // Install tap with simple format
            inputNode?.installTap(onBus: 0,
                                bufferSize: 8192,
                                format: recordingFormat) { [weak self] buffer, time in
                guard let self = self,
                      let audioFile = self.audioFile else { return }
                try? audioFile.write(from: buffer)
            }
            
            // Prepare and start engine
            audioEngine?.prepare()
            try audioEngine?.start()
            
            isRecording = true
        } catch {
            print("Audio setup failed: \(error.localizedDescription)")
            isRecording = false
        }
    }
    
    func startRecording() {
        do {
            try setupAudioSession()
        } catch {
            print("Recording failed to start: \(error.localizedDescription)")
        }
    }
    
    func stopRecording(completionHandler: @escaping (Result<String, Error>) -> Void) {
        guard let recordingURL = recordingURL else { return }
        
        // Stop and cleanup
        audioEngine?.stop()
        inputNode?.removeTap(onBus: 0)
        audioEngine = nil
        isRecording = false
        
        // Deactivate audio session
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        
        // Process the recorded audio
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.extractTextFromAudio(recordingURL, completionHandler: completionHandler)
        }
    }
    
    func extractTextFromAudio(_ audioURL: URL, completionHandler: @escaping (Result<String, Error>) -> Void) {
        guard let modelURL = Bundle.main.url(forResource: "tiny", withExtension: "bin") else {
            completionHandler(.failure(NSError(domain: "Whisper", code: -1, userInfo: [NSLocalizedDescriptionKey: "Model file not found"])))
            return
        }
        
        do {
            let whisper = try Whisper(fromFileURL: modelURL)
            convertAudioFileToPCMArray(fileURL: audioURL) { result in
                switch result {
                case .success(let audioFrames):
                    Task {
                        do {
                            let segments = try await whisper.transcribe(audioFrames: audioFrames)
                            DispatchQueue.main.async {
                                completionHandler(.success(segments.map(\.text).joined()))
                            }
                        } catch {
                            DispatchQueue.main.async {
                                completionHandler(.failure(error))
                            }
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        completionHandler(.failure(error))
                    }
                }
            }
        } catch {
            completionHandler(.failure(error))
        }
    }
    
    func convertAudioFileToPCMArray(fileURL: URL, completionHandler: @escaping (Result<[Float], Error>) -> Void) {
        var options = FormatConverter.Options()
        options.format = .wav
        options.sampleRate = 16000
        options.bitDepth = 16
        options.channels = 1
        options.isInterleaved = false
        
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("temp_conversion.wav")
        let converter = FormatConverter(inputURL: fileURL, outputURL: tempURL, options: options)
        
        converter.start { error in
            if let error = error {
                completionHandler(.failure(error))
                return
            }
            
            do {
                let data = try Data(contentsOf: tempURL)
                let floats = stride(from: 44, to: data.count, by: 2).map {
                    return data[$0..<$0 + 2].withUnsafeBytes {
                        let short = Int16(littleEndian: $0.load(as: Int16.self))
                        return max(-1.0, min(Float(short) / 32767.0, 1.0))
                    }
                }
                
                try? FileManager.default.removeItem(at: tempURL)
                completionHandler(.success(floats))
                
            } catch {
                completionHandler(.failure(error))
            }
        }
    }
}
