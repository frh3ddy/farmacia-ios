import Foundation

// MARK: - HTTP Method

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

// MARK: - API Endpoint

enum APIEndpoint {
    
    // MARK: - Setup Endpoints
    case setupStatus
    case setupSyncLocations   // Sync locations from Square during setup
    case initialSetup
    
    // MARK: - Auth Endpoints
    case deviceActivate
    case pinLogin
    case pinRefresh
    case switchLocation
    case currentUser
    case logout
    case auditLogs
    
    // MARK: - Employee Endpoints
    case createEmployee
    case listEmployees
    case getEmployee(id: String)
    case updateEmployee(id: String)
    case deleteEmployee(id: String)
    case resetPIN(employeeId: String)
    case resetPINLockout(employeeId: String)
    case assignLocations(employeeId: String)
    
    // MARK: - Inventory Endpoints
    case receiveInventory
    case getReceiving(id: String)
    case listReceivingsByLocation(locationId: String)
    case listReceivingsByProduct(productId: String)
    case receivingSummary(locationId: String)
    case retrySquareSync(receivingId: String)
    
    // MARK: - Adjustment Endpoints
    case createAdjustment
    case adjustmentDamage
    case adjustmentTheft
    case adjustmentExpired
    case adjustmentFound
    case adjustmentReturn
    case adjustmentCountCorrection
    case adjustmentWriteOff
    case getAdjustment(id: String)
    case adjustmentsByProduct(productId: String)
    case adjustmentsByLocation(locationId: String)
    case adjustmentSummary(locationId: String)
    case adjustmentTypes
    
    // MARK: - Reports Endpoints
    case cogsReport
    case valuationReport
    case profitMarginReport
    case adjustmentImpactReport
    case receivingSummaryReport
    case profitLossReport
    case dashboardReport
    
    // MARK: - Expense Endpoints
    case createExpense
    case listExpenses
    case getExpense(id: String)
    case updateExpense(id: String)
    case deleteExpense(id: String)
    case expenseSummary
    case expenseTypes
    
    // MARK: - Inventory Aging Endpoints
    case agingSummary
    case agingProducts
    case agingLocation
    case agingCategory
    case agingSignals
    case agingExpiring
    case agingClearCache
    
    // MARK: - Reconciliation Endpoints
    case reconcileProduct(productId: String)
    case reconcileLocation(locationId: String)
    case consumptionSummary(productId: String)
    case saleItemConsumption(saleItemId: String)
    case verifyFIFO(saleId: String)
    case batchDetail(batchId: String)
    
    // MARK: - Location Endpoints
    case listLocations
    case getLocation(id: String)
    
    // MARK: - Product Endpoints
    case listProducts
    case getProduct(id: String)
    case createProduct
    case updateProductPrice(id: String)
    case productSuppliers(productId: String)
    case productCostHistory(productId: String)
    case supplierCatalog(supplierId: String)
    
    // MARK: - Supplier Endpoints
    case listSuppliers
    
    // MARK: - Properties
    
