//
//  ViewSprintViewController.h
//  CodeSprint
//
//  Created by Vincent Chau on 8/4/16.
//  Copyright © 2016 Vincent Chau. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "Artifacts.h"
#import "ImportItemsViewController.h"

@interface ViewSprintViewController : UIViewController

@property (nonatomic) NSInteger selectedIndex;
@property (strong, nonatomic) Artifacts *currentArtifact;
@property (strong, nonatomic) ImportItemsViewController *vc;

@end
