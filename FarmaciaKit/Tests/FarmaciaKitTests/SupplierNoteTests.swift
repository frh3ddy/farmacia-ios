import Testing
@testable import FarmaciaKit

/// Supplier notes as shown in the detail's suppliers list. The cutover wrote
/// "Migrated from cutover <uuid>" on every migrated supplier; it means nothing to staff.
struct SupplierNoteTests {
    private let migrated = "Migrated from cutover 3f2a9c1e-5b7d-4e8a-9c0f-1a2b3c4d5e6f"

    @Test("given \"Migrated from cutover 3f2a9c1e-…\", should be nil")
    func migrationOnly() {
        #expect(SupplierNote.display(migrated) == nil)
    }

    @Test("given another note, should keep it as is", arguments: ["Caja de 10", "Pedir los lunes. Entrega martes", "-10% en caja"])
    func otherNotes(note: String) {
        #expect(SupplierNote.display(note) == note)
    }

    @Test("given the phrase inside a longer note, should remove only it and its separator")
    func insideLongerNote() {
        #expect(SupplierNote.display("Caja de 10 · \(migrated)") == "Caja de 10")
        #expect(SupplierNote.display("\(migrated) · Caja de 10") == "Caja de 10")
        #expect(SupplierNote.display("Caja de 10 · \(migrated) · entrega martes") == "Caja de 10 · entrega martes")
        #expect(SupplierNote.display("Caja de 10. \(migrated)") == "Caja de 10.")
    }

    @Test("given no note, empty or whitespace, should be nil", arguments: [nil, "", "   \n"] as [String?])
    func empty(note: String?) {
        #expect(SupplierNote.display(note) == nil)
    }
}
