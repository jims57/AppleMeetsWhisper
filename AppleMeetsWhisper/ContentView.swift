//
//  ContentView.swift
//  AppleMeetsWhisper
//
//  Created by Arnav Singhal on 14/07/24.
//

import SwiftUI

struct ContentView: View {
    @StateObject var audioVM = AudioViewModel()
    @State var processing: Bool = false
    @State var audioTranscription: String?
    
    var body: some View {
        VStack {
            Button(audioVM.isRecording ? "Stop Recording" : "Start Recording") {
                if audioVM.isRecording {
                    self.processing = true
                    audioVM.stopRecording { result in
                        switch result {
                            case .success(let transcription):
                                self.processing = false
                                self.audioTranscription = transcription
                            case .failure(let error):
                                print(error)
                                self.processing = false
                        }
                    }
                } else {
                    self.audioTranscription = nil
                    audioVM.startRecording()
                }
            }
            .buttonStyle(.borderedProminent)
            
            ScrollView {
                if let audioTranscription {
                    Text(audioTranscription)
                        .multilineTextAlignment(.leading)
                } else if processing {
                    ProgressView()
                }
            }
        }
        .padding()
    }
}

#Preview {
    ContentView()
}
