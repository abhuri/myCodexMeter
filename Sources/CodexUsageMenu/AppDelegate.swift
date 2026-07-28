import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuController: UsageMenuController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuController = UsageMenuController()
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuController?.stop()
    }
}
