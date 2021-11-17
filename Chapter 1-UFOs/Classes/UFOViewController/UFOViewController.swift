//
//  UFOViewController.swift
//  GameCenter
//
//  Created by Kyle Richter on 11/14/10.
//  Copyright 2010 Dragon Forged Software. All rights reserved.
//

import GameKit
import UIKit

class UFOViewController: UIViewController, GKGameCenterControllerDelegate {
    
    @IBAction func playButtonPressed() {
        let gameViewController = UFOGameViewController()
        navigationController?.pushViewController(gameViewController, animated: true)
    }

    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        dismiss(animated: true, completion: nil)
    }
}
