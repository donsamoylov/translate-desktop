import AppKit
// Иконка Translate Desktop: темная плашка, как у Maps Desktop, и две карточки в духе Google Переводчика —
// синяя с «A» и белая с «文». Нарисована с нуля, логотип Google («G») не используется.
// swift make_icon.swift <папка .iconset>
let out = CommandLine.arguments[1]

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}
let space = CGColorSpace(name: CGColorSpace.sRGB)!

/// Знак по центру точки: высота — по контуру самого знака, а не строки. «文» берется из системного
/// шрифта с иероглифами (CoreText подставляет его сам).
func glyph(_ text: String, at c: CGPoint, height: CGFloat, weight: NSFont.Weight, color: NSColor, in ctx: CGContext) {
    let base = NSFont.systemFont(ofSize: height, weight: weight)
    let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: height) } ?? base
    let probe = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font]))
    let size = height * height / CTLineGetBoundsWithOptions(probe, .useGlyphPathBounds).height
    let sized = NSFont(descriptor: font.fontDescriptor, size: size) ?? font
    let line = CTLineCreateWithAttributedString(NSAttributedString(
        string: text, attributes: [.font: sized, .foregroundColor: color]))
    let b = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    ctx.textMatrix = .identity
    ctx.textPosition = CGPoint(x: c.x - b.midX, y: c.y - b.midY)
    CTLineDraw(line, ctx)
}

/// Заливка фигуры вертикальным градиентом с мягкой тенью под ней.
func fill(_ path: CGPath, _ top: UInt32, _ bottom: UInt32, shadow: CGFloat, in ctx: CGContext) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -shadow * 0.4), blur: shadow, color: rgb(0x000000, 0.4))
    ctx.addPath(path); ctx.setFillColor(rgb(bottom)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    let box = path.boundingBoxOfPath
    let shade = CGGradient(colorsSpace: space, colors: [rgb(top), rgb(bottom)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(shade, start: CGPoint(x: 0, y: box.maxY), end: CGPoint(x: 0, y: box.minY), options: [])
    ctx.restoreGState()
}

for (size, name) in [(16,"16x16"),(32,"16x16@2x"),(32,"32x32"),(64,"32x32@2x"),(128,"128x128"),(256,"128x128@2x"),(256,"256x256"),(512,"256x256@2x"),(512,"512x512"),(1024,"512x512@2x")] {
    let s = CGFloat(size)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext

    // Плашка по сетке значков macOS: тело 824/1024, скругление ≈ 22,5 %.
    let inset = s * 100 / 1024
    let body = CGRect(x: inset, y: inset, width: s - 2 * inset, height: s - 2 * inset)
    let plate = CGPath(roundedRect: body, cornerWidth: body.width * 0.225, cornerHeight: body.width * 0.225, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.01), blur: s * 0.02, color: rgb(0x000000, 0.35))
    ctx.addPath(plate); ctx.setFillColor(rgb(0x1E1F22)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(plate); ctx.clip()
    let shade = CGGradient(colorsSpace: space, colors: [rgb(0x34363C), rgb(0x1C1D21)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(shade, start: CGPoint(x: 0, y: body.maxY), end: CGPoint(x: 0, y: body.minY), options: [])
    ctx.restoreGState()

    // Карточки в долях тела плашки: белая — справа ниже, синяя — слева выше, поверх нее; вместе — по центру.
    let w = body.width
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: body.minX + x * w, y: body.minY + y * w) }
    func card(_ x: CGFloat, _ y: CGFloat) -> CGPath {
        CGPath(roundedRect: CGRect(origin: p(x, y), size: CGSize(width: w * 0.44, height: w * 0.48)),
               cornerWidth: w * 0.06, cornerHeight: w * 0.06, transform: nil)
    }
    let white = card(0.42, 0.17)
    let blue = card(0.14, 0.35)
    // Синий «загиб» под синей карточкой, как у Переводчика, — ложится на белую.
    let fold = CGMutablePath()
    fold.move(to: p(0.42, 0.36))
    fold.addLine(to: p(0.58, 0.36))
    fold.addLine(to: p(0.58, 0.22))
    fold.closeSubpath()

    fill(white, 0xF8F9FA, 0xDADCE0, shadow: s * 0.02, in: ctx)
    fill(fold, 0x2F5FCC, 0x2A56C6, shadow: 0, in: ctx)
    fill(blue, 0x5A95FF, 0x3B78F0, shadow: s * 0.025, in: ctx)
    glyph("文", at: p(0.71, 0.36), height: w * 0.2, weight: .semibold, color: NSColor(srgbRed: 0x5F / 255, green: 0x63 / 255, blue: 0x68 / 255, alpha: 1), in: ctx)
    glyph("A", at: p(0.36, 0.59), height: w * 0.23, weight: .heavy, color: .white, in: ctx)

    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/icon_\(name).png"))
}
