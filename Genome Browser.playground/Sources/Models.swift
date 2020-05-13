import Foundation

public enum BaseCompletion {
    case complete
    case partial5
    case partial3
    case complement
}

public struct Genome {
    public var locus: Locus
    public var metadata: [MetadataKey: String]
    public var source: Source
    
    public var references: [Reference]
        
    public var features: [Feature]
    
    public var sequence: GeneSequence
    
    public init(locus: Locus, metadata: [MetadataKey: String], source: Source, references: [Reference], features: [Feature], sequence: GeneSequence) {
        self.locus = locus
        self.metadata = metadata
        self.source = source
        self.references = references
        self.features = features
        self.sequence = sequence
    }
    
    public struct MetadataKey: RawRepresentable, Hashable {
        public var rawValue: String
        
        public init(rawValue: String) {
            self.rawValue = rawValue
        }
    }
}

public struct Locus {
    public var name: String
    public var sequenceLength: Int
    public var moleculeType: String
    public var division: String
    public var modified: String
    
    public init(name: String, sequenceLength: Int, moleculeType: String, division: String, modified: String) {
        self.name = name
        self.sequenceLength = sequenceLength
        self.moleculeType = moleculeType
        self.division = division
        self.modified = modified
    }
}

public struct Source {
    public var name: String
    public var organism: String?
    
    public init(name: String, organism: String?) {
        self.name = name
        self.organism = organism
    }
}

public struct Reference {
    public var id: Int
    public var bases: ClosedRange<Int>
    public var authors: String?
    public var consortium: String?
    public var title: String
    public var journal: Journal
    
    public enum Journal {
        case unpublished
        case published(title: String, pubmed: Int?)
    }
    
    public init(id: Int, bases: ClosedRange<Int>, authors: String?, consortium: String?, title: String, journal: Journal) {
        self.id = id
        self.bases = bases
        self.authors = authors
        self.consortium = consortium
        self.title = title
        self.journal = journal
    }
}

public struct Feature {
    public var type: String
    public var bases: RangeSet<Int>
    public var baseCompletion: BaseCompletion
    public var qualifiers: [String: String]
    
    public init(type: String, bases: RangeSet<Int>, with completion: BaseCompletion, qualifiers: [String: String]) {
        self.type = type
        self.bases = bases
        self.baseCompletion = completion
        self.qualifiers = qualifiers
    }
}

extension Genome.MetadataKey: ExpressibleByStringLiteral {
    public init(stringLiteral: String) {
        self.init(rawValue: stringLiteral)
    }
}

extension Genome.MetadataKey {
    public static let definition: Genome.MetadataKey = "DEFINITION"
    public static let accession: Genome.MetadataKey = "ACCESSION"
    public static let version: Genome.MetadataKey = "VERSION"
    public static let keywords: Genome.MetadataKey = "KEYWORDS"
    public static let comment: Genome.MetadataKey = "COMMENT"
    public static let dbLink: Genome.MetadataKey = "DBLINK"
}
