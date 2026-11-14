# Farmacia iOS

SwiftUI iOS application for Farmacia multi-location pharmacy inventory management system.

## Overview

This iOS app provides a mobile interface for managing pharmacy inventory, including:
- Multi-location support with location switching
- Employee PIN-based authentication
- Inventory receiving and adjustments
- Real-time reports and dashboards
- Expense management
- Square POS integration visibility

## Requirements

- iOS 17.0+
- Xcode 15.0+
- Swift 5.9+

## Project Structure

```
FarmaciaApp/
├── App/
│   ├── FarmaciaApp.swift          # Main app entry point
│   └── AppConfiguration.swift      # Environment and app config
│
├── Core/
│   ├── Network/
│   │   ├── APIClient.swift         # HTTP client with auth
│   │   ├── APIEndpoint.swift       # All API endpoints
│   │   └── NetworkError.swift      # Error handling
│   │
│   ├── Auth/
│   │   ├── AuthManager.swift       # Authentication state
│   │   └── KeychainManager.swift   # Secure storage
│   │
│   ├── Storage/                    # Local persistence
│   └── Extensions/                 # Swift extensions
│
├── Features/
│   ├── Auth/
│   │   └── Views/
│   │       ├── DeviceActivationView.swift
│   │       ├── PINEntryView.swift
│   │       └── LocationSwitchView.swift
│   │
│   ├── Dashboard/
│   │   └── Views/
│   │       ├── MainTabView.swift
│   │       ├── DashboardView.swift
│   │       └── SettingsView.swift
│   │
│   ├── Inventory/
│   │   └── Views/                  # receive/adjust forms, opened from product detail
│   │       ├── ReceiveInventoryFormView.swift
│   │       ├── AdjustmentFormView.swift
│   │       └── InventoryViewModel.swift
│   │
│   ├── Reports/
│   │   └── Views/
│   │       └── ReportsView.swift
│   │
│   └── Employees/
│       └── Views/
│           └── EmployeesView.swift
│
├── Models/
│   ├── Employee.swift
│   ├── Device.swift
│   ├── Location.swift
│   ├── Product.swift
│   ├── Inventory.swift
│   ├── Adjustment.swift
│   ├── Expense.swift
│   └── Reports.swift
│
└── Resources/
    └── Assets.xcassets
```

## Authentication Flow

### Device Activation (One-time setup)
1. Owner/Manager enters email and password
2. Backend validates credentials and returns device token
3. Device token stored in iOS Keychain
4. Device is now activated for all employees

### Employee Login (Daily)
1. Employee selects their location
2. Employee enters 4-6 digit PIN
3. Backend validates PIN and returns session token
4. Session token stored in memory (4-hour expiry)

### API Authentication Headers
```
Authorization: Bearer <deviceToken>
X-Session-Token: <sessionToken>
```

## Features

### Dashboard
- Real-time sales and profit overview
- Inventory valuation summary
- Recent adjustments
- P&L snapshot

