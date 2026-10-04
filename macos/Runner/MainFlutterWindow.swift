import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    RegisterGeneratedPlugins(registry: flutterViewController)
    MacosWindowHolder.window = self
    MacosProximityPlugin.register(messenger: flutterViewController.engine.binaryMessenger)

    super.awakeFromNib()
  }

  override func close() {
    MacosWindowHolder.window = nil
    super.close()
  }
}
