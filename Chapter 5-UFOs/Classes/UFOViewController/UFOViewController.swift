//
//  UFOViewController.swift
//  GameCenter
//
//  Created by Kyle Richter on 11/14/10.
//  Copyright 2010 Dragon Forged Software. All rights reserved.
//

import MultipeerConnectivity
import GameKit
import UIKit

class UFOViewController: UIViewController, GameCenterManagerPlayerDelegate, GKGameCenterControllerDelegate, GKMatchmakerViewControllerDelegate {
    var gcManager: GameCenterManager?
    var peerPickerController: MCBrowserViewController?
    var currentSession: MCSession?
    var advertiserAssistant: MCAdvertiserAssistant?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(localUserAuthenticationChanged(_:)),
            name: .GKPlayerAuthenticationDidChangeNotificationName,
            object: nil)
        
        gcManager = GameCenterManager()
        gcManager?.playerDelegate = self
        gcManager?.authenticateLocalUser(self)
        gcManager?.populateAchievementCache()
        gcManager?.findAllActivity()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        gcManager?.playerDelegate = self
    }
    
    func playerDataLoaded(_ players: [GKPlayer]?, error: Error?) {
        if let error = error {
            print("An error occured during player lookup: \(error.localizedDescription)")
        } else {
            print("Players loaded: \(players ?? [])")
        }
    }
    
    @objc func localUserAuthenticationChanged(_ notif: Notification?) {
        if let object = notif?.object {
            print("Authenication Changed: \(object)")
        }
    }
    
    func processGameCenterAuthentication(_ error: Error?) {
        if let error = error {
            print("An error occured during authentication: \(error.localizedDescription)")
        }
    }
    
    func findProgrammaticMatch() {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 4


        GKMatchmaker.shared().findMatch(for: request, withCompletionHandler: { match, error in
            if let error = error {
                print("An error occurrred during finding a match: \(error.localizedDescription)")
            } else if let match = match {
                print("A match has been found: \(match)")
            }
        })
    }
    
    func findProgrammaticHostedMatch() {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 16
        
        GKMatchmaker.shared().findPlayers(forHostedRequest: request) { players, error in
            if let error = error {
                print("An error occurrred during finding a match: \(error.localizedDescription)")
            } else if let players = players {
                print("Players have been found for match: \(players)")
            }
        }
    }
    
    func addPlayer(to match: GKMatch?, with request: GKMatchRequest?) {
        if let match = match, let request = request {
            GKMatchmaker.shared().addPlayers(to: match, matchRequest: request, completionHandler: { error in
                if let error = error {
                    print("An error occurrred during adding a player to match: \(error.localizedDescription)")
                } else {
                    print("A player has been added to the match")
                }
            })
        }
    }
    
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
    
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFind match: GKMatch) {
        dismiss(animated: true, completion: nil)
    }
    
    func matchmakerViewController(_ viewController: GKMatchmakerViewController, didFindPlayers playerIDs: [String]) {
        dismiss(animated: true, completion: nil)
        print("Players: \(playerIDs)")
        //Begin Hosted Game
    }
    
    func playerActivity(_ activity: Int?, error: Error?) {
        if let error = error {
            print("An error occurred while querying player activity: \(error.localizedDescription)")
        } else {
            print("All recent player activity: \(activity ?? 0)")
        }
        
    }
    
    func playerActivityForGroup(_ activityDict: [AnyHashable : Any]?, error: Error?) {
        if let error = error {
            print("An error occurred while querying player activity: \(error.localizedDescription)")
        } else {
            if let activity = activityDict?["activity"],
               let playerGroup = activityDict?["playerGroup"] {
                print("All recent player activity: \(activity) For group: \(playerGroup)")
            }
        }
    }
    
    func friendsFinishedLoading(_ friends: [GKPlayer]?, error: Error?) {
        if let error = error {
            print("An error occured during friends list request: \(error.localizedDescription)")
        } else if let friends = friends {
            playerDataLoaded(friends, error: error)
        }
    }
    
    @IBAction func playButtonPressed() {
        let gameViewController = UFOGameViewController()
        gameViewController.gcManager = gcManager
        navigationController?.pushViewController(gameViewController, animated: true)
    }

    @IBAction func leaderboardButtonPressed() {
        let leaderboardController = GKGameCenterViewController.init(state: .default)
        leaderboardController.gameCenterDelegate = self
        present(leaderboardController, animated: true)
    }

    @IBAction func customLeaderboardButtonPressed() {
        let leaderboardViewController = UFOLeaderboardViewController()
        leaderboardViewController.gcManager = gcManager
        present(leaderboardViewController, animated: true)
    }
    
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        dismiss(animated: true, completion: nil)
    }
    

    @IBAction func achievementButtonPressed() {
        var achievementViewController: GKGameCenterViewController? = nil
        if let state = GKGameCenterViewControllerState(rawValue: 1) {
            achievementViewController = GKGameCenterViewController(state: state)
        }
        achievementViewController?.gameCenterDelegate = self
        if let achievementViewController = achievementViewController {
            present(achievementViewController, animated: true)
        }
    }

    @IBAction func customAchievementButtonPressed() {
        let achievementViewController = UFOAchievementViewController()
        achievementViewController.gcManager = gcManager
        present(achievementViewController, animated: true)
    }

    @IBAction func multiplayerButtonPressed() {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 4
        
        guard let matchmakerViewController = GKMatchmakerViewController(matchRequest: request) else {
            print("There was an error creating the matchmaker view controller.")
            return
        }
        
        matchmakerViewController.matchmakerDelegate = self
        matchmakerViewController.isHosted = true
        
        present(matchmakerViewController, animated: true)
    }
    
    @IBAction func localMultiplayerPressed(_ sender: UIButton) {
        let request = GKMatchRequest()
        request.minPlayers = 2
        request.maxPlayers = 4

        let matchmakerViewController = GKMatchmakerViewController(matchRequest: request)
        matchmakerViewController?.matchmakerDelegate = self

        if let matchmakerViewController = matchmakerViewController {
            present(matchmakerViewController, animated: true)
        }
    }
}
