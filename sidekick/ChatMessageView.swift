//
//  ChatMessageView.swift
//  sidekick
//
//  Created by Jakob Frick on 06/01/2024.
//

import Foundation
import Highlighter
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
  var codeLanguage: String? = nil
  var highlightedText: NSAttributedString? = nil
  public let id: UUID = UUID()
}

struct ChatMessageView: View {
  @Binding  var chatMessage: ChatMessage
  @Binding  var finishedRendering: Bool
  @State private var highlighter: Highlighter? = nil
  
  @State private var hasBeenCopied = false
  @State private var paragraphs: [Paragraph] = []

    func renderChatMessage() {
        if (!finishedRendering) {
            paragraphs = [Paragraph(text: chatMessage.content, type: .TEXT)]
            return
        }
        let splits = chatMessage.content.components(separatedBy: "```")
        if (splits.count == 1) {
          paragraphs = [Paragraph(text: chatMessage.content, type: .TEXT)]
          return
        }
          
        if highlighter == nil {
            highlighter = Highlighter()
        }
        highlighter?.setTheme("tomorrow")
        paragraphs = splits.enumerated().map { (idx, text) in
          if idx % 2 == 1 {
              let (parsedText, lang) = parseCodeBlock(text: text)
                
              let highlightedText = highlighter?.highlight(parsedText, as: lang)
              
            return Paragraph(
              text: parsedText.trimmingCharacters(in: .whitespacesAndNewlines), type: .CODE,
              codeLanguage: lang, highlightedText: highlightedText)
          } else {
            return Paragraph(text: text.trimmingCharacters(in: .whitespacesAndNewlines), type: .TEXT)
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
      }
      ScrollView {
        VStack.init(alignment: .leading, spacing: 15) {
          ForEach(paragraphs) { paragraph in
            if paragraph.type == .CODE {
              CodeBlock(
                text: paragraph.text,highlightedText: paragraph.highlightedText, lang: paragraph.codeLanguage )
            } else {
              TextBlock(text: paragraph.text)
            }
          }
        }
      } // .defaultScrollAnchor(.bottom)
    }
    .padding()
    .background(.white)
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
    .padding(.horizontal)
    .onChange(of: chatMessage) {
        renderChatMessage()
    }.onAppear(perform: renderChatMessage)
  }
}


struct CodeBlock: View {
    let text: String
    let lang: String?
    let highlightedText: NSAttributedString?
    @State private var copyMessageTimer: Timer?
    @State private var hasBeenCopied = false

    init(text: String, highlightedText: NSAttributedString?, lang: String?) {
        self.text = text
        self.highlightedText = highlightedText
        self.lang = lang
    }

  var body: some View {
    VStack {
      HStack {
        if let languageSetting = lang {
          Text(languageSetting)
            .font(.subheadline)
            .fontWeight(.semibold)
            .padding(.leading)
            .foregroundStyle(.black.opacity(0.5))
        }
        Spacer()
        Button(
          action: copyCode,
          label: {
            if hasBeenCopied {
              Image(systemName: "checkmark").foregroundStyle(.green)

            } else {
              Image(systemName: "clipboard").foregroundStyle(.black)
            }
          }
        ).buttonStyle(.borderless)
      }
      if let highlighted = highlightedText {
        Text(AttributedString(highlighted))
          .textSelection(.enabled)
          .padding()
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.white.opacity(0.3))
          .cornerRadius(10)
      } else {
        Text(text)
          .textSelection(.enabled)
          .padding(.horizontal)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(.white.opacity(0.3))
          .cornerRadius(10)
      }
    }
  }
    
    func copyCode() {
      copyToClipboard(text: text)
      hasBeenCopied = true

      copyMessageTimer?.invalidate()
      let timer = Timer(
        timeInterval: 1, repeats: false,
        block: { _ in
          hasBeenCopied = false
        })
        self.copyMessageTimer = timer
      RunLoop.current.add(timer, forMode: .common)
    }
}

struct TextBlock: View {
  public var text: String
  @State var formattedText: AttributedString = AttributedString()
    
    
    init(text: String) {
        self.text = text
    }
    
    func renderText() {
        let regex = try! NSRegularExpression(pattern: "`(.*?)`", options: [])
        let attributedString = NSMutableAttributedString(string: text)

        regex.enumerateMatches(in: text, options: [], range: NSRange(text.startIndex..., in: text)) { match, _, _ in
            guard let match = match, let range = Range(match.range(at: 1), in: text) else { return }

            let attributedRange = NSRange(range, in: text)
            attributedString.addAttribute(.font, value: NSFont.monospacedSystemFont(ofSize: 12, weight: .bold), range: attributedRange)
        }
        
        self.formattedText = AttributedString(attributedString)
    }

  var body: some View {
    Text(formattedText)
      .font(.title3)
      .frame(maxWidth: .infinity, alignment: .leading)
      .foregroundStyle(.black)
      .padding(.horizontal)
      .background(.clear)
      .textSelection(.enabled)
      .onAppear(perform: renderText).onChange(of: text, renderText)
  }
  
}

func copyToClipboard(text: String) {
  let pasteboard = NSPasteboard.general
  pasteboard.clearContents()
  pasteboard.setString(text, forType: .string)
}

func parseCodeBlock(text: String) -> (String, String?) {
  var lang: String? = nil
  var content = text

  if let lineEndIndex = text.firstIndex(of: "\n") {
    if lineEndIndex != text.startIndex {
      lang = String(text[text.startIndex...text.index(before: lineEndIndex)])
      content.removeFirst(lang!.count)
    }
  }
  return (content, lang)
}
