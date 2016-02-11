//
//  MacawView.swift
//  Macaw
//
//  Created by Yuri Strot on 12/19/15.
//  Copyright © 2015 Exyte. All rights reserved.
//

import Foundation
import UIKit

public class MacawView: UIView {

    let node: Node

    public required init?(node: Node, coder aDecoder: NSCoder) {
        self.node = node
        super.init(coder: aDecoder)
    }

    public required convenience init?(coder aDecoder: NSCoder) {
        self.init(node: Group(pos: Transform()), coder: aDecoder)
    }

    override public func drawRect(rect: CGRect) {
        let ctx = UIGraphicsGetCurrentContext()
        drawNode(node, ctx: ctx)
    }

    private func drawNode(node: Node, ctx: CGContext?) {
        if node.visible == true {
            CGContextSaveGState(ctx)
//            if (node.pos != nil) {
                CGContextConcatCTM(ctx, mapTransform(node.pos))
//            }
            if let shape = node as? Shape {
                setGeometry(shape.form, ctx: ctx)
                setFill(shape.fill, ctx: ctx)
                setStroke(shape.stroke, ctx: ctx)
            } else if let group = node as? Group {
                for content in group.contents {
                    drawNode(content, ctx: ctx)
                }
            } else if let text = node as? Text {
                drawText(text, ctx: ctx)
            } else if let image = node as? Image {
                drawImage(image, ctx: ctx)
            } else {
                print("Unsupported node: \(node)")
            }
            CGContextRestoreGState(ctx)
        }
    }
    
    private func drawText(text: Text, ctx: CGContext?) {
        let message = text.text
        var font: UIFont
        if let customFont = UIFont(name: text.font.name, size: 24) {
            font = customFont
        } else {
            font = UIFont.systemFontOfSize(CGFloat(text.font.size))
        }
        // positive NSBaselineOffsetAttributeName values don't work, couldn't find why
        // for now move the rect itself
        let textAttributes = [
            NSFontAttributeName: font,
            NSForegroundColorAttributeName: getTextColor(text.fill)]
        let textSize = NSString(string: text.text).sizeWithAttributes(textAttributes)
        message.drawInRect(CGRectMake(calculateAlignmentOffset(text, font: font), calculateBaselineOffset(text, font: font),
            CGFloat(textSize.width), CGFloat(textSize.height)), withAttributes:textAttributes)
    }

    private func calculateBaselineOffset(text: Text, font: UIFont) -> CGFloat {
        var baselineOffset = CGFloat(0)
        switch text.baseline {
        case Baseline.alphabetic:
            baselineOffset = font.ascender
        case Baseline.bottom:
            baselineOffset = font.ascender - font.descender
        case Baseline.mid:
            baselineOffset = (font.ascender - font.descender) / 2
        default:
            break
        }
        return -baselineOffset
    }
    
    private func calculateAlignmentOffset(text: Text, font: UIFont) -> CGFloat {
        let textAttributes = [
            NSFontAttributeName: font
        ]
        let textSize = NSString(string: text.text).sizeWithAttributes(textAttributes)
        var alignmentOffset = CGFloat(0)
        switch text.align {
        case Align.mid:
            alignmentOffset = textSize.width/2
        case Align.max:
            alignmentOffset = textSize.width
        default:
            break
        }
        return -alignmentOffset
    }

    private func getTextColor(fill: Fill) -> UIColor {
        if let color = fill as? Color {
            return UIColor(CGColor: mapColor(color))
        }
        return UIColor.blackColor()
    }
    
