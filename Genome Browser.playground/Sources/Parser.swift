import Foundation

public enum GenomeParserError: Error {
    case malformedData
    case reachedEndOfLine
    case unrecognizedRangeFunction(String)
    case reachedEndOfRange
    case expectedCommaInRangeFunction
    case expectedInteger(String)
    case unexpectedTokenInFeature
    case reachedEndOfFeature
    case reachedEndOfData
    case malformedLocus
    case malformedReference
    case missing(PartialKeyPath<Genome>)
}

public class GenomeParser {
    public init() {}
    
    internal static let newline = UInt8("\n".unicodeScalars.first!.value)
    internal static let encoding = String.Encoding.utf8
    
    internal struct MetadataItem {
        var name: String
        var content: String
        var children: [MetadataItem]
    }
    
    internal func parseMetadataItem(from lines: [ArraySlice<UInt8>], at position: Int) throws -> (MetadataItem, Int) {
        var linesRead = 1
                
        guard let str = String(bytes: lines[position], encoding: GenomeParser.encoding) else {
            throw GenomeParserError.malformedData
        }
        
        guard let keyStartIndex = str.firstIndex(where: { $0 != " " }) else {
            throw GenomeParserError.reachedEndOfLine
        }
        
        let keyIndent = str.distance(from: str.startIndex, to: keyStartIndex)
        let keyEndIndex = str[keyStartIndex..<str.endIndex].firstIndex(of: " ") ?? str.endIndex
        var value: String
        var items = [MetadataItem]()
                
        if keyEndIndex != str.endIndex, let valueStartIndex = str[keyEndIndex..<str.endIndex].firstIndex(where: { $0 != " " }) {
            let valueIndent = str.distance(from: str.startIndex, to: valueStartIndex)
            value = String(str[valueStartIndex..<str.endIndex])
            
            while position + linesRead < lines.count {
                guard let line = String(bytes: lines[position + linesRead], encoding: GenomeParser.encoding) else {
                    throw GenomeParserError.reachedEndOfLine
                }
                
                let startIndex = line.firstIndex(where: { $0 != " " }) ?? line.endIndex
                
                let indent = line.distance(from: line.startIndex, to: startIndex)
                if indent >= valueIndent {
                    value += "\n"
                    value += line.suffix(line.count - indent)
                    linesRead += 1
                } else if indent > keyIndent {
                    let (child, childLinesRead) = try parseMetadataItem(from: lines, at: position + linesRead)
                    items.append(child)
                    linesRead += childLinesRead
                } else {
                    break
                }
            }
        } else {
            value = ""
        }
                
        return (MetadataItem(name: String(str[keyStartIndex..<keyEndIndex]), content: value, children: items), linesRead)
    }
    
    internal func parseRangeSet(from string: String, index: inout String.Index) throws -> RangeSet<Int> {
        if string[index].isNumber {
            var current = ""
            
            while string[index].isNumber {
                current.append(string[index])
                string.formIndex(after: &index)
                if index == string.endIndex {
                    throw GenomeParserError.reachedEndOfRange
                }
            }
            
            guard let a = Int(current) else {
                throw GenomeParserError.expectedInteger(current)
            }
            
            while !string[index].isNumber {
                string.formIndex(after: &index)
                if index == string.endIndex {
                    throw GenomeParserError.reachedEndOfRange
                }
            }
            
            current = ""
            
            while index != string.endIndex && string[index].isNumber {
                current.append(string[index])
                string.formIndex(after: &index)
            }
            
            guard let b = Int(current) else {
                throw GenomeParserError.expectedInteger(current)
            }
            
            return RangeSet(Range(a...b))
        } else {
            var current = ""
            
            while current.last != "(" {
                if index == string.endIndex {
                    throw GenomeParserError.reachedEndOfRange
                }
                
                current.append(string[index])
                string.formIndex(after: &index)
            }
            
            let function = current.prefix(current.count - 1)
            switch function {
            case "join":
                var set = RangeSet<Int>()
                var readyForArgument = true
                var stop = false
                
                while !stop {
                    if index == string.endIndex {
                        throw GenomeParserError.reachedEndOfRange
                    }
                    
                    switch string[index] {
                    case ")":
                        stop = true
                        string.formIndex(after: &index)
                    case ",":
                        readyForArgument = true
                        string.formIndex(after: &index)
                    default:
                        if readyForArgument {
                            set.formUnion(try parseRangeSet(from: string, index: &index))
                        } else {
                            throw GenomeParserError.expectedCommaInRangeFunction
                        }
                    }
                }
                
                return set
            default:
                throw GenomeParserError.unrecognizedRangeFunction(String(function))
            }
        }
    }
    
