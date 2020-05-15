import Foundation
import AppKit
import SwiftUI
import PlaygroundSupport

let url = Bundle.main.url(forResource: "NC_045512", withExtension: "gb")
let data = try! Data(contentsOf: url!)

let parser = GenomeParser()

let genome = try! parser.parse(data)
genome.locus
genome.references
genome.features
genome.metadata

let attributedString = NSMutableAttributedString(string: genome.sequence.description, attributes: [.foregroundColor: NSColor.textColor])

genome.features.forEach { feature in
    feature.bases.ranges.forEach { range in
        let color = NSColor(calibratedHue: CGFloat.random(in: 0...1), saturation: CGFloat.random(in: 0.2...1.0), brightness: CGFloat.random(in: 0.2...1.0), alpha: 0.3)
        attributedString.addAttributes([.backgroundColor: color], range: NSMakeRange(range.lowerBound - 1, range.upperBound - range.lowerBound))
    }
}

let scrollView = NSScrollView()
let textView = NSTextView()
textView.isEditable = false
let textViewKey = "textView"
textView.textStorage!.setAttributedString(attributedString)
scrollView.frame = CGRect(x: 0, y: 0, width: 500, height: 400)
scrollView.documentView = textView
scrollView.hasVerticalScroller = true
textView.autoresizingMask = .width
textView.frame = scrollView.contentView.bounds

textView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)

PlaygroundPage.current.liveView = scrollView
