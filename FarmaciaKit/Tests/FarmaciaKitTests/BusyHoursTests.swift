import Foundation
import Testing
@testable import FarmaciaKit

struct BusyHoursTests {
    // Square Reporting, last 90 days, Lolita. dayOfWeek 0 = Sunday.
    private let reference: [BusyHours.Cell] = [
        .init(dayOfWeek: 1, hour: 9, orders: 67), .init(dayOfWeek: 6, hour: 19, orders: 58),
        .init(dayOfWeek: 2, hour: 9, orders: 56), .init(dayOfWeek: 4, hour: 20, orders: 55),
        .init(dayOfWeek: 5, hour: 20, orders: 54), .init(dayOfWeek: 0, hour: 12, orders: 10),
    ]

    @Test("given the reference cells, should rank Mon 9h, Sat 19h, Tue 9h")
    func topThree() {
        #expect(BusyHours(cells: reference).topText == "lun 9 h · sáb 19 h · mar 9 h")
    }

    @Test("given cells from 9 to 20 h, should lay out Monday-first rows over those hours")
    func grid() {
        let busy = BusyHours(cells: reference)
        #expect(busy.hours == Array(9...20))
        #expect(busy.days.map(\.label) == ["lun", "mar", "mié", "jue", "vie", "sáb", "dom"])
        #expect(busy.share(day: 1, hour: 9) == 1)
        #expect(busy.share(day: 0, hour: 12) == 10.0 / 67)
    }

    @Test("given an hour the API left out, should count it as 0")
    func missingIsZero() {
        #expect(BusyHours(cells: reference).share(day: 3, hour: 15) == 0)
    }

    @Test("given no cells, should be empty with Sin datos de ventas")
    func empty() {
        let busy = BusyHours(cells: [])
        #expect(busy.isEmpty && busy.hours.isEmpty && busy.topText == "Sin datos de ventas")
    }

    @Test("given the API's JSON, should decode")
    func decodes() throws {
        let json = #"{"timezone":"America/Mexico_City","cells":[{"dayOfWeek":1,"hour":9,"orders":67}]}"#
        let response = try JSONDecoder().decode(BusyHours.Response.self, from: Data(json.utf8))
        #expect(response.timezone == "America/Mexico_City")
        #expect(BusyHours(cells: response.cells).topText == "lun 9 h")
    }

    @Test("given Sat 19 h and Mon 9 h both at 50 orders, should list lun 9 h first (equal counts: Monday-first, then earlier hour)")
    func tieOrder() {
        let busy = BusyHours(cells: [.init(dayOfWeek: 6, hour: 19, orders: 50), .init(dayOfWeek: 1, hour: 12, orders: 50),
                                     .init(dayOfWeek: 1, hour: 9, orders: 50), .init(dayOfWeek: 0, hour: 8, orders: 50)])
        #expect(busy.topText == "lun 9 h · lun 12 h · sáb 19 h")
        // The list shown when the grid doesn't fit (largest text sizes, small phones).
        #expect(busy.topSlots == ["lun 9 h", "lun 12 h", "sáb 19 h"])
    }

    @Test("given the API's time zone, should name its city in the caption", arguments: [
        ("America/Mexico_City", "Pedidos por hora · hora de Ciudad de México"),
        ("America/Chicago", "Pedidos por hora · hora de Chicago"),
        ("America/Port_of_Spain", "Pedidos por hora · hora de Port of Spain"),
    ])
    func caption(timezone: String, expected: String) {
        #expect(BusyHours.caption(timezone: timezone) == expected)
    }
}
