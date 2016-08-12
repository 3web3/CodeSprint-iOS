//
//  BacklogTableViewController.h
//  CodeSprint
//
//  Created by Vincent Chau on 7/29/16.
//  Copyright © 2016 Vincent Chau. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Team.h"
#import "ArtifactsTableViewCell.h"
#import "Artifacts.h"

@protocol BacklogTableViewControllerDelegate <NSObject>

@optional
-(void)notifySubscribers:(Artifacts*)artifact;

@end

@interface BacklogTableViewController : UITableViewController

@property (strong, nonatomic) NSString *selectedTeam;
@property (strong, nonatomic) Artifacts *artifacts;
@property (strong, nonatomic) NSMutableArray *allSprints;

@property (weak, nonatomic) id<BacklogTableViewControllerDelegate> delegate;

@end
