//
//  ContentView.swift
//  AppleMeetsWhisper
//
//  Created by Arnav Singhal on 14/07/24.
//

import SwiftUI

struct ContentView: View {
    
    @State var startImporting: Bool = false
    @State var processing: Bool = false
    @State var audioTranscription: String?
    
    var audioVM = AudioViewModel()
    
    var body: some View {
        VStack {
            Button("Import Audio") {
                self.processing = false
                self.audioTranscription = nil
                self.startImporting.toggle()
            }
            
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
        .fileImporter(isPresented: $startImporting, allowedContentTypes: [.audio]) { result in
            handleFileMediaResponse(result)
        }
    }
    
    func handleFileMediaResponse(_ result: Result<URL, any Error>) {
        switch result {
            case .success(let success):
                self.processing = true
                _ = success.startAccessingSecurityScopedResource()
                audioVM.extractTextFromAudio(success.absoluteURL) { result in
                    switch result {
                        case .success(let success):
                            self.processing = false
                            self.audioTranscription = success
                        case .failure(let failure):
                            print(failure)
                    }
                }
            case .failure(let failure):
                print(failure)
        }
    }
}

#Preview {
    ContentView()
}
