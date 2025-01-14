//
//  FirebaseManager.m
//  CodeSprint
//
//  Created by Vincent Chau on 6/20/16.
//  Copyright © 2016 Vincent Chau. All rights reserved.
//

#import "FirebaseManager.h"
#import <FBSDKLoginKit/FBSDKLoginKit.h>
#import <FBSDKCoreKit/FBSDKCoreKit.h>
#include "Constants.h"
#include "User.h"
#include "Artifacts.h"
#include "Chatroom.h"

@implementation FirebaseManager

#pragma mark - Singleton

+ (FirebaseManager *)sharedInstance
{
    static FirebaseManager *_sharedInstance = nil;
    static dispatch_once_t oncePredicate;
    
    dispatch_once(&oncePredicate, ^{
        _sharedInstance = [[FirebaseManager alloc] init];
    });

    return _sharedInstance;
}

#pragma mark - References Lazy Initializers

- (FIRDatabaseReference *)refs
{
    if (!refs) {
        refs = [[FIRDatabase database] reference];
    }
    
    return refs;
}

- (FIRDatabaseReference *)teamRefs
{
    if (!teamsRefs) {
        teamsRefs = [[self refs] child:kTeamsHead];
    }
    
    return teamsRefs;
}

- (FIRDatabaseReference *)userRefs
{
    if (!userRefs) {
        userRefs = [[self refs] child:kCSUserHead];
    }
    
    return userRefs;
}

- (FIRDatabaseReference *)scrumRefs
{
    if (!scrumRefs) {
        scrumRefs = [[self refs] child:kScrumHead];
    }
    
    return scrumRefs;
}

- (FIRDatabaseReference *)chatroomRefs
{
    if (!chatroomRefs) {
        chatroomRefs = [[self refs] child:kChatroomHead];
    }
    
    return chatroomRefs;
}

#pragma mark - Reference Getters

+ (FIRDatabaseReference *)mainRef
{
    return [self sharedInstance].refs;
}

+ (FIRDatabaseReference *)teamRef
{
    return [self sharedInstance].teamRefs;
}

+ (FIRDatabaseReference *)userRef
{
    return [self sharedInstance].userRefs;
}

+ (FIRDatabaseReference *)scrumRef
{
    return [self sharedInstance].scrumRefs;
}

+ (FIRDatabaseReference *)chatRef
{
    return [self sharedInstance].chatroomRefs;
}

#pragma mark - User Management - Lifecycle

+ (void)logoutUser
{
    [FirebaseManager sharedInstance].currentUser = nil;
}

+ (void)deleteUser
{
    [self deleteHelperWithCompletion:^(BOOL result) {
        FIRUser *user = [FIRAuth auth].currentUser;
        
        [user deleteWithCompletion:^(NSError *_Nullable error) {
            if (error) {
                NSLog(@"ERROR: %@", error.localizedDescription);
            } else {
                NSError *signOutError;
                BOOL status = [[FIRAuth auth] signOut:&signOutError];

                if (!status) {
                    NSLog(@"Error signing out: %@", signOutError);
                    return;
                }
            }
        }];
    }];
}

+ (void)deleteHelperWithCompletion:(void (^)(BOOL result))block
{
    User *currentUser = [FirebaseManager sharedInstance].currentUser;
    
    if ([currentUser.groupsIDs count] != 0) {
        FIRDatabaseReference *userRef = [[[self userRef] child:currentUser.uid] child:kCSUserTeamKey];
        [userRef removeValue];
        __block int i = 0;
        
        for (NSString *teamName in currentUser.groupsIDs) {
            [self removeFromTeam:currentUser.uid team:teamName withCompletion:^(BOOL result) {
                i++;
        
                if (i == currentUser.groupsIDs.count) {
                     block(true);
                }
            }];
        }
    }
}

+ (void)setUpNewUser:(NSString *)displayName
{
    NSString *uid = [FirebaseManager sharedInstance].currentUser.uid;
    [FirebaseManager sharedInstance].currentUser.displayName = displayName;
    [[[self userRef] child:uid] updateChildValues:@{kCSUserDidSetDisplay : @1,
                                                    kCSUserDisplayKey : displayName}];
}

