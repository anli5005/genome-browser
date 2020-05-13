import Foundation

extension String {
    public subscript(nsRange: NSRange) -> Substring {
        self[Range(nsRange, in: self)!]
    }
}

extension Optional {
    public func unwrap(errorIfNil error: Error) throws -> Wrapped {
        guard let wrapped = self else {
            throw error
        }
        
        return wrapped
    }
}
