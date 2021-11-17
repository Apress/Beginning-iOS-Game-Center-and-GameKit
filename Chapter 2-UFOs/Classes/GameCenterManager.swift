import Foundation
import GameKit
import MultipeerConnectivity

protocol GameCenterManagerPlayerDelegate: AnyObject {
    
    func processGameCenterAuthentication(_ error: Error?)
    func friendsFinishedLoading(_ friends: [GKPlayer]?, error: Error?)
    func playerDataLoaded(_ players: [GKPlayer]?, error: Error?)
    func playerActivity(_ activity: Int?, error: Error?)
    func playerActivityForGroup(_ activityDict: [AnyHashable: Any]?, error: Error?)

}

class GameCenterManager: UIViewController, GKMatchmakerViewControllerDelegate, GKMatchDelegate, GKLocalPlayerListener, UIAlertViewDelegate {
    func matchmakerViewControllerWasCancelled(_ viewController: GKMatchmakerViewController) {
        dismiss(animated: true, completion: nil)
    }
    
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFailWithError error: Error) {
        dismiss(animated: true, completion: nil)
        
        let alert = UIAlertController.init(title: "", message: "An error occurred: \(error.localizedDescription)", preferredStyle: .alert)
        let defaultAction = UIAlertAction(title: "Dismiss", style: .default, handler: { action in
            self.dismiss(animated: true, completion: nil)
        })
        
        alert.addAction(defaultAction)
        present(alert, animated: true, completion: nil)
    }
    
    weak var playerDelegate: GameCenterManagerPlayerDelegate?
    
    func playersForIDs(_ playerIDs: [String]) {
        GKPlayer.loadPlayers(forIdentifiers: playerIDs) { [weak self] players, error in
            DispatchQueue.main.async {
                self?.playerDelegate?.playerDataLoaded(players, error: error)
            }
        }
    }
    
    func playerForID(_ playerID: String) {
        playersForIDs([playerID])
    }
    
    func retrieveFriendsList() {
        if GKLocalPlayer.local.isAuthenticated == true {
            GKLocalPlayer.local.loadRecentPlayers(completionHandler: { [weak self] recentPlayers, error in
                DispatchQueue.main.async { [weak self] in
                    self?.playerDelegate?.friendsFinishedLoading(recentPlayers, error: error)
                }
            })
        } else {
            print("You must authenicate first")
        }
    }
    
    func authenticateLocalUser(_ controller: UIViewController?) {
        let localPlayer = GKLocalPlayer.local
        if localPlayer.isAuthenticated == false {
            localPlayer.authenticateHandler = { [weak self] viewController, error in
                guard let self = self else {
                    return
                }
                if let viewController = viewController {
                    controller?.present(viewController, animated: true)
                }
                if localPlayer.isAuthenticated {
                    localPlayer.unregisterListener(self)
                    GKLocalPlayer.local.register(self)
                }
                self.playerDelegate?.processGameCenterAuthentication(error)
            }
        }
    }
}
