//
//  AnimationGenerator.h
//  CodeSprint
//
//  Created by Vincent Chau on 6/24/16.
//  Copyright © 2016 Vincent Chau. All rights reserved.
//


#import <UIKit/UIKit.h>


@interface AnimationGenerator : NSObject
+ (CGPoint) offScreenRight;
+ (CGPoint) offScreenLeft;
+ (CGPoint) offScreenCenter;

@property (strong, nonatomic) NSArray *allConstraints;

-(id)initWithConstraints:(NSArray*)constraints;
-(void)animateScreenWithDelay:(double)delay;
@end
