import AppKit
import ObjectiveC

/// Glyph + resource resolver for the Tap pane. Mirrors the pattern
/// used by Uninstaller / Alfred / Sentry so the bundled artwork
/// loads in BOTH worlds the pane runs in:
///
///   • Standalone `Tap.app` — SwiftPM's resource bundle is copied
///     verbatim into `Contents/Frameworks/TapPane_TapPane.bundle`
///     (or for some builders, flattened into `Contents/Resources/`).
///   • Merged into the launcher — the launcher `dlopen`s
///     `libTapPane.dylib` out of `Tap.app/Contents/Frameworks/`,
///     so `Bundle.module` (the SwiftPM-generated accessor) fatals
///     and `Bundle.main` resolves to the *launcher* bundle, not
///     ours. We hand-walk from the dylib's loaded path back to the
///     adjacent resource bundle / Resources directory.
///
/// The walk falls back through every layout we've seen in the
/// suite so a fresh app builder doesn't need a special case.
enum TapBrand {
    private final class BundleToken {}

    static func resourceURL(_ name: String, _ ext: String) -> URL? {
        // Standalone .app — when the PNG is copied flat into
        // Contents/Resources, Bundle.main finds it first.
        if let u = Bundle.main.url(forResource: name, withExtension: ext) {
            return u
        }
        // Dylib path — class_getImageName returns the absolute path
        // the dynamic linker loaded this class from. Walk up to find
        // the adjacent resource bundle the SwiftPM target produced.
        if let img = class_getImageName(BundleToken.self) {
            let dylib = URL(fileURLWithPath: String(cString: img))
            let fw = dylib.deletingLastPathComponent()
            // Default SwiftPM layout: `<Target>_<Module>.bundle`
            // alongside the dylib, with the PNG inside.
            if let b = Bundle(url: fw.appendingPathComponent(
                    "TapPane_TapPane.bundle")),
               let u = b.url(forResource: name, withExtension: ext) {
                return u
            }
            // Some build flavours flatten resources next to the
            // dylib instead of leaving them in a sub-bundle.
            let res = fw.deletingLastPathComponent()
                .appendingPathComponent("Resources/\(name).\(ext)")
            if FileManager.default.fileExists(atPath: res.path) {
                return res
            }
            let same = fw.appendingPathComponent("\(name).\(ext)")
            if FileManager.default.fileExists(atPath: same.path) {
                return same
            }
        }
        // Last resort: the framework Bundle for this token class —
        // covers dev/test invocations where the dylib path trick
        // doesn't pan out.
        return Bundle(for: BundleToken.self)
            .url(forResource: name, withExtension: ext)
    }

    /// Full-colour 1024×1024 server-tapped artwork used everywhere
    /// Tap is rendered as itself: the popover SignInView's big mark,
    /// the ServerListView header's small chip, and the NSStatusItem
    /// when Tap runs standalone. Kept full-colour intentionally —
    /// the artwork *is* the brand; a template silhouette would lose
    /// the smiling-server character that's the whole point of v2.
    private static let logoSource: NSImage = {
        if let url = resourceURL("Logo", "png"),
           let img = NSImage(contentsOf: url) {
            return img
        }
        // SF-Symbol fallback only if the bundle dance somehow fails
        // — `bolt.horizontal.circle` was the placeholder Tap shipped
        // with through v1, so this preserves the historical look
        // rather than rendering a broken-image box.
        return NSImage(
            systemSymbolName: "bolt.horizontal.circle",
            accessibilityDescription: "Tap"
        ) ?? NSImage()
    }()

    /// Menu-bar status item — sized to 18pt tall so it sits at the
    /// same visual weight as every other tray icon on macOS. NOT
    /// template: we want the server character readable in colour
    /// (Discord/Slack-style brand presence), not flattened to a B/W
    /// silhouette where the face + antenna disappear.
    static let menuBarIcon: NSImage = {
        let img = logoSource.copy() as? NSImage ?? logoSource
        let h: CGFloat = 18
        let aspect = img.size.width / max(img.size.height, 1)
        img.size = NSSize(width: h * aspect, height: h)
        img.isTemplate = false
        return img
    }()

    /// Popover header / SignInView mark — full size, the source
    /// image's natural rasters get downscaled by SwiftUI via the
    /// `.resizable().scaledToFit()` modifiers at the call site.
    static let logo: NSImage = logoSource
}
