//
//  dataloading.swift
//  sidekick
//
//  Created by Jakob Frick on 06/01/2024.
//

import Combine
import Foundation
import Network

public struct WireChatMessage: Codable {
  let content: String
  let role: String
}

struct ChatResponse: Decodable {
  let model: String
  let created_at: String
  let message: WireChatMessage
  let done: Bool
  let total_duration: Int?
  let context: [Int]?
}

public struct ModelsResponse: Decodable {
  let models: [ModelResponse]
}

public struct ModelResponse: Identifiable, Decodable {
  let name: String
  let modified_at: String
  let size: Int
  public var id: String { name }
}

class StreamProcessor: NSObject, URLSessionDataDelegate {
  let callbackFn: (_: String) -> Void
  let completeFn: () -> Void
  var dataBuffer = Data()

  init(
    callbackFn: @escaping @Sendable (_: String) -> Void, completeFn: @escaping @Sendable () -> Void,
    dataBuffer: Data = Data()
  ) {
    self.dataBuffer = dataBuffer
    self.completeFn = completeFn
    self.callbackFn = callbackFn
  }

  func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
    dataBuffer.append(data)
    processBuffer()
  }

  func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    completeFn()
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
          let response = try decoder.decode(ChatResponse.self, from: Data(line.utf8))
          callbackFn(response.message.content)
        } catch {
          print("Could not parse JSON: \(error)")
          print(line)
        }
      }

      processBuffer()  // Recursively process the next line
    }
  }
}

public func callLlm(
  chatMessages: [WireChatMessage], callbackFn: @escaping @Sendable (_: String) -> Void,
  completeFn: @escaping @Sendable () -> Void
) -> URLSessionDataTask? {

  let session = URLSession(
    configuration: .default,
    delegate: StreamProcessor(callbackFn: callbackFn, completeFn: completeFn), delegateQueue: nil)
  guard let url = URL(string: "http://127.0.0.1:11434/api/chat") else { return nil }
  struct RequestOptions: Codable {
    let num_predict: Int
  }

  struct RequestBody: Codable {
    let messages: [WireChatMessage]
    let model: String
    let stream: Bool
  }

  let requestBody = RequestBody(messages: chatMessages, model: "zephyr:latest", stream: true)

  var request = URLRequest(url: url)
  let body = try! JSONEncoder().encode(requestBody)
  request.addValue("application/json", forHTTPHeaderField: "content-type")
  request.httpMethod = "POST"
  request.httpBody = body

  let task = session.dataTask(with: request)
  task.resume()
  return task
}

public func checkIfOllamaIsRunning(callbackFn: @escaping @Sendable (_: Bool) -> Void) {
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

public func loadModels(callbackFn: @escaping @Sendable (_: ModelsResponse) -> Void) {
  let session = URLSession.shared
  guard let baseUrl = URL(string: "http://127.0.0.1:11434/api/tags") else {
    return
  }
  let loadModelsTask = session.dataTask(with: baseUrl) { data, response, error in
    guard let data = data else {
      return
    }

    do {
      let models = try JSONDecoder().decode(ModelsResponse.self, from: data)
      callbackFn(models)
    } catch {
      print("Failed to parsee models JSON")
      print(error)
    }
  }
  loadModelsTask.resume()
}
