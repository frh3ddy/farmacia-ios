// Renders the Farmacia brand art: app icons (prod + DEV) and logo lockups.
// usage: swift icon.swift <outdir>
import AppKit

let out = CommandLine.arguments[1]
let pink = NSColor(srgbRed: 0xFC/255, green: 0xAC/255, blue: 0xAC/255, alpha: 1)
let charcoalDark = NSColor(srgbRed: 0x3F/255, green: 0x42/255, blue: 0x4A/255, alpha: 1)
let charcoalLight = NSColor(srgbRed: 0x6E/255, green: 0x71/255, blue: 0x77/255, alpha: 1)
let amber = NSColor(srgbRed: 0xF2/255, green: 0xB3/255, blue: 0x3D/255, alpha: 1)

func render(_ w: Int, _ h: Int, _ name: String, _ draw: (CGContext) -> Void) {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: w, pixelsHigh: h, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    draw(NSGraphicsContext.current!.cgContext)
    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/\(name)"))
}

func background(_ ctx: CGContext, _ w: CGFloat, _ h: CGFloat) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
                       colors: [charcoalDark.cgColor, charcoalLight.cgColor] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(g, start: .zero, end: CGPoint(x: w, y: h), options: [])
}

/// The monogram: a brush-like ring (a few offset strokes) around a script F.
func monogram(_ ctx: CGContext, center c: CGPoint, radius r: CGFloat) {
    for (dx, dy, width, alpha) in [(0.0, 0.0, 0.075, 1.0), (0.012, -0.008, 0.03, 0.55), (-0.01, 0.01, 0.025, 0.4)] {
        ctx.setStrokeColor(pink.withAlphaComponent(alpha).cgColor)
        ctx.setLineWidth(r * width)
        let rr = r * (1 + dx)
        ctx.strokeEllipse(in: CGRect(x: c.x - rr + r * dy, y: c.y - rr - r * dx, width: rr * 2, height: rr * 2))
    }
    let font = NSFont(name: "SnellRoundhand-Black", size: r * 1.2)!
    let f = NSAttributedString(string: "F", attributes: [.font: font, .foregroundColor: pink])
    // Center the ink (not the text box): the script F's swash makes its box lopsided.
    let line = CTLineCreateWithAttributedString(f)
    let ink = CTLineGetImageBounds(line, ctx)
    ctx.textPosition = CGPoint(x: c.x - ink.midX, y: c.y - ink.midY)
    CTLineDraw(line, ctx)
}

func text(_ s: String, size: CGFloat, weight: String, kern: CGFloat, color: NSColor, centerX: CGFloat, y: CGFloat) {
    let a = NSAttributedString(string: s, attributes: [
        .font: NSFont(name: weight, size: size)!, .foregroundColor: color, .kern: kern])
    a.draw(at: CGPoint(x: centerX - a.size().width / 2 + kern / 2, y: y))
}

// App icons — square, opaque; iOS applies the corner mask.
render(1024, 1024, "AppIcon.png") { ctx in
    background(ctx, 1024, 1024)
    monogram(ctx, center: CGPoint(x: 512, y: 512), radius: 330)
}
render(1024, 1024, "AppIcon-Dev.png") { ctx in
    background(ctx, 1024, 1024)
    monogram(ctx, center: CGPoint(x: 512, y: 590), radius: 290)
    ctx.setFillColor(amber.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: 1024, height: 210))
    text("DEV", size: 150, weight: "AvenirNext-Heavy", kern: 24, color: charcoalDark, centerX: 512, y: 22)
}

// Logo lockups (for the brand doc / print): master, and location-endorsed.
render(1600, 1000, "logo-farmacia.png") { ctx in
    background(ctx, 1600, 1000)
    monogram(ctx, center: CGPoint(x: 800, y: 600), radius: 190)
    text("FARMACIA", size: 92, weight: "AvenirNext-Medium", kern: 30, color: pink, centerX: 800, y: 210)
}
render(1600, 1000, "logo-farmacia-oriente.png") { ctx in
    background(ctx, 1600, 1000)
    monogram(ctx, center: CGPoint(x: 800, y: 620), radius: 180)
    text("FARMACIA", size: 92, weight: "AvenirNext-Medium", kern: 30, color: pink, centerX: 800, y: 250)
    text("SUCURSAL ORIENTE", size: 40, weight: "AvenirNext-Regular", kern: 14, color: pink.withAlphaComponent(0.8), centerX: 800, y: 180)
}
print("ok")