    internal static let complementPrefix = "complement("
    
    internal func parseFeature(from metadata: MetadataItem) throws -> Feature {
        let firstNewline = metadata.content.firstIndex(of: "\n") ?? metadata.content.endIndex
        
        let baseCompletion: BaseCompletion
        var baseStr = metadata.content
        let firstLine = metadata.content.prefix(upTo: firstNewline)
        if firstLine.hasPrefix("<") {
            baseCompletion = .partial5
            baseStr.removeFirst()
        } else if firstLine.hasSuffix(">") {
            baseCompletion = .partial3
            baseStr.removeLast()
        } else if firstLine.starts(with: GenomeParser.complementPrefix) {
            guard firstLine.hasSuffix(")") else {
                throw GenomeParserError.reachedEndOfRange
            }
            
            baseCompletion = .complement
            baseStr.removeFirst(GenomeParser.complementPrefix.count)
            baseStr.removeLast()
        } else {
            baseCompletion = .complete
        }
        
        if baseStr.isEmpty {
            throw GenomeParserError.reachedEndOfRange
        }
        
        var index = baseStr.startIndex
        let bases = try parseRangeSet(from: baseStr, index: &index)
        
        var attributes = [String: String]()
        
        var current = firstNewline
        if current < metadata.content.endIndex {
            metadata.content.formIndex(after: &current)
        }
        
        while current < metadata.content.endIndex {
            if metadata.content[current] != "/" {
                throw GenomeParserError.unexpectedTokenInFeature
            }
                        
            guard let equalsIndex = metadata.content[current..<metadata.content.endIndex].firstIndex(where: { $0 == "=" || $0 == "\n" }) else {
                throw GenomeParserError.reachedEndOfFeature
            }
            
            let key = String(metadata.content[metadata.content.index(after: current)..<equalsIndex])
            var valueStart = metadata.content.index(after: equalsIndex)
            let valueEnd: String.Index
            
            if valueStart == metadata.content.endIndex {
                throw GenomeParserError.reachedEndOfFeature
            }
            
            if metadata.content[valueStart] == "\"" {
                valueStart = metadata.content.index(after: valueStart)
                guard let end = metadata.content[valueStart..<metadata.content.endIndex].firstIndex(of: "\"") else {
                    throw GenomeParserError.reachedEndOfFeature
                }
                
                valueEnd = end
                current = metadata.content.index(after: valueEnd)
            } else if metadata.content[equalsIndex] == "\n" {
                valueEnd = valueStart
                current = equalsIndex
            } else {
                valueEnd = metadata.content[valueStart..<metadata.content.endIndex].firstIndex(of: "\n") ?? metadata.content.endIndex
                current = valueEnd
            }
            
            attributes[key] = String(metadata.content[valueStart..<valueEnd])
                        
            if current != metadata.content.endIndex {
                guard metadata.content[current] == "\n" else {
                    throw GenomeParserError.unexpectedTokenInFeature
                }
                
                metadata.content.formIndex(after: &current)
            }
        }
                
        return Feature(
            type: metadata.name,
            bases: bases,
            with: baseCompletion,
            qualifiers: attributes
        )
    }
    
    internal static let locusRegex = try! NSRegularExpression(pattern: "^([^ ]+) +(\\d+) bp +(.+) +([A-Z]{3}) +(.+)$", options: [])
    