+ (void)lookUpUser:(User *)currentUser withCompletion:(void (^)(BOOL result))block
{
    __block BOOL theResult = false;
    [[[self userRef] child:currentUser.uid] observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *_Nonnull snapshot) {
      
        if (snapshot.value == [NSNull null]) {
            NSString *defaultPhoto = @"https://firebasestorage.googleapis.com/v0/b/code-spring-ios.appspot.com/o/UserImage.png?alt=media&token=4d5c5207-9d4a-4e98-8a99-95e7f201f44c";
            [[[self userRef] child:currentUser.uid] updateChildValues:@{kCSUserDidSetDisplay : @0,
                                                                        kCSUserPhotoURL:defaultPhoto,
                                                                        }];
            block(false);
        } else {
            FIRDatabaseQuery *userQuery = [[[self userRef] child:currentUser.uid] queryOrderedByChild:kCSUserDisplayKey];
            [userQuery observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *_Nonnull snapshot) {
            
                if (snapshot.value) {
                    NSDictionary *response = (NSDictionary *)snapshot.value;
                    theResult = ([response objectForKey:kCSUserDisplayKey] ? true : false);
                
                    if (theResult) {
                        [FirebaseManager sharedInstance].currentUser.displayName = response[kCSUserDisplayKey];
                        [FirebaseManager sharedInstance].currentUser.photoURL = [NSURL URLWithString:response[kCSUserPhotoURL]];
                    }
                }
                block(theResult);
            }];
        }
    }];
}

+ (void)retreiveUsersTeams
{
    FIRDatabaseQuery *usersQuery = [[[self userRef] child:[FirebaseManager sharedInstance].currentUser.uid] queryOrderedByChild:kCSUserTeamKey];
    [usersQuery observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *_Nonnull snapshot) {
        NSDictionary *response = (NSDictionary *)snapshot.value;
        
        if ([[response allKeys] containsObject:kCSUserTeamKey]) {
            [FirebaseManager sharedInstance].currentUser.groupsIDs = [[response objectForKey:kCSUserTeamKey] mutableCopy];
        } else {
        
        }
    }];
}

// HANDLE: newTeamsHandle
+ (void)observeNewTeams
{
    FIRDatabaseQuery *usersQuery = [[[self userRef] child:[FirebaseManager sharedInstance].currentUser.uid] queryOrderedByChild:kCSUserTeamKey];
    [FirebaseManager sharedInstance].newTeamsHandle = [usersQuery observeEventType:FIRDataEventTypeValue
                                                                         withBlock:^(FIRDataSnapshot *_Nonnull snapshot) {
        NSDictionary *response = (NSDictionary *)snapshot.value;
                                                                             
        if ([[response allKeys] containsObject:kCSUserTeamKey]) {
            [FirebaseManager sharedInstance].currentUser.groupsIDs = [[response objectForKey:kCSUserTeamKey] mutableCopy];
            
            for (NSString *groupID in [FirebaseManager sharedInstance].currentUser.groupsIDs) {
                FIRDatabaseQuery *scrumQuery = [[[self teamRef] child:groupID] queryOrderedByChild:kTeamsScrumKey];
                [scrumQuery observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *_Nonnull snapshot) {
                    NSDictionary *scrumSnap = (NSDictionary *)snapshot.value;
                    NSString *scrumKey = scrumSnap[kTeamsScrumKey];
                   [[FirebaseManager sharedInstance].currentUser.scrumIDs setObject:scrumKey forKey:groupID];
                }];
            }
        } else {
            [FirebaseManager sharedInstance].currentUser.groupsIDs = [[NSMutableArray alloc] init];
        }
    }];

}

#pragma mark - Queries

+ (void)isNewTeam:(NSString *)teamName withCompletion:(void (^)(BOOL result))block
{
    __block NSDictionary *response = [[NSDictionary alloc] init];
    [[[self teamRef] child:teamName] observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *_Nonnull snapshot) {
        response = (NSDictionary *)snapshot.value;
        BOOL isNew = ([response isEqual:[NSNull null]]) ? true : false;
        block(isNew);
    }];
}

+ (void)updatePictureURLForUserWithCompletion:(void (^)(BOOL result))block
{
    NSString *currentUID = [FirebaseManager sharedInstance].currentUser.uid;
    NSString *url = [[FirebaseManager sharedInstance].currentUser.photoURL absoluteString];
    FIRDatabaseReference *usersNode = [[self userRef] child:currentUID];
    [usersNode observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *_Nonnull snapshot) {
        NSDictionary *response = (NSDictionary *)snapshot.value;
        
        if ([[response allKeys] containsObject:kCSUserPhotoURL]) {
            // Has photoalready
            [FirebaseManager sharedInstance].currentUser.photoURL = response[kCSUserPhotoURL];
            block(true);
        } else {
            block(true);
            [usersNode updateChildValues:@{kCSUserPhotoURL:url}];
        }
    }];
}

