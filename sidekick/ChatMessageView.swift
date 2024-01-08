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
    let splits = chatMessage.content.components(separatedBy: "```")
    if splits.count == 0 || !finishedRendering {
      self.paragraphs = [Paragraph(text: chatMessage.content, type: .TEXT)]
      return
    }
    self.paragraphs = splits.enumerated().map { (idx, text) in

      if idx % 2 == 1 {
        let (parsedText, lang) = parseCodeBlock(text: text)
        return Paragraph(
          text: parsedText.trimmingCharacters(in: .whitespacesAndNewlines), type: .CODE,
          codeLanguage: lang)
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
        VStack.init(alignment: .leading, spacing: 15) {
          ForEach(paragraphs) { paragraph in
            if paragraph.type == .CODE {
              CodeBlock(
                text: paragraph.text, shouldHighlight: finishedRendering,
                language: paragraph.codeLanguage)
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
    .padding(.horizontal)
  }
}

class HighlightedTextModel: ObservableObject {
  @Published var highlightedText: NSAttributedString = .init(string: "")
  @Published var inputText = ""
  @Published var hasBeenCopied = false

  private let highlighter = Highlighter()
  private var copyMessageTimer: Timer?

  func highlightText(language: String?) -> Bool {
    highlighter?.setTheme("tomorrow")
    if let highlighted = highlighter?.highlight(inputText, as: language) {
      highlightedText = highlighted
      return true
    } else {
      print("Failed to highlight text")
      return false
    }
  }

  func copyCode() {
    copyToClipboard(text: inputText)
    hasBeenCopied = true

    copyMessageTimer?.invalidate()
    let timer = Timer(
      timeInterval: 1, repeats: false,
      block: { _ in
        self.hasBeenCopied = false
      })
    copyMessageTimer = timer
    RunLoop.current.add(timer, forMode: .common)
  }
}

struct CodeBlock: View {
  let text: String
  let lang: String?
  var shouldHighlight: Bool
  @ObservedObject var textModel = HighlightedTextModel()

  init(text: String, shouldHighlight: Bool, language: String?) {
    self.text = text
    self.lang = language
    self.shouldHighlight = shouldHighlight
    textModel.inputText = text
    if shouldHighlight {
      let highlighted = textModel.highlightText(language: language)
      self.shouldHighlight = highlighted
    }
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
          action: textModel.copyCode,
          label: {
            if textModel.hasBeenCopied {
              Image(systemName: "checkmark").foregroundStyle(.green)

            } else {
              Image(systemName: "clipboard").foregroundStyle(.black)
            }
          }
        ).buttonStyle(.borderless)
      }
      if shouldHighlight {
        Text(AttributedString(textModel.highlightedText))
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
}

struct TextBlock: View {
  let formattedText: AttributedString
    
    init(text: String) {
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
      print("start - line end index", text.startIndex, lineEndIndex)
      content.removeFirst(lang!.count)
    }
  }
  return (content, lang)
}
