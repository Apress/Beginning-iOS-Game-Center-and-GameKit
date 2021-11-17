//
//  GameCenterGameViewController.h
//  GameCenter
//
//  Created by Kyle Richter on 11/14/10.
//  Copyright 2010 Dragon Forged Software. All rights reserved.
//

//#import <UIKit/UIKit.h>
//#import <CoreMotion/CoreMotion.h>
//#import "GameCenterManager.h"
//
//
//@interface UFOGameViewController : UIViewController <UIAccelerometerDelegate, GameCenterManagerDelegate>
//{
//
//    CMMotionManager *motionManager;
//
//    float accelerationX;
//    float accelerationY;
//    UIAccelerationValue accel[3];
//
//    BOOL tractorBeamOn;
//
//    IBOutlet UILabel *scoreLabel;
//    IBOutlet UILabel *enemeyScoreLabel;
//    IBOutlet UIButton *micButton;
//
//    UIImageView *myPlayerImageView;
//    UIImageView *currentAbductee;
//    UIImageView *tractorBeamImageView;
//
//    UIImageView *otherPlayerImageView;
//    UIImageView *otherPlayerTractorBeamImageView;
//    UIImageView *otherPlayerCurrentAbductee;
//
//    NSMutableArray *cowArray;
//
//    float movementSpeed;
//    float accelerometerDamp;
//    float accelerometer0Angle;
//
//    float score;
//
//    GameCenterManager *gcManager;
//
//    IBOutlet UIView *achievementCompletionView;
//    IBOutlet UILabel *achievementcompletionLabel;
//
//    NSTimer *timer;
//
//    BOOL gameIsMultiplayer;
//    BOOL isHost;
//
//    NSString *peerIDString;
//    GKMatch *peerMatch;
//
//    double randomHostNumber;
//
//    GKVoiceChat *mainChannel;
//    BOOL micOn;
//
//    BOOL purchasedUpgrade;
//}
//
//@property(nonatomic, retain) GameCenterManager *gcManager;
//@property(nonatomic, assign) BOOL gameIsMultiplayer;
//
//@property(nonatomic, retain) NSString *peerIDString;
//@property(nonatomic, retain) GKMatch *peerMatch;
//
//
//
//-(IBAction)exitAction:(id)sender;
//-(IBAction)startVoice:(id)sender;
//
//-(void)spawnCow;
//-(void)updateCowPaths;
//-(void)abductCow:(UIImageView *)cowImageView;
//-(void)finishAbducting;
//-(void)movePlayer:(float)vertical :(float)horizontal;
//-(UIImageView *)hitTest;
//-(void)tickThreeSeconds;
//-(void)setupVoiceChat;
//
//-(void)determineHost:(NSDictionary *)dataDictionary;
//-(void)generateAndSendHostNumber;
//-(void)drawEnemyShipWithData:(NSDictionary *)dataDictionary;
//-(void)spawnCowFromNetwork:(int)x;
//-(void)updateCowPathsFromNetwork:(NSDictionary *)dataDictionary;
//-(void)beginTractorFromNetwork;
//-(void)endTractorFromNetwork;
//-(void)abductCowFromNetworkAtIndex:(int)x;
//-(void)finishAbductingFromNetwork;
//
//@end
