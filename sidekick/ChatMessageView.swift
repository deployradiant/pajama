//
//  ChatMessageView.swift
//  sidekick
//
//  Created by Jakob Frick on 06/01/2024.
//

import Foundation
import SwiftUI
import Highlighter


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
    let finishedRendering: Bool
  
  @State private var hasBeenCopied = false
  @State private var isHovering = false
  private var paragraphs: [Paragraph] = []

  init(
    chatMessage: ChatMessage, finishedRendering: Bool = true, hasBeenCopied: Bool = false,
    isHovering: Bool = false
  ) {
    self.chatMessage = chatMessage
      self.finishedRendering = finishedRendering
    self.hasBeenCopied = hasBeenCopied
    self.isHovering = isHovering
    print("finishedRendering", finishedRendering)
      
    

    let splits = chatMessage.content.components(separatedBy: "```")
    if splits.count == 0 {
      self.paragraphs = [Paragraph(text: chatMessage.content, type: .TEXT)]
      return
    }
    self.paragraphs = splits.enumerated().map { (idx, text) in
      if idx % 2 == 1 {
        return Paragraph(text: ">>>" + text, type: .CODE)
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
        if chatMessage.role == "assistant" && isHovering && false {
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
                CodeBlock(text: paragraph.text, highlightText: finishedRendering)
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


class HighlightedTextModel: ObservableObject {
    @Published var highlightedText: NSAttributedString = .init(string: "")
    @Published var inputText = ""
    @Published var hasBeenCopied = false
    
    private var copyMessageTimer: Timer?
    
    func highlightText() {
        if let highlighter = Highlighter() {
            highlighter.setTheme("tomorrow")
            let lines = inputText.split(separator: "\n")
            if let firstLine = lines.first {
                if firstLine.starts(with: ">>>") {
                    
                }
            }
            
            
            if let highlighted = highlighter.highlight(inputText, as: "swift") {
                highlightedText = highlighted
            } else {
                print("Failed to highlight text")
            }
        } else {
            print("Failed to initialise highlighter")
        }
    }
    
    func copyCode() {
        copyToClipboard(text: inputText)
        hasBeenCopied = true
        
        copyMessageTimer?.invalidate()
        let timer = Timer(timeInterval: 1, repeats: false, block: { _ in
            self.hasBeenCopied = false
        })
        copyMessageTimer = timer
        RunLoop.current.add(timer, forMode: .common)
    }
}


struct CodeBlock: View {
  let text: String
    let highlightText: Bool
  @ObservedObject var textModel = HighlightedTextModel()
  
    init(text: String, highlightText: Bool) {
        self.text = text
        self.highlightText = highlightText
        textModel.inputText = text
        if highlightText {
            textModel.highlightText()
        }
    }
    

  var body: some View {
    ZStack(alignment: .top) {
        if highlightText {
            Text(AttributedString(textModel.highlightedText))
                .textSelection(.enabled)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.3))
               .cornerRadius(10)
               
        } else {
            Text(text)
                .textSelection(.enabled)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.3))
               .cornerRadius(10)
        }
           
      HStack {
        Spacer()
        Button(
          action: {
              textModel.copyCode()
          },
          label: {
              if textModel.hasBeenCopied {
              Image(systemName: "checkmark").foregroundStyle(.green)

            } else {
              Image(systemName: "clipboard").foregroundStyle(.black)

            }
          }
        ).buttonStyle(.borderless)
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
