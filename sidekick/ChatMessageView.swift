//
//  ChatMessageView.swift
//  sidekick
//
//  Created by Jakob Frick on 06/01/2024.
//

import Foundation
import SwiftUI

public struct ChatMessage: Identifiable, Hashable {
  var content: String
  let role: String
  public let id: UUID = UUID()
}

enum ParagraphType {
  case CODE
  case TEXT
}

struct Paragraph: Identifiable, Hashable {
  let text: String
  let type: ParagraphType
  public let id: UUID = UUID()
}

struct ChatMessageView: View {
  let chatMessage: ChatMessage
  @State private var hasBeenCopied = false
  @State private var isHovering = false
  private var paragraphs: [Paragraph] = []

  init(chatMessage: ChatMessage, hasBeenCopied: Bool = false, isHovering: Bool = false) {
    self.chatMessage = chatMessage
    self.hasBeenCopied = hasBeenCopied
    self.isHovering = isHovering

    let splits = chatMessage.content.components(separatedBy: "```")
    if splits.count == 0 {

      self.paragraphs = [Paragraph(text: chatMessage.content, type: .TEXT)]

      return
    }
    self.paragraphs = splits.enumerated().map { (idx, text) in
      if idx % 2 == 1 {
        return Paragraph(text: text, type: .CODE)
      } else {
        return Paragraph(text: text, type: .TEXT)
      }
    }
  }

  var body: some View {
    VStack(alignment: .leading) {
      HStack {
        Text(chatMessage.role)
          .font(.subheadline)
          .fontWeight(.light)
          .foregroundStyle(.blue)
          .padding(.horizontal)
        Spacer()
        if chatMessage.role == "assistant" && isHovering {
          Button(
            action: {
              copyToClipboard(text: chatMessage.content)
              hasBeenCopied = true

            },
            label: {
              if hasBeenCopied {
                Image(systemName: "checkmark")
                Text("Copied")
              } else {
                Image(systemName: "clipboard")
                Text("Copy to clipboard")
              }
            })
        }
      }
      ScrollView {
        VStack {
          ForEach(paragraphs) { paragraph in
            if paragraph.type == .CODE {
              CodeBlock(text: paragraph.text)
            } else {
              TextBlock(text: paragraph.text)
            }
          }
        }
      }
    }
    .padding()
    .background(.white.opacity(0.5))
    .cornerRadius(10)
    .onHover(perform: { hovering in
      isHovering = hovering
    })
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

struct CodeBlock: View {
  let text: String
  @State private var hasBeenCopied = false

    var body: some View {
        ZStack(alignment: .top) {
            Text(text)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .foregroundStyle(.black.opacity(0.9))
                .padding()
                .background(.gray)
                .textSelection(.enabled)
                .cornerRadius(10)
            HStack {
                Spacer()
                Button(
                    action: {
                        copyToClipboard(text: text)
                        hasBeenCopied = true
                        
                    },
                    label: {
                        if hasBeenCopied {
                            Image(systemName: "checkmark").foregroundStyle(.green)
                            
                        } else {
                            Image(systemName: "clipboard").foregroundStyle(.black)
                            
                        }
                    }).buttonStyle(.borderless)
                .padding()
            }
        }
    }
}

struct TextBlock: View {
  let text: String

  var body: some View {
    Text(text)
      .font(.title3)
      .frame(maxWidth: .infinity, alignment: .leading)
      .foregroundStyle(.black)
      .padding(.horizontal)
      .background(.clear)
      .textSelection(.enabled)
  }
}

func copyToClipboard(text: String) {
  let pasteboard = NSPasteboard.general
  pasteboard.clearContents()
  pasteboard.setString(text, forType: .string)
}