    var path: String {
        switch self {
        // Setup
        case .setupStatus: return "/auth/setup/status"
        case .setupSyncLocations: return "/auth/setup/sync-locations"
        case .initialSetup: return "/auth/setup/initial"
            
        // Auth
        case .deviceActivate: return "/auth/device/activate"
        case .pinLogin: return "/auth/pin"
        case .pinRefresh: return "/auth/pin/refresh"
        case .switchLocation: return "/auth/switch-location"
        case .currentUser: return "/auth/me"
        case .logout: return "/auth/logout"
        case .auditLogs: return "/auth/audit-logs"
            
        // Employees
        case .createEmployee, .listEmployees: return "/employees"
        case .getEmployee(let id), .updateEmployee(let id), .deleteEmployee(let id): return "/employees/\(id)"
        case .resetPIN(let id): return "/employees/\(id)/pin"
        case .resetPINLockout(let id): return "/employees/\(id)/pin/reset-lockout"
        case .assignLocations(let id): return "/employees/\(id)/locations"
            
        // Inventory Receiving
        case .receiveInventory: return "/inventory/receive"
        case .getReceiving(let id): return "/inventory/receive/\(id)"
        case .listReceivingsByLocation(let locationId): return "/inventory/receive/location/\(locationId)"
        case .listReceivingsByProduct(let productId): return "/inventory/receive/product/\(productId)"
        case .receivingSummary(let locationId): return "/inventory/receive/location/\(locationId)/summary"
        case .retrySquareSync(let id): return "/inventory/receive/\(id)/retry-square-sync"
            
        // Adjustments
        case .createAdjustment: return "/inventory/adjustments"
        case .adjustmentDamage: return "/inventory/adjustments/damage"
        case .adjustmentTheft: return "/inventory/adjustments/theft"
        case .adjustmentExpired: return "/inventory/adjustments/expired"
        case .adjustmentFound: return "/inventory/adjustments/found"
        case .adjustmentReturn: return "/inventory/adjustments/return"
        case .adjustmentCountCorrection: return "/inventory/adjustments/count-correction"
        case .adjustmentWriteOff: return "/inventory/adjustments/write-off"
        case .getAdjustment(let id): return "/inventory/adjustments/\(id)"
        case .adjustmentsByProduct(let productId): return "/inventory/adjustments/product/\(productId)"
        case .adjustmentsByLocation(let locationId): return "/inventory/adjustments/location/\(locationId)"
        case .adjustmentSummary(let locationId): return "/inventory/adjustments/location/\(locationId)/summary"
        case .adjustmentTypes: return "/inventory/adjustments/types/list"
            
        // Reports
        case .cogsReport: return "/inventory/reports/cogs"
        case .valuationReport: return "/inventory/reports/valuation"
        case .profitMarginReport: return "/inventory/reports/profit-margin"
        case .adjustmentImpactReport: return "/inventory/reports/adjustment-impact"
        case .receivingSummaryReport: return "/inventory/reports/receiving-summary"
        case .profitLossReport: return "/inventory/reports/profit-loss"
        case .dashboardReport: return "/inventory/reports/dashboard"
            
        // Expenses
        case .createExpense, .listExpenses: return "/expenses"
        case .getExpense(let id), .updateExpense(let id), .deleteExpense(let id): return "/expenses/\(id)"
        case .expenseSummary: return "/expenses/summary/report"
        case .expenseTypes: return "/expenses/types/list"
            
        // Inventory Aging
        case .agingSummary: return "/inventory/aging/summary"
        case .agingProducts: return "/inventory/aging/products"
        case .agingLocation: return "/inventory/aging/location"
        case .agingCategory: return "/inventory/aging/category"
        case .agingSignals: return "/inventory/aging/signals"
        case .agingExpiring: return "/inventory/aging/expiring"
        case .agingClearCache: return "/inventory/aging/clear-cache"
            
        // Reconciliation
        case .reconcileProduct(let productId): return "/inventory/reconciliation/product/\(productId)"
        case .reconcileLocation(let locationId): return "/inventory/reconciliation/location/\(locationId)"
        case .consumptionSummary(let productId): return "/inventory/reconciliation/consumption/\(productId)"
        case .saleItemConsumption(let saleItemId): return "/inventory/reconciliation/sale-item/\(saleItemId)"
        case .batchDetail(let batchId): return "/inventory/reports/batch/\(batchId)"
        case .verifyFIFO(let saleId): return "/inventory/reconciliation/verify-fifo/\(saleId)"
            
        // Locations
        case .listLocations: return "/locations"
        case .getLocation(let id): return "/locations/\(id)"
            
        // Products
        case .listProducts: return "/products"
        case .getProduct(let id): return "/products/\(id)"
        case .createProduct: return "/products"
        case .updateProductPrice(let id): return "/products/\(id)/price"
        case .productSuppliers(let productId): return "/products/\(productId)/suppliers"
        case .productCostHistory(let productId): return "/products/\(productId)/cost-history"
        case .supplierCatalog(let supplierId): return "/products/supplier-catalog/\(supplierId)"
            
        // Suppliers
        case .listSuppliers: return "/admin/inventory/cutover/suppliers"
        }
    }
    
    var method: HTTPMethod {
        switch self {
        // Setup
        case .setupStatus:
            return .get
        case .setupSyncLocations, .initialSetup:
            return .post
            
        // Auth
        case .deviceActivate, .pinLogin, .pinRefresh, .switchLocation, .logout:
            return .post
        case .currentUser, .auditLogs:
            return .get
            
        // Employees
        case .createEmployee, .resetPIN, .resetPINLockout, .assignLocations:
            return .post
        case .listEmployees, .getEmployee:
            return .get
        case .updateEmployee:
            return .put
        case .deleteEmployee:
            return .delete
            
        // Inventory Receiving
        case .receiveInventory, .retrySquareSync:
            return .post
        case .getReceiving, .listReceivingsByLocation, .listReceivingsByProduct, .receivingSummary:
            return .get
            
        // Adjustments
        case .createAdjustment, .adjustmentDamage, .adjustmentTheft, .adjustmentExpired,
             .adjustmentFound, .adjustmentReturn, .adjustmentCountCorrection, .adjustmentWriteOff:
            return .post
        case .getAdjustment, .adjustmentsByProduct, .adjustmentsByLocation,
             .adjustmentSummary, .adjustmentTypes:
            return .get
            
        // Reports
        case .cogsReport, .valuationReport, .profitMarginReport, .adjustmentImpactReport,
             .receivingSummaryReport, .profitLossReport, .dashboardReport:
            return .get
            
        // Inventory Aging
        case .agingSummary, .agingProducts, .agingLocation, .agingCategory, .agingSignals, .agingExpiring:
            return .get
        case .agingClearCache:
            return .post
            
        // Expenses
        case .createExpense:
            return .post
        case .listExpenses, .getExpense, .expenseSummary, .expenseTypes:
            return .get
        case .updateExpense:
            return .put
        case .deleteExpense:
            return .delete
            
        // Reconciliation
        case .reconcileProduct, .reconcileLocation, .consumptionSummary,
             .saleItemConsumption, .verifyFIFO, .batchDetail:
            return .get
            
        // Locations
        case .listLocations, .getLocation:
            return .get
            
        // Products
        case .listProducts, .getProduct, .productSuppliers, .productCostHistory, .supplierCatalog:
            return .get
        case .createProduct:
            return .post
        case .updateProductPrice:
            return .patch
            
        // Suppliers
        case .listSuppliers:
            return .get
        }
    }
    
    var requiresDeviceToken: Bool {
        switch self {
        case .deviceActivate, .setupStatus, .setupSyncLocations, .initialSetup:
            return false
        default:
            return true
        }
    }
    
    var requiresSessionToken: Bool {
        switch self {
        case .deviceActivate, .pinLogin, .setupStatus, .setupSyncLocations, .initialSetup:
            return false
        default:
            return true
        }
    }
}
