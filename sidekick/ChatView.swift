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
  let message: String

  @Binding var isPresented: Bool
  @State private var textInput = ""
  @State private var isLoading = false
  @State private var connectionState = "loading"
  @State private var chatMessages: [ChatMessage] = []
  @State private var loadingMessage: ChatMessage = ChatMessage(message: "", role: "assistant")

  private func getDotColor() -> Color {
    switch self.connectionState {
    case "loading":
      return Color.blue
    case "loaded":
      return Color.green
    case "error":
      return Color.red
    default:
      return Color.orange
    }

  }

  var body: some View {
    GeometryReader { geometry in
      ZStack {
        RoundedRectangle(cornerRadius: 10)
          .fill(.ultraThinMaterial)
          .background(
            .linearGradient(
                Gradient(colors: [.white.opacity(0.7), .black.opacity(0.5)]), startPoint: .top, endPoint: .bottom)
             )
          .opacity(0.85)
          .border(.clear)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
        VStack {
          HStack {
            Circle()
              .fill(
                self.getDotColor()
              )
              .frame(width: 10, height: 10)
              .onAppear {
                checkIfOllamaIsRunning { result in
                  connectionState = if result { "loaded" } else { "error" }
                }
              }
            Text(message)
              .padding(.horizontal)
              .font(.title)
              .foregroundColor(.white)
          }.padding(.top)
          Spacer()
          if isLoading {
            ProgressView().padding(.horizontal)
          } else {
              ScrollView{
                  VStack {
                      ForEach(chatMessages) { chatMessage in
                          ChatMessageView(chatMessage: chatMessage)
                      }
                      if !loadingMessage.message.isEmpty {
                          ChatMessageView(chatMessage: loadingMessage)
                      }
                  }
              }.defaultScrollAnchor(.bottom)
          }
          Spacer()
            VStack(alignment: .leading) {
                
          TextField("Enter text here...", text: $textInput)
            .font(.title)
            .padding()
            .onSubmit {
              let prompt = textInput
                chatMessages.append(ChatMessage(message: prompt, role: "user"))

              
              isLoading = true
              DispatchQueue.global(qos: .background).async {
                callLlm(
                  prompt: prompt,
                  callbackFn: { response in

                    loadingMessage = ChatMessage(
                      message: loadingMessage.message + response, role: loadingMessage.role)
                    
                    isLoading = false
                  },
                  completeFn: {
                    chatMessages.append(loadingMessage)
                    loadingMessage = ChatMessage(message: "", role: "assistant")
                  }
                )
              }
              textInput = ""
            }
            }
              .background(.white.opacity(0.5))
              .cornerRadius(10)
              .overlay(
                Rectangle()
                  .stroke(.black.opacity(0.1), lineWidth: 1)
                  .cornerRadius(10)
                  .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 0)
                  .clipShape(
                    Rectangle()
                  )
              )
              .shadow(radius: 1)
              .padding()
        }

      }
      .ignoresSafeArea()
    }
  }

}

struct ChatView_Previews: PreviewProvider {
  static var previews: some View {
    ChatView(message: "This is a simple overlay!", isPresented: .constant(true))
      .previewDevice(PreviewDevice(rawValue: "iPhone 12"))
      .preferredColorScheme(.dark)
  }
}