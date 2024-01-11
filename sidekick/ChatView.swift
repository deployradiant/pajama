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
  @State private var connectionStatus: ConnectionStatus = .CONNECTING
  @State private var selectedModel: String?
  @State private var textInput = ""
  @State private var loadingTask: URLSessionDataTask? = nil
  @State private var showSidebar = true
  @State private var chatMessages: [ChatMessage] = []
  @FocusState private var textInputFocused: Bool
  @State private var loadingMessage: ChatMessage = ChatMessage(content: "", role: "assistant")

  var body: some View {
    ZStack(alignment: .top) {
      HStack(spacing: 0) {
          Sidebar(selectedModel: $selectedModel, connectionStatus: $connectionStatus).frame(
          maxWidth: showSidebar ? 200 : 0, maxHeight: .infinity, alignment: .top
        ).background(.gray)
        ZStack {
          Rectangle()
            .fill(.ultraThinMaterial)
            .background(
              .linearGradient(
                Gradient(colors: [.black.opacity(0.3), .black.opacity(0.3)]), startPoint: .top,
                endPoint: .bottom)
            )
            .opacity(0.9)
            .border(.clear)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

          VStack {
            Spacer(minLength: 20).fixedSize()
            Spacer()
            if connectionStatus == .CONNECTING {
                Spacer()
                ProgressView()
                Spacer()
            } else if connectionStatus == .CONNECTED {
              ScrollViewReader { viewReader in
                ScrollView {
                  VStack(alignment: .center, spacing: 20) {
                    ForEach(chatMessages) { chatMessage in
                      ChatMessageView(
                        chatMessage: .constant(chatMessage), finishedRendering: .constant(true))
                    }
                    if !loadingMessage.content.isEmpty {
                      ChatMessageView(
                        chatMessage: $loadingMessage, finishedRendering: .constant(false))
                    } else if loadingTask != nil {
                      ProgressView().padding(.horizontal)
                    }
                  }
                } // .defaultScrollAnchor(.bottom)
              }
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
                .focused($textInputFocused, equals: true)
                .onAppear {
                  DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.textInputFocused = true
                  }
                }
                .foregroundColor(.white)
                .border(.secondary)
                .onSubmit {
                  if loadingTask != nil || selectedModel == nil {
                    return
                  }
                  let prompt = textInput
                  chatMessages.append(ChatMessage(content: prompt, role: "user"))
                  DispatchQueue.global(qos: .background).async {
                    loadingTask = callLlm(
                      model: selectedModel!,
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
            } else if connectionStatus == .ERROR {
              Text("Could not connect ollama, is it running?")
              Spacer()
              Button(
                action: {
                  connectionStatus = .CONNECTING
                  DispatchQueue.global(qos: .background).async {
                    let _ = runBashCommand(command: "/usr/local/bin/ollama run zephyr \"\"")
                    checkConnectionStatus()
                  }
                },
                label: {
                  Text("Start ollama server")
                }
              )
              .buttonStyle(.borderedProminent)
              Spacer()
            } else {
              Spacer()
              Text("It appears ollama is not installed under /usr/local/bin/ollama.")
              Link(destination: URL(string: "https://ollama.ai")!) {
                Text("Get ollama")
              }
              Spacer()
            }

          }
        }
        .ignoresSafeArea()
      }
      VStack {
        Spacer(minLength: 5).fixedSize()
        HStack(alignment: .top) {
          Spacer(minLength: 70).fixedSize()
          HStack {
            Button {
              showSidebar = !showSidebar
            } label: {
              Image(systemName: "sidebar.left").imageScale(.large)
            }.buttonStyle(.borderless)
            Button {
              chatMessages = []
            } label: {
              Image(systemName: "trash.circle").imageScale(.large)
            }.buttonStyle(.borderless)
          }
          ConnectionStatusView(state: $connectionStatus).padding(.horizontal)
            .onAppear {
              checkConnectionStatus()
            }
        }
      }.ignoresSafeArea()
    }
  }

  private func checkConnectionStatus() -> Void {
    checkIfOllamaIsRunning { result in
      connectionStatus = if result {
         .CONNECTED
        } else {
          if checkIfOllamaInstalled() {
            .ERROR
          } else {
            .NOT_INSTALLED
          }
        }
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

struct Sidebar: View {
  @Binding var selectedModel: String?
  @Binding var connectionStatus: ConnectionStatus
  @State var isPullingModel: Bool = false
  @State private var models: [ModelResponse] = []

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Rectangle().frame(height: 1).opacity(0.5)
      HStack {
        Text("Available models")
        Spacer()
        if isPullingModel {
          ProgressView()
        } else {
          PullModelView(isPullingModel: $isPullingModel)
        }
      }.padding(.horizontal)
      Rectangle().frame(height: 1).opacity(0.5)
      List(models, selection: $selectedModel) { model in
        Text(model.name)
      }.listStyle(.sidebar).scrollContentBackground(.hidden).background(.clear).onChange(
        of: selectedModel,
        {
          if selectedModel == nil {
            return
          }
          setSelectedModel(model: selectedModel!)
        })
    }.onChange(
      of: isPullingModel, initial: false,
      {
        if isPullingModel {
          return
        }
        loadModels(callbackFn: setModels)
      }).onChange(of: connectionStatus, {
          if connectionStatus == .CONNECTED {
              loadModels(callbackFn: setModels)
          }
      })
  }

  @Sendable func setModels(response: ModelsResponse) {
    models = response.models
    if selectedModel == nil {
      if let storedModel = getSelectedModel() {
        selectedModel = storedModel
      } else {
        selectedModel = models.first?.id
      }
    }
  }
}

struct PullModelView: View {
  @State var showingPopover: Bool = false
  @State var modelToPullName: String = ""
  @Binding var isPullingModel: Bool

  var body: some View {
    Button(
      action: {
        showingPopover = true
      },
      label: {
        Image(systemName: "plus")
      }
    ).buttonStyle(.borderless)
      .popover(isPresented: $showingPopover) {
        VStack {
          TextField("Model name...", text: $modelToPullName).onSubmit {
            onPullModel()
          }
          Button("Pull model") {
            onPullModel()
          }
        }.padding().frame(width: 200)
      }
  }

  func onPullModel() {
    if modelToPullName.isEmpty {
      return
    }
    isPullingModel = true
    DispatchQueue.global(qos: .background).async {
      pullModel(modelName: modelToPullName) { success in
        isPullingModel = false
      }
    }
  }
}
