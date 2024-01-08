//
//  ContentView.swift
//  sidekick
//
//  Created by Jakob Frick on 06/01/2024.
//

import Combine
import Foundation
import Network
import SwiftUI



struct ChatView: View {
  @Binding var isPresented: Bool
  @State private var connectionState: ConnectionStatus = .CONNECTING
  
  @State private var textInput = ""
  @State private var isLoading = false
  @State private var chatMessages: [ChatMessage] = []
  @State private var loadingMessage: ChatMessage = ChatMessage(content: "", role: "assistant")

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        RoundedRectangle(cornerRadius: 10)
          .fill(.ultraThinMaterial)
          .background(
            .linearGradient(
              Gradient(colors: [.white.opacity(0.8), .black.opacity(0.3)]), startPoint: .top,
              endPoint: .bottom)
          )
          .opacity(0.85)
          .border(.clear)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          VStack {
              ConnectionStatusView(state: $connectionState).padding(.horizontal)
                  .onAppear {
                      checkIfOllamaIsRunning { result in
                          connectionState = if result { .CONNECTED } else { .ERROR }
                      }
                  }
              Spacer()
              if connectionState == .CONNECTING {
                  ProgressView()
              } else if connectionState == .CONNECTED {
                  ScrollView {
                      VStack(alignment: .center, spacing: 20) {
                          ForEach(chatMessages) { chatMessage in
                              ChatMessageView(chatMessage: chatMessage, finishedRendering: true)
                          }
                          if isLoading && chatMessages.count < 2 {
                              ProgressView().padding(.horizontal)
                          } else {
                              if !loadingMessage.content.isEmpty {
                                  ChatMessageView(chatMessage: loadingMessage, finishedRendering: false)
                              }
                          }
                      }
                  }.defaultScrollAnchor(.bottom)
                  Spacer()
                  VStack(alignment: .leading) {
                      TextField("Enter text here...", text: $textInput)
                          .font(.title3)
                          .foregroundColor(.black)
                          .padding()
                          .onSubmit {
                              let prompt = textInput
                              chatMessages.append(ChatMessage(content: prompt, role: "user"))
                              
                              isLoading = true
                              DispatchQueue.global(qos: .background).async {
                                  callLlm(
                                    chatMessages: chatMessages.map({ message in
                                        WireChatMessage(content: message.content, role: message.role)
                                    }),
                                    callbackFn: { response in
                                        loadingMessage.content += response
                                        isLoading = false
                                    },
                                    completeFn: {
                                        chatMessages.append(loadingMessage)
                                        loadingMessage = ChatMessage(content: "", role: "assistant")
                                    }
                                  )
                              }
                              textInput = ""
                          }
                  }
                  .background(.white.opacity(0.8))
                  .cornerRadius(10)
                  .padding()
              } else {
                  Text("Could not connect ollama, is it running?")
                  Spacer()
                  Button(action: {
                      connectionState = .CONNECTING
                      DispatchQueue.global(qos: .background).async {
                         let _ = runBashCommand(command: "/usr/local/bin/ollama run zephyr \"\"")
                         checkIfOllamaIsRunning { result in
                              connectionState = if result { .CONNECTED } else { .ERROR }
                         }
                      }
                  }, label: {
                    Text("Start ollama server")
                  })
                  .buttonStyle(.borderedProminent)
                  Spacer()
              }
          }
      }
      .ignoresSafeArea()
    }
  }

}

struct ChatView_Previews: PreviewProvider {
  static var previews: some View {
    ChatView(isPresented: .constant(true))
      .previewDevice(PreviewDevice(rawValue: "iPhone 12"))
      .preferredColorScheme(.dark)
  }
}