#pragma mark - Team Management - Creations

+ (void)createTeamWith:(Team *)teamInformation andPassword:(NSString *)password withCompletion:(void (^)(BOOL result))block
{
    NSArray *newTeams = [self sharedInstance].currentUser.groupsIDs;
    NSString *currentUID = [self sharedInstance].currentUser.uid;
    [[[self userRef] child:currentUID] updateChildValues:@{kCSUserTeamKey : newTeams}];
    
    FIRDatabaseReference *scrumNode = [[self scrumRef] childByAutoId];
    FIRDatabaseReference *teamRef = [[self teamRef] child:teamInformation.nickname];
    [teamRef updateChildValues:@{kMembersHead : teamInformation.membersUID,
                                 kTeamsScrumKey : scrumNode.key,
                                 kTeamsPassword : password}];
    [scrumNode setValue:@{kScrumCreator:currentUID}];
    FIRDatabaseReference *chatRef = [self chatRef];
    [chatRef updateChildValues:@{teamInformation.nickname:@(-1)}];

    block(true);
}

+ (void)addUserToTeam:(NSString *)teamName andUser:(NSString *)uid withCompletion:(void (^)(BOOL result))block
{
    __block BOOL alreadyJoined = false;
    FIRDatabaseQuery *membersQuery = [[[[self teamRef] child:teamName] child:kMembersHead] queryOrderedByChild:uid];
    [membersQuery observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *_Nonnull snapshot) {
        for (FIRDataSnapshot *child in snapshot.children) {
            if ([child.value isEqualToString:uid]) {
                alreadyJoined = true;
                block(false);
            }
        }
        
        if (!alreadyJoined) {
            NSMutableArray *oldMembers = [(NSArray *)snapshot.value mutableCopy];
            [oldMembers addObject:uid];
            FIRDatabaseReference *teamRef = [[self teamRef] child:teamName];
            FIRDatabaseQuery *usersQuery = [[[self userRef] child:uid] queryOrderedByChild:kCSUserTeamKey];
            [teamRef updateChildValues:@{kMembersHead :[NSArray arrayWithArray:oldMembers]}];
            [usersQuery observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *_Nonnull snapshot) {
                NSDictionary *response = (NSDictionary *)snapshot.value;
                NSArray *newTeams;
                
                if ([[response allKeys] containsObject:kCSUserTeamKey]) {
                    NSMutableArray *oldTeams = [[response objectForKey:kCSUserTeamKey] mutableCopy];
                    [oldTeams addObject:teamName];
                    newTeams = [oldTeams mutableCopy];
                    
                } else {
                    newTeams = [NSArray arrayWithArray:[NSMutableArray arrayWithObject:teamName]];
                }
                [[[[self userRef] child:uid] child:kCSUserTeamKey] setValue:newTeams];
                block(true);
            }];
        }
    }];
}

+ (void)checkTeamAndPasswordWithName:(NSString *)teamName andPassword:(NSString *)password withCompletion:(void (^)(BOOL result))block
{
    FIRDatabaseReference *teamRef = [[self teamRef] child:teamName];
    [teamRef observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *_Nonnull snapshot) {
        NSDictionary *snap = (NSDictionary *)snapshot.value;
        NSString *teamPass = snap[kTeamsPassword];
        
        if ([teamPass isEqualToString:password]) {
            block(true);
        } else {
            block(false);
        }
    }];
}

#pragma mark - Team Management - Deletions

+ (void)removeUserFromTeam:(NSString *)uid withIndexs:(NSArray *)index withCompletion:(void (^)(BOOL result))block
{
    FIRDatabaseReference *userRef = [[self userRef] child:uid];
    [userRef observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *_Nonnull snapshot) {
        NSDictionary *userDictionary = (NSDictionary *)snapshot.value;
        NSString *teamName;
        
        for (NSNumber *selected in index) {
            NSInteger myInt = [selected integerValue];
            teamName = [userDictionary[kTeamsHead] objectAtIndex:myInt];
            [userDictionary[kTeamsHead] removeObjectAtIndex:myInt];
        }
        [FirebaseManager sharedInstance].currentUser.groupsIDs = userDictionary[kTeamsHead];
        [[FirebaseManager sharedInstance].currentUser.scrumIDs removeObjectForKey:teamName];
        [userRef updateChildValues:@{kTeamsHead:userDictionary[kTeamsHead]}];
        [self removeFromTeam:uid team:teamName withCompletion:^(BOOL result) {
            block(true);
        }];
    }];
}

