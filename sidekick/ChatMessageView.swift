//
//  ChatMessageView.swift
//  sidekick
//
//  Created by Jakob Frick on 06/01/2024.
//

import Foundation
import SwiftUI

struct ChatMessage: Identifiable, Hashable {
  let message: String
  let role: String
  let id: UUID = UUID()
}

struct ChatMessageView: View {
  let chatMessage: ChatMessage
    @State private var hasBeenCopied = false
    

  var body: some View {
    VStack(alignment: .leading) {
        HStack{
            Text(chatMessage.role)
                .font(.subheadline)
                .fontWeight(.light)
                .foregroundStyle(.blue)
                .padding(.horizontal)
            Spacer()
            if chatMessage.role == "assistant" {
                Button(action:{
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(chatMessage.message, forType: .string)
                    hasBeenCopied = true
                    
                }, label:{
                    let buttonLabel = if hasBeenCopied 
                    { "Copied"} else {"Copy to clipboard"}
                    
                    Image(systemName: "clipboard")
                    Text(buttonLabel)
                })
            }
        }
        ScrollView {
            Text(chatMessage.message)
                .font(.title3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.black)
                .padding(.horizontal)
                .background(.clear)
                .textSelection(.enabled)
        }
    }
    .padding()
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
