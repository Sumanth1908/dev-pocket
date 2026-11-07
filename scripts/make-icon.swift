// Renders the DevPocket app icon (a pocket holding a code glyph) as vector
// drawing at every size and packs it into an .icns.
//
//   swift scripts/make-icon.swift [--style NAME] <out.icns> [preview.png]
//   swift scripts/make-icon.swift --list
//
// Drawn with plain paths rather than SF Symbols, whose license doesn't
// allow them in app icons.
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

enum Glyph { case braces, prompt }

struct Style {
    /// Tile gradient, top to bottom.
    var tile: [UInt32]
    var pocketFill: (UInt32, CGFloat)
    var pocketStroke: UInt32
    var stitch: (UInt32, CGFloat)
    var glyph: Glyph
    /// One color, or two for a top-to-bottom gradient.
    var glyphColors: [UInt32]
}

let styles: [(name: String, style: Style)] = [
    ("classic", Style(tile: [0x5A9BFF, 0x3A63E8, 0x2A3FC4], pocketFill: (0xFFFFFF, 0.16), pocketStroke: 0xFFFFFF,
                      stitch: (0xFFFFFF, 0.7), glyph: .braces, glyphColors: [0xFFFFFF])),
    ("midnight", Style(tile: [0x343B52, 0x1A1F2E, 0x0E1119], pocketFill: (0xFFFFFF, 0.06), pocketStroke: 0xE6E9F2,
                       stitch: (0xFFFFFF, 0.45), glyph: .braces, glyphColors: [0x5EEAD4, 0x3B82F6])),
    ("sunset", Style(tile: [0xFFB45C, 0xFF6B6B, 0xD63D8F], pocketFill: (0xFFFFFF, 0.18), pocketStroke: 0xFFFFFF,
                     stitch: (0xFFFFFF, 0.7), glyph: .braces, glyphColors: [0xFFFFFF])),
    ("paper", Style(tile: [0xFFFFFF, 0xF2F4F8, 0xDDE2EC], pocketFill: (0x3A63E8, 1), pocketStroke: 0x2F54D6,
                    stitch: (0xFFFFFF, 0.75), glyph: .braces, glyphColors: [0xFFFFFF])),
    ("terminal", Style(tile: [0x2A3342, 0x161C26, 0x0B0F15], pocketFill: (0x34D399, 0.06), pocketStroke: 0x34D399,
                       stitch: (0x34D399, 0.55), glyph: .prompt, glyphColors: [0x34D399])),
]

var args = Array(CommandLine.arguments.dropFirst())
if args == ["--list"] {
    print(styles.map(\.name).joined(separator: "\n"))
    exit(0)
}
var styleName = "classic"
if let i = args.firstIndex(of: "--style"), i + 1 < args.count {
    styleName = args[i + 1]
    args.removeSubrange(i...(i + 1))
}
guard let style = styles.first(where: { $0.name == styleName })?.style, !args.isEmpty else {
    FileHandle.standardError.write(Data("usage: make-icon.swift [--style \(styles.map(\.name).joined(separator: "|"))] <out.icns> [preview.png]\n".utf8))
    exit(1)
}
let outputURL = URL(fileURLWithPath: args[0])
let previewURL = args.count >= 2 ? URL(fileURLWithPath: args[1]) : nil

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

func verticalGradient(_ hexes: [UInt32]) -> CGGradient {
    let locations = hexes.indices.map { CGFloat($0) / CGFloat(max(hexes.count - 1, 1)) }
    return CGGradient(colorsSpace: sRGB, colors: hexes.map { color($0) } as CFArray, locations: locations)!
}

