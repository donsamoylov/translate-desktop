import AppKit
// Иконка Translate Desktop: темная плашка, как у Maps Desktop, и два облачка реплик с буквами A и Я
// в цветах Maps Desktop. Нарисована с нуля, логотип Google не используется.
// swift make_icon.swift <папка .iconset>
let out = CommandLine.arguments[1]

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}
let space = CGColorSpace(name: CGColorSpace.sRGB)!

/// Облачко: скругленный прямоугольник и хвостик внизу — у левого или у правого края.
func bubble(_ r: CGRect, tailLeft: Bool) -> CGPath {
    let radius = r.height * 0.3
    let body = CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
    let d: CGFloat = tailLeft ? 1 : -1
    let start = tailLeft ? r.minX + radius * 0.5 : r.maxX - radius * 0.5
    let tip = CGPoint(x: start - d * r.width * 0.02, y: r.minY - r.height * 0.3)
    let tail = CGMutablePath()
    tail.move(to: CGPoint(x: start, y: r.minY + radius))
    tail.addLine(to: CGPoint(x: start, y: r.minY))
    tail.addQuadCurve(to: tip, control: CGPoint(x: start, y: tip.y + r.height * 0.12))
    tail.addQuadCurve(to: CGPoint(x: start + d * r.width * 0.3, y: r.minY),
                      control: CGPoint(x: start + d * r.width * 0.1, y: r.minY - r.height * 0.06))
    tail.addLine(to: CGPoint(x: start + d * r.width * 0.3, y: r.minY + radius))
    tail.closeSubpath()
    return body.union(tail)
}

/// Буква белым по центру точки: высота — по контуру самой буквы, а не строки.
func letter(_ text: String, at c: CGPoint, height: CGFloat, in ctx: CGContext) {
    let base = NSFont.systemFont(ofSize: height, weight: .heavy)
    let font = base.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: height) } ?? base
    let probe = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font]))
    let size = height * height / CTLineGetBoundsWithOptions(probe, .useGlyphPathBounds).height
    let sized = NSFont(descriptor: font.fontDescriptor, size: size) ?? font
    let line = CTLineCreateWithAttributedString(NSAttributedString(
        string: text, attributes: [.font: sized, .foregroundColor: NSColor.white]))
    let b = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    ctx.textMatrix = .identity
    ctx.textPosition = CGPoint(x: c.x - b.midX, y: c.y - b.midY)
    CTLineDraw(line, ctx)
}

func fill(_ path: CGPath, _ top: UInt32, _ bottom: UInt32, in ctx: CGContext, shadow s: CGFloat) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -s * 0.008), blur: s * 0.025, color: rgb(0x000000, 0.45))
    ctx.addPath(path); ctx.setFillColor(rgb(top)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(path); ctx.clip()
    let box = path.boundingBoxOfPath
    let shade = CGGradient(colorsSpace: space, colors: [rgb(top), rgb(bottom)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(shade, start: CGPoint(x: box.minX, y: box.maxY), end: CGPoint(x: box.maxX, y: box.minY), options: [])
    // Легкий объем: светлее сверху.
    let gloss = CGGradient(colorsSpace: space, colors: [rgb(0xFFFFFF, 0.18), rgb(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(gloss, start: CGPoint(x: 0, y: box.maxY), end: CGPoint(x: 0, y: box.midY), options: [])
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

    // Облачка в долях тела плашки: заднее (Я) справа вверху, переднее (A) слева внизу; вместе — по центру.
    let w = body.width
    func rect(_ x: CGFloat, _ y: CGFloat) -> CGRect {
        CGRect(x: body.minX + x * w, y: body.minY + y * w, width: w * 0.5, height: w * 0.38)
    }
    let front = bubble(rect(0.13, 0.26), tailLeft: true)
    let back = bubble(rect(0.37, 0.49), tailLeft: false)
    // Между облачками — зазор цвета плашки.
    let gap = front.copy(strokingWithWidth: w * 0.07, lineCap: .round, lineJoin: .round, miterLimit: 10)
    fill(back.subtracting(front.union(gap)), 0xF59A2E, 0xE0457B, in: ctx, shadow: s)
    fill(front, 0x4F8BFF, 0x8A7BFF, in: ctx, shadow: s)
    letter("Я", at: CGPoint(x: body.minX + w * 0.7, y: body.minY + w * 0.72), height: w * 0.18, in: ctx)
    letter("A", at: CGPoint(x: body.minX + w * 0.38, y: body.minY + w * 0.45), height: w * 0.21, in: ctx)

    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/icon_\(name).png"))
}
