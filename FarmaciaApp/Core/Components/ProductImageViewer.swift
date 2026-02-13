import SwiftUI

// MARK: - Full-Screen Product Image Viewer
// Supports pinch-to-zoom, double-tap to zoom, and drag to pan.
// Swipe down to dismiss.

struct ProductImageViewer: View {
    let imageUrl: String
    let productName: String
    @Environment(\.dismiss) var dismiss
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dismissOffset: CGFloat = 0
    
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 5.0
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    Color.black.ignoresSafeArea()
                    
                    if let url = URL(string: imageUrl) {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .scaleEffect(scale)
                                    .offset(x: offset.width, y: offset.height + dismissOffset)
                                    .gesture(zoomGesture)
                                    .gesture(panGesture)
                                    .gesture(dismissDragGesture)
                                    .onTapGesture(count: 2) {
                                        withAnimation(.spring(response: 0.3)) {
                                            if scale > 1.0 {
                                                // Reset to original
                                                scale = 1.0
                                                lastScale = 1.0
                                                offset = .zero
                                                lastOffset = .zero
                                            } else {
                                                // Zoom to 3x
                                                scale = 3.0
                                                lastScale = 3.0
                                            }
                                        }
                                    }
                                    
                            case .failure:
                                VStack(spacing: 12) {
                                    Image(systemName: "photo.badge.exclamationmark")
                                        .font(.system(size: 50))
                                        .foregroundColor(.gray)
                                    Text("Failed to load image")
                                        .foregroundColor(.gray)
                                }
                                
                            case .empty:
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(1.5)
                                    
                            @unknown default:
                                EmptyView()
                            }
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(productName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .lineLimit(1)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }
    
    // MARK: - Gestures
    
    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let newScale = lastScale * value.magnification
                scale = min(max(newScale, minScale), maxScale)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= minScale {
                    withAnimation(.spring(response: 0.3)) {
                        offset = .zero
                        lastOffset = .zero
                    }
                }
            }
    }
    
    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale > 1.0 else { return }
                offset = CGSize(
                    width: lastOffset.width + value.translation.width,
                    height: lastOffset.height + value.translation.height
                )
            }
            .onEnded { _ in
                lastOffset = offset
            }
    }
    
    private var dismissDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                guard scale <= 1.0 else { return }
                // Only allow downward drag to dismiss
                if value.translation.height > 0 {
                    dismissOffset = value.translation.height
                }
            }
            .onEnded { value in
                guard scale <= 1.0 else { return }
                if value.translation.height > 150 {
                    dismiss()
                } else {
                    withAnimation(.spring(response: 0.3)) {
                        dismissOffset = 0
                    }
                }
            }
    }
}
