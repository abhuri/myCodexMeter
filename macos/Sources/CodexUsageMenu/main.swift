import AppKit
import Foundation

let arguments = CommandLine.arguments

if arguments.contains("--self-test") {
    exit(SelfTestRunner.run() ? EXIT_SUCCESS : EXIT_FAILURE)
} else if arguments.contains("--check-live-usage") {
    exit(SelfTestRunner.checkLiveUsage() ? EXIT_SUCCESS : EXIT_FAILURE)
} else if let optionIndex = arguments.firstIndex(of: "--launch-at-login") {
    guard arguments.indices.contains(optionIndex + 1) else {
        fputs("Usage: --launch-at-login status|enable|disable\n", stderr)
        exit(EXIT_FAILURE)
    }

    let command = arguments[optionIndex + 1]

    do {
        switch command {
        case "status":
            print(LaunchAtLoginManager.isEnabled ? "enabled" : "disabled")
        case "enable":
            try LaunchAtLoginManager.setEnabled(true)
            print(LaunchAtLoginManager.isEnabled ? "enabled" : "disabled")
        case "disable":
            try LaunchAtLoginManager.setEnabled(false)
            print(LaunchAtLoginManager.isEnabled ? "enabled" : "disabled")
        default:
            fputs("Usage: --launch-at-login status|enable|disable\n", stderr)
            exit(EXIT_FAILURE)
        }
    } catch {
        fputs("Launch at Login error: \(error.localizedDescription)\n", stderr)
        exit(EXIT_FAILURE)
    }

    exit(EXIT_SUCCESS)
} else {
    let application = NSApplication.shared
    let appDelegate = AppDelegate()

    application.delegate = appDelegate
    application.setActivationPolicy(.accessory)
    application.run()
}
