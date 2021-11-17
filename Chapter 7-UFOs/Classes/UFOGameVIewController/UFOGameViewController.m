//
//  GameCenterGameViewController.m
//  GameCenter
//
//  Created by Kyle Richter on 11/14/10.
//  Copyright 2010 Dragon Forged Software. All rights reserved.
//

#import "UFOGameViewController.h"
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVFoundation.h>
#import "UFOVoiceChatClient.h"
#import <AudioToolbox/AudioToolbox.h>
#import <CoreMotion/CoreMotion.h>

@implementation UFOGameViewController

@synthesize gcManager;
@synthesize gameIsMultiplayer;

@synthesize peerIDString, peerMatch;

#pragma mark Init and Teardown
#pragma mark -

- init
{
    if (self != [super init])
        return nil;
    
    //    [[UIAccelerometer sharedAccelerometer] setUpdateInterval:0.05];
    //    [[UIAccelerometer sharedAccelerometer] setDelegate:self];
    
    motionManager = [[CMMotionManager alloc] init];
    if ([motionManager isAccelerometerAvailable]) {
        // Accelerometer is available. Configure to get acceleration
        [motionManager setAccelerometerUpdateInterval:0.05];
        [motionManager startAccelerometerUpdatesToQueue:[NSOperationQueue currentQueue] withHandler:^(CMAccelerometerData *accelerometerData, NSError *error) {
            accel[0] = accelerometerData.acceleration.x * accelerometerDamp + accel[0] * (1.0 - accelerometerDamp);
            accel[1] = accelerometerData.acceleration.y * accelerometerDamp + accel[1] * (1.0 - accelerometerDamp);
            accel[2] = accelerometerData.acceleration.z * accelerometerDamp + accel[2] * (1.0 - accelerometerDamp);
            
            if(!tractorBeamOn)
                [self movePlayer:accel[0] :accel[1]];
        }];
    }
    
    return self;
}



-(void)viewDidLoad
{
    [self.gcManager setDelegate: self];
    
    purchasedUpgrade = [[NSUserDefaults standardUserDefaults] boolForKey:@"shipPlusAvailable"];
    
        
      [super viewDidLoad];
    
    accelerometerDamp = 0.3f;
    accelerometer0Angle = 0.6f;
    movementSpeed = 15;
    isHost = YES; //set to yes for single player logic
    
    CGRect playerFrame = CGRectMake(100, 70, 80, 34);
    myPlayerImageView = [[UIImageView alloc] initWithFrame: playerFrame];
    myPlayerImageView.animationDuration = 0.75;
    myPlayerImageView.animationRepeatCount = 99999;
    NSArray *imageArray;
    
    if(purchasedUpgrade)
        imageArray = [NSArray arrayWithObjects: [UIImage imageNamed: @"Ship1.png"], [UIImage imageNamed: @"Ship2.png"], nil];
    else
        imageArray = [NSArray arrayWithObjects: [UIImage imageNamed: @"Saucer1.png"], [UIImage imageNamed: @"Saucer2.png"], nil];

    
    myPlayerImageView.animationImages = imageArray;
    [myPlayerImageView startAnimating];
    [self.view addSubview: myPlayerImageView];
    
    
    if(self.gameIsMultiplayer)
    {
        CGRect otherPlayerFrame = CGRectMake(100, 70, 80, 34);
        otherPlayerImageView = [[UIImageView alloc] initWithFrame: otherPlayerFrame];
        otherPlayerImageView.animationDuration = 0.75;
        otherPlayerImageView.animationRepeatCount = 99999;
        NSArray *imageArray = [NSArray arrayWithObjects: [UIImage imageNamed: @"EnemySaucer1.png"], [UIImage imageNamed: @"EnemySaucer2.png"], nil];
        otherPlayerImageView.animationImages = imageArray;
        [otherPlayerImageView startAnimating];
        [self.view addSubview: otherPlayerImageView];
    }
    
    cowArray = [[NSMutableArray alloc] init];
    tractorBeamImageView = [[UIImageView alloc] initWithFrame: CGRectZero];
    otherPlayerTractorBeamImageView = [[UIImageView alloc] initWithFrame: CGRectZero];

    score = 0;
    scoreLabel.text = [NSString stringWithFormat: @"SCORE %05.0f", score];
    
    
    if(self.gameIsMultiplayer == NO)
    {
        for(int x = 0; x < 5; x++)
        {
            [self spawnCow];
        }
        
        [self updateCowPaths];
    }
    
    else
    {
        
        [self generateAndSendHostNumber];

        NSError *error = nil;
        
        [[AVAudioSession sharedInstance] setActive:YES error:Nil];
//        AudioSessionInitialize(NULL, NULL, NULL, self)

        AVAudioSession *audioSession = [AVAudioSession sharedInstance];
        [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:&error];
        [audioSession setActive: YES error: &error];
        
        
        if(error)
        {
            NSLog(@"An error occurred while starting audio session: %@", [error localizedDescription]);
        }
        
        [self setupVoiceChat];
    }
}



