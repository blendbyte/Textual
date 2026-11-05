// Draws the download disk image's background, 1000 × 960 pixels for its
// 500 × 480 point window. Positions match the icons in MakeDMG.sh, at twice the
// size. Finder draws the icons' labels dark in Light and Dark Mode alike, so the
// picture stays light.
//
//   swift Packaging/DMGBackground.swift Packaging/DMGBackground.png

import AppKit

let width: CGFloat = 1000
let height: CGFloat = 960

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> NSColor {
	NSColor(srgbRed: CGFloat((hex >> 16) & 255) / 255,
			green: CGFloat((hex >> 8) & 255) / 255,
			blue: CGFloat(hex & 255) / 255,
			alpha: alpha)
}

func gradient(_ colors: [NSColor]) -> CGGradient {
	CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
			   colors: colors.map(\.cgColor) as CFArray,
			   locations: nil)!
}

func drawCenteredText(_ context: CGContext, _ text: String, _ color: NSColor, fontName: String, size: CGFloat, baseline: CGFloat) {
	let font = NSFont(name: fontName, size: size)!

	let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: [
		.font: font,
		.foregroundColor: color,
		.kern: size * -0.012
	]))

	let textWidth = CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))

	context.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
	context.textPosition = CGPoint(x: (width - textWidth) / 2, y: baseline)

	CTLineDraw(line, context)
}

guard CommandLine.arguments.count == 2 else {
	fatalError("Usage: DMGBackground.swift <output.png>")
}

let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil,
							  pixelsWide: Int(width),
							  pixelsHigh: Int(height),
							  bitsPerSample: 8,
							  samplesPerPixel: 4,
							  hasAlpha: true,
							  isPlanar: false,
							  colorSpaceName: .deviceRGB,
							  bytesPerRow: 0,
							  bitsPerPixel: 0)!

bitmap.size = NSSize(width: width, height: height)

let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap)!

NSGraphicsContext.current = graphicsContext

let context = graphicsContext.cgContext

// Top left origin, as Finder positions icons
context.translateBy(x: 0, y: height)
context.scaleBy(x: 1, y: -1)

// A light surface with a breath of the icon's purple behind the name
context.drawLinearGradient(gradient([color(0xFBFAFE), color(0xF1EDF9)]),
						   start: .zero,
						   end: CGPoint(x: 0, y: height),
						   options: [])

let glowCenter = CGPoint(x: 500, y: 150)

context.drawRadialGradient(gradient([color(0x8F63E0, 0.16), color(0x8F63E0, 0)]),
						   startCenter: glowCenter,
						   startRadius: 0,
						   endCenter: glowCenter,
						   endRadius: 560,
						   options: [])

drawCenteredText(context, "Textual", color(0x33244F), fontName: "HelveticaNeue-Light", size: 118, baseline: 250)
drawCenteredText(context, "Drag Textual to Applications to install", color(0x5A4A78), fontName: "HelveticaNeue", size: 26, baseline: 322)

// The arrow between the app and the Applications link
let arrowY: CGFloat = 476

context.setStrokeColor(color(0x7E57C9).cgColor)
context.setLineWidth(7)
context.setLineCap(.round)
context.setLineJoin(.round)
context.move(to: CGPoint(x: 438, y: arrowY))
context.addLine(to: CGPoint(x: 562, y: arrowY))
context.move(to: CGPoint(x: 526, y: arrowY - 34))
context.addLine(to: CGPoint(x: 564, y: arrowY))
context.addLine(to: CGPoint(x: 526, y: arrowY + 34))
context.strokePath()

// Sets the Read Me and links apart from the install
context.setStrokeColor(color(0x33244F, 0.10).cgColor)
context.setLineWidth(2)
context.move(to: CGPoint(x: 90, y: 652))
context.addLine(to: CGPoint(x: 910, y: 652))
context.strokePath()

NSGraphicsContext.current = nil

try! bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
