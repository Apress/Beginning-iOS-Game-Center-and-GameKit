//  UFOGameViewController.swift
//  GameCenter
//
//  Created by Kyle Richter on 11/14/10.
//  Copyright 2010 Dragon Forged Software. All rights reserved.
//

import AudioToolbox
import AVFoundation
import CoreMotion
import QuartzCore
import GameKit
import UIKit

class UFOGameViewController: UIViewController {
    var motionManager: CMMotionManager?
    var accelerationX = 0.0
    var accelerationY = 0.0
    var accel = [Double](repeating: 0.0, count: 3)
    var tractorBeamOn = false
    @IBOutlet var scoreLabel: UILabel!
    @IBOutlet var enemeyScoreLabel: UILabel!
    @IBOutlet var micButton: UIButton!
    var myPlayerImageView: UIImageView?
    var currentAbductee: UIImageView?
    var tractorBeamImageView: UIImageView?
    var otherPlayerImageView: UIImageView?
    var otherPlayerTractorBeamImageView: UIImageView?
    var otherPlayerCurrentAbductee: UIImageView?
    var cowArray: [AnyHashable]?
    var movementSpeed = 0.0
    var accelerometerDamp = 0.0
    var accelerometer0Angle = 0.0
    var score: Int = 0
    @IBOutlet var achievementCompletionView: UIView!
    @IBOutlet var achievementcompletionLabel: UILabel!
    var timer: Timer?
    var isHost = false
    var randomHostNumber = 0.0
    var mainChannel: GKVoiceChat?
    var micOn = false
    var purchasedUpgrade = false
    
    var gcManager: GameCenterManager?
    var gameIsMultiplayer = false
    var peerMatch: GKMatch?
    
