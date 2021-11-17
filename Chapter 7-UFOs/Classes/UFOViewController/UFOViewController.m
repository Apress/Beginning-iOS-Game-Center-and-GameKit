//
//  GameCenterViewController.m
//  GameCenter
//
//  Created by Kyle Richter on 11/14/10.
//  Copyright 2010 Dragon Forged Software. All rights reserved.
//

#import "UFOViewController.h"
#import "UFOGameViewController.h"
#import "UFOLeaderboardViewController.h"
#import "UFOAchievementViewController.h"

@implementation UFOViewController

-(void)viewDidLoad
{
	[super viewDidLoad];
	
	if([GameCenterManager isGameCenterAvailable])
	{
		[[NSNotificationCenter defaultCenter] addObserver:self
												 selector:@selector(localUserAuthenticationChanged:)
													 name:GKPlayerAuthenticationDidChangeNotificationName 
												   object:nil];
		
		gcManager = [[GameCenterManager alloc] init];
		gcManager.delegate = self;
        [gcManager authenticateLocalUser: self];
		[gcManager populateAchievementCache];
		//[gcManager resetAchievements];
		[gcManager findAllActivity];
		
	}
	
	else
		NSLog(@"Game Center not available");	
    
}

-(void)viewDidUnload
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:GKPlayerAuthenticationDidChangeNotificationName object:nil];	
	
	[super viewDidUnload];
}	

-(void)viewWillAppear:(BOOL)animated
{
	gcManager.delegate = self;
	[super viewWillAppear:animated];
}

- (void)playerDataLoaded:(NSArray *)players error:(NSError *)error;
{
	if(error != nil)
		NSLog(@"An error occured during player lookup: %@", [error localizedDescription]);
	else 
		NSLog(@"Players loaded: %@", players);
}

-(void)localUserAuthenticationChanged:(NSNotification *)notif; 
{
	NSLog(@"Authenication Changed: %@", notif.object);	
}

- (void)processGameCenterAuthentication:(NSError*)error;
{
	if(error != nil)
	{
		NSLog(@"An error occured during authentication: %@", [error localizedDescription]);
	}
	else 
	{
		[gcManager setupInvitationHandler:self];
	}
}

- (void)findProgrammaticMatch
{
	GKMatchRequest *request = [[[GKMatchRequest alloc] init] autorelease]; 
	request.minPlayers = 2;
	request.maxPlayers = 4;
	
    
	[[GKMatchmaker sharedMatchmaker] findMatchForRequest:request withCompletionHandler:^(GKMatch *match, NSError *error) {
		if (error) 
		{
			NSLog(@"An error occurrred during finding a match: %@", [error localizedDescription]);
		} 
		
		else if (match != nil)
		{
			NSLog(@"A match has been found: %@", match);
		}
	}];
}

- (void)findProgrammaticHostedMatch
{
	GKMatchRequest *request = [[[GKMatchRequest alloc] init] autorelease]; 
	request.minPlayers = 2;
	request.maxPlayers = 16;
    [[GKMatchmaker sharedMatchmaker] findPlayersForHostedRequest:request withCompletionHandler:^(NSArray<GKPlayer *> * _Nullable players, NSError * _Nullable error) {
        if (error) {
            NSLog(@"An error occurrred during finding a match: %@", [error localizedDescription]);
        } else if (players != nil) {
            NSLog(@"Players have been found for match: %@", players);
        }
    }];
}

- (void)addPlayerToMatch:(GKMatch *)match withRequest:(GKMatchRequest *)request
{
	[[GKMatchmaker sharedMatchmaker] addPlayersToMatch:match matchRequest:request completionHandler:^(NSError *error)
	{
		if (error) 
		{
			NSLog(@"An error occurrred during adding a player to match: %@", [error localizedDescription]);
		} 
		
		else if (match != nil)
		{
			NSLog(@"A player has been added to the match");
		}
	}];
}


- (void)friendsFinishedLoading:(NSArray *)friends error:(NSError *)error;
{
	if(error != nil)
		NSLog(@"An error occured during friends list request: %@", [error localizedDescription]);
	else 
		[gcManager playersForIDs: friends];
}

- (void)scoreReported: (NSError*) error;
{
	if(error)
		NSLog(@"There was an error in reporting the score: %@", [error localizedDescription]);
	
	else	
		NSLog(@"Score submitted");
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	if(interfaceOrientation == UIInterfaceOrientationLandscapeLeft || interfaceOrientation == UIInterfaceOrientationLandscapeRight)
		return YES;
	
	return NO;
}

-(IBAction)playButtonPressed
{
	UFOGameViewController *gameViewController = [[UFOGameViewController alloc] init];
	gameViewController.gcManager = gcManager;
	[self.navigationController pushViewController: gameViewController animated:YES];
	[gameViewController release];
}

-(IBAction)leaderboardButtonPressed;
{
    GKGameCenterViewController *leaderboardController = [[GKGameCenterViewController alloc] initWithState: leaderboardController];
    leaderboardController.gameCenterDelegate = self;
    [self presentViewController:leaderboardController animated:YES completion:nil];
}

-(IBAction)customLeaderboardButtonPressed;
{
	UFOLeaderboardViewController *leaderboardViewController = [[UFOLeaderboardViewController alloc] init];
	leaderboardViewController.gcManager = gcManager;
    [self presentViewController:leaderboardViewController animated:YES completion:nil];
	[leaderboardViewController release];
}

- (void)gameCenterViewControllerDidFinish:(GKGameCenterViewController *)gameCenterViewController {
    [self dismissViewControllerAnimated:YES completion: nil];
}