/// Draws the icon on a 1024×1024 canvas (origin bottom-left).
func drawIcon(_ style: Style, in ctx: CGContext) {
    // Shadow offset/blur ignore the CTM, so scale them to the output size.
    let k = ctx.ctm.a
    // Background tile, per Apple's macOS icon grid: 824pt square, ~185pt corners.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let tilePath = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12 * k), blur: 28 * k, color: color(0x000000, 0.35))
    ctx.addPath(tilePath)
    ctx.setFillColor(color(style.tile[style.tile.count / 2]))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(tilePath)
    ctx.clip()
    ctx.drawLinearGradient(verticalGradient(style.tile), start: CGPoint(x: 512, y: tile.maxY),
                           end: CGPoint(x: 512, y: tile.minY), options: [])
    ctx.restoreGState()

    // Pocket: straight top and sides, bottom tapering to a soft point.
    let left: CGFloat = 282, right: CGFloat = 742, top: CGFloat = 742
    let shoulder: CGFloat = 430, tip: CGFloat = 268, mid: CGFloat = 512
    let pocket = CGMutablePath()
    pocket.move(to: CGPoint(x: left, y: top))
    pocket.addLine(to: CGPoint(x: right, y: top))
    pocket.addLine(to: CGPoint(x: right, y: shoulder))
    pocket.addCurve(to: CGPoint(x: mid, y: tip),
                    control1: CGPoint(x: right, y: shoulder - 70),
                    control2: CGPoint(x: mid + 120, y: tip + 24))
    pocket.addCurve(to: CGPoint(x: left, y: shoulder),
                    control1: CGPoint(x: mid - 120, y: tip + 24),
                    control2: CGPoint(x: left, y: shoulder - 70))
    pocket.closeSubpath()

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6 * k), blur: 16 * k, color: color(0x0A1A66, 0.3))
    ctx.addPath(pocket)
    ctx.setFillColor(color(style.pocketFill.0, style.pocketFill.1))
    ctx.fillPath()
    ctx.restoreGState()

    ctx.addPath(pocket)
    ctx.setStrokeColor(color(style.pocketStroke))
    ctx.setLineWidth(26)
    ctx.setLineJoin(.round)
    ctx.strokePath()

    // Stitching along the pocket's opening.
    ctx.setStrokeColor(color(style.stitch.0, style.stitch.1))
    ctx.setLineWidth(9)
    ctx.setLineCap(.round)
    ctx.setLineDash(phase: 0, lengths: [20, 18])
    ctx.move(to: CGPoint(x: left + 40, y: top - 42))
    ctx.addLine(to: CGPoint(x: right - 40, y: top - 42))
    ctx.strokePath()
    ctx.setLineDash(phase: 0, lengths: [])

    // Glyph inside the pocket, stroked then filled with its color(s).
    let glyph = CGMutablePath()
    switch style.glyph {
    case .braces:
        glyph.addPath(brace(x: 386, mirrored: false))
        glyph.addPath(brace(x: 560, mirrored: true))
    case .prompt:
        glyph.move(to: CGPoint(x: 398, y: 612))
        glyph.addLine(to: CGPoint(x: 494, y: 520))
        glyph.addLine(to: CGPoint(x: 398, y: 428))
        glyph.move(to: CGPoint(x: 540, y: 410))
        glyph.addLine(to: CGPoint(x: 630, y: 410))
    }
    ctx.saveGState()
    ctx.addPath(glyph)
    ctx.setLineWidth(32)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    ctx.drawLinearGradient(verticalGradient(style.glyphColors.count == 1 ? style.glyphColors + style.glyphColors : style.glyphColors),
                           start: CGPoint(x: 512, y: 640), end: CGPoint(x: 512, y: 380), options: [])
    ctx.restoreGState()
}

/// `{` whose leftmost point is at `x`; `mirrored` gives `}`.
func brace(x: CGFloat, mirrored: Bool) -> CGPath {
    let width: CGFloat = 78, top: CGFloat = 628, bottom: CGFloat = 388
    let mid = (top + bottom) / 2, height = top - bottom
    let stem = width * 0.38
    func p(_ dx: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: mirrored ? x + width - dx : x + dx, y: y)
    }
    let path = CGMutablePath()
    path.move(to: p(width, top))
    path.addQuadCurve(to: p(stem, top - height * 0.14), control: p(stem, top))
    path.addLine(to: p(stem, mid + height * 0.1))
    path.addQuadCurve(to: p(0, mid), control: p(stem, mid))
    path.addQuadCurve(to: p(stem, mid - height * 0.1), control: p(stem, mid))
    path.addLine(to: p(stem, bottom + height * 0.14))
    path.addQuadCurve(to: p(width, bottom), control: p(stem, bottom))
    return path
}

func render(_ style: Style, pixels: Int) -> CGImage {
    let ctx = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    ctx.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
    drawIcon(style, in: ctx)
    return ctx.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) {
    let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { fatalError("couldn't write \(url.path)") }
}

let iconset = FileManager.default.temporaryDirectory
    .appendingPathComponent("DevPocket-\(UUID().uuidString).iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    writePNG(render(style, pixels: points), to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    writePNG(render(style, pixels: points * 2), to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
if let previewURL { writePNG(render(style, pixels: 1024), to: previewURL) }

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", outputURL.path]
try iconutil.run()
iconutil.waitUntilExit()
try? FileManager.default.removeItem(at: iconset)
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
print("Wrote \(outputURL.path) (style: \(styleName))")
