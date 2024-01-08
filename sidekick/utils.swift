//
//  utils.swift
//  sidekick
//
//  Created by Jakob Frick on 07/01/2024.
//

import Foundation


func runBashCommand(command: String) -> String? {
    let process = Process()
    let pipe = Pipe()

    process.launchPath = "/bin/bash"
    process.arguments = ["-c", command]
    process.standardOutput = pipe
    process.standardError = pipe

    do {
        try process.run()
    } catch {
        print("Error: \(error.localizedDescription)")
        return nil
    }

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    let output = String(data: data, encoding: .utf8)
    
    return output
}