### Inventory Management
Opened from a product (Productos → product → Recibir Inventario / Ajustar Inventario).
- Stock is added only at a store that sells the product: a product sold only at another store shows no Recibir / Encontrado / Devolución there (removals stay available)
- Receive new inventory with cost tracking
- Quick adjustments (damage, theft, expired, found, etc.); an adjustment that adds stock uses the product's last cost, and asks for a unit cost only when the product has none on record
- Count correction by counted total against the store's live stock (needs a connection)
- Employees with more than one store see a thin strip in the store's color with its name under the nav bar of Recibir, Ajustar, the scanner and Nuevo producto, and Recibir's button names the store ("Recibir en Centro"), so stock doesn't land in the wrong store. Each store's color is derived from its id, so every device shows the same one
- Before saving, adjustments, counts and receivings show what they do to this store's stock ("Centro · 42 → 39 (−3)"), and warn when a removal is more than the stock on hand; the product row at the top shows the same fresh stock
- Recibir inventario puts the quantity first: a large number with −/+ (hold to repeat), Unidades / Cajas, and with Cajas the arithmetic shown ("3 × 12 = 36 uds")
- Supplier, invoice and unit cost sit together (one piece of paper); the supplier's last cost fills the cost, and a change shows as "▲ 8% vs último $16.50"; "Sin proveedor" is a choice in the picker; an empty (or cleared) cost shows the previous one as its placeholder ("Anterior 16.50": the supplier's last cost, else the product's average; `ReceivingCost.hint`)
- Tapping Recibir inventario while the supplier and its cost are still loading waits (the button shows its spinner), then saves; if the supplier list fails to load, the section says so and you pick one or type the cost
- Changing the sale price while receiving offers margin chips: "Actual" (the margin at the supplier's last cost, kept at the new cost) pre-selected, then 30 · 40 · 50 %, each showing its price (rounded up to $0.50)
- Lot and expiry share a section; notes come last. For a product whose latest receiving had an expiry (or that was never received) the section sits right after the quantity, expiry first; otherwise it's at the bottom
- Expiry is picked as month and year (two wheels, no day calendar) and saved as the 1st of that month, so there's time to sell the lot at a discount; it starts empty, and empty means no expiry. A month that has already started warns that the lot saves as expired
- A camera button in the Lote row reads the lot and expiry off the box (VisionKit live text, or exactly from a GS1 DataMatrix when there is one), fills both and closes; it closes as soon as it reads a caducidad, with the lote if read in the same moment (`LotScan.autoAccept`); a lote alone waits for Usar. Boxes with "Lote:"/"Caducidad:" in a header, or no labels at all, and the values inkjet-printed elsewhere: the lote is the number printed with the caducidad, on its line or just above (`LotNumber.unlabeled`, text read in page order by `ReadingOrder`); spaced dot-matrix, 0-for-O months ("0CT", "AG0"), a lote glued to the month and prices that look like dates are handled; device only
- A price changed while receiving goes to every store (and Square POS) when the owner changes it, to the current store when a manager does; a note under Nuevo precio says which. The receiving saves straight from the button, no review step
- Editar Precio: the owner's "Aplicar en todas las sucursales" starts on (turn it off to price one store), also when the change doesn't go to Square; a manager prices their own store. A product sold at only one store has no switch. The note under the price mentions Square POS only for products that are in Square
- Money fields show a ⊗ while editing to empty them; an applied margin chip can be released with the ⊗ next to the margin, keeping the price as a manual price
- Both inventory forms have one full-width button at the bottom that is always enabled; a tap with something missing focuses the first problem field, shows the message under it and shakes it (not with Reduce Motion), and the line above the button says what's missing ("Falta cantidad y costo")
- Lot expiry shows in words and an icon, not just color ("2 vencidos", "1 por vencer"; caution from 90 days)
- Nuevo producto: photo beside a wrapping name (counter from 28 characters; Square POS and receipts show ~32), then Precio (cost → margin chips → price; the price follows the cost while a chip is picked), Identificación (SKU, barcode with a scan button), Inventario inicial (supplier, caducidad and lote, with the lot camera, only with a quantity; uses the cost from Precio; also shown from the scanner's Contar, not Recibir), Disponibilidad and Descripción. A cost without a quantity is allowed (it only suggests the price)
- After creating, the button shows a checkmark and the sheet closes; an alert appears only when there's something to read (offline queue, photo not uploaded, Square POS not reached)
- Switching store returns the other tabs to their first screen, so nothing from the previous store or role stays open
- Receiving and adjustment history (product activity and global history), for the current store only
- Sueltos (Más, owner/manager): link a box product to its loose product for the current store, set pieces per box (the same at every store), or unlink; pick each product by typing or scanning its barcode, with its photo; see the store's linked pairs and tap one to edit or unlink it
- Transferencias (Más, owner/manager): send a list of products to another store (each pick or scan opens a sheet with the product, this store's stock and expiry dates, and a −/+ quantity up to the stock; the newest is on top, a re-pick edits its quantity, and each row has its own −/+) in one shipment, all or nothing (FIFO: the oldest lots leave first and keep their cost, received date and expiry at the other store); by default the other store gets the stock at once, or "Confirmar al llegar" leaves it in transit until that store receives it in "Por recibir" (one count per product; a shortfall comes off the last lot); a manager without access to the other store always sends with "Confirmar al llegar"; quantities are checked against this store's stock before sending, and errors name the product; the list stays on the phone (per employee and store) until it's sent or cleared with "Vaciar lista", its stock refreshes when it loads (POST /transfers/stock) with a note naming what changed, and changing a list after a send that may have gone through warns that it could arrive twice
- Conteo inicial (owner, Ajustes): a store-wide recount that fixes the stock the migration loaded without counting as shrinkage. While it's open, every count at the store (scanner Contar shows "Conteo inicial en curso", and the detail screen's Corrección de Conteo) is saved as Conteo inicial, including a count that matches the stock, so the product counts as counted. "Ver no contados" lists products still showing stock that nobody counted (largest value first) with "Poner en 0" per row and "Poner todos en 0" after a confirmation (`3 productos · 8 unidades · $80.00`). Units and Valor de inventario change; P&L, Ganancia neta and the loss report don't (`StockCountSession`, `CountSave`, `UncountedSummary`). Recibir on a product the open count hasn't counted warns to count it first, since "Poner en 0" would zero the received units too (`ReceiveCountWarning`)
- Caducidad (Vence) is picked as month + year on wheels in a bottom sheet (Listo, Quitar caducidad), so they're never cut off below a lot row; an empty one opens a year out (`MonthYear.openingValue`). Same in Conteo, Recibir and Nuevo producto
- Counting (Corrección de Conteo and Conteo inicial) uses the receiving stepper, starting at the current stock. In a Conteo inicial: "Sin cambios: hay N" saves in one tap; "Ya contado en este conteo: 10 · 5 nov, Fredy" shows when the product was already counted (counts span days); and "Lotes y caducidad" pre-fills the product's current lots (caducidad required, lote optional, camera scan or "Escanear caja"). Changing the count, or adding/removing a lot, spreads the count over the lots (one lot takes it all, several split it evenly; a lot edited by hand keeps its quantity and the others share the rest) and each lot has its own ± stepper. Lots may cover less than the count ("N sin lote"), never more; untouched pre-filled lots aren't sent; a lot left at 0 units is ignored. Razón and Notas are saved with the count (API `feature/stock-count-notes`), and every Conteo inicial write names the store shown (`CountLots`, `LotSplit`, `CurrentLot`, `CountedEntry`)
- Square sync status on each receiving and adjustment; the owner can retry a failed sync from product activity or global history

### Products
- The on-device product cache (used by the barcode scanner) stays current with a delta sync (`GET /products/sync`): opening Productos fetches only what changed since the last sync; the full catalog is downloaded once per store
- Products carry their barcode (`gtin`, Square's GTIN field), shown in product detail
- Product detail is one screen of 5 blocks (docs/product-detail-findings.md): the name wraps (never truncated) with `SKU · ‖ barcode` under it; price and cost printed once, as ink (`MoneyText`), with the margin in percent and pesos (`Margen 55.5% · $122.00 por unidad`, `PriceMargin`). The cost is the latest supplier cost (preferred, else first; average without a supplier, `UnitCost`), with where it came from (`Moscoso · Mejor precio · compra 2 nov · 3 proveedores` → costs and suppliers sheet); Inventario with the other stores and Movimientos; Lotes (FIFO) with one chip that is neutral unless something needs attention (`ProductAlert`: vencido, agotado, riesgo, por vencer — no fixed "Bajo"), shelf age in words (`AgingSentence`), and per lot `valor del lote` and a caducidad row (`Vence 15 feb 2028 · 15 meses`, `Expiry.countdown`); an empty activity is one row; Ajustar and Recibir inventario sit in a bottom bar. Dates and timestamps use one format (`DisplayDate`), money one (`$220.00`, the currency code once per block); textual green is the accessible `#0F7B3F` app-wide (`Tone.positive`). Inventario shows how the product sells, with the same rate as Alertas ("Vende ~1 al día · última venta hace 2 días", `StockAlert.salesLine` from the API's `stockAlert.rate`; no dead-stock caution — Lotes flags old stock). The costs and suppliers sheet hides the cutover's "Migrated from cutover <id>" supplier note (`SupplierNote`); the aging bar's segments always fit its width (`BarSegments`)
- Scanning a barcode finds the product by SKU or barcode, whether saved as the 13 digits on the box or the 14-digit form the iPhone sometimes reads (`03664798067460` = `3664798067460`, `BarcodeLookup.codeVariants`/`matches`), offline from the on-device cache too
- The scanner has three modes (`Consultar | Recibir | Contar`, remembered; Recibir and Contar for owners and managers): Consultar opens the product (a product created from an unknown code opens too); Recibir and Contar open its receive form or Corrección de Conteo in place, then reopen the scanner for the next item with the last save in a strip (`✓ Aspirina 500mg · +20 uds` / `12 → 10 (−2)`; tap it to open the product). Scanning the same product again right after shows a reminder. A count that matches the stock closes as "Sin cambios". Each count saves at once, since the API works out the change from its own stock when it saves (`ScanMode`, `ScanNext`, `RecentScanSave`). Recibir has "Recibiendo de": the delivery's supplier, preselected in every receive form of the run (over the product's preferred one; "Sin proveedor" means none for the run) until the scanner closes (`RunSupplier`, `PreferredSupplier.pick`). An unknown code in Recibir opens Nuevo producto, then the receive form with the cost typed there already in (only the quantity is left), then the scanner (`ScanNext.receive(cost:)`, `ReceivingCost.prefill`)
- Nuevo Producto has a "Código de barras" field (8, 12, 13 or 14 digits, sent to Square as the item's barcode); a scan that finds nothing fills it with the 13 digits on the box and leaves the SKU for the server to generate
- The Products stats row reads "X de Y sincronizados con Square", both from the server's catalog counts
- Catalog counts (stock chips, synced, stock alerts) come from the server for every role; a cashier's have no low-margin count, since it's worked out from cost
- Productos is search-first (`ProductsScreen`): the search field and scanner on top, then chips with counts (Sin Stock, Stock Bajo, Por Vencer, Pausados, plus En Riesgo and Margen Bajo for owners and managers), each opening its short server list; with no search and no chip, the 10 products opened most recently on this phone (`RecentProducts`, from the cache, so offline too). "Ver todo" opens the full catalog with its sort and cards/list switch; search and chip lists keep the server's order (search is ranked; Sin Stock is most recent stock-out first). Counts show "—" until they load
- Stock badges follow the API's per-product alert (`StockAlert`, docs/stock-alerts-design.md): only regular sellers alert ("Agotado" red, "Bajo" amber); a slow mover at 0 is a gray "Agotado"; "Agotado hace 3 días" when the API knows since when; "Pausado · Proveedor sin surtido" for a product paused at this store. A server without alerts falls back to the fixed cutoffs (0, 1–9). Filter chip, margin and lot-age colors follow what they mean (`StockLevel`, `ProductFilter.tone`, `BatchAge.tone` in FarmaciaKit)
- Pausar / Reanudar (owners and managers) at the end of the product's Ajustar menu: a reason, an optional note, and the replacement for "Reemplazado por equivalente" (`PauseForm`). A paused product stops alerting at this store and resumes by itself when the store receives it
- Alertas → Ver Productos: Sin Stock and Stock Bajo are the server's ranked lists (`AlertList`, `filter=outAlert|lowAlert`): only regular sellers that aren't paused, the most lost sales a day first, paged with no 200 cap. Each row says why it matters ("Vende ~3 al día" under the "Agotado hace 2 días" badge, "Vende ~1 al día · alcanza para ~4 días"). Margen Bajo stays for owners and managers. The card's counts come from `/products/counts` (`outAlert`, `lowStock`, `lowMargin`)
- Lot age colors, the 0–30d / 31–90d / 90+d counts and the aging chart use the API's aging buckets
- Lotes FIFO lists lots in the order they sell (oldest first, "Sale siguiente" on the next one); the lot detail is in Spanish, with stock left as a progress bar, movements newest first and a retry on load errors
- Product photo (camera or library): square crop → background removal → preview; the crop screen opens on the first try
- In Nuevo producto, the photo also names the product: an empty Nombre is filled, a typed one gets a chip ("Sugerencia: X · Usar"), and an empty Descripción gets the presentation ("100 ml", "30 tabletas"). Apple Intelligence reads the photo itself where the phone has it (iOS 27, e.g. iPhone 15 Pro); otherwise Vision uses the label's biggest text, then the object and its color ("Caja blanca", "Lentes de sol negros"), from a short Spanish list of what a pharmacy stocks (`PhotoNameSuggestion`, `LabelName`, `Presentation`, `ObjectName`, `ColorName` in FarmaciaKit)

### Reports
- Cost of Goods Sold (COGS)
- Profit Margin analysis
- Inventory Valuation
- Adjustment Impact
- Receiving Summary
- Profit & Loss statement
- Horas pico (owner/manager): orders per weekday × hour from Square sales history, on Inicio (90 days, refreshed with the dashboard) and in Reportes (30 días–2 años), with the top 3 slots as text (`BusyHours`; equal counts list Monday-first) and the time zone named ("hora de Ciudad de México"); when the grid doesn't fit (largest text sizes) it shows the top slots as a list
- Merma in the P&L (dashboard card and statement) is losses; stock that came back (Encontrado, a count corrected up) shows apart as "Mercancía recuperada" and lowers the expense total

### Design system
- Status colors come from meaning (`Tone`: positive/caution/critical/info/neutral) across Productos, Lotes, Gastos,
  Empleados, Nómina, aging risk (Alto and Crítico both red) and gain/loss figures; empty and error screens use the standard iOS layout with a retry where loading can fail

### Employee Management (Owner only)
- Add/edit employees
- Assign locations
- Reset PINs
- View activity

## Configuration

Edit `AppConfiguration.swift` to change:
- API base URL per environment
- Session duration
- PIN configuration
- Keychain service name

## Backend API

This app connects to the Farmacia NestJS backend:
- **Repository**: https://github.com/frh3ddy/farmacia-ops
- **Documentation**: query the farmacia-ops graphify knowledge graph (`graphify-out/`) for current endpoint contracts and domain model — the old hand-written `API_CONTRACTS.md`/`CONTEXT.md` were removed for having drifted stale.

## Development

### Building
```bash
# Open in Xcode
open FarmaciaApp.xcodeproj

# Or build from command line
xcodebuild -scheme FarmaciaApp -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Dev and production side by side
The two builds are separate apps, so both can be installed on the same phone:

| | Debug | Release |
|---|---|---|
| Name on home screen | Farmacia Dev (amber **DEV** icon) | Farmacia |
| Bundle ID | `com.farmacia.ios.dev` | `com.farmacia.ios` |
| API | local (`AppConfiguration` `.development`) | production |
| Install on iPhone | `scripts/dev-build-install.sh` (or Run in Xcode) | `scripts/release-build-install.sh` |

Each keeps its own Keychain entries, so each app is activated once against its own server.
Both scripts install on the first connected (or Wi-Fi paired) iPhone; the dev script warns if the local API isn't reachable and keeps `build/dev` between runs for faster rebuilds.
On a free Apple account, the two count as 2 of the 3 sideloaded apps a device allows.

**Profile renewal**: a free account's signing profile lasts 7 days, after which the app stops opening.
- `scripts/install-renew-agent.sh` (run once) schedules `scripts/renew-profile.sh` daily at 9:00. When the release profile has under 48h left, it reinstalls the release on both iPhones and posts a Mac notification.
- If a phone fails (locked, or off this Wi-Fi), an alert says how long the app has left. Retry with `FORCE=1 scripts/renew-profile.sh`, or let the next day's run try again.
- The log is `~/Library/Logs/farmacia-renew.log`.
- The Mac must be awake and signed in to the Apple ID in Xcode.
- The Debug app isn't renewed; reinstall it with `scripts/dev-build-install.sh`.
Brand art (icon, logo lockups) comes from `scripts/brand/render-brand.swift`; see `docs/brand-guidelines.md`.

### Testing
```bash
xcodebuild test -scheme FarmaciaApp -destination 'platform=iOS Simulator,name=iPhone 15'
```

## License

Private - Farmacia Operations