+ (void)removeFromTeam:(NSString *)uid team:(NSString *)teamName withCompletion:(void (^)(BOOL result))block
{
    FIRDatabaseReference *teamReference = [[self teamRef] child:teamName];
    [teamReference observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *_Nonnull snapshot) {
        NSMutableArray *members = [(NSArray *)snapshot.value[kMembersHead] mutableCopy];
        
        if ([members count] == 1) {
            // remove whole team
            NSDictionary *response = (NSDictionary *)snapshot.value;
            // delete scrum
            NSString *scrumNode = response[kScrumHead];
            [[[self scrumRef] child:scrumNode] removeValue];
            [teamReference removeValue];
            FIRDatabaseReference *chatroom = [[self chatRef] child:teamName];
            [chatroom removeValue];
        } else {
            [members removeObject:uid];
            [teamReference updateChildValues:@{kMembersHead:[NSArray arrayWithArray:members]}];
        }
        block(true);
    }];
}

#pragma mark - Scrum Management - Insertions

+ (void)addProductSpecToScrum:(NSString *)scrumKey withArtifact:(Artifacts *)artifact withCompletion:(void (^)(BOOL completed))block
{
    FIRDatabaseReference *scrumRef = [[self scrumRef] child:scrumKey];
    [scrumRef updateChildValues:@{kScrumProductSpecs:artifact.productSpecs}];
    block(true);
}

+ (void)addSprintGoalToScrum:(NSString *)scrumKey withArtifact:(Artifacts *)artifact withCompletion:(void (^)(BOOL completed))block
{
    FIRDatabaseReference *scrumRef = [[self scrumRef] child:scrumKey];
    [scrumRef updateChildValues:@{kScrumSprintGoals:artifact.sprintGoals}];
    block(true);
}

+ (void)createSprintFor:(NSString *)scrumKey withArtifact:(Artifacts *)artifact withCompletion:(void (^)(BOOL completed))block
{
    FIRDatabaseReference *scrumRef = [[self scrumRef] child:scrumKey];
    [scrumRef updateChildValues:@{kSprintHead:artifact.sprintCollection}];
    block(true);
}

+ (void)updateSprintFor:(NSString *)scrumKey withGoalRefs:(NSMutableArray *)refs andCollectionIndex:(NSInteger)index withArtifact:(Artifacts *)artifact withCompletion:(void (^)(Artifacts *artifact))block
{
    FIRDatabaseQuery *goalRefQuery = [[[self scrumRef] child:scrumKey] queryOrderedByChild:kSprintHead];
    [goalRefQuery observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *_Nonnull snapshot) {
        NSDictionary *response = (NSDictionary *)snapshot.value;
        NSMutableArray *sprintArray = [(NSArray *)response[kSprintHead] mutableCopy];
        NSDictionary *currentSprint = sprintArray[index];
        NSMutableArray *goalRef = [currentSprint[kSprintGoalReference] mutableCopy];
        NSMutableArray *sprintGoals = [(NSArray *)response[kScrumSprintGoals] mutableCopy];
        
        if ([goalRef containsObject:@(-1)]) {
            [goalRef removeObject:@(-1)];
        }
        
        for (int i = 0; i < refs.count; i++) {
            NSIndexPath *path = (NSIndexPath *)refs[i];
            NSInteger index = path.row;
            NSDictionary *goalDict = sprintGoals[index];
            
            if ([goalRef containsObject:goalDict]) {
                
            } else {
                 [goalRef addObject:goalDict];
            }
        }
        NSArray *arrayWithoutDuplicates = [NSArray arrayWithArray:goalRef];
        NSMutableDictionary *dict = [[artifact.sprintCollection objectAtIndex:index] mutableCopy];
        FIRDatabaseReference *updateRef = [[[[self scrumRef] child:scrumKey] child:kSprintHead] child:[NSString stringWithFormat:@"%ld", (long)index]];
        [updateRef updateChildValues:@{kSprintGoalReference:arrayWithoutDuplicates}];
        dict[kSprintGoalReference] = arrayWithoutDuplicates;
        artifact.sprintCollection[index] = dict;
        Artifacts *newArtifact = [[Artifacts alloc] initWithProductSpecs:artifact.productSpecs andGoals:artifact.sprintGoals withSprints:artifact.sprintCollection];
        block(newArtifact);
    }];
}

