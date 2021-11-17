//  UFOGameViewController.swift
//  GameCenter
//
//  Created by Kyle Richter on 11/14/10.
//  Copyright 2010 Dragon Forged Software. All rights reserved.
//

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
    
    var gcManager: GameCenterManager?
    
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
        
        accelerometerDamp = 0.3
        accelerometer0Angle = 0.6
        movementSpeed = 15
        
        let playerFrame = CGRect(x: 100, y: 70, width: 80, height: 34)
        myPlayerImageView = UIImageView(frame: playerFrame)
        myPlayerImageView?.animationDuration = 0.75
        myPlayerImageView?.animationRepeatCount = 99999
        let imageArray = [UIImage(named: "Saucer1.png"), UIImage(named: "Saucer2.png")].compactMap { $0 }
        
        myPlayerImageView?.animationImages = imageArray
        myPlayerImageView?.startAnimating()
        if let myPlayerImageView = myPlayerImageView {
            view.addSubview(myPlayerImageView)
        }
        
        cowArray = []
        tractorBeamImageView = UIImageView(frame: CGRect.zero)
        otherPlayerTractorBeamImageView = UIImageView(frame: CGRect.zero)
        
        score = 0
        scoreLabel.text = "SCORE \(score)"
    }
    
    override var shouldAutorotate: Bool {
        //only allow landscape orientations
        if traitCollection.verticalSizeClass == .compact {
            return true
        }
        
        return false
    }
    
    // MARK :- Input and Actions
    
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
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        currentAbductee = nil
        
        tractorBeamOn = true
        
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
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        tractorBeamOn = false
        
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
    
    // MARK :- Gameplay
    
    func spawnCow() {
        let x = Int(arc4random() % 480)
        
        let cowImageView = UIImageView(frame: CGRect(x: CGFloat(x), y: 260, width: 64, height: 42))
        cowImageView.image = UIImage(named: "Cow1.png")
        view.addSubview(cowImageView)
        cowArray?.append(cowImageView)
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
            }
        }
        
        //change the paths for the cows every 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: {
            self.updateCowPaths()
        })
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
    
    func finishAbducting(_ finished: Bool) {
        if currentAbductee == nil || !tractorBeamOn {
            return
        }
        
        cowArray = cowArray?.filter({ ($0) as AnyObject !== (currentAbductee) as AnyObject })
        
        tractorBeamImageView?.removeFromSuperview()
        
        tractorBeamOn = false
        
        score += 1
        scoreLabel.text = String(format: "SCORE %05.0f", score)
        
        currentAbductee?.layer.removeAllAnimations()
        currentAbductee?.removeFromSuperview()
        
        currentAbductee = nil
        
        spawnCow()
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
                
                return tempCow
            }
        }
        
        return nil
    }
}
