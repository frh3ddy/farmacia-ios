import CoreGraphics
import CoreText
import Foundation
import FarmaciaKit
import Testing
@testable import FarmaciaScan

/// Synthetic photos: a colored box on a light-gray counter, or the counter alone.
enum SyntheticPhoto {
    static let size = 400

    static func image(box: CGColor?) -> CGImage {
        let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 0.85, green: 0.85, blue: 0.85, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: size, height: size))
        if let box {
            ctx.setFillColor(box)
            ctx.fill(CGRect(x: 120, y: 80, width: 160, height: 240))
        }
        return ctx.makeImage()!
    }

    static let blue = CGColor(red: 0.1, green: 0.3, blue: 0.8, alpha: 1)
    static let red = CGColor(red: 0.85, green: 0.1, blue: 0.1, alpha: 1)

    /// RGB (0...255) of one pixel, y from the top.
    static func pixel(_ image: CGImage, x: Int, y: Int) -> (r: Int, g: Int, b: Int) {
        let ctx = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let bytes = ctx.data!.assumingMemoryBound(to: UInt8.self)
        let i = (y * image.width + x) * 4
        return (Int(bytes[i]), Int(bytes[i + 1]), Int(bytes[i + 2]))
    }
}

struct SubjectMaskTests {
    @Test("given a plain counter with no object, should return nil (no subject)")
    func noSubject() {
        #expect(SubjectMask.lift(SyntheticPhoto.image(box: nil)) == nil)
    }

    @Test("given a box on a counter, should keep the box and turn the counter white")
    func lifted() throws {
        let lifted = try #require(SubjectMask.lift(SyntheticPhoto.image(box: SyntheticPhoto.blue)))
        let corner = SyntheticPhoto.pixel(lifted, x: 5, y: 5)
        let center = SyntheticPhoto.pixel(lifted, x: 200, y: 200)
        #expect(corner.r > 245 && corner.g > 245 && corner.b > 245)
        #expect(center.b > 150 && center.r < 80)
        #expect(lifted.width == SyntheticPhoto.size && lifted.height == SyntheticPhoto.size)
    }
}

struct FeaturePrinterTests {
    @Test("given the same photo twice, should give vectors with similarity ≥ 0.99")
    func samePhoto() throws {
        let photo = SyntheticPhoto.image(box: SyntheticPhoto.blue)
        let a = try #require(FeaturePrinter.vector(photo))
        let b = try #require(FeaturePrinter.vector(photo))
        #expect(try #require(FeatureVector.similarity(a, b)) >= 0.99)
    }

    @Test("given a blue box and a red box, should be less alike than the same photo twice")
    func differentPhotos() throws {
        let blue = try #require(FeaturePrinter.vector(SyntheticPhoto.image(box: SyntheticPhoto.blue)))
        let red = try #require(FeaturePrinter.vector(SyntheticPhoto.image(box: SyntheticPhoto.red)))
        #expect(try #require(FeatureVector.similarity(blue, red)) < 0.99)
    }

    @Test("given the pinned revision, should report it and give its 768 floats")
    func revision() throws {
        let v = try #require(FeaturePrinter.vector(SyntheticPhoto.image(box: SyntheticPhoto.blue)))
        #expect(FeaturePrinter.revision == 2)
        #expect(v.count == 768)
    }
}

struct PhotoTextTests {
    static func label(_ text: String) -> CGImage {
        let ctx = CGContext(data: nil, width: 800, height: 300, bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: 800, height: 300))
        let font = CTFontCreateWithName("Helvetica-Bold" as CFString, 72, nil)
        let string = NSAttributedString(string: text, attributes: [.init(kCTFontAttributeName as String): font])
        ctx.textPosition = CGPoint(x: 40, y: 120)
        CTLineDraw(CTLineCreateWithAttributedString(string), ctx)
        return ctx.makeImage()!
    }

    @Test("given a label printed PARACETAMOL, should read it")
    func reads() {
        #expect(PhotoText.lines(Self.label("PARACETAMOL")).contains { $0.uppercased().contains("PARACETAMOL") })
    }

    @Test("given a blank image, should read nothing")
    func blank() {
        #expect(PhotoText.lines(SyntheticPhoto.image(box: nil)).isEmpty)
    }
}