-(IBAction)achievementButtonPressed;
{
    GKGameCenterViewController *achievementViewController = [[GKGameCenterViewController alloc] initWithState: 1];
    achievementViewController.gameCenterDelegate = self;
    [self presentViewController:achievementViewController animated:YES completion:nil];
}

-(IBAction)customAchievementButtonPressed;
{
	UFOAchievementViewController *achievementViewController = [[UFOAchievementViewController alloc] init];
	achievementViewController.gcManager = gcManager;
    [self presentViewController:achievementViewController animated:YES completion:nil];
	[achievementViewController release];
}

-(IBAction)multiplayerButtonPressed;
{
	GKMatchRequest *request = [[[GKMatchRequest alloc] init] autorelease];
	request.minPlayers = 2; 
	request.maxPlayers = 4;
	
	GKMatchmakerViewController *matchmakerViewController = [[[GKMatchmakerViewController alloc] initWithMatchRequest:request] autorelease];
	matchmakerViewController.matchmakerDelegate = self; 
		
    [self presentViewController:matchmakerViewController animated:YES completion:nil];
}

- (void)matchmakerViewControllerWasCancelled:(GKMatchmakerViewController *)viewController 
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

//MARK: Depreacated Function
- (void)matchmakerViewController:(GKMatchmakerViewController *)viewController didFailWithError:(NSError *)error 
{
    [self dismissViewControllerAnimated:YES completion:nil];
	
	if(error != nil)
	{
        UIAlertController *alert = [UIAlertController
                                    alertControllerWIthTitle:@""
                                    message:[NSString stringWithFormat:@"An error occurred: %@", [error localizedDescription]]
                                    ];
//											  delegate:nil
//											  cancelButtonTitle:@"Dismiss"
//											  otherButtonTitles:nil];
        UIAlertAction *defaultAction = [UIAlertAction
                                    actionWithTitle:@"Dismiss" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {}];
    
        [alert addAction:defaultAction];
        
        [self presentViewController:alert animated:YES completion:nil];
	}	
}

- (void)matchmakerViewController:(GKMatchmakerViewController *)viewController didFindMatch:(GKMatch *)match 
{
    [self dismissViewControllerAnimated:YES completion:nil];
    
    gcManager.matchOrSession = match;
    
    [gcManager setupInvitationHandler: gcManager];

    UFOGameViewController *gameVC = [[UFOGameViewController alloc] init];
    gameVC.gcManager = gcManager;
    gameVC.gameIsMultiplayer = YES;
    gameVC.peerIDString = nil;
    gameVC.peerMatch = match;
    [self.navigationController pushViewController:gameVC animated:YES];
    [gameVC release];
}

- (void)matchmakerViewController:(GKMatchmakerViewController *)viewController didFindPlayers:(NSArray *)playerIDs
{
    [self dismissViewControllerAnimated:YES completion:nil];
	NSLog(@"Players: %@", playerIDs);
	//Begin Hosted Game
}

- (void)playerActivity:(NSNumber *)activity error:(NSError *)error
{
	if(error != nil)
	{
		NSLog(@"An error occurred while querying player activity: %@", [error localizedDescription]);
	}	
	
	else
	{
		NSLog(@"All recent player activity: %@", activity);
	}
}

- (void)playerActivityForGroup:(NSDictionary *)activityDict error:(NSError *)error
{
	if(error != nil)
	{
		NSLog(@"An error occurred while querying player activity: %@", [error localizedDescription]);
	}	
	
	else
	{
		NSLog(@"All recent player activity: %@ For Group: %@", [activityDict objectForKey:@"activity"], [activityDict objectForKey:@"group"]);
	}
}	


-(IBAction)localMultiplayerGameButtonPressed
{
	peerPickerController = [[MCBrowserViewController alloc] initWithServiceType:@"space" session:currentSession];
	peerPickerController.delegate = self;
//	peerPickerController.connectionTypesMask = GKPeerPickerConnectionTypeNearby;
    [peerPickerController presentViewController:peerPickerController animated:true completion:nil];
}


- (void)setupSession {
    MCPeerID *peer = [[MCPeerID alloc] initWithDisplayName: [[GKLocalPlayer localPlayer] alias]];
    currentSession = [[MCSession alloc] initWithPeer:peer];
    currentSession.delegate = gcManager;
    advertiserAssistant = [[MCAdvertiserAssistant alloc] initWithServiceType:@"space" discoveryInfo:nil session: currentSession];
    [advertiserAssistant start];
}

//- (void)peerPickerController:(MCBrowserViewController *)picker didSelectConnectionType:(MCNearbyServiceBrowser *)type
//{
//	if(type == GKPeerPickerConnectionTypeOnline)
//	{
//        [picker dismissViewControllerAnimated:true completion:nil];
//        [picker release];
//
//		// Display your own user interface here.
//	}
//}

- (void)peerPickerController:(MCBrowserViewController *)picker
              didConnectPeer:(NSString *)peerID
                   toSession:(MCSession *)session
{
    [picker dismissViewControllerAnimated:true completion:nil];

	currentSession = session;
    gcManager.matchOrSession = session;

    [session setDataReceiveHandler: gcManager  withContext: nil];

    UFOGameViewController *gameVC = [[UFOGameViewController alloc] init];
    gameVC.gcManager = gcManager;
    gameVC.gameIsMultiplayer = YES;
    gameVC.peerIDString = peerID;
    gameVC.peerMatch = nil;
    [self.navigationController pushViewController:gameVC animated:YES];
    [gameVC release];
}

-(IBAction)storeButtonPressed;
{
    
    UFOStoreViewController *storeVC = [[UFOStoreViewController alloc] init];
    [self presentViewController:storeVC animated:TRUE completion:nil];
}

@end