//MARK: NEEDS REIMPLEMENTATION https://developer.apple.com/documentation/gamekit/gkvoicechat?language=objc
-(void)setupVoiceChat
{
    //GameKit
    if(self.peerIDString)
    {
        NSError *error = nil;
        
        UFOVoiceChatClient *voiceChatClient = [[UFOVoiceChatClient alloc] init];
        voiceChatClient.session = self.gcManager.matchOrSession;
//        [GKVoiceChatService defaultVoiceChatService].client = voiceChatClient;
//        [[GKVoiceChatService defaultVoiceChatService] startVoiceChatWithParticipantID:self.peerIDString error:&error];
//        [GKVoiceChatService defaultVoiceChatService].microphoneMuted = YES;

        if(error)
        {
            NSLog(@"An error occurred when setting up voice chat: %@", [error localizedDescription]);
            
        }
    }
    
    //Game Center
    else
    {
        mainChannel = [[self.peerMatch voiceChatWithName:@"main"] retain];
        [mainChannel start];
        mainChannel.volume = 1.0;
        mainChannel.active = NO;
    }
}


-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear: animated];
    
    timer = [NSTimer scheduledTimerWithTimeInterval:3.0
                                             target:self
                                           selector:@selector(tickThreeSeconds)
                                           userInfo:nil
                                            repeats:YES];
}


-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear: animated];
    
    [timer invalidate];
    timer = nil;
}


-(void)generateAndSendHostNumber;
{
    randomHostNumber = arc4random();
    NSString *randomNumberString = [NSString stringWithFormat: @"$Host:%f", randomHostNumber];
   
    [self.gcManager sendStringToAllPeers:randomNumberString reliable: YES];
}


- (void)receivedData:(NSDictionary *)dataDictionary;
{
        
    if([[dataDictionary objectForKey: @"data"] hasPrefix:@"$Host:"])
    {
        [self determineHost: dataDictionary];
    }
    
    else if([[dataDictionary objectForKey: @"data"] hasPrefix:@"$PlayerPosition:"])
    {
        [self drawEnemyShipWithData: dataDictionary];
    }
    
    else if([[dataDictionary objectForKey: @"data"] hasPrefix:@"$spawnCow:"])
    {
        
        int x = [[[dataDictionary objectForKey: @"data"] stringByReplacingOccurrencesOfString:@"$spawnCow:" withString:@""] intValue];
        
        [self spawnCowFromNetwork: x];
    }

    else if([[dataDictionary objectForKey: @"data"] hasPrefix:@"$cowMove:"])
    {
        
        [self updateCowPathsFromNetwork: dataDictionary];
    }
    
    else if([[dataDictionary objectForKey: @"data"] hasPrefix:@"$score:"])
    {

        float enemyScore = [[[dataDictionary objectForKey: @"data"] stringByReplacingOccurrencesOfString:@"$score:" withString:@""] floatValue];
        
        enemeyScoreLabel.text = [NSString stringWithFormat: @"ENEMY %05.0f", enemyScore];

    }
    
    else if([[dataDictionary objectForKey: @"data"] hasPrefix:@"$beginTractorBeam"])
    {
        
        [self beginTractorFromNetwork];
    }
    
    else if([[dataDictionary objectForKey: @"data"] hasPrefix:@"$endTractorBeam"])
    {
        
        [self endTractorFromNetwork];
    }
    
    else if([[dataDictionary objectForKey: @"data"] hasPrefix:@"$abductCowAtIndex:"])
    {
        
        int index = [[[dataDictionary objectForKey: @"data"] stringByReplacingOccurrencesOfString:@"$abductCowAtIndex:" withString:@""] intValue];

        
        [self abductCowFromNetworkAtIndex:index];
    }
 
               
    else
    {
        NSLog(@"Unable to determine type of message: %@", dataDictionary);
    }
}

