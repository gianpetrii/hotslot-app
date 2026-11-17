import ImageIO
import UIKit

/// Miniaturas de las imágenes guardadas en slots, reducidas al tamaño de la card y en caché.
enum SlotImageLoader {
    private static let cache = NSCache<NSString, UIImage>()

    /// Miniatura cuyo lado más largo mide `maxPixel` píxeles.
    static func thumbnail(fileName: String, maxPixel: CGFloat) -> UIImage? {
        let key = "\(fileName)@\(Int(maxPixel))" as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let url = AppSupportDirectory.images.appendingPathComponent(fileName)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let image = UIImage(cgImage: cgImage)
        cache.setObject(image, forKey: key)
        return image
    }

    /// Medidas de la imagen original, sin cargarla en memoria.
    static func pixelSize(fileName: String) -> CGSize? {
        let url = AppSupportDirectory.images.appendingPathComponent(fileName)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = properties[kCGImagePropertyPixelHeight] as? CGFloat else { return nil }
        return CGSize(width: width, height: height)
    }
}