    private func drawImage(image: Image, ctx: CGContext?) {
        if let uiimage = UIImage(named: image.src) {
            let imageSize = uiimage.size
            var w = CGFloat(image.w)
            var h = CGFloat(image.h)
            var rect: CGRect
            if ((w == 0 || w == imageSize.width) && (h == 0 || h == imageSize.height)) {
                rect = CGRectMake(0, 0, imageSize.width, imageSize.height)
            } else {
                if (w == 0) {
                    w = imageSize.width * h / imageSize.height
                } else if (h == 0) {
                    h = imageSize.height * w / imageSize.width
                }
                switch (image.aspectRatio) {
                case AspectRatio.meet:
                    rect = calculateMeetAspectRatio(image, size: imageSize)
                case AspectRatio.slice:
                    rect = calculateSliceAspectRatio(image, size: imageSize)
                    CGContextClipToRect(ctx, CGRectMake(0, 0, w, h))
                default:
                    rect = CGRectMake(0, 0, w, h)
                }
            }
            uiimage.drawInRect(rect)
        }
    }

    
    private func calculateMeetAspectRatio(image: Image, size: CGSize) -> CGRect {
        let w = CGFloat(image.w)
        let h = CGFloat(image.h)
        // destination and source aspect ratios
        let destAR = w / h
        let srcAR = size.width / size.height
        var resultW = w
        var resultH = h
        var destX = CGFloat(0)
        var destY = CGFloat(0)
        if (destAR < srcAR) {
        // fill all available width and scale height
            resultH = size.height * w / size.width
        } else {
        // fill all available height and scale width
            resultW = size.width * h / size.height
        }
        let xalign = image.xAlign
        switch (xalign) {
            case Align.min:
                destX = 0
            case Align.mid:
                destX = w / 2 - resultW / 2
            case Align.max:
                destX = w - resultW
        }
        let yalign = image.yAlign
        switch (yalign) {
        case Align.min:
            destY = 0
        case Align.mid:
            destY = h / 2 - resultH / 2
        case Align.max:
            destY = h - resultH
        }
        return CGRectMake(destX, destY, resultW, resultH)
    }
    
    private func calculateSliceAspectRatio(image: Image, size: CGSize) -> CGRect {
        let w = CGFloat(image.w)
        let h = CGFloat(image.h)
        var srcX = CGFloat(0)
        var srcY = CGFloat(0)
        var totalH: CGFloat = 0
        var totalW: CGFloat = 0
        // destination and source aspect ratios
        let destAR = w / h
        let srcAR = size.width / size.height
        if (destAR > srcAR) {
            // fill all available width and scale height
            totalH = size.height * w / size.width
            totalW = w
            switch (image.yAlign) {
            case Align.min:
                srcY = 0
            case Align.mid:
                srcY = -(totalH / 2 - h / 2)
            case Align.max:
                srcY = -(totalH - h)
            }
        } else {
            // fill all available height and scale width
            totalW = size.width * h / size.height
            totalH = h
            switch (image.xAlign) {
            case Align.min:
                srcX = 0
            case Align.mid:
                srcX = -(totalW / 2 - w / 2)
            case Align.max:
                srcX = -(totalW - w)
            }
        }
        return CGRectMake(srcX, srcY, totalW, totalH)
    }
    