// HANDLE: passiveScrumHandle
#pragma mark - Scrum Management - Observers

+ (void)observePassiveScrumNode:(NSString *)scrumKey withCompletion:(void (^)(Artifacts *artifact))block
{
    FIRDatabaseQuery *scrumQuery = [[[self scrumRef] child:scrumKey] queryOrderedByChild:kScrumCreator];
    [FirebaseManager sharedInstance].passiveScrumHandle = [scrumQuery observeEventType:FIRDataEventTypeValue
                                                                             withBlock:^(FIRDataSnapshot *_Nonnull snapshot) {
        NSMutableArray *productSpecs = [[NSMutableArray alloc] init];
        NSMutableArray *allGoals = [[NSMutableArray alloc] init];
        NSMutableArray *sprintCollection = [[NSMutableArray alloc] init];
        NSDictionary *response = (NSDictionary *)snapshot.value;
                                                                                 
        if ([[response allKeys] containsObject:kScrumProductSpecs]) {
            productSpecs = response[kScrumProductSpecs];
        }
                                                                                 
        if ([[response allKeys] containsObject:kScrumSprintGoals]) {
            NSArray *test = (NSArray *)response[kScrumSprintGoals];
            
            for (NSDictionary *dict in test) {
                [allGoals addObject:dict];
            }
        }
                                                                                 
        if ([[response allKeys] containsObject:kSprintHead]) {
            NSArray *sprintIntervals = (NSArray *)response[kSprintHead];
            
            for (NSDictionary *dict in sprintIntervals) {
                [sprintCollection addObject:dict];
            }
        }
        Artifacts *artifact = [[Artifacts alloc] initWithProductSpecs:productSpecs andGoals:allGoals withSprints:sprintCollection];
        block(artifact);
    }];
}

// HANDLE: scrumDeleteHandle
+ (void)observeIncaseDelete:(NSString *)scrumKey withCurrentIndex:(NSInteger)index withCompletion:(void (^)(BOOL completed))block
{
    NSString *currentIndex = [NSString stringWithFormat:@"%ld", (long)index];
    FIRDatabaseReference *change = [[[self scrumRef] child:scrumKey] child:kSprintHead];
    [FirebaseManager sharedInstance].scrumDeleteHandle = [change observeEventType:FIRDataEventTypeChildRemoved
                                                                        withBlock:^(FIRDataSnapshot *_Nonnull snapshot) {
        if ([snapshot.key isEqualToString:currentIndex]) {
            block(true);
        } else {
            block(false);
        }
    }];
}

+ (void)observeScrumNode:(NSString *)scrumKey withCompletion:(void (^)(Artifacts *artifact))block
{
    FIRDatabaseQuery *scrumQuery = [[[self scrumRef] child:scrumKey] queryOrderedByChild:kScrumCreator];
    [scrumQuery observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *_Nonnull snapshot) {
        NSMutableArray *productSpecs = [[NSMutableArray alloc] init];
        NSMutableArray *allGoals = [[NSMutableArray alloc] init];
        NSMutableArray *sprintCollection = [[NSMutableArray alloc] init];
        NSDictionary *response = (NSDictionary *)snapshot.value;
        
        if ([[response allKeys] containsObject:kScrumProductSpecs]) {
            productSpecs = response[kScrumProductSpecs];
        }
        
        if ([[response allKeys] containsObject:kScrumSprintGoals]) {
            NSArray *test = (NSArray *)response[kScrumSprintGoals];
        
            for (NSDictionary *dict in test) {
                [allGoals addObject:dict];
            }
        }
        
        if ([[response allKeys] containsObject:kSprintHead]) {
            NSArray *sprintIntervals = (NSArray *)response[kSprintHead];
        
            for (NSDictionary *dict in sprintIntervals) {
                [sprintCollection addObject:dict];
            }
        }
        Artifacts *artifact = [[Artifacts alloc] initWithProductSpecs:productSpecs andGoals:allGoals withSprints:sprintCollection];
        block(artifact);
    }];
}

#pragma mark - Scrum Management - Deletions

