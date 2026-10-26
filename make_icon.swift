import AppKit
// Иконка Translate Desktop: темная плашка, как у Maps Desktop, и значок в духе Google Переводчика —
// синяя «страница» с косым краем и загибом поверх серой карточки с «文». Цвета Google, но на синей
// странице «A», а не логотип «G». Нарисована с нуля.
// swift make_icon.swift <папка .iconset>
let out = CommandLine.arguments[1]

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat(hex >> 16 & 0xff) / 255, green: CGFloat(hex >> 8 & 0xff) / 255,
            blue: CGFloat(hex & 0xff) / 255, alpha: a)
}
let space = CGColorSpace(name: CGColorSpace.sRGB)!

/// Знак по центру точки: высота — по контуру самого знака, а не строки.
func glyph(_ text: String, font name: String, fallback weight: NSFont.Weight, at c: CGPoint, height: CGFloat,
           color: UInt32, in ctx: CGContext) {
    let font = NSFont(name: name, size: height) ?? NSFont.systemFont(ofSize: height, weight: weight)
    let probe = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [.font: font]))
    let size = height * height / CTLineGetBoundsWithOptions(probe, .useGlyphPathBounds).height
    let sized = NSFont(descriptor: font.fontDescriptor, size: size) ?? font
    let line = CTLineCreateWithAttributedString(NSAttributedString(
        string: text, attributes: [.font: sized, .foregroundColor: NSColor(cgColor: rgb(color))!]))
    let b = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
    ctx.textMatrix = .identity
    ctx.textPosition = CGPoint(x: c.x - b.midX, y: c.y - b.midY)
    CTLineDraw(line, ctx)
}

/// Многоугольник со скругленными углами: у каждой вершины свой радиус (0 — острый угол).
func polygon(_ points: [(CGPoint, CGFloat)]) -> CGPath {
    let path = CGMutablePath()
    let n = points.count
    let start = CGPoint(x: (points[n - 1].0.x + points[0].0.x) / 2, y: (points[n - 1].0.y + points[0].0.y) / 2)
    path.move(to: start)
    for i in 0..<n {
        let (corner, radius) = points[i]
        let next = points[(i + 1) % n].0
        if radius > 0 { path.addArc(tangent1End: corner, tangent2End: next, radius: radius) } else { path.addLine(to: corner) }
    }
    path.closeSubpath()
    return path
}

func fill(_ path: CGPath, _ top: UInt32, _ bottom: UInt32, shadow: CGFloat = 0, in ctx: CGContext) {
    ctx.saveGState()
    if shadow > 0 { ctx.setShadow(offset: CGSize(width: shadow * 0.3, height: -shadow * 0.3), blur: shadow, color: rgb(0x000000, 0.3)) }
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

    // Значок в своих единицах, как у оригинала: 215 × 243, отсчет сверху; на плашке — 64 % высоты, по центру.
    let w = body.width, k = w * 0.64 / 243
    func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: body.midX + (x - 107.5) * k, y: body.midY - (y - 121.5) * k)
    }
    let r = 12 * k
    // Левый край карточки — под синей страницей и загибом; острие загиба — в ее нижнем левом углу.
    let card = polygon([(p(108, 43), r), (p(215, 43), r), (p(215, 243), r), (p(108, 243), 0)])
    let page = polygon([(p(0, 0), r), (p(102, 0), r * 0.5), (p(155, 198), 0), (p(0, 198), r)])
    let fold = polygon([(p(108, 198), 0), (p(155, 198), 0), (p(108, 243), 0)])

    fill(card, 0xE6E6E6, 0xD6D6D6, shadow: s * 0.02, in: ctx)
    glyph("文", font: "PingFangSC-Medium", fallback: .medium, at: p(178, 141), height: 66 * k, color: 0x757575, in: ctx)
    fill(fold, 0x3F51B5, 0x3F51B5, in: ctx)
    fill(page, 0x4C8DF6, 0x4285F4, shadow: s * 0.015, in: ctx)
    glyph("A", font: "AvenirNext-DemiBold", fallback: .semibold, at: p(62, 99), height: 72 * k, color: 0xFFFFFF, in: ctx)

    NSGraphicsContext.restoreGraphicsState()
    try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(out)/icon_\(name).png"))
}
