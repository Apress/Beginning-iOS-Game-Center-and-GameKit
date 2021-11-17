//
//  UFOLeaderboardViewController.m
//  UFOs
//
//  Created by Kyle Richter on 2/13/11.
//  Copyright 2011 Dragon Forged Software. All rights reserved.
//

import GameKit
import UIKit

class UFOLeaderboardViewController: UIViewController {
    
    @IBOutlet var leaderboardTableView: UITableView!
    @IBOutlet var scopeSegementedController: UISegmentedControl!
    var playerArray: [AnyHashable]?

    var gcManager: GameCenterManager?
    var scoreArray: [Any]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        segementedControllerDidChange(nil)
        gcManager?.leaderboardDelegate = self
        playerArray = [AnyHashable]()
    }

    @IBAction func dismiss() {
        self.dismiss(animated: true, completion: nil)
    }

    @IBAction func segementedControllerDidChange(_ sender: Any?) {
        var playerScope: GKLeaderboard.PlayerScope

        if scopeSegementedController.selectedSegmentIndex == 0 {
            playerScope = .friendsOnly
        } else {
            playerScope = .global
        }

        scoreArray = nil
        gcManager?.retrieveScores(forCategory: "com.dragonforged.ufo.single", playerScope: playerScope, timeScope: GKLeaderboard.TimeScope.allTime, range: NSRange(location: 1, length: 50))
        leaderboardTableView.reloadData()
    }

    deinit {
        scoreArray = nil
        gcManager = nil
    }
}

extension UFOLeaderboardViewController: GameCenterManagerLeaderboardDelegate {
    func leaderboardUpdated(_ scores: [GKLeaderboard.Entry]?, error: Error?) {
        if let error = error {
            print(String(format: "An error occurred: ", error.localizedDescription))
        } else {
            if let scores = scores {
                scoreArray = scores
            }
        }

        leaderboardTableView.reloadData()
    }
    
    func mappedPlayerID(to player: GKPlayer?, error: Error?) {
        if let error = error {
            print("Error during player mapping: \(error.localizedDescription)")
        } else {
            if let player = player {
                playerArray?.append(player)
            }
        }

        leaderboardTableView.reloadData()
    }
    
}

extension UFOLeaderboardViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return scoreArray?.count ?? 0
    }
    
    static let tableViewCellIdentifier = "Cell"
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        var cell = tableView.dequeueReusableCell(withIdentifier: UFOLeaderboardViewController.tableViewCellIdentifier)
        if cell == nil {
            cell = UITableViewCell(style: .subtitle, reuseIdentifier: UFOLeaderboardViewController.tableViewCellIdentifier)
            cell?.selectionStyle = .none
        }

        let score = scoreArray?[indexPath.row] as? GKLeaderboard.Entry

        let playerName = score?.player.alias

        if playerName == nil {
            cell?.textLabel?.text = "Loading Name..."
        } else {
            cell?.textLabel?.text = playerName
        }

        cell?.detailTextLabel?.text = score?.formattedScore

        return cell!
    }
}