+ (void)removeActiveSprintFor:(NSString *)scrumKey withArtifact:(Artifacts *)artifact forIndex:(NSInteger)selectedIndex withCompletion:(void (^)(BOOL compelted))block
{
    FIRDatabaseReference *currentSprint = [[[self scrumRef] child:scrumKey] child:kSprintHead];
    [currentSprint observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *_Nonnull snapshot)
    {
        NSMutableArray *sprintArray = [(NSArray *)snapshot.value mutableCopy];
        [sprintArray removeObjectAtIndex:selectedIndex];
        [currentSprint setValue:sprintArray];
        block(true);
    }];
}

+ (void)removeProductSpecFor:(NSString *)scrumKey withArtifact:(Artifacts *)artifact forIndex:(NSInteger)selectedIndex withCompletion:(void (^)(BOOL compelted))block
{
    FIRDatabaseReference *currentScrum = [[[self scrumRef] child:scrumKey] child:kScrumProductSpecs];
    [currentScrum observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *_Nonnull snapshot) {
        NSMutableArray *productSpecs = [(NSArray *)snapshot.value mutableCopy];
        [productSpecs removeObjectAtIndex:selectedIndex];
        [currentScrum setValue:productSpecs];
        block(true);
    }];
}

+ (void)removeSprintGoalFor:(NSString *)scrumKey withArtifact:(Artifacts *)artifact forIndex:(NSInteger)selectedIndex andSprintIndex:(NSUInteger)selectedSprint withCompletion:(void (^)(Artifacts *artifact))block
{
    FIRDatabaseQuery *goalRefQuery = [[[self scrumRef] child:scrumKey] queryOrderedByChild:kSprintHead];
    [goalRefQuery observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *_Nonnull snapshot) {
        NSDictionary *response = (NSDictionary *)snapshot.value;
        NSMutableArray *sprintArray = [(NSArray *)response[kSprintHead] mutableCopy];
        NSDictionary *currentSprint = sprintArray[selectedSprint];
        NSMutableArray *goalRef = [currentSprint[kSprintGoalReference] mutableCopy];
        [goalRef removeObjectAtIndex:selectedIndex];
        
        if (goalRef.count == 0) {
            [goalRef addObject:@(-1)];
        }
        NSArray *array = [NSArray arrayWithArray:goalRef];
        FIRDatabaseReference *updateRef = [[[[self scrumRef] child:scrumKey] child:kSprintHead] child:[NSString stringWithFormat:@"%ld", (long)selectedSprint]];
        [updateRef updateChildValues:@{kSprintGoalReference:array}];
        block(artifact);
    }];
}

+ (void)removeSprintFromAllFor:(NSString *)scrumKey withArtifact:(Artifacts *)currentArtifact andIndex:(NSInteger)indexPath withCompletion:(void (^)(BOOL completed))block
{
    FIRDatabaseQuery *goalRefQuery = [[[self scrumRef] child:scrumKey]queryOrderedByChild:kSprintHead
                                      ];
    [goalRefQuery observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *_Nonnull snapshot) {
        NSDictionary *response = (NSDictionary *)snapshot.value;
        NSMutableArray *sprintGoals = [(NSArray *)response[kScrumSprintGoals] mutableCopy];
        [sprintGoals removeObjectAtIndex:indexPath];
        NSArray *newGoals = [NSArray arrayWithArray:sprintGoals];
        FIRDatabaseReference *update = [[self scrumRef] child:scrumKey];
        [update updateChildValues:@{kScrumSprintGoals:newGoals}];
        block(TRUE);
    }];
}

#pragma mark - Scrum Object Completion Functions

+ (void)markSprintGoalAsCompleteFor:(NSString *)scrumKey withArtifact:(Artifacts *)artifact andSelected:(NSInteger)selectedIndex withCompletion:(void (^)(BOOL completed))block
{
    NSDictionary *localSprint = artifact.sprintGoals[selectedIndex];
    
    if ([localSprint[kScrumSprintCompleted] isEqual:@(0)]) {
        FIRDatabaseReference *sprintGoalRef = [[[self scrumRef] child:scrumKey] child:kScrumSprintGoals];
        NSString *indexChild = [NSString stringWithFormat:@"%ld", (long)selectedIndex];
        FIRDatabaseReference *exactSprint = [sprintGoalRef child:indexChild];
        NSDate *today = [NSDate date];
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        [formatter setDateFormat:@"MMM d YYYY"];
        NSString *stringFromDate = [formatter stringFromDate:today];
        [exactSprint updateChildValues:@{kScrumSprintCompleted:@(1),
                                         kScrumSprintFinishDate:stringFromDate}];
    }
    block(TRUE);
}

