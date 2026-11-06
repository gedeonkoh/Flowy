//
//  CallView.swift
//  Flowly
//
//  Created by Gedeon Koh on 8/12/25.
//

import SwiftUI
import Speech
import AVFoundation

struct CallView: View {
    @StateObject private var callManager = CallManager()
    @State private var isCallActive = false
    @State private var callDuration: TimeInterval = 0
    @State private var timer: Timer?
    
    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [Color(red: 0.2, green: 0.1, blue: 0.4), Color(red: 0.4, green: 0.2, blue: 0.6), Color(red: 0.1, green: 0.2, blue: 0.5)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            if isCallActive {
                activeCallView
            } else {
                noCallView
            }
        }
    }
    
    private var noCallView: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // Large AI agent icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.3), Color.white.opacity(0.1)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
                
                Text("🤖")
                    .font(.system(size: 60))
            }
            
            Text("No active calls")
                .font(.system(size: 24, weight: .medium, design: .rounded))
                .foregroundColor(.white)
            
            // Call button
            Button(action: {
                startCall()
            }) {
                LiquidGlassButton(title: "Call one of our agents here", icon: "phone.fill")
            }
            
            Spacer()
        }
        .padding()
    }
    
    private var activeCallView: some View {
        VStack(spacing: 20) {
            // Status bar info
            HStack {
                Text(timeString(from: callDuration))
                    .font(.system(size: 16, weight: .medium, design: .rounded))
                    .foregroundColor(.white.opacity(0.8))
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 8)
            
            // Call duration
            Text(timeString(from: callDuration))
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
            
            // Agent name
            Text("Assistant")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            // Large emoji face
            Text("😊")
                .font(.system(size: 100))
            
            // Speech bubble with AI response
            if !callManager.currentResponse.isEmpty {
                SpeechBubble(text: callManager.currentResponse)
                    .padding(.horizontal, 40)
            } else if callManager.isProcessing {
                SpeechBubble(text: "Thinking...")
                    .padding(.horizontal, 40)
            } else if callManager.isSpeaking {
                SpeechBubble(text: callManager.currentResponse)
                    .padding(.horizontal, 40)
            }
            
            // Audio visualizer - show when listening or speaking
            AudioVisualizer(isActive: callManager.isListening || callManager.isSpeaking)
                .frame(height: 40)
                .padding(.horizontal, 40)
            
            Spacer()
            
            // Text input field
            TextInputField(callManager: callManager)
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
            
            // Call controls
            HStack(spacing: 40) {
                // Speaker button
                CallControlButton(
                    icon: "speaker.wave.2.fill",
                    title: "Speaker",
                    color: callManager.isSpeakerOn ? .white : Color(red: 0.2, green: 0.3, blue: 0.5)
                ) {
                    callManager.toggleSpeaker()
                }
                
                // Voice input button (press and hold)
                VoiceInputButton(callManager: callManager)
                
                // Hang up button
                CallControlButton(icon: "phone.down.fill", title: "End", color: .red) {
                    endCall()
                }
            }
            .padding(.bottom, 40)
        }
    }
    
    private func startCall() {
        isCallActive = true
        callManager.startCall()
        startTimer()
    }
    
    private func endCall() {
        isCallActive = false
        callManager.endCall()
        stopTimer()
        callDuration = 0
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            callDuration += 1
        }
    }
    
    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
    
    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct LiquidGlassButton: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
            Text(title)
                .font(.system(size: 18, weight: .semibold, design: .rounded))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 32)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 25)
                .fill(
                    LinearGradient(
                        colors: [Color.white.opacity(0.25), Color.white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.white.opacity(0.1))
                        .blur(radius: 10)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 25)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.5), Color.white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

struct SpeechBubble: View {
    let text: String
    
    var body: some View {
        Text(text)
            .font(.system(size: 16, weight: .regular, design: .rounded))
            .foregroundColor(.black)
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.95))
            )
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
    }
}

struct AudioVisualizer: View {
    let isActive: Bool
    @State private var animationAmounts: [CGFloat] = [0.3, 0.5, 0.4, 0.6, 0.3, 0.5, 0.4]
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<7) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.white.opacity(0.8))
                    .frame(width: 4, height: isActive ? animationAmounts[index] * 40 : 8)
                    .animation(
                        Animation.easeInOut(duration: 0.3)
                            .repeatForever()
                            .delay(Double(index) * 0.1),
                        value: isActive
                    )
            }
        }
        .onAppear {
            if isActive {
                startAnimation()
            }
        }
        .onChange(of: isActive) { newValue in
            if newValue {
                startAnimation()
            }
        }
    }
    
    private func startAnimation() {
        for i in 0..<animationAmounts.count {
            animationAmounts[i] = CGFloat.random(in: 0.3...1.0)
        }
    }
}

struct CallControlButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 8) {
            Button(action: action) {
                Circle()
                    .fill(color)
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    )
            }
            
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

struct TextInputField: View {
    @ObservedObject var callManager: CallManager
    @State private var textInput = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            TextField("Type your message...", text: $textInput)
                .font(.system(size: 16, design: .rounded))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 25)
                        .fill(Color.white.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 25)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                )
                .focused($isFocused)
                .onSubmit {
                    sendMessage()
                }
            
            Button(action: sendMessage) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.white)
            }
            .disabled(textInput.trimmingCharacters(in: .whitespaces).isEmpty || callManager.isProcessing)
        }
    }
    
    private func sendMessage() {
        let message = textInput.trimmingCharacters(in: .whitespaces)
        guard !message.isEmpty else { return }
        
        textInput = ""
        isFocused = false
        
        // Process the typed message
        callManager.processTextInput(message)
    }
}

struct VoiceInputButton: View {
    @ObservedObject var callManager: CallManager
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 8) {
            Button(action: {}) {
                Circle()
                    .fill(isPressed ? Color.red : Color(red: 0.3, green: 0.5, blue: 0.7))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: isPressed ? "mic.fill" : "mic")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundColor(.white)
                    )
                    .scaleEffect(isPressed ? 1.1 : 1.0)
                    .animation(.spring(response: 0.3), value: isPressed)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            callManager.startVoiceInput()
                        }
                    }
                    .onEnded { _ in
                        if isPressed {
                            isPressed = false
                            callManager.stopVoiceInput()
                        }
                    }
            )
            
            Text("Hold to Talk")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundColor(.white)
        }
    }
}

#Preview {
    CallView()
}

