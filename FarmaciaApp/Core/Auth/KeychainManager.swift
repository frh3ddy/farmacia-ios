import Foundation
import Security

// MARK: - Keychain Manager

final class KeychainManager {
    
    // MARK: - Singleton
    
    static let shared = KeychainManager()
    
    // MARK: - Properties
    
    private let service = AppConfiguration.keychainServiceName
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Device Token Management
    
    var deviceToken: String? {
        get {
            return getString(forKey: AppConfiguration.deviceTokenKey)
        }
        set {
            if let value = newValue {
                setString(value, forKey: AppConfiguration.deviceTokenKey)
            } else {
                delete(forKey: AppConfiguration.deviceTokenKey)
            }
        }
    }
    
    // MARK: - Last Employee ID
    
    var lastEmployeeId: String? {
        get {
            return getString(forKey: AppConfiguration.employeeIdKey)
        }
        set {
            if let value = newValue {
                setString(value, forKey: AppConfiguration.employeeIdKey)
            } else {
                delete(forKey: AppConfiguration.employeeIdKey)
            }
        }
    }
    
    // MARK: - Generic Keychain Operations
    
    func getString(forKey key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess,
              let data = result as? Data,
              let string = String(data: data, encoding: .utf8) else {
            return nil
        }
        
        return string
    }
    
    @discardableResult
    func setString(_ value: String, forKey key: String) -> Bool {
        // Delete existing item first
        delete(forKey: key)
        
        guard let data = value.data(using: .utf8) else {
            return false
        }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        
        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }
    
    @discardableResult
    func delete(forKey key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
    
    // MARK: - Clear All
    
    func clearAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        
        SecItemDelete(query as CFDictionary)
    }
}
