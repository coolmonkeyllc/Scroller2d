import SpriteKit
import UIKit
import Scroller2d

/// UIKit application entry point. Scroller2d is not used directly in this file; `GameScene` owns that integration.
@main
final class DesertRuinsApp: UIResponder, UIApplicationDelegate {
}

final class DesertRuinsWindowScene: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    /// Creates the app window, installs the game view controller, and displays it for the connected scene.
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

		let build = String(format: "%04d", LibraryVersion.getBuildNumber())
		print("Scroller2d Api Library Version: \(LibraryVersion.getVersion()) (build \(build))")
		print("Scroller2d Api Schema Version: \(LibraryVersion.getSchemaVersion())")

		let window = UIWindow(windowScene: windowScene)
        window.rootViewController = GameViewController()
        self.window = window
        window.makeKeyAndVisible()
    }

    /// Stops the demo as soon as the simulator scene is no longer active.
    func sceneWillResignActive(_ scene: UIScene) {
        stopDemo()
    }

    /// Also stops the demo when the scene enters the background without disconnecting.
    func sceneDidEnterBackground(_ scene: UIScene) {
        stopDemo()
    }

    /// Handles final scene disconnection as a fallback shutdown path.
    func sceneDidDisconnect(_ scene: UIScene) {
        stopDemo()
    }

    /// Routes every scene shutdown callback through one idempotent cleanup path.
    private func stopDemo() {
        (window?.rootViewController as? GameViewController)?.stopDemo()
    }
}

final class GameViewController: UIViewController {
    private var game: GameScene?
    private weak var spriteView: GameInputView?

    /// Keeps the game canvas clear of the Home indicator while it is onscreen.
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    /// Hides the status bar so the SpriteKit scene can use the full safe-area canvas.
    override var prefersStatusBarHidden: Bool { true }
    /// Allows every orientation on iPad but restricts the phone experience to landscape.
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        traitCollection.userInterfaceIdiom == .pad ? .all : .landscape
    }

    /// Loads level data, creates the game scene, and presents it in an input-aware SpriteKit view.
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.09, green: 0.07, blue: 0.14, alpha: 1)
        do {
            let game = try GameScene(data: LevelData())
            let spriteView = GameInputView()
            self.game = game
            self.spriteView = spriteView
            spriteView.game = game
            spriteView.translatesAutoresizingMaskIntoConstraints = false
            spriteView.isMultipleTouchEnabled = true
            spriteView.ignoresSiblingOrder = true
            spriteView.preferredFramesPerSecond = 60
            view.addSubview(spriteView)
            let frame = view.safeAreaLayoutGuide
            NSLayoutConstraint.activate([
                spriteView.leadingAnchor.constraint(equalTo: frame.leadingAnchor),
                spriteView.trailingAnchor.constraint(equalTo: frame.trailingAnchor),
                spriteView.topAnchor.constraint(equalTo: frame.topAnchor),
                spriteView.bottomAnchor.constraint(equalTo: frame.bottomAnchor)
            ])
            spriteView.presentScene(game)
        } catch {
            let message = UILabel()
            message.translatesAutoresizingMaskIntoConstraints = false
            message.text = error.localizedDescription
            message.textColor = .white
            message.numberOfLines = 0
            view.addSubview(message)
            NSLayoutConstraint.activate([
                message.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                message.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                message.widthAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.widthAnchor, multiplier: 0.9)
            ])
            NSLog("DESERTRUINS_LOAD_FAILED %@", error.localizedDescription)
        }
    }

    /// Stops simulation and audio, then detaches the SpriteKit scene from its view.
    func stopDemo() {
        game?.stopDemo()
        spriteView?.presentScene(nil)
        game = nil
    }
}


final class GameInputView: SKView {
    weak var game: GameScene?

    /// Allows the SpriteKit view to receive hardware-keyboard press events.
    override var canBecomeFirstResponder: Bool { true }

    /// Acquires keyboard focus when attached and releases held controls when detached.
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil { becomeFirstResponder() } else { game?.releaseControls() }
    }

    /// Clears active game controls before giving up keyboard focus.
    override func resignFirstResponder() -> Bool {
        game?.releaseControls()
        return super.resignFirstResponder()
    }

    /// Forwards key-down events to the game and passes unhandled presses up the responder chain.
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let remaining = forward(presses, pressed: true)
        if !remaining.isEmpty { super.pressesBegan(remaining, with: event) }
    }

    /// Forwards key-up events to the game and passes unhandled presses up the responder chain.
    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let remaining = forward(presses, pressed: false)
        if !remaining.isEmpty { super.pressesEnded(remaining, with: event) }
    }

    /// Treats cancelled presses as releases so movement cannot remain stuck.
    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        let remaining = forward(presses, pressed: false)
        if !remaining.isEmpty { super.pressesCancelled(remaining, with: event) }
    }

    /// Sends keyboard usages to `GameScene` and returns only presses the game did not consume.
    private func forward(_ presses: Set<UIPress>, pressed: Bool) -> Set<UIPress> {
        presses.filter { press in
            guard let key = press.key else { return true }
            return game?.key(key.keyCode, pressed: pressed) != true
        }
    }
}