+ (void)markGoalInsideSprintFor:(NSString *)scrumKey withArtifact:(Artifacts *)currentArtifact andSelected:(NSInteger)selectedIndex withPath:(NSInteger)indexPath withCompletion:(void (^)(BOOL completed))block
{

    NSDictionary *currentSprint = currentArtifact.sprintCollection[selectedIndex];
    NSMutableArray *goalRefs = [currentSprint[kSprintGoalReference] mutableCopy];
    NSMutableDictionary *currentGoal = [goalRefs[indexPath] mutableCopy]; // current goal from ref
    currentGoal[kScrumSprintCompleted] = @(1);
    NSDate *today = [NSDate date];
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    [formatter setDateFormat:@"MMM d YYYY"];
    NSString *stringFromDate = [formatter stringFromDate:today];
    currentGoal[kScrumSprintFinishDate] = stringFromDate;
    goalRefs[indexPath] = currentGoal;
    FIRDatabaseReference *reference = [[[[self scrumRef] child:scrumKey] child:kSprintHead] child:[NSString stringWithFormat:@"%ld", (long)selectedIndex]];
    [reference updateChildValues:@{kSprintGoalReference:goalRefs}];
    block(TRUE);
}

// HANDLE: chatroomHandle
#pragma mark - Chatroom Functions

+ (void)observeChatroomFor:(NSString *)teamName withCompletion:(void (^)(Chatroom *updatedChat))block
{
    FIRDatabaseReference *chat = [[self chatRef] child:teamName];
    [FirebaseManager sharedInstance].chatroomHandle = [chat observeEventType:FIRDataEventTypeValue
                                                                   withBlock:^(FIRDataSnapshot *_Nonnull snapshot) {

        if ([snapshot.value isEqual:@(-1)]) {
            NSMutableArray *emptyUsers = [[NSMutableArray alloc] init];
            NSMutableArray *emptyMessages = [[NSMutableArray alloc] init];
            Chatroom *newChatroom = [[Chatroom alloc] initChatWithTeamName:teamName withUser:emptyUsers withMessages:emptyMessages];
            block(newChatroom);
        } else {
            __block NSMutableArray *arrayOfMsg = [(NSArray *)snapshot.value mutableCopy];
            FIRDatabaseReference *currentUsers = [[[self teamRef] child:teamName] child:kMembersHead];
            [currentUsers observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *_Nonnull snapshot) {
                NSMutableArray *arrayOfMembers = [[NSMutableArray alloc] init];
                
                for (NSString *uid in (NSArray *)snapshot.value) {
                    [arrayOfMembers addObject:uid];
                }
                Chatroom *newChatroom = [[Chatroom alloc] initChatWithTeamName:teamName withUser:arrayOfMembers withMessages:arrayOfMsg];
                block(newChatroom);
            }];
        }
    }];
}

+ (void)sendMessageForChatroom:(NSString *)teamName withMessage:(ChatroomMessage *)message withCompletion:(void (^)(BOOL completed))block
{
    FIRDatabaseReference *chat = [[self chatRef] child:teamName];
    [chat observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *_Nonnull snapshot) {
        if ([snapshot.value isEqual:@(-1)]) {
            NSMutableArray *msgArray = [[NSMutableArray alloc] init];

            NSDictionary *currentMsg = @{kChatroomSenderID:message.senderID,
                                         kChatroomSenderText:message.senderText,
                                         kChatroomDisplayName:message.displayName
                                         };
            [msgArray addObject:currentMsg];
            [[self chatRef] updateChildValues:@{teamName:msgArray}];
            block(true);
        } else {
            NSMutableArray *msgArray = [(NSArray *)snapshot.value mutableCopy];
            NSInteger count = [msgArray count];
     
            FIRDatabaseReference *messageRef = [[self chatRef] child:teamName];
                                                NSDictionary *currentMsg = @{kChatroomSenderID:message.senderID,
                                                                             kChatroomSenderText:message.senderText,
                                                                             kChatroomDisplayName:message.displayName
                                                                             };
            [messageRef updateChildValues:@{[NSString stringWithFormat:@"%ld", (long)count]:currentMsg}];
        }
    }];
}

