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
  @State private var loadingTask: URLSessionDataTask? = nil
  @State private var showSidebar = true
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
          Spacer(minLength: 5).fixedSize()
          HStack(alignment: .top) {
            Spacer(minLength: 70).fixedSize()
            Button {
              showSidebar = !showSidebar
            } label: {
              Image(systemName: "sidebar.left").imageScale(.large)
            }.buttonStyle(.borderless)
            ConnectionStatusView(state: $connectionState).padding(.horizontal)
              .onAppear {
                checkIfOllamaIsRunning { result in
                  connectionState = if result { .CONNECTED } else { .ERROR }
                }
              }
          }
          Spacer()
          if connectionState == .CONNECTING {
            ProgressView()
          } else if connectionState == .CONNECTED {
            ScrollView {
              VStack(alignment: .center, spacing: 20) {
                ForEach(chatMessages) { chatMessage in
                    ChatMessageView(chatMessage: .constant(chatMessage), finishedRendering: .constant(true))
                }
                  if !loadingMessage.content.isEmpty {
                      ChatMessageView(chatMessage: $loadingMessage, finishedRendering: .constant(false))
                  } else if loadingTask != nil {
                  ProgressView().padding(.horizontal)
                }
              }
            }.defaultScrollAnchor(.bottom)
            Spacer()
            if loadingTask != nil {
              Button {
                loadingTask?.cancel()
                loadingTask = nil
              } label: {
                Image(systemName: "stop.circle").imageScale(.large)
              }.buttonStyle(.borderless)
            }
            TextField("Enter text here...", text: $textInput, axis: .vertical)
              .font(.title3)
              .foregroundColor(.white)
              .border(.secondary)
              .onSubmit {
                if loadingTask != nil {
                  return
                }
                let prompt = textInput
                chatMessages.append(ChatMessage(content: prompt, role: "user"))
                DispatchQueue.global(qos: .background).async {
                  loadingTask = callLlm(
                    chatMessages: chatMessages.map({ message in
                      WireChatMessage(content: message.content, role: message.role)
                    }),
                    callbackFn: { response in
                      loadingMessage.content += response
                    },
                    completeFn: {
                      chatMessages.append(loadingMessage)
                      loadingTask = nil
                      loadingMessage = ChatMessage(content: "", role: "assistant")
                    }
                  )
                }
                textInput = ""
              }.padding()
              .background(.white.opacity(0.2))
              .cornerRadius(10)
              .padding()
          } else {
            Text("Could not connect ollama, is it running?")
            Spacer()
            Button(
              action: {
                connectionState = .CONNECTING
                DispatchQueue.global(qos: .background).async {
                  let _ = runBashCommand(command: "/usr/local/bin/ollama run zephyr \"\"")
                  checkIfOllamaIsRunning { result in
                    connectionState = if result { .CONNECTED } else { .ERROR }
                  }
                }
              },
              label: {
                Text("Start ollama server")
              }
            )
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
