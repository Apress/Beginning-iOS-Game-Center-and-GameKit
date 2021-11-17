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

protocol GameCenterManagerGameDelegate: AnyObject {
    
    func scoreReported(_ error: Error?)

}

protocol GameCenterManagerLeaderboardDelegate: AnyObject {
    
    func leaderboardUpdated(_ scores: [GKLeaderboard.Entry]?, error: Error?)
    
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
    weak var gameDelegate: GameCenterManagerGameDelegate?
    weak var leaderboardDelegate: GameCenterManagerLeaderboardDelegate?
    
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
    
    struct SavedScore: Codable {
        let score: Int
        let category: String
    }
    static let savedScoresKey = "savedScores"
    
    func reportScore(_ score: Int, forCategory category: String) {
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [category]) { [weak self] error in
            if let error = error {
                print("An error occurred while submitting a score. Data will be saved to UserDefaults: \(error.localizedDescription)")
                let savedScore = SavedScore(score: score, category: category)
                self?.storeScoreForLater(savedScore)
            }
            DispatchQueue.main.async { [weak self] in
                self?.gameDelegate?.scoreReported(error)
            }
        }
    }
    
    func storeScoreForLater(_ savedScore: SavedScore) {
        let defaults = UserDefaults.standard
        var updatedSavedScores: [SavedScore]
        if let savedScoresData = defaults.data(forKey: Self.savedScoresKey),
           let savedScores = try? JSONDecoder().decode([SavedScore].self, from: savedScoresData) {
            updatedSavedScores = savedScores
        } else {
            updatedSavedScores = []
        }
        updatedSavedScores.append(savedScore)
        if let savedScoresData = try? JSONEncoder().encode(updatedSavedScores) {
            defaults.setValue(savedScoresData, forKey: Self.savedScoresKey)
        }
    }
    
    func submitAllSavedScores() {
        let defaults = UserDefaults.standard
        
        if let savedScoresData = defaults.data(forKey: Self.savedScoresKey) {
            defaults.removeObject(forKey: Self.savedScoresKey)
            
            if let savedScores = try? JSONDecoder().decode([SavedScore].self, from: savedScoresData) {
                savedScores.forEach { savedScore in
                    GKLeaderboard.submitScore(savedScore.score, context: 0, player: GKLocalPlayer.local, leaderboardIDs: [savedScore.category]) { [weak self] error in
                        if let error = error {
                            print("An error occurred while submitting a score. Data will be saved to UserDefaults: \(error.localizedDescription)")
                            self?.storeScoreForLater(savedScore)
                        } else {
                            print("Saved score submitted")
                        }
                    }
                }
            }
        }
    }
    
    func retrieveScores(forCategory category: String, playerScope: GKLeaderboard.PlayerScope, timeScope: GKLeaderboard.TimeScope, range: NSRange) {
        GKLeaderboard.loadLeaderboards(IDs: [category]) { [weak self] leaderboards, error in
            leaderboards?.first?.loadEntries(for: playerScope, timeScope: timeScope, range: range, completionHandler: { [weak self] playerEntry, entries, totalPlayerCount, error in
                self?.leaderboardDelegate?.leaderboardUpdated(entries, error: error)
            })
        }
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
                    self.submitAllSavedScores()
                    GKLocalPlayer.local.register(self)
                }
                self.playerDelegate?.processGameCenterAuthentication(error)
            }
        }
    }
}