-(void)determineHost:(NSDictionary *)dataDictionary
{
    NSString *dataString = [[dataDictionary objectForKey: @"data"] stringByReplacingOccurrencesOfString:@"$Host:" withString:@""];
    
    if([dataString doubleValue] == randomHostNumber)
    {
        NSLog(@"Host numbers are equal, we need to reroll them");
        [self generateAndSendHostNumber];
    }
    
    else if([dataString doubleValue] > randomHostNumber)
    {
        isHost = YES;
        
        for(int x = 0; x < 5; x++)
        {
            [self spawnCow];
        }
        
        [self updateCowPaths];
    }
    
    else if([dataString doubleValue] < randomHostNumber)
    {
        isHost = NO;
    }
}
     
-(void)tickThreeSeconds
{
    if([self.gcManager achievementWithIdentifierIsComplete: @"com.dragonforged.ufo.play5"])
        return;
    else
    {
//        double percentComplete = [self.gcManager percentageCompleteOfAchievementWithIdentifier:@"com.dragonforged.ufo.play5"];
//        percentComplete++;
//        [self.gcManager submitAchievement:@"com.dragonforged.ufo.play5" percentComplete:percentComplete];
    }
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    //only allow landscape orientations
    if(UIInterfaceOrientationIsLandscape(interfaceOrientation))
        return YES;
    
    return NO;
}




- (void)dealloc
{
    [gcManager release]; gcManager = nil;
    [cowArray release];
    [super dealloc];
}

#pragma mark Input and Actions
#pragma mark -

//MARK: NEEDS REIMPLEMENTATION https://developer.apple.com/documentation/gamekit/gkvoicechat?language=objc
-(IBAction)startVoice:(id)sender;
{
    micOn = !micOn;
    
    if(micOn)
    {
        [micButton setTitle:@"Mic On" forState:UIControlStateNormal];
        
        //GameKit
        if(self.peerIDString)
        {
//            [GKVoiceChatService defaultVoiceChatService].microphoneMuted = NO;
        }
        
        //Game Center
        else
        {
            mainChannel.active = YES;
        }
    }
    
    else
    {
        [micButton setTitle:@"Mic Off" forState:UIControlStateNormal];
        
        //GameKit
        if(self.peerIDString)
        {
//            [GKVoiceChatService defaultVoiceChatService].microphoneMuted = YES;
        }
        
        //Game Center
        else
        {
            mainChannel.active = NO;
        }
    }
}

-(void) movePlayer:(float)vertical :(float)horizontal;
{
    vertical += accelerometer0Angle;
    
    if(vertical > .50)
        vertical = .50;
    else if (vertical < -.50)
        vertical = -.50;
    
    if(horizontal > .50)
        horizontal = .50;
    else if (horizontal < -.50)
        horizontal = -.50;
    
    CGRect playerFrame = myPlayerImageView.frame;
    
    if ((vertical < 0 && playerFrame.origin.y < 120) || (vertical > 0 && playerFrame.origin.y > 20))
        playerFrame.origin.y -= vertical*movementSpeed;
    
    if ((horizontal < 0 && playerFrame.origin.x < 440) || (horizontal > 0 && playerFrame.origin.x > 0))
        playerFrame.origin.x -= horizontal*movementSpeed;

        
    myPlayerImageView.frame = playerFrame;
    
    if(self.gameIsMultiplayer)
    {
        NSString *positionString = [NSString stringWithFormat: @"$PlayerPosition: %f %f", playerFrame.origin.x, playerFrame.origin.y];
        
        [self.gcManager sendStringToAllPeers:positionString reliable: NO];
    }
}

-(void)drawEnemyShipWithData:(NSDictionary *)dataDictionary
{
    NSArray *dataArray = [[dataDictionary objectForKey: @"data"] componentsSeparatedByString:@" "];
            
    float x = [[dataArray objectAtIndex: 1] floatValue];
    float y = [[dataArray objectAtIndex: 2] floatValue];

    otherPlayerImageView.frame = CGRectMake(x, y, 80, 34);
}


- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
{
    currentAbductee = nil;
    
    tractorBeamOn = YES;
    
    if(self.gameIsMultiplayer)
    {
        [gcManager sendStringToAllPeers:@"$beginTractorBeam" reliable:YES];
    }
    
    tractorBeamImageView.frame = CGRectMake(myPlayerImageView.frame.origin.x+25, myPlayerImageView.frame.origin.y+10, 28, 318);
    tractorBeamImageView.animationDuration = 0.5;
    tractorBeamImageView.animationRepeatCount = 99999;
    NSArray *imageArray = [NSArray arrayWithObjects: [UIImage imageNamed: @"Tractor1.png"], [UIImage imageNamed: @"Tractor2.png"], nil];
    
    tractorBeamImageView.animationImages = imageArray;
    [tractorBeamImageView startAnimating];
    
    [self.view insertSubview:tractorBeamImageView atIndex:4];
    
    UIImageView *cowImageView = [self hitTest];
    
    if(cowImageView)
    {
        currentAbductee = cowImageView;
        [self abductCow: cowImageView];
    }
    
}

-(void)beginTractorFromNetwork
{
    otherPlayerTractorBeamImageView.frame = CGRectMake(otherPlayerImageView.frame.origin.x+25, otherPlayerImageView.frame.origin.y+10, 28, 318);
    otherPlayerTractorBeamImageView.animationDuration = 0.5;
    otherPlayerTractorBeamImageView.animationRepeatCount = 99999;
    NSArray *imageArray = [NSArray arrayWithObjects: [UIImage imageNamed: @"Tractor1.png"], [UIImage imageNamed: @"Tractor2.png"], nil];
    
    otherPlayerTractorBeamImageView.animationImages = imageArray;
    [otherPlayerTractorBeamImageView startAnimating];
    
    [self.view insertSubview:otherPlayerTractorBeamImageView atIndex:4];
}

