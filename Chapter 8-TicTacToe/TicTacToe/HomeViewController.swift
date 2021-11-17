//
//  ViewController.swift
//  TicTacToe
//
//  Created by Beau G. Bolle on 2021-9-27.
//

import UIKit
import GameKit

class HomeViewController: UIViewController {
    
    var gcManager: GameCenterManager?
    
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
    
    @objc func localUserAuthenticationChanged(_ notification: Notification?) {
        if let object = notification?.object {
            print("Authenication Changed: \(object)")
        }
    }

    @IBAction func showMatchmaker() {
        let match = GKMatchRequest()
        match.minPlayers = 2
        match.maxPlayers = 2
        
        let turnMatchmakerVC = GKTurnBasedMatchmakerViewController(matchRequest: match)
        
        turnMatchmakerVC.turnBasedMatchmakerDelegate = self
        
        present(turnMatchmakerVC, animated: true)
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        guard
            segue.identifier == "PlayGame",
            let match = sender as? GKTurnBasedMatch,
            let game = segue.destination as? GameViewController
        else { return }
        
        game.match = match
    }
    
    func findMatch() {
        let match = GKMatchRequest()
        
        match.minPlayers = 2
        match.maxPlayers = 2
        
        GKTurnBasedMatch.find(for: match) { match, error in
            if let error = error {
                print("An error occurred when finding a match: \(error.localizedDescription)")
                return
            }
            
            // Start new game with returned match.
        }
        
    }
    
    func loadMatches() {
        GKTurnBasedMatch.loadMatches { matches, error in
            if let error = error {
                print("An error occurred while loading matches: \(error.localizedDescription)")
                return
            }
            
            print("Existing Matches: \(matches ?? [])")
        }
        
    }
    
}

extension HomeViewController: GKTurnBasedMatchmakerViewControllerDelegate {

    func turnBasedMatchmakerViewControllerWasCancelled(_ viewController: GKTurnBasedMatchmakerViewController) {
        dismiss(animated: true)
    }
    
    func turnBasedMatchmakerViewController(_ viewController: GKTurnBasedMatchmakerViewController, didFind match: GKTurnBasedMatch) {
        performSegue(withIdentifier: "PlayGame", sender: match)
        
        dismiss(animated: true)
    }
    
    func turnBasedMatchmakerViewController(_ viewController: GKTurnBasedMatchmakerViewController, playerQuitFor match: GKTurnBasedMatch) {
        guard let localParticipant = match.participants.first(where: { $0.player == GKLocalPlayer.local }),
              let otherParticipant = match.participants.first(where: {$0 != localParticipant}) else {
            return
        }
        localParticipant.matchOutcome = .quit
        otherParticipant.matchOutcome = .won
        
        match.endMatchInTurn(withMatch: match.matchData ?? Data()) { error in
            if let error = error {
                print("An error occurred ending match: \(error.localizedDescription)")
            }
        }
    }
    
    func turnBasedMatchmakerViewController(_ viewController: GKTurnBasedMatchmakerViewController, didFailWithError error: Error) {
        print("Turn Based Matchmaker Failed with Error: \(error.localizedDescription)")
    }
    
}
