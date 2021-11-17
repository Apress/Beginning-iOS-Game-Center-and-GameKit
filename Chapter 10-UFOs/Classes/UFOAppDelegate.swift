import UIKit

@UIApplicationMain
class UFOAppDelegate: NSObject, UIApplicationDelegate {
    @IBOutlet var window: UIWindow?
    @IBOutlet var navController: UINavigationController!

// MARK: -
// MARK: Application lifecycle
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Override point for customization after application launch.

        // Add the view controller's view to the window and display.
        window?.rootViewController = navController
        window?.makeKeyAndVisible()

        return true
    }

// MARK: -
// MARK: Memory management
    deinit {
    }
}