    internal func parseLocus(from string: String) throws -> Locus {
        guard let match = GenomeParser.locusRegex.firstMatch(in: string, options: [], range: NSMakeRange(0, string.count)), let length = Int(string[match.range(at: 2)]) else {
            throw GenomeParserError.malformedLocus
        }
        
        return Locus(
            name: String(string[match.range(at: 1)]),
            sequenceLength: length,
            moleculeType: String(string[match.range(at: 3)]),
            division: String(string[match.range(at: 4)]),
            modified: String(string[match.range(at: 5)])
        )
    }
    
    internal func parseSource(from item: MetadataItem) -> Source {
        Source(name: item.content, organism: item.children.last(where: { $0.name == "ORGANISM" })?.content)
    }
    
    internal static let referenceRegex = try! NSRegularExpression(pattern: "^(\\d+) +\\(bases (\\d+) to (\\d+)\\)$", options: [])
    
    internal func parseReference(from item: MetadataItem) throws -> Reference {
        guard let match = GenomeParser.referenceRegex.firstMatch(in: item.content, options: [], range: NSMakeRange(0, item.content.count)), let id = Int(item.content[match.range(at: 1)]), let a = Int(item.content[match.range(at: 2)]), let b = Int(item.content[match.range(at: 3)]) else {
            throw GenomeParserError.malformedReference
        }
        
        var title: String?
        var authors: String?
        var journal: Reference.Journal?
        var consortium: String?
        
        item.children.forEach { child in
            switch child.name {
            case "TITLE":
                title = child.content
            case "AUTHORS":
                authors = child.content
            case "CONSRTM":
                consortium = child.content
            case "JOURNAL":
                if child.content == "Unpublished" {
                    journal = .unpublished
                } else {
                    journal = .published(title: child.content, pubmed: (child.children.last(where: { $0.name == "PUBMED" })?.content).flatMap { Int($0) })
                }
            default:
                break
            }
        }
        
        if title == nil {
            throw GenomeParserError.malformedReference
        }
        
        return Reference(id: id, bases: a...b, authors: authors, consortium: consortium, title: title!, journal: journal!)
    }
    
    internal static let alphabet = [UInt8: BasePair](uniqueKeysWithValues: BasePair.allCases.map { (UInt8($0.description.unicodeScalars.first!.value), $0) })
    
    public func parse<TSequence: Sequence>(_ sequence: TSequence) throws -> Genome where TSequence.Element == UInt8 {
        var originReached = false
        let lines = sequence.split(separator: GenomeParser.newline)
        var current = lines.startIndex
        
        var locus: Locus?
        var source: Source?
        var references = [Reference]()
        var features = [Feature]()
        var otherAttributes = [Genome.MetadataKey: String]()
        
        while !originReached {
            if current >= lines.endIndex {
                throw GenomeParserError.reachedEndOfData
            }
            
            let (item, linesRead) = try parseMetadataItem(from: lines, at: current)
            switch item.name {
            case "LOCUS":
                locus = try parseLocus(from: item.content)
            case "SOURCE":
                source = parseSource(from: item)
            case "REFERENCE":
                references.append(try parseReference(from: item))
            case "FEATURES":
                features += try item.children.map { try parseFeature(from: $0) }
            case "ORIGIN":
                originReached = true
                continue
            default:
                otherAttributes[Genome.MetadataKey(rawValue: item.name)] = item.content
            }
            
            current += linesRead
        }
        
        var geneSequence = GeneSequence()
        for line in lines[current..<lines.endIndex] {
            for byte in line {
                if let pair = GenomeParser.alphabet[byte] {
                    geneSequence.append(pair)
                }
            }
        }
        
        return try Genome(
            locus: locus.unwrap(errorIfNil: GenomeParserError.missing(\Genome.locus)),
            metadata: otherAttributes,
            source: source.unwrap(errorIfNil: GenomeParserError.missing(\Genome.source)),
            references: references,
            features: features,
            sequence: geneSequence
        )
    }
}
