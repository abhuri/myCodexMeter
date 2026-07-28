import AppKit
import Foundation

if CommandLine.arguments.contains("--self-test") {
    exit(SelfTestRunner.run() ? EXIT_SUCCESS : EXIT_FAILURE)
} else if CommandLine.arguments.contains("--check-live-usage") {
    exit(SelfTestRunner.checkLiveUsage() ? EXIT_SUCCESS : EXIT_FAILURE)
} else {
    let application = NSApplication.shared
    let appDelegate = AppDelegate()

    application.delegate = appDelegate
    application.setActivationPolicy(.accessory)
    application.run()
}