    // MARK :- Init and Teardown
    init() {
        super.init(nibName: nil, bundle: nil)
        
        motionManager = CMMotionManager()
        if motionManager?.isAccelerometerAvailable ?? false {
            // Accelerometer is available. Configure to get acceleration
            motionManager?.accelerometerUpdateInterval = 0.05
            if let current = OperationQueue.current {
                motionManager?.startAccelerometerUpdates(to: current, withHandler: { [self] accelerometerData, error in
                    accel[0] = (accelerometerData?.acceleration.x ?? 0.0) * accelerometerDamp + accel[0] * (1.0 - accelerometerDamp)
                    accel[1] = (accelerometerData?.acceleration.y ?? 0.0) * accelerometerDamp + accel[1] * (1.0 - accelerometerDamp)
                    accel[2] = (accelerometerData?.acceleration.z ?? 0.0) * accelerometerDamp + accel[2] * (1.0 - accelerometerDamp)
                    
                    if !tractorBeamOn {
                        movePlayer(accel[0], accel[1])
                    }
                })
            }
        }
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        gcManager?.gameDelegate = self
        
        purchasedUpgrade = UserDefaults.standard.bool(forKey: "shipPlusAvailable")
        
        
        super.viewDidLoad()
        
        accelerometerDamp = 0.3
        accelerometer0Angle = 0.6
        movementSpeed = 15
        isHost = true //set to yes for single player logic
        
        let playerFrame = CGRect(x: 100, y: 70, width: 80, height: 34)
        myPlayerImageView = UIImageView(frame: playerFrame)
        myPlayerImageView?.animationDuration = 0.75
        myPlayerImageView?.animationRepeatCount = 99999
        var imageArray: [UIImage]
        
        if purchasedUpgrade {
            imageArray = [UIImage(named: "Ship1.png"), UIImage(named: "Ship2.png")].compactMap { $0 }
        } else {
            imageArray = [UIImage(named: "Saucer1.png"), UIImage(named: "Saucer2.png")].compactMap { $0 }
        }
        
        myPlayerImageView?.animationImages = imageArray
        myPlayerImageView?.startAnimating()
        if let myPlayerImageView = myPlayerImageView {
            view.addSubview(myPlayerImageView)
        }
        
        
        if gameIsMultiplayer {
            let otherPlayerFrame = CGRect(x: 100, y: 70, width: 80, height: 34)
            otherPlayerImageView = UIImageView(frame: otherPlayerFrame)
            otherPlayerImageView?.animationDuration = 0.75
            otherPlayerImageView?.animationRepeatCount = 99999
            let imageArray = [UIImage(named: "EnemySaucer1.png"), UIImage(named: "EnemySaucer2.png")]
            otherPlayerImageView?.animationImages = imageArray.compactMap { $0 }
            otherPlayerImageView?.startAnimating()
            if let otherPlayerImageView = otherPlayerImageView {
                view.addSubview(otherPlayerImageView)
            }
        }
        
        cowArray = []
        tractorBeamImageView = UIImageView(frame: CGRect.zero)
        otherPlayerTractorBeamImageView = UIImageView(frame: CGRect.zero)
        
        score = 0
        scoreLabel.text = "SCORE \(score)"
        
        if gameIsMultiplayer == false {
            for _ in 0..<5 {
                spawnCow()
            }
            
            updateCowPaths()
        } else {
            
            generateAndSendHostNumber()
            
            var error: Error? = nil
            
            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setCategory(.playAndRecord)
            } catch (let err){
                error = err
            }
            
            do {
                try audioSession.setActive(true)
            } catch (let err) {
                error = err
            }
            
            if let error = error {
                print("An error occurred while starting audio session: \(error.localizedDescription)")
            }
            
            setupVoiceChat()
        }
    }
    
    func setupVoiceChat() {
        mainChannel = peerMatch?.voiceChat(withName: "main")
        mainChannel?.start()
        mainChannel?.volume = 1.0
        mainChannel?.isActive = false
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        timer = Timer.scheduledTimer(
            withTimeInterval: 3.0,
            repeats: true,
            block: { [weak self] timer in
                self?.tickThreeSeconds()
            }
        )
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        timer?.invalidate()
        timer = nil
    }
    
    func generateAndSendHostNumber() {
        randomHostNumber = Double(arc4random())
        let randomNumberString = "$Host:\(randomHostNumber)"
        
        gcManager?.sendStringToAllPeers(randomNumberString, reliable: true)
    }
    
    func receivedData(_ dataDictionary: [AnyHashable : Any]?) {
        
        guard let dataDictionary = dataDictionary as? [String: String] else { return }
        
        if dataDictionary["data"]?.hasPrefix("$Host:") ?? false {
            determineHost(dataDictionary)
        } else if dataDictionary["data"]?.hasPrefix("$PlayerPosition:") ?? false {
            drawEnemyShip(withData: dataDictionary)
        } else if dataDictionary["data"]?.hasPrefix("$spawnCow:") ?? false {
            
            let x = Int(dataDictionary["data"]?.replacingOccurrences(of: "$spawnCow:", with: "") ?? "") ?? 0
            
            spawnCow(fromNetwork: x)
        } else if dataDictionary["data"]?.hasPrefix("$cowMove:") ?? false {
            
            updateCowPaths(fromNetwork: dataDictionary)
        } else if dataDictionary["data"]?.hasPrefix("$score:") ?? false {
            
            let enemyScore = Float(dataDictionary["data"]?.replacingOccurrences(of: "$score:", with: "") ?? "") ?? 0.0
            
            enemeyScoreLabel.text = String(format: "ENEMY %05.0f", enemyScore)
        } else if dataDictionary["data"]?.hasPrefix("$beginTractorBeam") ?? false {
            
            beginTractorFromNetwork()
        } else if dataDictionary["data"]?.hasPrefix("$endTractorBeam") ?? false {
            
            endTractorFromNetwork()
        } else if dataDictionary["data"]?.hasPrefix("$abductCowAtIndex:") ?? false {
            
            let index = Int(dataDictionary["data"]?.replacingOccurrences(of: "$abductCowAtIndex:", with: "") ?? "") ?? 0
            
            
            abductCowFromNetwork(at: index)
        } else {
            print("Unable to determine type of message: \(dataDictionary)")
        }
    }
    
    func determineHost(_ dataDictionary: [String : String]?) {
        let dataString = dataDictionary?["data"]?.replacingOccurrences(of: "$Host:", with: "")
        
        if Double(dataString ?? "") ?? 0.0 == randomHostNumber {
            print("Host numbers are equal, we need to reroll them")
            generateAndSendHostNumber()
        } else if Double(dataString ?? "") ?? 0.0 > randomHostNumber {
            isHost = true
            
            for _ in 0..<5 {
                spawnCow()
            }
            
            updateCowPaths()
        } else if Double(dataString ?? "") ?? 0.0 < randomHostNumber {
            isHost = false
        }
    }
    
    func tickThreeSeconds() {
        if gcManager?.achievement(withIdentifierIsComplete: "com.dragonforged.ufo.play5") == true {
            return
        } else {
            var percentComplete = gcManager?.percentageCompleteOfAchievement(withIdentifier: "com.dragonforged.ufo.play5") ?? 0.0
            percentComplete += 1
            gcManager?.submitAchievement("com.dragonforged.ufo.play5", percentComplete: percentComplete)
        }
    }
    
    override var shouldAutorotate: Bool {
        //only allow landscape orientations
        if traitCollection.verticalSizeClass == .compact {
            return true
        }
        
        return false
    }
    
    // MARK :- Input and Actions
    
    @IBAction func startVoice(_ sender: Any) {
        micOn = !micOn
        
        if micOn {
            micButton.setTitle("Mic On", for: .normal)
            
            mainChannel?.isActive = true
        } else {
            micButton.setTitle("Mic Off", for: .normal)
            
            mainChannel?.isActive = false
        }
    }
    
    func movePlayer(_ vertical: Double, _ horizontal: Double) {
        var vertical = vertical
        var horizontal = horizontal
        vertical += accelerometer0Angle
        
        if vertical > 0.50 {
            vertical = 0.50
        } else if vertical < -0.50 {
            vertical = -0.50
        }
        
        if horizontal > 0.50 {
            horizontal = 0.50
        } else if horizontal < -0.50 {
            horizontal = -0.50
        }
        
        var playerFrame = myPlayerImageView?.frame
        
        if (vertical < 0 && (playerFrame?.origin.y ?? 0.0) < 120) || (vertical > 0 && (playerFrame?.origin.y ?? 0.0) > 20) {
            playerFrame?.origin.y -= CGFloat(vertical * movementSpeed)
        }
        
        if (horizontal < 0 && (playerFrame?.origin.x ?? 0.0) < 440) || (horizontal > 0 && (playerFrame?.origin.x ?? 0.0) > 0) {
            playerFrame?.origin.x -= CGFloat(horizontal * movementSpeed)
        }
        
        
        myPlayerImageView?.frame = playerFrame ?? CGRect.zero
        
        if gameIsMultiplayer {
            let positionString = "$PlayerPosition: \(playerFrame?.origin.x ?? 0.0) \(playerFrame?.origin.y ?? 0.0)"
            
            gcManager?.sendStringToAllPeers(positionString, reliable: false)
        }
    }
    
    func drawEnemyShip(withData dataDictionary: [String : String]?) {
        let dataArray = dataDictionary?["data"]?.components(separatedBy: " ")
        
        let x = Double(dataArray?[1] ?? "") ?? 0.0
        let y = Double(dataArray?[2] ?? "") ?? 0.0
        
        otherPlayerImageView?.frame = CGRect(x: CGFloat(x), y: CGFloat(y), width: 80, height: 34)
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        currentAbductee = nil
        
        tractorBeamOn = true
        
        if gameIsMultiplayer {
            gcManager?.sendStringToAllPeers("$beginTractorBeam", reliable: true)
        }
        
        tractorBeamImageView?.frame = CGRect(x: (myPlayerImageView?.frame.origin.x ?? 0.0) + 25, y: (myPlayerImageView?.frame.origin.y ?? 0.0) + 10, width: 28, height: 318)
        tractorBeamImageView?.animationDuration = 0.5
        tractorBeamImageView?.animationRepeatCount = 99999
        let imageArray = [UIImage(named: "Tractor1.png"), UIImage(named: "Tractor2.png")]
        
        tractorBeamImageView?.animationImages = imageArray.compactMap { $0 }
        tractorBeamImageView?.startAnimating()
        
        if let tractorBeamImageView = tractorBeamImageView {
            view.insertSubview(tractorBeamImageView, at: 4)
        }
        
        let cowImageView = hitTest()
        
        if let cowImageView = cowImageView {
            currentAbductee = cowImageView
            abductCow(cowImageView)
        }
        
    }
    
    func beginTractorFromNetwork() {
        otherPlayerTractorBeamImageView?.frame = CGRect(x: (otherPlayerImageView?.frame.origin.x ?? 0.0) + 25, y: (otherPlayerImageView?.frame.origin.y ?? 0.0) + 10, width: 28, height: 318)
        otherPlayerTractorBeamImageView?.animationDuration = 0.5
        otherPlayerTractorBeamImageView?.animationRepeatCount = 99999
        let imageArray = [UIImage(named: "Tractor1.png"), UIImage(named: "Tractor2.png")]
        
        otherPlayerTractorBeamImageView?.animationImages = imageArray.compactMap { $0 }
        otherPlayerTractorBeamImageView?.startAnimating()
        
        if let otherPlayerTractorBeamImageView = otherPlayerTractorBeamImageView {
            view.insertSubview(otherPlayerTractorBeamImageView, at: 4)
        }
    }
    
    func endTractorFromNetwork() {
        otherPlayerTractorBeamImageView?.removeFromSuperview()
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        tractorBeamOn = false
        
        if gameIsMultiplayer {
            gcManager?.sendStringToAllPeers("$endTractorBeam", reliable: true)
        }
        
        tractorBeamImageView?.removeFromSuperview()
        
        if let currentAbductee = currentAbductee {
            UIView.animate(
                withDuration: 1.0,
                delay: 0,
                options: [.curveEaseIn, .beginFromCurrentState],
                animations: {
                    var frame = currentAbductee.frame
                    
                    frame.origin.y = 260
                    frame.origin.x = (self.myPlayerImageView?.frame.origin.x ?? 0.0) + 15
                    
                    currentAbductee.frame = frame
                }
            )
        }
        
        currentAbductee = nil
    }
    
    @IBAction func exitAction(_ sender: Any) {
        navigationController?.popViewController(animated: true)
        gcManager?.reportScore(score, forCategory: "com.dragonforged.ufo.single")
    }
    
    // MARK :- Gameplay
    
    func spawnCow() {
        let x = Int(arc4random() % 480)
        
        let cowImageView = UIImageView(frame: CGRect(x: CGFloat(x), y: 260, width: 64, height: 42))
        cowImageView.image = UIImage(named: "Cow1.png")
        view.addSubview(cowImageView)
        cowArray?.append(cowImageView)
        
        if isHost && gameIsMultiplayer {
            gcManager?.sendStringToAllPeers(String(format: "$spawnCow:%i", x), reliable: true)
        }
    }
    
    func spawnCow(fromNetwork x: Int) {
        let cowImageView = UIImageView(frame: CGRect(x: CGFloat(x), y: 260, width: 64, height: 42))
        cowImageView.image = UIImage(named: "Cow1.png")
        view.addSubview(cowImageView)
        cowArray?.append(cowImageView)
    }
    
    func updateCowPaths() {
        for x in 0..<(cowArray?.count ?? 0) {
            let tempCow = cowArray?[x] as? UIImageView
            
            if tempCow != currentAbductee && tempCow != otherPlayerCurrentAbductee {
                let currentX = tempCow?.frame.origin.x ?? 0.0
                var newX = currentX + Double(arc4random() % 100) - 50
                
                if newX > 480 {
                    newX = 480
                }
                if newX < 0 {
                    newX = 0
                }
                
                if tempCow != currentAbductee {
                    UIView.animate(
                        withDuration: 3.0,
                        delay: 0,
                        options: [.curveLinear],
                        animations: {
                            tempCow?.frame = CGRect(x: CGFloat(newX), y: 260, width: 64, height: 42)
                        }
                    )
                }
                
                tempCow?.animationDuration = 0.75
                tempCow?.animationRepeatCount = 99999
                
                //flip cow
                if newX < currentX {
                    let flippedCowImageArray = [UIImage(named: "Cow1Reversed.png"), UIImage(named: "Cow2Reversed.png"), UIImage(named: "Cow3Reversed.png")]
                    tempCow?.animationImages = flippedCowImageArray.compactMap { $0 }
                } else {
                    let cowImageArray = [UIImage(named: "Cow1.png"), UIImage(named: "Cow2.png"), UIImage(named: "Cow3.png")]
                    tempCow?.animationImages = cowImageArray.compactMap { $0 }
                }
                
                tempCow?.startAnimating()
                
                if gameIsMultiplayer {
                    let dataString = String(format: "$cowMove:%i:%f", x, newX)
                    gcManager?.sendStringToAllPeers(dataString, reliable: true)
                }
            }
        }
        
        //change the paths for the cows every 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: {
            self.updateCowPaths()
        })
    }
    
    func updateCowPaths(fromNetwork dataDictionary: [String : String]?) {
        let dataArray = dataDictionary?["data"]?.components(separatedBy: ":")
        
        let placeInArray = Int(dataArray?[1] ?? "") ?? 0
        
        let tempCow = cowArray?[placeInArray] as? UIImageView
        
        let currentX = tempCow?.frame.origin.x ?? 0.0
        
        let newX = Double(Int(dataArray?[2] ?? "") ?? 0)
        
        if tempCow != currentAbductee {
            UIView.animate(
                withDuration: 3.0,
                delay: 0,
                options: [.curveLinear],
                animations: {
                    tempCow?.frame = CGRect(x: CGFloat(newX), y: 260, width: 64, height: 42)
                }
            )
        }
        
        tempCow?.animationDuration = 0.75
        tempCow?.animationRepeatCount = 99999
        
        //flip cow
        if newX < currentX {
            let flippedCowImageArray = [UIImage(named: "Cow1Reversed.png"), UIImage(named: "Cow2Reversed.png"), UIImage(named: "Cow3Reversed.png")]
            tempCow?.animationImages = flippedCowImageArray.compactMap { $0 }
        } else {
            let cowImageArray = [UIImage(named: "Cow1.png"), UIImage(named: "Cow2.png"), UIImage(named: "Cow3.png")]
            tempCow?.animationImages = cowImageArray.compactMap { $0 }
        }
        
        tempCow?.startAnimating()
    }
    
    func abductCow(_ cowImageView: UIImageView?) {
        UIView.animate(
            withDuration: 4.0,
            delay: 0,
            options: [.curveEaseIn, .beginFromCurrentState],
            animations: {
                var frame = cowImageView?.frame
                frame?.origin.y = self.myPlayerImageView?.frame.origin.y ?? 0.0
                cowImageView?.frame = frame ?? CGRect.zero
            },
            completion: finishAbducting
        )
    }
    
    func abductCowFromNetwork(at x: Int) {
        otherPlayerCurrentAbductee = cowArray?[x] as? UIImageView
        
        otherPlayerCurrentAbductee?.layer.removeAllAnimations()
        
        UIView.animate(
            withDuration: 4.0,
            delay: 0,
            options: [.curveEaseIn, .beginFromCurrentState],
            animations: {
                var frame = self.otherPlayerCurrentAbductee?.frame
                frame?.origin.y = self.otherPlayerImageView?.frame.origin.y ?? 0.0
                self.otherPlayerCurrentAbductee?.frame = frame ?? CGRect.zero
            },
            completion: finishAbductingFromNetwork
        )
    }
    
    func finishAbductingFromNetwork(_ finished: Bool) {
        cowArray = cowArray?.filter({ ($0) as AnyObject !== (otherPlayerCurrentAbductee) as AnyObject })
        endTractorFromNetwork()
        
        otherPlayerCurrentAbductee?.layer.removeAllAnimations()
        otherPlayerCurrentAbductee?.removeFromSuperview()
        
        otherPlayerCurrentAbductee = nil
        
        if isHost {
            spawnCow()
        }
    }
    
    func finishAbducting(_ finished: Bool) {
        if currentAbductee == nil || !tractorBeamOn {
            return
        }
        
        cowArray = cowArray?.filter({ ($0) as AnyObject !== (currentAbductee) as AnyObject })
        
        tractorBeamImageView?.removeFromSuperview()
        
        tractorBeamOn = false
        
        score += 1
        scoreLabel.text = String(format: "SCORE %05.0f", score)
        
        if gameIsMultiplayer {
            gcManager?.sendStringToAllPeers("$score:\(score)", reliable: true)
        }
        
        currentAbductee?.layer.removeAllAnimations()
        currentAbductee?.removeFromSuperview()
        
        currentAbductee = nil
        
        if isHost {
            spawnCow()
        }
        
        if (gcManager?.achievement(withIdentifierIsComplete: "com.dragonforged.ufo.aduct1") == false) {
            gcManager?.submitAchievement("com.dragonforged.ufo.aduct1", percentComplete: 100)
        }
        
        if (gcManager?.achievement(withIdentifierIsComplete: "com.dragonforged.ufo.abduct25") == false) {
            var percentComplete = gcManager?.percentageCompleteOfAchievement(withIdentifier: "com.dragonforged.ufo.abduct25") ?? 0.0
            percentComplete += 4
            gcManager?.submitAchievement("com.dragonforged.ufo.abduct25", percentComplete: percentComplete)
        }
    }
    
    func hitTest() -> UIImageView? {
        if !tractorBeamOn {
            return nil
        }
        
        for x in 0..<(cowArray?.count ?? 0) {
            let tempCow = cowArray?[x] as? UIImageView
            let cowLayer = tempCow?.layer.presentation()
            let cowFrame = cowLayer?.frame
            
            if cowFrame?.intersects(tractorBeamImageView?.frame ?? CGRect.zero) ?? false {
                tempCow?.frame = cowLayer?.frame ?? CGRect.zero
                tempCow?.layer.removeAllAnimations()
                
                if gameIsMultiplayer {
                    gcManager?.sendStringToAllPeers(String(format: "$abductCowAtIndex:%i", x), reliable: true)
                }
                
                return tempCow
            }
        }
        
        return nil
    }
}

