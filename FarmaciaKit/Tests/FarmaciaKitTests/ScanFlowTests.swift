import Testing
@testable import FarmaciaKit

struct ScanModeTests {
    @Test("given a saved count and an employee who can't manage inventory, should be consult")
    func cashierFallsBack() {
        #expect(ScanMode.effective(saved: .count, canManageInventory: false) == .consult)
    }

    @Test("given nothing saved, should be consult")
    func defaultsToConsult() {
        #expect(ScanMode.effective(saved: nil, canManageInventory: true) == .consult)
    }

    @Test("given a saved mode and an employee who can manage inventory, should keep it",
          arguments: [ScanMode.consult, .receive, .count])
    func keepsSaved(mode: ScanMode) {
        #expect(ScanMode.effective(saved: mode, canManageInventory: true) == mode)
    }
}

struct ScanNextTests {
    @Test("given receive mode and one match, should go to the receive form, not the detail screen")
    func receiveMatch() {
        #expect(ScanNext.after(.matched, in: .receive) == .receive)
    }

    @Test("given a match (or a pick from several), should follow the mode",
          arguments: [(ScanMode.consult, ScanNext.openDetail), (.receive, .receive), (.count, .count)])
    func matchFollowsMode(mode: ScanMode, next: ScanNext) {
        #expect(ScanNext.after(.matched, in: mode) == next)
    }

    @Test("given several matches or an unknown code, should choose or create in any mode",
          arguments: ScanMode.allCases)
    func severalOrUnknown(mode: ScanMode) {
        #expect(ScanNext.after(.severalMatched, in: mode) == .choose)
        #expect(ScanNext.after(.unknown, in: mode) == .create)
    }

    @Test("given a product created from the code, should open its detail, receive form or count form",
          arguments: [(ScanMode.consult, ScanNext.openDetail), (.receive, .receive), (.count, .count)])
    func createdFollowsMode(mode: ScanMode, next: ScanNext) {
        #expect(ScanNext.after(.created, in: mode) == next)
    }

    @Test("given a form closed with nothing to show (saved, cancelled, or created offline), should scan the next item in a run",
          arguments: [ScanMode.receive, .count])
    func closedScansNext(mode: ScanMode) {
        #expect(ScanNext.after(.closed, in: mode) == .scan)
    }

    @Test("given Consultar and Nuevo Producto or the choose list closed with nothing to show, should close the flow as today")
    func consultClosedCloses() {
        #expect(ScanNext.after(.closed, in: .consult) == .close)
    }
}

struct RecentScanSaveTests {
    @Test("given Aspirina 500mg received 20, should read 'Aspirina 500mg · +20 uds'")
    func received() {
        #expect(RecentScanSave(productId: "p1", name: "Aspirina 500mg", kind: .received(20)).text
                == "Aspirina 500mg · +20 uds")
    }

    @Test("given 1 received, should say ud, not uds")
    func receivedOne() {
        #expect(RecentScanSave(productId: "p1", name: "Gasas", kind: .received(1)).text == "Gasas · +1 ud")
    }

    @Test("given counted 10 against 12, should read '12 → 10 (−2)'")
    func countedLower() {
        #expect(RecentScanSave(productId: "p1", name: "Aspirina 500mg", kind: .counted(before: 12, counted: 10)).text
                == "Aspirina 500mg · 12 → 10 (−2)")
    }

    @Test("given counted the same as stock, should say nothing changed")
    func countedSame() {
        #expect(RecentScanSave(productId: "p1", name: "Aspirina 500mg", kind: .counted(before: 12, counted: 12)).text
                == "Aspirina 500mg · 12, sin cambios")
    }

    @Test("given a count without the stock it was compared to, should show what was counted")
    func countedUnknownBefore() {
        #expect(RecentScanSave(productId: "p1", name: "Aspirina 500mg", kind: .counted(before: nil, counted: 10)).text
                == "Aspirina 500mg · contados: 10")
    }

    @Test("given the same product scanned again in the same mode, should be a repeat with a note")
    func repeatScan() {
        let received = RecentScanSave(productId: "p1", name: "Aspirina", kind: .received(20))
        #expect(received.repeatNote(productId: "p1", mode: .receive) == "Ya recibiste 20 uds de este producto hace un momento.")
        let counted = RecentScanSave(productId: "p1", name: "Aspirina", kind: .counted(before: 12, counted: 10))
        #expect(counted.repeatNote(productId: "p1", mode: .count) == "Ya contaste este producto hace un momento.")
    }

    @Test("given another product, or the same one in another mode, should not be a repeat")
    func notRepeat() {
        let received = RecentScanSave(productId: "p1", name: "Aspirina", kind: .received(20))
        #expect(received.repeatNote(productId: "p2", mode: .receive) == nil)
        #expect(received.repeatNote(productId: "p1", mode: .count) == nil)
    }
}

struct ScanCreateStockTests {
    @Test("given Consultar or Contar, Nuevo producto should show quantity, cost and supplier; given Recibir, its form asks for those")
    func showsInitialStock() {
        #expect(ScanMode.consult.createShowsInitialStock)
        #expect(ScanMode.count.createShowsInitialStock)
        #expect(!ScanMode.receive.createShowsInitialStock)
    }
}
