//
//  UFOAchievementViewController.swift
//  UFOs
//
//  Created by Kyle Richter on 3/4/11.
//  Copyright 2011 Dragon Forged Software. All rights reserved.
//

import UIKit
import GameKit

class UFOAchievementViewController: UIViewController {
    
    @IBOutlet var achievementTableView: UITableView!

    var gcManager: GameCenterManager?
    var achievementArray: [GKAchievementDescription]?
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.gcManager?.achievementDelegate = self
        self.gcManager?.retrieveAchievmentMetadata()
    }

    @IBAction func dismissAction() {
        dismiss(animated: true, completion: nil)
    }
    
    deinit {
        achievementArray = nil
        gcManager = nil
    }
}

extension UFOAchievementViewController: GameCenterManagerAchievementDelegate {
    func achievementDescriptionsLoaded(_ descriptions: [GKAchievementDescription]?, error: Error?) {
        if error == nil {
            achievementArray = descriptions
        } else {
            print("An error occurred when retrieving the achievement descriptions: \(error?.localizedDescription ?? "")")
        }
        achievementTableView.reloadData()
    }
}

extension UFOAchievementViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        self.achievementArray?.count ?? 0
    }
    
    static let tableViewCellIdentifier = "Cell"

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell = tableView.dequeueReusableCell(withIdentifier: UFOAchievementViewController.tableViewCellIdentifier)
        if cell == nil {
            cell = UITableViewCell(style: .default, reuseIdentifier: UFOAchievementViewController.tableViewCellIdentifier)
            cell?.selectionStyle = .none
        }

        let achievementDescription = achievementArray?[indexPath.row]

        if let percentage = gcManager?.percentageCompleteOfAchievement(withIdentifier: achievementDescription?.identifier) {
            let percentageCompleteString = String(format: " %.1f%% Complete", percentage)
            cell?.textLabel?.text = (achievementDescription?.title ?? "") + percentageCompleteString
        }

        achievementDescription?.loadImage(completionHandler: { (image, error) in
            if image != nil {
                cell?.imageView?.image = image
            } else {
                cell?.imageView?.image = GKAchievementDescription.placeholderCompletedAchievementImage()
            }
        })

        return cell!
    }
}
