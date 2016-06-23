//
//  FirebaseManager.h
//  CodeSprint
//
//  Created by Vincent Chau on 6/20/16.
//  Copyright © 2016 Vincent Chau. All rights reserved.
//

#import <Foundation/Foundation.h>
@import Firebase;

@interface FirebaseManager : NSObject{
     FirebaseManager* sharedInstance;
     FIRDatabaseReference *ref;
}

#pragma mark - App State Properties
@property (nonatomic, assign) BOOL signedIn;
@property (nonatomic, retain) NSString *usersName;
@property (nonatomic, retain) NSURL *photoUrl;

@end
