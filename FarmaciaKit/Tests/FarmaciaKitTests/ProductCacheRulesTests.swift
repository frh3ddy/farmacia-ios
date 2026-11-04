import Foundation
import Testing
@testable import FarmaciaKit

/// The on-device product cache holds one row per product. Stock and price belong to a
/// store (the same for every role there); cost is never cached, so a role change at
/// the same store doesn't invalidate it. The cache outlives an app restart.
struct ProductCacheScopeTests {
    let centro = ProductCacheScope(locationId: "centro")

    @Test("given an owner then a cashier at the same store, should keep the cache")
    func roleChangeSameStore() {
        #expect(!ProductCacheScope(locationId: "centro").needsClear(storedKey: centro.key))
    }

    @Test("given another store, should clear")
    func otherStore() {
        #expect(ProductCacheScope(locationId: "norte").needsClear(storedKey: centro.key))
    }

    @Test("given no stored scope (first launch after this update, or an older cache that may hold costs), should clear")
    func noStoredScope() {
        #expect(centro.needsClear(storedKey: nil))
    }

    @Test("given a cache saved before products carried a barcode, should clear (download it again with barcodes)")
    func beforeBarcodes() {
        #expect(centro.needsClear(storedKey: "store:centro"))
    }

    @Test("given a key stored by the previous version of this rule (store plus cost visibility), should clear")
    func previousRuleKey() {
        #expect(centro.needsClear(storedKey: "centro|costs"))
    }
}

struct BarcodeLookupTests {
    @Test("given two cached products with the same barcode, should ask the server instead of opening one")
    func shared() {
        #expect(BarcodeLookup.cacheDecision(matchCount: 2) == .askServer)
    }

    @Test("given exactly one match, should open it; given none, should ask the server")
    func singleOrNone() {
        #expect(BarcodeLookup.cacheDecision(matchCount: 1) == .open)
        #expect(BarcodeLookup.cacheDecision(matchCount: 0) == .askServer)
    }
}

/// After a scan the cache couldn't settle, the server's exact search decides the
/// next step of the scan flow: open the product, choose among several, or create
/// one with the scanned code. An error offers to create too.
struct BarcodeServerDecisionTests {
    @Test("given an exact match, should open it")
    func exactMatch() {
        #expect(BarcodeLookup.serverDecision(exactMatch: true, resultCount: 3) == .open)
    }

    @Test("given one result that isn't exact, should open it")
    func singleFuzzy() {
        #expect(BarcodeLookup.serverDecision(exactMatch: false, resultCount: 1) == .open)
    }

    @Test("given several results, should list them to choose")
    func several() {
        #expect(BarcodeLookup.serverDecision(exactMatch: false, resultCount: 2) == .choose)
        #expect(BarcodeLookup.serverDecision(exactMatch: nil, resultCount: 4) == .choose)
    }

    @Test("given no results, should offer to create a product with the code")
    func none() {
        #expect(BarcodeLookup.serverDecision(exactMatch: nil, resultCount: 0) == .create)
    }
}

/// The iPhone can read an EAN-13 as its 14-digit GTIN (3664798067460 → 03664798067460),
/// and some products were saved with that form as their SKU. A scan tries every
/// zero-padded GTIN form of the code, the scanned one first.
struct BarcodeVariantsTests {
    @Test("given the 14-digit form of an EAN-13, should also try the 13 digits printed on the box")
    func fourteenToThirteen() {
        #expect(BarcodeLookup.codeVariants("03664798067460") == ["03664798067460", "3664798067460"])
    }

    @Test("given an EAN-13, should also try its 14-digit form (a product saved from an earlier scan)")
    func thirteenToFourteen() {
        #expect(BarcodeLookup.codeVariants("3664798067460") == ["3664798067460", "03664798067460"])
    }

    @Test("given a UPC-A, should try its 12-, 13- and 14-digit forms")
    func upcA() {
        #expect(BarcodeLookup.codeVariants("012345678905") == ["012345678905", "0012345678905", "00012345678905"])
    }

    @Test("given a case-pack GTIN-14 (no leading zero), should try only itself")
    func realGtin14() {
        #expect(BarcodeLookup.codeVariants("13664798067467") == ["13664798067467"])
    }

    @Test("given a code that isn't a GTIN, should try only itself", arguments: ["ABC-123", "12345", "036647980674601"])
    func notGtin(code: String) {
        #expect(BarcodeLookup.codeVariants(code) == [code])
    }

    @Test("given the 14-digit form, a new product's barcode should be the 13 digits printed on the box")
    func prefillDropsZero() {
        #expect(BarcodeLookup.newProductBarcode("03664798067460") == "3664798067460")
    }

    @Test("given any other code, a new product's barcode should be the code as scanned", arguments: ["3664798067460", "13664798067467", "ABC-123"])
    func prefillUnchanged(code: String) {
        #expect(BarcodeLookup.newProductBarcode(code) == code)
    }
}

/// A scan matches a product by SKU (any letter case) or barcode, in any GTIN form.
struct BarcodeMatchTests {
    let scan = BarcodeLookup.codeVariants("03664798067460")

    @Test("given the barcode in the GTIN field and another SKU, should match")
    func byGtin() {
        #expect(BarcodeLookup.matches(sku: "8857379", gtin: "3664798067460", variants: scan))
    }

    @Test("given the barcode as the SKU, should match")
    func bySku() {
        #expect(BarcodeLookup.matches(sku: "3664798067460", gtin: nil, variants: scan))
    }

    @Test("given a SKU in other letter case, should match")
    func skuCase() {
        #expect(BarcodeLookup.matches(sku: "abc-1", gtin: nil, variants: ["ABC-1"]))
    }

    @Test("given neither, should not match")
    func neither() {
        #expect(!BarcodeLookup.matches(sku: "8857379", gtin: nil, variants: scan))
    }
}