-(void)endTractorFromNetwork
{
    [otherPlayerTractorBeamImageView removeFromSuperview];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    tractorBeamOn = NO;
    
    if(self.gameIsMultiplayer)
    {
        [gcManager sendStringToAllPeers:@"$endTractorBeam" reliable:YES];
    }
    
    [tractorBeamImageView removeFromSuperview];
    
    if(currentAbductee)
    {
        [UIView beginAnimations: @"dropCow" context:nil];
        [UIView setAnimationDuration: 1.0];
        [UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
        [UIView setAnimationBeginsFromCurrentState: YES];
        
        CGRect frame = currentAbductee.frame;
        
        frame.origin.y = 260;
        frame.origin.x = myPlayerImageView.frame.origin.x +15;
        
        currentAbductee.frame = frame;
        
        [UIView commitAnimations];
    }
    
    currentAbductee = nil;
}

-(IBAction)exitAction:(id)sender;
{
    [[self navigationController] popViewControllerAnimated: YES];
    [self.gcManager reportScore:score forCategory:@"com.dragonforged.ufo.single"];
}

#pragma mark Gameplay
#pragma mark -


-(void)spawnCow;
{
    int x = arc4random()%480;
    
    UIImageView *cowImageView = [[UIImageView alloc] initWithFrame:CGRectMake(x, 260, 64, 42)];
    cowImageView.image = [UIImage imageNamed: @"Cow1.png"];
    [self.view addSubview: cowImageView];
    [cowArray addObject: cowImageView];
    [cowImageView release];
    
    if(isHost && self.gameIsMultiplayer)
    {
        [gcManager sendStringToAllPeers:[NSString stringWithFormat:@"$spawnCow:%i", x] reliable:YES];
    }
}

-(void)spawnCowFromNetwork:(int)x
{
    UIImageView *cowImageView = [[UIImageView alloc] initWithFrame:CGRectMake(x, 260, 64, 42)];
    cowImageView.image = [UIImage imageNamed: @"Cow1.png"];
    [self.view addSubview: cowImageView];
    [cowArray addObject: cowImageView];
    [cowImageView release];
}

-(void)updateCowPaths
{
    for(int x = 0; x < [cowArray count]; x++)
    {
        UIImageView *tempCow = [cowArray objectAtIndex: x];
        
        if(tempCow != currentAbductee && tempCow != otherPlayerCurrentAbductee)
        {
            [UIView beginAnimations:@"cowWalk" context:nil];
            [UIView setAnimationDuration: 3.0];
            [UIView setAnimationCurve:UIViewAnimationCurveLinear];
            
            float currentX = tempCow.frame.origin.x;
            float newX = currentX + arc4random()%100-50;
            
            if(newX > 480)
                newX = 480;
            if(newX < 0)
                newX = 0;
            
            if(tempCow != currentAbductee)
                tempCow.frame = CGRectMake(newX, 260, 64, 42);
            
            [UIView commitAnimations];
            
            tempCow.animationDuration = 0.75;
            tempCow.animationRepeatCount = 99999;

            //flip cow
            if(newX < currentX)
            {
                NSArray *flippedCowImageArray = [NSArray arrayWithObjects: [UIImage imageNamed: @"Cow1Reversed.png"], [UIImage imageNamed: @"Cow2Reversed.png"], [UIImage imageNamed: @"Cow3Reversed.png"], nil];
                tempCow.animationImages = flippedCowImageArray;
            }
            else
            {
                NSArray *cowImageArray = [NSArray arrayWithObjects: [UIImage imageNamed: @"Cow1.png"], [UIImage imageNamed: @"Cow2.png"], [UIImage imageNamed: @"Cow3.png"], nil];
                tempCow.animationImages = cowImageArray;
            }
            
            [tempCow startAnimating];
            
            if(self.gameIsMultiplayer)
            {
                NSString *dataString = [NSString stringWithFormat:@"$cowMove:%i:%f", x, newX];
                [gcManager sendStringToAllPeers:dataString reliable:YES];
            }
        }
    }
    
    
    //change the paths for the cows every 3 seconds
    [self performSelector:@selector(updateCowPaths) withObject:nil afterDelay:3.0];
}

-(void)updateCowPathsFromNetwork:(NSDictionary *)dataDictionary;
{
    NSArray *dataArray = [[dataDictionary objectForKey: @"data"] componentsSeparatedByString:@":"];
        
    int placeInArray = [[dataArray objectAtIndex: 1] intValue];
    
    UIImageView *tempCow = [cowArray objectAtIndex: placeInArray];

    float currentX = tempCow.frame.origin.x;

    [UIView beginAnimations:@"cowWalk" context:nil];
    [UIView setAnimationDuration: 3.0];
    [UIView setAnimationCurve:UIViewAnimationCurveLinear];
    
    float newX = [[dataArray objectAtIndex: 2] intValue];
    
    if(tempCow != currentAbductee)
        tempCow.frame = CGRectMake(newX, 260, 64, 42);
    
    [UIView commitAnimations];
    
    tempCow.animationDuration = 0.75;
    tempCow.animationRepeatCount = 99999;
    
    //flip cow
    if(newX < currentX)
    {
        NSArray *flippedCowImageArray = [NSArray arrayWithObjects: [UIImage imageNamed: @"Cow1Reversed.png"], [UIImage imageNamed: @"Cow2Reversed.png"], [UIImage imageNamed: @"Cow3Reversed.png"], nil];
        tempCow.animationImages = flippedCowImageArray;
    }
    else
    {
        NSArray *cowImageArray = [NSArray arrayWithObjects: [UIImage imageNamed: @"Cow1.png"], [UIImage imageNamed: @"Cow2.png"], [UIImage imageNamed: @"Cow3.png"], nil];
        tempCow.animationImages = cowImageArray;
    }
    
    [tempCow startAnimating];
}


-(void)abductCow:(UIImageView *)cowImageView;
{
    [UIView beginAnimations: @"abduct" context:nil];
    [UIView setAnimationDuration: 4.0];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
    [UIView setAnimationDelegate: self];
    [UIView setAnimationDidStopSelector: @selector(finishAbducting)];
    [UIView setAnimationBeginsFromCurrentState: YES];

    CGRect frame = cowImageView.frame;
    frame.origin.y = myPlayerImageView.frame.origin.y;
    cowImageView.frame = frame;
    
    [UIView commitAnimations];
}

-(void)abductCowFromNetworkAtIndex:(int)x
{
    otherPlayerCurrentAbductee = [cowArray objectAtIndex: x];
    
    
    otherPlayerCurrentAbductee.frame = otherPlayerCurrentAbductee.frame;
    [otherPlayerCurrentAbductee.layer removeAllAnimations];
    
    [UIView beginAnimations: @"abductNetwork" context:nil];
    [UIView setAnimationDuration: 4.0];
    [UIView setAnimationCurve:UIViewAnimationCurveEaseIn];
    [UIView setAnimationDelegate: self];
    [UIView setAnimationDidStopSelector: @selector(finishAbductingFromNetwork)];
    [UIView setAnimationBeginsFromCurrentState: YES];
    
    CGRect frame = otherPlayerCurrentAbductee.frame;
    frame.origin.y = otherPlayerImageView.frame.origin.y;
    otherPlayerCurrentAbductee.frame = frame;
    
    [UIView commitAnimations];
}

-(void)finishAbductingFromNetwork;
{
    [cowArray removeObjectIdenticalTo:otherPlayerCurrentAbductee];
    [self endTractorFromNetwork];
    
    [otherPlayerCurrentAbductee.layer removeAllAnimations];
    [otherPlayerCurrentAbductee removeFromSuperview];
    
    otherPlayerCurrentAbductee = nil;
    
    if(isHost)
        [self spawnCow];
}

-(void)finishAbducting;
{
    if(!currentAbductee || !tractorBeamOn)
        return;
    
    [cowArray removeObjectIdenticalTo:currentAbductee];
    
    [tractorBeamImageView removeFromSuperview];
    
    tractorBeamOn = NO;
    
    score++;
    scoreLabel.text = [NSString stringWithFormat: @"SCORE %05.0f", score];
    
    if(self.gameIsMultiplayer)
    {
        [gcManager sendStringToAllPeers:[NSString stringWithFormat:@"$score:%f", score] reliable:YES];
    }
    
    [currentAbductee.layer removeAllAnimations];
    [currentAbductee removeFromSuperview];
    
    currentAbductee = nil;
    
    if(isHost)
        [self spawnCow];
    
    if(![self.gcManager achievementWithIdentifierIsComplete:@"com.dragonforged.ufo.aduct1"])
    {
        [self.gcManager submitAchievement:@"com.dragonforged.ufo.aduct1" percentComplete:100];
    }
    
    if(![self.gcManager achievementWithIdentifierIsComplete:@"com.dragonforged.ufo.abduct25"])
    {
//        double percentComplete = [self.gcManager percentageCompleteOfAchievementWithIdentifier:@"com.dragonforged.ufo.abduct25"];
//        percentComplete += 4;
//        [self.gcManager submitAchievement:@"com.dragonforged.ufo.abduct25" percentComplete:percentComplete];
    }
}

-(UIImageView *)hitTest
{
    if(!tractorBeamOn)
        return nil;
    
    for(int x = 0; x < [cowArray count]; x++)
    {
        UIImageView *tempCow = [cowArray objectAtIndex: x];
        CALayer *cowLayer= [[tempCow layer] presentationLayer];
        CGRect cowFrame = [cowLayer frame];
        
        if (CGRectIntersectsRect(cowFrame, tractorBeamImageView.frame))
        {
            tempCow.frame = cowLayer.frame;
            [tempCow.layer removeAllAnimations];
            
            if(self.gameIsMultiplayer)
            {
                [gcManager sendStringToAllPeers:[NSString stringWithFormat: @"$abductCowAtIndex:%i", x] reliable:YES];
            }
            
            return tempCow;
        }
    }
    
    return nil;
}


#pragma mark Game Center Delegate
#pragma mark -

- (void)scoreReported: (NSError*) error;
{
    if(error)
        NSLog(@"There was an error in reporting the score: %@", [error localizedDescription]);
              
    else
        NSLog(@"Score submitted");
    
}

- (void)achievementSubmitted:(GKAchievement *)achievement error:(NSError *)error;
{
    if(error)
        NSLog(@"There was an error in reporting the achievement: %@", [error localizedDescription]);
    
    else
        NSLog(@"achievement submitted");
}

- (void)achievementEarned:(GKAchievementDescription *)achievement;
{
    achievementCompletionView.frame = CGRectMake(0, 320, 480, 25);
    [self.view addSubview: achievementCompletionView];
    achievementcompletionLabel.text = achievement.achievedDescription;
    
    [UIView beginAnimations:@"SlideInAchievement" context:nil];
    [UIView setAnimationDuration: 0.5];
    [UIView setAnimationDelegate: self];
    [UIView setAnimationDidStopSelector: @selector(achievementEarnedAnimationDone)];
    achievementCompletionView.frame = CGRectMake(0, 295, 480, 25);
    [UIView commitAnimations];
}
                                                   
-(void)achievementEarnedAnimationDone
{
    [UIView beginAnimations:@"SlideInAchievement" context:nil];
    [UIView setAnimationDelay: 5.0];
    [UIView setAnimationDuration: 1.0];
    achievementCompletionView.frame = CGRectMake(0, 320, 480, 25);
    [UIView commitAnimations];
}



@end
