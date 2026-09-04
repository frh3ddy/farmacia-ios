import SwiftUI

// MARK: - PIN Entry View

struct PINEntryView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var viewModel = PINEntryViewModel()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                headerSection
                
                Spacer()
                
                // PIN Display
                pinDisplaySection
                
                Spacer()
                
                // Number Pad
                numberPadSection
            }
            .padding()
            .background(Color(.systemBackground))
            .navigationTitle("Inicio de Sesión")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            viewModel.showDeactivateAlert = true
                        } label: {
                            Label("Desactivar Dispositivo", systemImage: "xmark.shield")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .alert("Error de Inicio", isPresented: $viewModel.showError) {
                Button("OK", role: .cancel) {
                    viewModel.clearPIN()
                }
            } message: {
                Text(viewModel.errorMessage)
            }
            .alert("Desactivar Dispositivo", isPresented: $viewModel.showDeactivateAlert) {
                Button("Cancelar", role: .cancel) {}
                Button("Desactivar", role: .destructive) {
                    authManager.deactivateDevice()
                }
            } message: {
                Text("Esto eliminará este dispositivo de Farmacia. Necesitarás credenciales de dueño/gerente para reactivarlo.")
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        Text("Ingresa tu PIN para iniciar sesión")
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.top, 20)
    }
    
    // MARK: - PIN Display Section
    
    private var pinDisplaySection: some View {
        VStack(spacing: 24) {
            // PIN Dots
            HStack(spacing: 20) {
                ForEach(0..<AppConfiguration.pinLength, id: \.self) { index in
                    Circle()
                        .fill(index < viewModel.pin.count ? Color.blue : Color(.systemGray4))
                        .frame(width: 20, height: 20)
                        .animation(.easeInOut(duration: 0.15), value: viewModel.pin.count)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("PIN")
            .accessibilityValue("\(viewModel.pin.count) de \(AppConfiguration.pinLength) dígitos ingresados")
            
            // Loading indicator
            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
    }
    
    // MARK: - Number Pad Section
    
    private var numberPadSection: some View {
        VStack(spacing: 16) {
            ForEach(0..<3) { row in
                HStack(spacing: 24) {
                    ForEach(1...3, id: \.self) { col in
                        let number = row * 3 + col
                        numberButton(number: number)
                    }
                }
            }
            
            // Bottom row: empty, 0, delete
            HStack(spacing: 24) {
                // Empty space
                Color.clear
                    .frame(width: 80, height: 80)
                
                // Zero
                numberButton(number: 0)
                
                // Delete
                deleteButton
            }
        }
        .padding(.bottom, 40)
    }
    
    // MARK: - Number Button
    
    private func numberButton(number: Int) -> some View {
        Button {
            viewModel.appendDigit(number, authManager: authManager)
        } label: {
            Text("\(number)")
                .font(.largeTitle)
                .fontWeight(.medium)
                .frame(width: 80, height: 80)
                .background(Color(.systemGray6))
                .clipShape(.rect(cornerRadius: 40))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.pin.count >= AppConfiguration.pinLength || viewModel.isLoading)
    }
    
    // MARK: - Delete Button
    
    private var deleteButton: some View {
        Button {
            viewModel.deleteDigit()
        } label: {
            Image(systemName: "delete.left")
                .font(.title2)
                .frame(width: 80, height: 80)
                .background(Color(.systemGray6))
                .clipShape(.rect(cornerRadius: 40))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.pin.isEmpty || viewModel.isLoading)
        .accessibilityLabel("Eliminar")
    }
}

// MARK: - PIN Entry View Model

@MainActor
class PINEntryViewModel: ObservableObject {
    @Published var pin: String = ""
    @Published var isLoading: Bool = false
    @Published var showDeactivateAlert: Bool = false
    @Published var showError: Bool = false
    @Published var errorMessage: String = ""

    func appendDigit(_ digit: Int, authManager: AuthManager) {
        guard pin.count < AppConfiguration.pinLength else { return }
        pin += "\(digit)"
        
        // Auto-submit when PIN is complete
        if pin.count == AppConfiguration.pinLength {
            Task {
                await login(authManager: authManager)
            }
        }
    }
    
    func deleteDigit() {
        guard !pin.isEmpty else { return }
        pin.removeLast()
    }
    
    func clearPIN() {
        pin = ""
    }
    
    func login(authManager: AuthManager) async {
        isLoading = true

        do {
            // The device is bound to one location at activation — PIN login
            // always grants access to that location. Employees assigned to
            // more than one location switch between them after login via
            // "Cambiar Ubicación" (LocationSwitchView), not here.
            try await authManager.loginWithPIN(pin: pin)
        } catch let error as NetworkError {
            // If device is not activated or unauthorized, go back to activation
            if case .deviceNotActivated = error {
                authManager.deactivateDevice()
                isLoading = false
                return
            }
            if case .unauthorized = error {
                // Check if it's a device issue vs wrong PIN
                if error.errorDescription?.contains("device") == true {
                    authManager.deactivateDevice()
                    isLoading = false
                    return
                }
            }
            errorMessage = error.errorDescription ?? "Error de inicio de sesión"
            showError = true
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
        
        isLoading = false
    }
}

// MARK: - Preview

#Preview {
    PINEntryView()
        .environmentObject(AuthManager.shared)
}
