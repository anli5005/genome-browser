import Foundation

let url = Bundle.main.url(forResource: "NC_045512", withExtension: "gb")
let data = try! Data(contentsOf: url!)

let parser = GenomeParser()

let genome = try! parser.parse(data)
genome.locus
genome.references
genome.features
genome.metadata
genome.sequence.description
