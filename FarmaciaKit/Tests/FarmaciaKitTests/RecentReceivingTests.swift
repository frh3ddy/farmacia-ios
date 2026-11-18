import Foundation
import Testing
@testable import FarmaciaKit

/// Recibir warns about this store's receivings of the product since yesterday,
/// from the server's history (it survives closing the scanner and covers other phones).
struct RecentReceivingTests {
    private let zone = TimeZone(identifier: "America/Mexico_City")!
    /// 18 nov 2026, 12:00 in Mexico City.
    private let now = Date(timeIntervalSince1970: 1_795_024_800)

    private func at(_ hoursAgo: Double, _ quantity: Int, store: String = "centro", supplier: String? = "Nadro") -> RecentReceiving.Row {
        .init(receivedAt: now.addingTimeInterval(-hoursAgo * 3600), quantity: quantity, locationId: store, supplierName: supplier)
    }

    private func note(_ rows: [RecentReceiving.Row]) -> String? {
        RecentReceiving.note(rows, locationId: "centro", now: now, timeZone: zone)
    }

    @Test("given one receiving of 20 today at 10:30 from Nadro, should say when, how many and from whom")
    func oneToday() {
        #expect(note([at(1.5, 20)]) == "Ya se recibieron 20 uds hoy a las 10:30 a.m. (Nadro). Revisa antes de recibir otra vez.")
    }

    @Test("given one receiving yesterday evening, should still warn and say ayer")
    func yesterday() {
        #expect(note([at(16, 5, supplier: nil)]) == "Ya se recibieron 5 uds ayer a las 8:00 p.m. Revisa antes de recibir otra vez.")
    }

    @Test("given a receiving two days ago, should not warn")
    func olderIgnored() {
        #expect(note([at(40, 5)]) == nil)
    }

    @Test("given a receiving today at another store, should not warn")
    func otherStoreIgnored() {
        #expect(note([at(1, 5, store: "oriente")]) == nil)
    }

    @Test("given two receivings since yesterday (newest first), should count them, total them and name the latest")
    func several() {
        #expect(note([at(1.5, 20), at(16, 10)])
                == "Ya se recibió 2 veces desde ayer (30 uds); la última hoy a las 10:30 a.m. (Nadro). Revisa antes de recibir otra vez.")
    }

    @Test("given two receivings both today, should say 'hoy', not 'desde ayer'")
    func severalToday() {
        #expect(note([at(1.5, 20), at(3, 10)])
                == "Ya se recibió 2 veces hoy (30 uds); la última hoy a las 10:30 a.m. (Nadro). Revisa antes de recibir otra vez.")
    }

    @Test("given 1 unit, should say ud")
    func oneUnit() {
        #expect(note([at(1.5, 1)]) == "Ya se recibió 1 ud hoy a las 10:30 a.m. (Nadro). Revisa antes de recibir otra vez.")
    }

    @Test("given a receiving at 1:15, should say 'a la 1:15', not 'a las'")
    func oneOClock() {
        #expect(note([at(10.75, 3, supplier: nil)]) == "Ya se recibieron 3 uds hoy a la 1:15 a.m. Revisa antes de recibir otra vez.")
    }

    @Test("given the history couldn't load, should say the check didn't run (not look like a clean history)")
    func unavailable() {
        #expect(RecentReceiving.note(nil, locationId: "centro", now: now, timeZone: zone)
                == "No se pudo revisar si ya se recibió hoy o ayer.")
    }

    @Test("given no history, should not warn")
    func none() {
        #expect(note([]) == nil)
    }
}
