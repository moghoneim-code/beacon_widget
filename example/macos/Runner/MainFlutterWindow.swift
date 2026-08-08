import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.setFrame(self.frame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()

    // The storefront grid wants more room than the 800x600 default, which
    // clips the product cards. Restoration has to be turned off first:
    // macOS reapplies the previously saved frame after awakeFromNib, so
    // setting a size without this is silently undone on every launch.
    self.isRestorable = false
    self.setFrameAutosaveName("")
    self.setContentSize(NSSize(width: 1180, height: 860))
    self.center()
  }
}
