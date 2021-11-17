//
//  UFOAchievementViewController.m
//  UFOs
//
//  Created by Kyle Richter on 3/4/11.
//  Copyright 2011 Dragon Forged Software. All rights reserved.
//

#import "UFOAchievementViewController.h"


@implementation UFOAchievementViewController
@synthesize gcManager, achievementArray;

-(void)viewDidLoad
{
	[super viewDidLoad];	
}	

-(void)viewWillAppear:(BOOL)animated
{
	self.gcManager.delegate = self;
	
	[super viewWillAppear: YES];
	
	[self.gcManager retrieveAchievmentMetadata];
}	

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	if(UIInterfaceOrientationIsLandscape(interfaceOrientation))
		return YES;
	
	return NO;
}

- (void)achievementDescriptionsLoaded:(NSArray *)descriptions error:(NSError *)error;
{
	if(error == nil)
	{
		self.achievementArray = descriptions;
	}	
	
	else
	{
		NSLog(@"An error occurred when retrieving the achievement descriptions: %@", [error localizedDescription]);	
	}

	[achievementTableView reloadData];
}

#pragma mark -
#pragma mark Table View DataSource
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return [self.achievementArray count];
}	

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) 
	{
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	}
	
	GKAchievementDescription *achievementDescription = [self.achievementArray objectAtIndex: indexPath.row];
	
	NSString *percentageCompleteString = [NSString stringWithFormat: @" %.0f%% Complete", [self.gcManager percentageCompleteOfAchievementWithIdentifier: achievementDescription.identifier]];
	cell.textLabel.text = [achievementDescription.title stringByAppendingString: percentageCompleteString];
	
	if(achievementDescription.image == nil)
	{
		cell.imageView.image = [GKAchievementDescription placeholderCompletedAchievementImage];
		
		[achievementDescription loadImageWithCompletionHandler:^(UIImage *image, NSError *error)
		 {
			 if (error == nil) 
			 {
				 cell.imageView.image = image;
			 } 
		 }];
	}
	
	else 
	{
		cell.imageView.image = achievementDescription.image;
	}

    return cell;
}

-(IBAction)dismissAction;
{
	[self dismissModalViewControllerAnimated: YES];
}	

- (void)dealloc 
{
	[achievementArray release]; achievementArray = nil;
	[gcManager release]; gcManager = nil;
    [super dealloc];
}


@end