+ (void)retreiveImageURLForTeam:(NSString *)teamName withCompletion:(void (^)(NSMutableDictionary *avatarsDict))block
{
    if (teamName != nil) {
        FIRDatabaseReference *team = [[self teamRef] child:teamName];
        [FirebaseManager sharedInstance].downloadImgHandle = [team observeEventType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *_Nonnull snapshot) {
            NSMutableDictionary *avatars = [[NSMutableDictionary alloc] init];
            NSDictionary *teamNode = (NSDictionary *)snapshot.value;
            NSArray *members = (NSArray *)teamNode[kMembersHead];
            [self getImagesForUsersArray:members withCompletion:^(NSMutableArray *urlArray) {
                int i = 0;
                
                for (NSString *user in members) {
                    avatars[user] = urlArray[i];
                    i++;
                }
                block(avatars);
            }];
        }];
    }
}

+ (void)getImagesForUsersArray:(NSArray *)array withCompletion:(void (^)(NSMutableArray *urlArray))block
{
    __block NSMutableArray *urls = [[NSMutableArray alloc] init];
    __block int i = 0;

    for (NSString *uid in array) {
        FIRDatabaseReference *userImage = [[[self userRef] child:uid] child:kCSUserPhotoURL];
         [userImage observeEventType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *_Nonnull snapshot) {
            [urls addObject:(NSString *)snapshot.value];
            i++;
    
             if (i == array.count) {
                block(urls);
            }
        }];
    }
}

+ (void)observeOnceForTeamMembers:(NSString *)teamName withCompletion:(void (^)(NSMutableArray *members))block
{
    FIRDatabaseReference *membersRef = [[self teamRef] child:teamName];
    [membersRef observeSingleEventOfType:FIRDataEventTypeValue withBlock:^(FIRDataSnapshot *_Nonnull snapshot) {
        NSMutableArray *allMembers = ((NSDictionary *)snapshot.value)[kMembersHead];
        block(allMembers);
    }];
}

+ (void)setPlaceHolderImageAsPhoto
{
    NSString *uid = [self sharedInstance].currentUser.uid;
    FIRDatabaseReference *userRef = [[self userRef] child:uid];
    [userRef updateChildValues:@{
                                  kCSUserPhotoURL:@"https://firebasestorage.googleapis.com/v0/b/code-spring-ios.appspot.com/o/UserImage.png?alt=media&token=4d5c5207-9d4a-4e98-8a99-95e7f201f44c",
                                  //kCSUserOldPhotoURL:oldPhoto
                                  }];
}

+ (void)uploadedNewPhoto:(NSURL *)newPhoto
{
    NSString *uid = [self sharedInstance].currentUser.uid;
    FIRDatabaseReference *userRef = [[self userRef] child:uid];
    NSString *photoURL = [newPhoto absoluteString];
    [userRef updateChildValues:@{
                                 kCSUserPhotoURL:photoURL
                                 }];
}

#pragma mark - Detach Observer

+ (void)removeAllObservers
{
    [[self mainRef] removeObserverWithHandle:[FirebaseManager sharedInstance].newTeamsHandle];
    [[self mainRef] removeObserverWithHandle:[FirebaseManager sharedInstance].passiveScrumHandle];
    [[self mainRef] removeObserverWithHandle:[FirebaseManager sharedInstance].scrumDeleteHandle];
    //[[self mainRef] removeObserverWithHandle:[FirebaseManager sharedInstance].chatroomHandle];
   // [[self mainRef] removeObserverWithHandle:[FirebaseManager sharedInstance].downloadImgHandle];
   // [[self mainRef] removeObserverWithHandle:[FirebaseManager sharedInstance].downloadTeamImagesHandle];
     
}

+ (void)detachChatroom
{
    [[self mainRef] removeObserverWithHandle:[FirebaseManager sharedInstance].chatroomHandle];
    [[self mainRef] removeObserverWithHandle:[FirebaseManager sharedInstance].downloadImgHandle];
    [[self mainRef] removeObserverWithHandle:[FirebaseManager sharedInstance].downloadTeamImagesHandle];
}

+ (void)detachScrum
{
    [[self mainRef] removeObserverWithHandle:[FirebaseManager sharedInstance].passiveScrumHandle];
}

+ (void)detachScrumDelete
{
    [[self mainRef] removeObserverWithHandle:[FirebaseManager sharedInstance].scrumDeleteHandle];
}

+ (void)detachNewTeams
{
    [[self mainRef] removeObserverWithHandle:[FirebaseManager sharedInstance].newTeamsHandle];
}

+ (void)detachImageDownload
{
    [[self mainRef] removeObserverWithHandle:[FirebaseManager sharedInstance].downloadImgHandle];
    //[[self mainRef] removeObserverWithHandle:[FirebaseManager sharedInstance].downloadTeamImagesHandle];
}

@end
