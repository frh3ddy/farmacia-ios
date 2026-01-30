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
│   │   └── Views/
│   │       └── InventoryView.swift
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
- Receive new inventory with cost tracking
- Quick adjustments (damage, theft, expired, found, etc.)
- View receiving history
- Square sync status

### Reports
- Cost of Goods Sold (COGS)
- Profit Margin analysis
- Inventory Valuation
- Adjustment Impact
- Receiving Summary
- Profit & Loss statement

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
- **Documentation**: See `API_CONTRACTS.md` and `CONTEXT.md`

## Related Documentation

- `CONTEXT.md` - System overview and implementation status
- `API_CONTRACTS.md` - Full API endpoint documentation

## Development

### Building
```bash
# Open in Xcode
open FarmaciaApp.xcodeproj

# Or build from command line
xcodebuild -scheme FarmaciaApp -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Testing
```bash
xcodebuild test -scheme FarmaciaApp -destination 'platform=iOS Simulator,name=iPhone 15'
```

## License

Private - Farmacia Operations
