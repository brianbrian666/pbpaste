import AppKit
import ImageIO

@MainActor
enum ThumbnailCache {
    private static let cache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 120
        return cache
    }()

    private static let sizeCache: NSCache<NSString, NSValue> = {
        let cache = NSCache<NSString, NSValue>()
        cache.countLimit = 120
        return cache
    }()

    private static let fileCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 120
        return cache
    }()

    /// Downsamples at decode time so a 4K screenshot never produces a full-size bitmap.
    static func thumbnail(for item: ClipItem, maxPixelSize: Int = 256) -> NSImage? {
        guard let data = item.imageData else { return nil }
        let key = item.contentHash as NSString
        if let cached = cache.object(forKey: key) { return cached }
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        let image: NSImage
        if let cgImage = downsample(CGImageSourceCreateWithData(data as CFData, sourceOptions), maxPixelSize: maxPixelSize) {
            image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        } else if let fallback = NSImage(data: data) {
            image = fallback
        } else {
            return nil
        }
        cache.setObject(image, forKey: key)
        return image
    }

    /// Downsamples straight from a file URL (e.g. an image file copied in Finder) without loading full-size data.
    static func fileThumbnail(for url: URL, maxPixelSize: Int = 256) -> NSImage? {
        let key = url.path as NSString
        if let cached = fileCache.object(forKey: key) { return cached }
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let cgImage = downsample(CGImageSourceCreateWithURL(url as CFURL, sourceOptions), maxPixelSize: maxPixelSize) else {
            return nil
        }
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        fileCache.setObject(image, forKey: key)
        return image
    }

    /// Pixel dimensions from the image header only — no full decode.
    static func pixelSize(for item: ClipItem) -> NSSize? {
        guard let data = item.imageData else { return nil }
        let key = item.contentHash as NSString
        if let cached = sizeCache.object(forKey: key) { return cached.sizeValue }
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = properties[kCGImagePropertyPixelWidth] as? Int,
              let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        let size = NSSize(width: width, height: height)
        sizeCache.setObject(NSValue(size: size), forKey: key)
        return size
    }

    private static func downsample(_ source: CGImageSource?, maxPixelSize: Int) -> CGImage? {
        guard let source else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ] as CFDictionary
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options)
    }
}
