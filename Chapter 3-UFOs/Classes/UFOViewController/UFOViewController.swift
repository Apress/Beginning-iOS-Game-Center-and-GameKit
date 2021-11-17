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

class UFOViewController: UIViewController, GKGameCenterControllerDelegate {
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
        gcManager?.authenticateLocalUser(self)
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
}
