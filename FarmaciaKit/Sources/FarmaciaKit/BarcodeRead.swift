import Foundation

// MARK: - Barcode read validation
//
// One camera read → the code to look up, or why it was dropped. A dropped read is a
// misread when its check digit is wrong; the scanner's vote never counts it.

public enum Symbology: String, CaseIterable, Sendable {
    case ean13, ean8, upce, code128, code39, code93, itf14
}

public enum BarcodeRead {
    public enum Rejection: Error, Equatable, Sendable {
        case notEnabled
        /// Wrong length or characters for the symbology.
        case malformed
        /// A GTIN whose GS1 check digit doesn't match: a misread.
        case checkDigit
    }

    public static func validated(symbology: Symbology, payload: String, enabled: Set<Symbology>) -> Result<String, Rejection> {
        guard enabled.contains(symbology) else { return .failure(.notEnabled) }
        switch symbology {
        case .ean13:
            // The iPhone sometimes reads an EAN-13 as 14 digits; the box prints 13. A UPC-A
            // (no symbology of its own) may come unpadded: products save it as 0 + 12.
            let code = payload.count == 12 ? "0" + payload : BarcodeLookup.newProductBarcode(payload)
            return gtin(code, length: 13, checked: code)
        case .ean8:
            return gtin(payload, length: 8, checked: payload)
        case .itf14:
            return gtin(payload, length: 14, checked: payload)
        case .upce:
            guard let upcA = UPCE.expanded(payload) else { return .failure(.malformed) }
            return gtin(payload, length: 8, checked: upcA)
        case .code128, .code39, .code93:
            // Product codes are printable ASCII; anything else is noise.
            let printable = !payload.isEmpty && payload.unicodeScalars.allSatisfy { (0x20...0x7E).contains($0.value) }
            return printable ? .success(payload) : .failure(.malformed)
        }
    }

    /// `code` must be `length` digits; `checked` is the GTIN whose check digit decides.
    private static func gtin(_ code: String, length: Int, checked: String) -> Result<String, Rejection> {
        guard code.count == length, code.allSatisfy({ $0.isASCII && $0.isNumber }) else { return .failure(.malformed) }
        return GTINCheck.isValid(checked) ? .success(code) : .failure(.checkDigit)
    }
}
