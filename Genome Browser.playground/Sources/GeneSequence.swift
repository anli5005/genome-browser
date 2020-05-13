public enum BasePair: UInt8, CaseIterable {
    case a = 0b00
    case c = 0b01
    case g = 0b10
    case t = 0b11
    
    public static let bitWidth = 2
    public static let bitMask: UInt8 = 0b11
}

extension BasePair: CustomStringConvertible {
    public var description: String {
        switch self {
        case .a: return "a"
        case .c: return "c"
        case .g: return "g"
        case .t: return "t"
        }
    }
}

public struct GeneSequence {
    public var storage: [UInt8]
    public var length: Int
    
    public init(storage: [UInt8], length: Int) {
        self.storage = storage
        self.length = length
    }
}

extension GeneSequence: RandomAccessCollection, RangeReplaceableCollection {
    public init() {
        self.init(storage: [], length: 0)
    }
    
    public var count: Int { length }
    
    public var startIndex: Int { 0 }
    public var endIndex: Int { length }
    
    public func formIndex(before i: inout Index) {
        i -= 1
    }
    
    public func formIndex(after i: inout Int) {
        i += 1
    }
    
    public func formIndex(_ i: inout Int, offsetBy distance: Int) {
        i += distance
    }
    
    public subscript(position: Int) -> BasePair {
        get {
            guard position >= startIndex && position < endIndex else {
                fatalError("Index \(position) out of bounds for gene sequence of length \(count)")
            }
            
            let pairsPerItem = UInt8.bitWidth / BasePair.bitWidth
            let value = storage[position / pairsPerItem]
            return BasePair(rawValue: (value >> ((position % pairsPerItem) * BasePair.bitWidth)) & BasePair.bitMask)!
        }
        set {
            guard position >= startIndex && position < endIndex else {
                fatalError("Index \(position) out of bounds for gene sequence of length \(count)")
            }
            
            let pairsPerItem = UInt8.bitWidth / BasePair.bitWidth
            let index = position / pairsPerItem
            let shift = (position % pairsPerItem) * BasePair.bitWidth
            let mask: UInt8 = BasePair.bitMask << shift
            storage[index] = (storage[index] & ~mask) | (newValue.rawValue << shift)
        }
    }
    
    public subscript(bounds: Range<Int>) -> Slice<GeneSequence> {
        get {
            Slice(base: self, bounds: bounds)
        }
    }
    
    public mutating func append(_ newElement: BasePair) {
        length += 1
        if storage.count <= (length - 1) / (UInt8.bitWidth / BasePair.bitWidth) {
            storage.append(newElement.rawValue)
        } else {
            self[length - 1] = newElement
        }
    }
    
    public mutating func removeLast() -> BasePair {
        let result = last!
        length -= 1
        return result
    }
}

extension GeneSequence: CustomStringConvertible {
    public var description: String {
        map(\.description).joined(separator: "")
    }
}
