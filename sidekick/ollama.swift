//
//  dataloading.swift
//  sidekick
//
//  Created by Jakob Frick on 06/01/2024.
//

import Combine
import Foundation
import Network

struct Response: Decodable {
  let model: String
  let created_at: String
  let response: String
  let done: Bool
  let context: [Int]?
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

public func callLlm(
  prompt: String, callbackFn: @escaping @Sendable (_: String) -> Void,
  completeFn: @escaping @Sendable () -> Void
) {

  let session = URLSession(
    configuration: .default,
    delegate: StreamProcessor(callbackFn: callbackFn, completeFn: completeFn), delegateQueue: nil)
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
