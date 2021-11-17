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
    func achievementSubmitted(_ achievement: GKAchievement?, error: Error?)
    func achievementEarned(_ achievement: GKAchievementDescription?)
    func receivedData(_ dataDictionary: [AnyHashable: Any]?)

}

protocol GameCenterManagerLeaderboardDelegate: AnyObject {
    
    func leaderboardUpdated(_ scores: [GKLeaderboard.Entry]?, error: Error?)
    
}

protocol GameCenterManagerAchievementDelegate: AnyObject {
    
    func achievementDescriptionsLoaded(_ descriptions: [GKAchievementDescription]?, error: Error?)
    
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
    weak var achievementDelegate: GameCenterManagerAchievementDelegate?
    
    private var earnedAchievementCache: [String: GKAchievement]?
    
    enum MatchOrSession {
        case match(GKMatch)
        case session(MCSession)
    }
    
    var matchOrSession: MatchOrSession?
    
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
    
    func resetAchievements() {
        earnedAchievementCache = nil
        
        GKAchievement.resetAchievements { error in
            if let error = error {
                print("There was an error in resetting the achievements: \(error.localizedDescription)")
            } else {
                print("Achievements have been reset")
            }
        }
    }
    
    func populateAchievementCache(_ completion: (() -> Void)? = nil) {
        guard earnedAchievementCache == nil else {
            completion?()
            return
        }
        
        GKAchievement.loadAchievements { [weak self] achievements, error in
            if let error = error {
                print("An error occurred while loading achievements: \(error.localizedDescription)")
            } else {
                if let achievements = achievements {
                    self?.earnedAchievementCache = achievements.reduce(into: [:], { result, achievement in
                        result[achievement.identifier] = achievement
                    })
                } else {
                    self?.earnedAchievementCache = [:]
                }
                completion?()
            }
        }
    }
    
    func storeAchievementToSubmitLater(_ achievement: GKAchievement) {
        let defaults = UserDefaults()
        let savedAchievementsKey = "savedAchievements"
        var achievementsDictionary = defaults.dictionary(forKey: savedAchievementsKey) as? [String: Double] ?? [:]
        
        let achievementKey = achievement.identifier
        let achievementProgress = achievement.percentComplete
        let storedProgress = achievementsDictionary[achievementKey] ?? 0
        
        if achievementProgress > storedProgress {
            achievementsDictionary[achievementKey] = achievementProgress
            defaults.setValue(achievementsDictionary, forKey: savedAchievementsKey)
        }
    }
    
    func submitAllSavedAchievements() {
        let defaults = UserDefaults()
        let savedAchievementsKey = "savedAchievements"
        
        if let achievementsDictionary = defaults.dictionary(forKey: savedAchievementsKey) as? [String: Double] {
            achievementsDictionary.forEach { key, value in
                submitAchievement(key, percentComplete: value)
            }
            
            defaults.removeObject(forKey: savedAchievementsKey)
        }
    }

