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
- Before saving, adjustments, counts and receivings show what they do to this store's stock ("Centro · 42 → 39 (−3)"), and warn when a removal is more than the stock on hand
- Receive by the box: Cajas × Piezas por caja fills Cantidad
- Lot expiry shows in words and an icon, not just color ("2 vencidos", "1 por vencer"; caution from 90 days)
- Nuevo Producto says next to the field why Crear is off (price 0, a quantity without cost, a cost without quantity)
- Switching store returns the other tabs to their first screen, so nothing from the previous store or role stays open
- Receiving and adjustment history (product activity and global history)
- Square sync status on each receiving and adjustment; the owner can retry a failed sync from product activity or global history

### Products
- The on-device product cache (used by the barcode scanner) stays current with a delta sync (`GET /products/sync`): opening Productos fetches only what changed since the last sync; the full catalog is downloaded once per store
- The Products stats row reads "X de Y sincronizados con Square", both from the server's catalog counts
- Catalog counts (stock chips, synced, stock alerts) come from the server for every role; a cashier's have no low-margin count, since it's worked out from cost
- Product list badges in Spanish ("Agotado" at 0, "Bajo" at 1–9, the API's stock-filter cutoffs); filter chip, margin and lot-age colors follow what they mean (`StockLevel`, `ProductFilter.tone`, `BatchAge.tone` in FarmaciaKit)
- Lot age colors, the 0–30d / 31–90d / 90+d counts and the aging chart use the API's aging buckets
- Lotes FIFO lists lots in the order they sell (oldest first, "Sale siguiente" on the next one); the lot detail is in Spanish, with stock left as a progress bar, movements newest first and a retry on load errors
- Product photo (camera or library): square crop → background removal → preview; the crop screen opens on the first try

### Reports
- Cost of Goods Sold (COGS)
- Profit Margin analysis
- Inventory Valuation
- Adjustment Impact
- Receiving Summary
- Profit & Loss statement
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
Brand art (icon, logo lockups) comes from `scripts/brand/render-brand.swift`; see `docs/brand-guidelines.md`.

### Testing
```bash
xcodebuild test -scheme FarmaciaApp -destination 'platform=iOS Simulator,name=iPhone 15'
```

## License

Private - Farmacia Operations