extension UFOGameViewController: GameCenterManagerGameDelegate {
    // MARK: GameCenterManagerDelegate
    
    func scoreReported(_ error: Error?) {
        if let error = error {
            print("There was an error in reporting the score: \(error.localizedDescription)")
        } else {
            print("Score submitted")
        }
        
    }
    
    func achievementSubmitted(_ achievement: GKAchievement?, error: Error?) {
        if let error = error {
            print("There was an error in reporting the achievement: \(error.localizedDescription)")
        } else {
            print("achievement submitted")
        }
    }
    
    func achievementEarned(_ achievement: GKAchievementDescription?) {
        achievementCompletionView.frame = CGRect(x: 0, y: 320, width: 480, height: 25)
        view.addSubview(achievementCompletionView)
        achievementcompletionLabel.text = achievement?.achievedDescription
        
        UIView.animate(
            withDuration: 0.5,
            animations: {
                self.achievementCompletionView.frame = CGRect(x: 0, y: 295, width: 480, height: 25)
            },
            completion: achievementEarnedAnimationDone
        )
    }
    
    func achievementEarnedAnimationDone(_ finished: Bool) {
        UIView.animate(
            withDuration: 1.0,
            delay: 5.0,
            animations: {
                self.achievementCompletionView.frame = CGRect(x: 0, y: 320, width: 480, height: 25)
            }
        )
    }
}