    func disconnect() {
        switch matchOrSession {
        case .match(let match):
            match.disconnect()
        case .session(let session):
            session.disconnect()
        case .none:
            break
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
    
    func findAllActivity() {
        GKMatchmaker.shared().queryActivity { [weak self] activity, error in
            DispatchQueue.main.async { [weak self] in
                self?.playerDelegate?.playerActivity(activity, error: error)
            }
        }
    }
    
    func findActivityForPlayerGroup(_ playerGroup: Int) {
        GKMatchmaker.shared().queryPlayerGroupActivity(playerGroup) { [weak self] activity, error in
            
            let activityDictionary = [
                "activity": activity,
                "playerGroup": playerGroup,
            ]
            
            DispatchQueue.main.async { [weak self] in
                self?.playerDelegate?.playerActivityForGroup(activityDictionary, error: error)
            }
        }
    }
    
    func sendStringToAllPeers(_ dataString: String, reliable: Bool) {
        guard matchOrSession != nil else {
            print("Game Center Manager matchOrSession property was not set, this needs to be set with the GKMatch or GKSession before sending or receiving data")
            return
        }
        
        guard let dataToSend = dataString.data(using: .utf8) else {
            print("Game Center Manager dataString could not be converted to Data.")
            return
        }
        
        var sendError: Error?
        
        switch matchOrSession {
        case .match(let match):
            let mode: GKMatch.SendDataMode = reliable ? .reliable : .unreliable
            
            do {
                try match.sendData(toAllPlayers: dataToSend, with: mode)
            } catch {
                sendError = error
            }
        case .session(let session):
            let peers = session.connectedPeers
            let mode: MCSessionSendDataMode = reliable ? .reliable : .unreliable
            
            do {
                try session.send(dataToSend, toPeers: peers, with: mode)
            } catch {
                sendError = error
            }
        case .none:
            print("Game Center Manager matchOrSession was not a GKMatch or a GKSession, we are unable to send data.")
        }
        
        if let sendError = sendError {
            print("An error occurred while sending data: \(sendError.localizedDescription)")
        }
    }
    
    func sendString(_ dataString: String, toPeers peers: [Any], reliable: Bool) {
        guard matchOrSession != nil else {
            print("Game Center Manager matchOrSession property was not set, this needs to be set with the GKMatch or GKSession before sending or receiving data")
            return
        }
        
        guard let dataToSend = dataString.data(using: .utf8) else {
            print("Game Center Manager dataString could not be converted to Data.")
            return
        }
        
        var sendError: Error?
        
        switch matchOrSession {
        case .match(let match):
            if let players = peers as? [GKPlayer] {
                let mode: GKMatch.SendDataMode = reliable ? .reliable : .unreliable
                
                do {
                    try match.send(dataToSend, to: players, dataMode: mode)
                } catch {
                    sendError = error
                }
            } else {
                print("Peers was not the correct type of array. We are unable to send data.")
            }
        case .session(let session):
            if let peerIDs = peers as? [MCPeerID] {
                let mode: MCSessionSendDataMode = reliable ? .reliable : .unreliable
                
                do {
                    try session.send(dataToSend, toPeers: peerIDs, with: mode)
                } catch {
                    sendError = error
                }
            } else {
                print("Peers was not the correct type of array. We are unable to send data.")
            }
        case .none:
            print("Game Center Manager matchOrSession was not a GKMatch or a GKSession. We are unable to send data.")
        }
        
        if let sendError = sendError {
            print("An error occurred while sending data: \(sendError.localizedDescription)")
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
                    self.submitAllSavedAchievements()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                        self?.populateAchievementCache(nil)
                    }
                    GKLocalPlayer.local.register(self)
                }
                self.playerDelegate?.processGameCenterAuthentication(error)
            }
        }
    }
    
    func retrieveAchievmentMetadata() {
        GKAchievementDescription.loadAchievementDescriptions { [weak self] (descriptions, error) in
            if let error = error {
                print("An error occurred while loading achievement descriptions: \(error.localizedDescription)")
            }
            DispatchQueue.main.async { [weak self] in
                self?.achievementDelegate?.achievementDescriptionsLoaded(descriptions, error: error)
            }
        }
    }
    
    func percentageCompleteOfAchievement(withIdentifier identifier: String?) -> Double {
        if GKLocalPlayer.local.isAuthenticated == false {
            return -1
        }

        if earnedAchievementCache == nil {
            print("Unable to determine achievement progress, local cache is empty")
        } else {
            let achievement = earnedAchievementCache?[identifier ?? ""]

            if let achievement = achievement {
                return achievement.percentComplete
            } else {
                return 0
            }
        }

        return -1
    }
    
    func achievement(forIdentifier identifier: String) -> GKAchievement? {
        guard var earnedAchievementCache = earnedAchievementCache else {
            return nil
        }
        
        if let achievement = earnedAchievementCache[identifier] {
            return achievement
        }
        
        let achievement = GKAchievement(identifier: identifier)
        earnedAchievementCache[identifier] = achievement
        self.earnedAchievementCache = earnedAchievementCache
        return achievement
    }
    
    func achievement(withIdentifierIsComplete identifier: String?) -> Bool {
        if percentageCompleteOfAchievement(withIdentifier: identifier) >= 100 {
            return true
        } else {
            return false
        }
    }
    
    func submitAchievement(_ identifier: String, percentComplete: Double) {
        if GKLocalPlayer.local.isAuthenticated == false {
            return
        }
        guard earnedAchievementCache != nil else {
            populateAchievementCache() {
                self.submitAchievement(identifier, percentComplete: percentComplete)
            }
            return
        }
        
        if let achievement = achievement(forIdentifier: identifier) {
            let storedProgress = achievement.percentComplete
            
            guard percentComplete > storedProgress else {
                return
            }
            
            achievement.percentComplete = percentComplete
            
            GKAchievement.report([achievement], withCompletionHandler: { [weak self] error in
                if let error = error {
                    print("An error occurred while reporting an achievement. Data will be saved to UserDefaults: \(error.localizedDescription)")
                    self?.storeAchievementToSubmitLater(achievement)
                }
                
                if percentComplete >= 100 {
                    GKAchievementDescription.loadAchievementDescriptions(completionHandler: { [weak self] achievementDescriptions, error in
                        if let error = error {
                            print("An error occurred while loading achievement descriptions: \(error.localizedDescription)")
                        }
                        achievementDescriptions?.forEach{ achievementDescription in
                            if achievement.identifier == achievementDescription.identifier {
                                self?.gameDelegate?.achievementEarned(achievementDescription)
                            }
                        }
                    })
                }
                
                DispatchQueue.main.async { [weak self] in
                    self?.gameDelegate?.achievementSubmitted(achievement, error: error)
                }
            })
        }
        
    }
    
}

extension GameCenterManager {
    
    public func player(_ player: GKPlayer, didAccept invite: GKInvite) {
        guard let matchmakerViewController = GKMatchmakerViewController(invite: invite) else {
            print("There was an error creating the matchmaker view controller.")
            return
        }
        
        matchmakerViewController.matchmakerDelegate = self
        present(matchmakerViewController, animated: true)
    }
    
    struct PlayerClass: OptionSet {
        let rawValue: UInt32
        
        static let squadLeader     = PlayerClass(rawValue: 0xFF000000)
        static let breacher        = PlayerClass(rawValue: 0x00FF0000)
        static let grenadier       = PlayerClass(rawValue: 0x0000FF00)
        static let lightMachineGun = PlayerClass(rawValue: 0x000000FF)
    }
    

    

    
    public func player(_ player: GKPlayer, didRequestMatchWithRecipients recipientPlayers: [GKPlayer]) {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 2
        request.recipients = recipientPlayers
        request.playerAttributes = PlayerClass.squadLeader.rawValue
        
        guard let matchmakerViewController = GKMatchmakerViewController(matchRequest: request) else {
            print("There was an error creating the matchmaker view controller.")
            return
        }
        matchmakerViewController.matchmakerDelegate = self
        present(matchmakerViewController, animated: true)
    }
    
}
