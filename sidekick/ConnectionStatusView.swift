//
//  ConnectionStatusView.swift
//  sidekick
//
//  Created by Jakob Frick on 07/01/2024.
//

import Foundation
import SwiftUI

enum ConnectionStatus {
  case CONNECTING
  case CONNECTED
  case ERROR
}

struct ConnectionStatusView: View {
  @Binding var state: ConnectionStatus

  var body: some View {
      HStack {
      Spacer()
      Circle()
        .fill(
          self.getDotColor()
        )
        .frame(width: 10, height: 10)
      Text(self.getConnectionMessage())
        .font(.title3)
        .foregroundColor(.white)
    }
  }

  private func getDotColor() -> Color {
    switch self.state {
    case .CONNECTING:
      return Color.blue
    case .CONNECTED:
      return Color.green
    case .ERROR:
      return Color.red
    }
  }

  private func getConnectionMessage() -> String {
    switch self.state {
    case .CONNECTING:
      return "Connecting..."
    case .CONNECTED:
      return "Ollama is running"
    case .ERROR:
      return "Failed to connect"
    }
  }
}
