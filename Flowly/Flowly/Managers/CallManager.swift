//
//  CallManager.swift
//  Flowly
//
//  Created by Gedeon Koh on 8/12/25.
//

import Foundation
import Speech
import AVFoundation
import Combine

class CallManager: ObservableObject {
    @Published var isListening = false
    @Published var currentResponse = ""
    @Published var isProcessing = false
    @Published var isSpeaking = false
    @Published var isSpeakerOn = false
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    private let aiService = AIService.shared
    private let speechSynthesizer = AVSpeechSynthesizer()
    
    func startCall() {
        requestSpeechAuthorization()
    }
    
    func endCall() {
        stopListening()
        stopSpeaking()
        currentResponse = ""
        isProcessing = false
    }
    
    private func requestSpeechAuthorization() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self?.startListening()
                case .denied, .restricted, .notDetermined:
                    self?.currentResponse = "Please enable microphone access in Settings"
                @unknown default:
                    break
                }
            }
        }
    }
    
    private func startListening() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            currentResponse = "Speech recognition is not available"
            return
        }
        
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest = recognitionRequest else { return }
            recognitionRequest.shouldReportPartialResults = true
            
            recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self = self else { return }
                
                if let result = result {
                    let transcript = result.bestTranscription.formattedString
                    if result.isFinal && !transcript.isEmpty {
                        self.processUserInput(transcript)
                    }
                }
                
                if let error = error {
                    print("Recognition error: \(error)")
                    self.stopListening()
                }
            }
            
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
                self.recognitionRequest?.append(buffer)
            }
            
            audioEngine.prepare()
            try audioEngine.start()
            isListening = true
            
        } catch {
            currentResponse = "Error starting speech recognition: \(error.localizedDescription)"
        }
    }
    
    private func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        isListening = false
        
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(false)
    }
    
    private func processUserInput(_ input: String) {
        isProcessing = true
        stopListening()
        
        _Concurrency.Task { [weak self] in
            guard let self = self else { return }
            do {
                let response = try await self.aiService.processUserCommand(input)
                await MainActor.run {
                    self.currentResponse = response
                    self.isProcessing = false
                    // Speak the response
                    self.speakText(response)
                }
            } catch {
                await MainActor.run {
                    let errorMessage = "I'm sorry, I encountered an error. Please try again."
                    self.currentResponse = errorMessage
                    self.isProcessing = false
                    self.speakText(errorMessage)
                }
            }
        }
    }
    
    private func speakText(_ text: String) {
        // Add follow-up question if it's a successful action
        let fullText: String
        if text.contains("Done!") || text.contains("I've") || text.contains("scheduled") || text.contains("added") {
            fullText = "\(text) Is there anything else I can help you with?"
        } else {
            fullText = text
        }
        
        let utterance = AVSpeechUtterance(string: fullText)
        
        // Use a more expressive voice
        if let voice = AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.Samantha-compact") {
            utterance.voice = voice
        } else if let voice = AVSpeechSynthesisVoice(language: "en-US") {
            utterance.voice = voice
        }
        
        // More expressive settings
        utterance.rate = 0.48  // Slightly slower for clarity
        utterance.pitchMultiplier = 1.15  // Higher pitch for more expression
        utterance.volume = 1.0
        
        // Add pauses for better expression
        utterance.preUtteranceDelay = 0.1
        utterance.postUtteranceDelay = 0.2
        
        // Update current response to show the full text
        currentResponse = fullText
        isSpeaking = true
        
        speechSynthesizer.speak(utterance)
        
        // Restart listening after speech finishes
        DispatchQueue.main.asyncAfter(deadline: .now() + Double(fullText.count) * 0.1 + 1.0) {
            self.isSpeaking = false
            self.startListening()
        }
    }
    
    func stopSpeaking() {
        speechSynthesizer.stopSpeaking(at: .immediate)
        isSpeaking = false
    }
    
    func processTextInput(_ input: String) {
        isProcessing = true
        stopListening()
        
        _Concurrency.Task { [weak self] in
            guard let self = self else { return }
            do {
                let response = try await self.aiService.processUserCommand(input)
                await MainActor.run {
                    self.currentResponse = response
                    self.isProcessing = false
                    // Speak the response
                    self.speakText(response)
                }
            } catch {
                await MainActor.run {
                    let errorMessage = "I'm sorry, I encountered an error. Please try again."
                    self.currentResponse = errorMessage
                    self.isProcessing = false
                    self.speakText(errorMessage)
                }
            }
        }
    }
    
    func toggleSpeaker() {
        isSpeakerOn.toggle()
        let audioSession = AVAudioSession.sharedInstance()
        do {
            if isSpeakerOn {
                try audioSession.overrideOutputAudioPort(.speaker)
            } else {
                try audioSession.overrideOutputAudioPort(.none)
            }
        } catch {
            print("Error toggling speaker: \(error)")
        }
    }
    
    func startVoiceInput() {
        // Stop any current listening
        stopListening()
        stopSpeaking()
        
        // Start recording
        requestSpeechAuthorization()
    }
    
    func stopVoiceInput() {
        // Stop listening and process the input
        if recognitionRequest != nil {
            recognitionRequest?.endAudio()
            // Give it a moment to finalize, then process
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                // The recognition task will call processUserInput when final
            }
        }
    }
}

