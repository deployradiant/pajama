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

struct Response: Decodable {
  let model: String
  let created_at: String
  let response: String
  let done: Bool
  let context: [Int]?
}

struct ChatView: View {
  let message: String

  @Binding var isPresented: Bool
  @State private var textInput = ""
  @State private var responseText = ""
  @State private var isLoading = false
  @State private var connectionState = "loading"

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
            .radialGradient(
              AnyGradient(Gradient(colors: [.white.opacity(0.5), .black.opacity(0.5)])),
              endRadius: CGFloat(1000))
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
            InfiniteProgressView().padding(.horizontal)
          } else {
            Text(responseText)
              .font(.title3)
              .foregroundStyle(.white)
              .padding(.horizontal)
              .background(.clear)
              .textSelection(.enabled)
              .scrollTarget(isEnabled: true)
          }
          Spacer()
          TextField("Enter text here...", text: $textInput)
            .font(.title3)
            .padding()
            .onSubmit {
              let prompt = self.textInput
              self.responseText = ""
              self.isLoading = true
              DispatchQueue.global(qos: .background).async {
                callLlm(
                  prompt: prompt,

                  callbackFn: { response in
                    self.responseText += response
                    self.isLoading = false
                  })
              }
              self.textInput = ""
            }
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

struct InfiniteProgressView: View {
  private let timerPublisher = Timer.publish(every: 0.1, on: .current, in: .default).autoconnect()
  @State private var counter: Float = 0

  var body: some View {
    GeometryReader { geometry in
      ProgressView(value: counter, total: 10)
    }.onReceive(timerPublisher) { _ in
      self.incrementCounter()
    }
  }

  private func incrementCounter() {
    self.counter = (self.counter + 0.1).truncatingRemainder(dividingBy: 10)
  }
}

class StreamProcessor: NSObject, URLSessionDataDelegate {
  let callbackFn: (_: String) -> Void
  var dataBuffer = Data()

  init(callbackFn: @escaping @Sendable (_: String) -> Void, dataBuffer: Data = Data()) {
    self.dataBuffer = dataBuffer
    self.callbackFn = callbackFn
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    dataBuffer.append(data)
    processBuffer()
  }

  func processBuffer() {
    // Find the range to the first newline character
    if let range = dataBuffer.range(of: Data("\n".utf8)) {
      let lineData = dataBuffer.subdata(in: 0..<range.lowerBound)
      dataBuffer.removeSubrange(0..<range.upperBound)

      if let line = String(data: lineData, encoding: .utf8) {

        do {
          // Parse the JSON data
          let decoder = JSONDecoder()
          let response = try decoder.decode(Response.self, from: Data(line.utf8))
          callbackFn(response.response)

        } catch {
          print("Could not parse JSON: \(error)")
          print(line)
        }
      }

      processBuffer()  // Recursively process the next line
    }
  }
}

func checkIfOllamaIsRunning(callbackFn: @escaping @Sendable (_: Bool) -> Void) {
  let session = URLSession.shared

  guard let baseUrl = URL(string: "http://127.0.0.1:11434") else {
    callbackFn(false)
    return
  }
  let checkTask = session.dataTask(with: baseUrl) { data, response, error in
    guard let data = data else {
      callbackFn(false)
      return
    }
    callbackFn(String(data: data, encoding: .utf8)! == "Ollama is running")
  }
  checkTask.resume()
}

func callLlm(prompt: String, callbackFn: @escaping @Sendable (_: String) -> Void) {

  let session = URLSession(
    configuration: .default, delegate: StreamProcessor(callbackFn: callbackFn), delegateQueue: nil)
  guard let url = URL(string: "http://127.0.0.1:11434/api/generate") else { return }
  struct RequestOptions: Codable {
    let num_predict: Int
  }

  struct RequestBody: Codable {
    let prompt: String
    let model: String

  }

  let requestBody = RequestBody(prompt: prompt, model: "zephyr:latest")

  var request = URLRequest(url: url)
  let body = try! JSONEncoder().encode(requestBody)
  request.addValue("application/json", forHTTPHeaderField: "content-type")
  request.httpMethod = "POST"
  request.httpBody = body

  let task = session.dataTask(with: request)

  task.resume()

}