    private func setGeometry(locus: Locus, ctx: CGContext?) {
        if let rect = locus as? Rect {
            CGContextAddRect(ctx, newCGRect(rect))
        } else if let round = locus as? RoundRect {
            let corners = CGSizeMake(CGFloat(round.rx), CGFloat(round.ry))
            let path = UIBezierPath(roundedRect: newCGRect(round.rect), byRoundingCorners:
                UIRectCorner.AllCorners, cornerRadii: corners).CGPath
            CGContextAddPath(ctx, path)
        } else if let circle = locus as? Circle {
            let cx = circle.cx
            let cy = circle.cy
            let r = circle.r
            CGContextAddEllipseInRect(ctx, CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        } else if let ellipse = locus as? Ellipse {
            let cx = ellipse.cx
            let cy = ellipse.cy
            let rx = ellipse.rx
            let ry = ellipse.ry
            CGContextAddEllipseInRect(ctx, CGRect(x: cx - rx, y: cy - ry, width: rx * 2, height: ry * 2))
        } else if let arc = locus as? Arc {
            CGContextAddPath(ctx, toBezierPath(arc).CGPath)
        } else if let point = locus as? Point {
            let path = UIBezierPath()
            path.moveToPoint(CGPointMake(CGFloat(point.x), CGFloat(point.y)))
            path.addLineToPoint(CGPointMake(CGFloat(point.x), CGFloat(point.y)))
            CGContextAddPath(ctx, path.CGPath)
        } else if let line = locus as? Line {
            let path = UIBezierPath()
            path.moveToPoint(CGPointMake(CGFloat(line.x1), CGFloat(line.y1)))
            path.addLineToPoint(CGPointMake(CGFloat(line.x2), CGFloat(line.y2)))
            CGContextAddPath(ctx, path.CGPath)
        } else if let polygon = locus as? Polygon {
            let path = toBezierPath(polygon.points)
            path.closePath()
            CGContextAddPath(ctx, path.CGPath)
        } else if let polygon = locus as? Polyline {
            CGContextAddPath(ctx, toBezierPath(polygon.points).CGPath)
        } else if let path = locus as? Path {
            CGContextAddPath(ctx, toBezierPath(path).CGPath)
        } else {
            print("Unsupported locus: \(locus)")
        }
    }

    private func toBezierPath(points: [Double]) -> UIBezierPath {
        let parts = 0.stride(to: points.count, by: 2).map { Array(points[$0..<$0 + 2]) }
        let path = UIBezierPath()
        var first = true
        for part in parts {
            let point = CGPointMake(CGFloat(part[0]), CGFloat(part[1]))
            if (first) {
                path.moveToPoint(point)
                first = false
            } else {
                path.addLineToPoint(point)
            }
        }
        return path
    }

    private func toBezierPath(arc: Arc) -> UIBezierPath {
        let extent = CGFloat(arc.extent)
        let end = CGFloat(arc.shift) + extent
        let ellipse = arc.ellipse
        if (ellipse.rx == ellipse.ry) {
            let center = CGPointMake(CGFloat(ellipse.cx), CGFloat(ellipse.cy))
            return UIBezierPath(arcCenter: center, radius: CGFloat(ellipse.rx), startAngle: extent, endAngle: end, clockwise: true)
        }
        print("Only circle arc supported for now")
        return UIBezierPath()
    }

    
    private func toBezierPath(path: Path) -> UIBezierPath {
        let bezierPath = UIBezierPath()
        
        var currentPoint: CGPoint?
        var cubicPoint: CGPoint?
        var quadrPoint: CGPoint?
        var initialPoint: CGPoint?
        
        
        func M(x: Double, y: Double) {
            let point = CGPointMake(CGFloat(x), CGFloat(y))
            bezierPath.moveToPoint(point)
            setInitPoint(point)
        }
        
        func m(x: Double, y: Double) {
            if let cur = currentPoint {
                let next = CGPointMake(CGFloat(x) + cur.x, CGFloat(y) + cur.y)
                bezierPath.moveToPoint(next)
                setInitPoint(next)
            } else {
                M(x, y: y)
            }
        }
        
        func L(x: Double, y: Double) {
            lineTo(CGPointMake(CGFloat(x), CGFloat(y)))
        }
        
        func l(x: Double, y: Double) {
            if let cur = currentPoint {
                lineTo(CGPointMake(CGFloat(x) + cur.x, CGFloat(y) + cur.y))
            } else {
                L(x, y: y)
            }
        }
        
        func H(x: Double) {
            if let cur = currentPoint {
                lineTo(CGPointMake(CGFloat(x), CGFloat(cur.y)))
            }
        }
        
        func h(x: Double) {
            if let cur = currentPoint {
                lineTo(CGPointMake(CGFloat(x) + cur.x, CGFloat(cur.y)))
            }
        }
        
        func V(y: Double) {
            if let cur = currentPoint {
                lineTo(CGPointMake(CGFloat(cur.x), CGFloat(y)))
            }
        }
        
        func v(y: Double) {
            if let cur = currentPoint {
                lineTo(CGPointMake(CGFloat(cur.x), CGFloat(y) + cur.y))
            }
        }
        
        func lineTo(p: CGPoint) {
            bezierPath.addLineToPoint(p)
            setPoint(p)
        }
        
        func c(x1: Double, y1: Double, x2: Double, y2: Double, x: Double, y: Double) {
            if let cur = currentPoint {
                let endPoint = CGPointMake(CGFloat(x) + cur.x, CGFloat(y) + cur.y)
                let controlPoint1 = CGPointMake(CGFloat(x1) + cur.x, CGFloat(y1) + cur.y)
                let controlPoint2 = CGPointMake(CGFloat(x2) + cur.x, CGFloat(y2) + cur.y)
                bezierPath.addCurveToPoint(endPoint, controlPoint1: controlPoint1, controlPoint2: controlPoint2)
                setCubicPoint(endPoint, cubic: controlPoint2)
            }
        }
        
        func C(x1: Double, y1: Double, x2: Double, y2: Double, x: Double, y: Double) {
            let endPoint = CGPointMake(CGFloat(x), CGFloat(y))
            let controlPoint1 = CGPointMake(CGFloat(x1), CGFloat(y1))
            let controlPoint2 = CGPointMake(CGFloat(x2), CGFloat(y2))
            bezierPath.addCurveToPoint(endPoint, controlPoint1: controlPoint1, controlPoint2: controlPoint2)
            setCubicPoint(endPoint, cubic: controlPoint2)
        }
        
        func s(x2: Double, y2: Double, x: Double, y: Double) {
            if let cur = currentPoint {
                let nextCubic = CGPointMake(CGFloat(x2) + cur.x, CGFloat(y2) + cur.y)
                let next = CGPointMake(CGFloat(x) + cur.x, CGFloat(y) + cur.y)
                
                var xy1: CGPoint?
                if let curCubicVal = cubicPoint {
                    xy1 = CGPointMake(CGFloat(2 * cur.x) - curCubicVal.x, CGFloat(2 * cur.y) - curCubicVal.y)
                } else {
                    xy1 = cur
                }
                bezierPath.addCurveToPoint(next, controlPoint1: xy1!, controlPoint2: nextCubic)
                setCubicPoint(next, cubic: nextCubic)
            }
        }

        func S(x2: Double, y2: Double, x: Double, y: Double) {
            if let cur = currentPoint {
                let nextCubic = CGPointMake(CGFloat(x2), CGFloat(y2))
                let next = CGPointMake(CGFloat(x), CGFloat(y))
                var xy1: CGPoint?
                if let curCubicVal = cubicPoint {
                   xy1 = CGPointMake(CGFloat(2 * cur.x) - curCubicVal.x, CGFloat(2 * cur.y) - curCubicVal.y)
                } else {
                    xy1 = cur
                }
                bezierPath.addCurveToPoint(next, controlPoint1: xy1!, controlPoint2: nextCubic)
                setCubicPoint(next, cubic: nextCubic)
            }
        }
        
        func Z() {
            if let initPoint = initialPoint {
                lineTo(initPoint)
            }
            bezierPath.closePath()
        }

        
        func setCubicPoint(p: CGPoint, cubic: CGPoint) {
            currentPoint = p
            cubicPoint = cubic
            quadrPoint = nil
        }
        
        func setInitPoint(p: CGPoint) {
            setPoint(p)
            initialPoint = p
        }
        
        func setPoint(p: CGPoint) {
            currentPoint = p
            cubicPoint = nil
            quadrPoint = nil
        }
        
        // TODO: think about this
        for part in path.segments {
            if let move = part as? Move {
                if move.absolute {
                    M(move.x, y: move.y)
                } else {
                    m(move.x, y: move.y)
                }
                
            } else if let pline = part as? PLine {
                if pline.absolute {
                    L(pline.x, y: pline.y)
                } else {
                    l(pline.x, y: pline.y)
                }
            } else if let hLine = part as? HLine {
                if hLine.absolute {
                    H(hLine.x)
                } else {
                    h(hLine.x)
                }
            } else if let vLine = part as? VLine {
                if vLine.absolute {
                    V(vLine.y)
                } else {
                    v(vLine.y)
                }
            } else if let cubic = part as? Cubic {
                if cubic.absolute {
                    C(cubic.x1, y1: cubic.y1, x2: cubic.x2, y2: cubic.y2, x: cubic.x, y: cubic.y)
                } else {
                    c(cubic.x1, y1: cubic.y1, x2: cubic.x2, y2: cubic.y2, x: cubic.x, y: cubic.y)
                }
            } else if let scubic = part as? SCubic {
                if scubic.absolute {
                    S(scubic.x2, y2: scubic.y2, x: scubic.x, y: scubic.y)
                } else {
                    s(scubic.x2, y2: scubic.y2, x: scubic.x, y: scubic.y)
                }
            } else if let _ = part as? Close {
                Z()
            }
        }
        return bezierPath
    }
    
    private func newCGRect(rect: Rect) -> CGRect {
        return CGRect(x: CGFloat(rect.x), y: CGFloat(rect.y), width: CGFloat(rect.w), height: CGFloat(rect.h))
    }

    private func setFill(fill: Fill?, ctx: CGContext?) {
        if fill != nil {
            if let color = fill as? Color {
                CGContextSetFillColorWithColor(ctx, mapColor(color))
                CGContextFillPath(ctx)
            } else if let gradient = fill as? LinearGradient {
                var start = CGPointMake(CGFloat(gradient.x1), CGFloat(gradient.y1))
                var end = CGPointMake(CGFloat(gradient.x2), CGFloat(gradient.y2))
                if gradient.userSpace {
                    let bounds = CGContextGetPathBoundingBox(ctx)
                    start = CGPointMake(start.x * bounds.width + bounds.minX, start.y * bounds.height + bounds.minY)
                    end = CGPointMake(end.x * bounds.width + bounds.minX, end.y * bounds.height + bounds.minY)
                }
                var colors: [CGColor] = []
                var stops: [CGFloat] = []
                for stop in gradient.stops {
                    stops.append(CGFloat(stop.offset))
                    colors.append(mapColor(stop.color))
                }
                let cgGradient = CGGradientCreateWithColors(CGColorSpaceCreateDeviceRGB(), colors, stops)
                CGContextClip(ctx)
                CGContextDrawLinearGradient(ctx, cgGradient, start, end, CGGradientDrawingOptions.DrawsAfterEndLocation)
            } else {
                print("Unsupported fill: \(fill)")
            }
        }
    }

    private func setStroke(stroke: Stroke?, ctx: CGContext?) {
        if stroke != nil {
            if let color = stroke!.fill as? Color {
                CGContextSetLineWidth(ctx, CGFloat(stroke!.width))
                CGContextSetLineJoin(ctx, mapLineJoin(stroke!.join))
                CGContextSetLineCap(ctx, mapLineCap(stroke!.cap))
                let dashes = stroke!.dashes
                if !dashes.isEmpty {
                    let dashPointer = mapDash(dashes)
                    CGContextSetLineDash(ctx, 0, dashPointer, dashes.count)
                    dashPointer.dealloc(dashes.count)
                }
                CGContextSetStrokeColorWithColor(ctx, mapColor(color))
                CGContextStrokePath(ctx)
            } else {
                print("Unsupported stroke fill: \(stroke!.fill)")
            }
        }
    }

    private func mapTransform(t: Transform) -> CGAffineTransform {
        return CGAffineTransform(a: CGFloat(t.m11), b: CGFloat(t.m21), c: CGFloat(t.m12),
                                 d: CGFloat(t.m22), tx: CGFloat(t.dx), ty: CGFloat(t.dy))
    }
    
    private func mapColor(color: Color) -> CGColor {
        let red = CGFloat(Double(color.r()) / 255.0)
        let green = CGFloat(Double(color.g()) / 255.0)
        let blue = CGFloat(Double(color.b()) / 255.0)
        let alpha = CGFloat(Double(color.a()) / 255.0)
        return UIColor(red: red, green: green, blue: blue, alpha: alpha).CGColor
    }

    private func mapLineJoin(join: LineJoin?) -> CGLineJoin {
        switch join {
            case LineJoin.round?: return CGLineJoin.Round
            case LineJoin.bevel?: return CGLineJoin.Bevel
            default: return CGLineJoin.Miter
        }
    }

    private func mapLineCap(cap: LineCap?) -> CGLineCap {
        switch cap {
            case LineCap.round?: return CGLineCap.Round
            case LineCap.square?: return CGLineCap.Square
            default: return CGLineCap.Butt
        }
    }

    private func mapDash(dashes: [Double]) -> UnsafeMutablePointer<CGFloat> {
        let p = UnsafeMutablePointer<CGFloat>(calloc(dashes.count, sizeof(CGFloat)))
        for (index, item) in dashes.enumerate() {
            p[index] = CGFloat(item)
        }
        return p
    }

}