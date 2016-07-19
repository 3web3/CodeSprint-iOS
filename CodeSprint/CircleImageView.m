//
//  CircleImageView.m
//  CodeSprint
//
//  Created by Vincent Chau on 6/23/16.
//  Copyright © 2016 Vincent Chau. All rights reserved.
//

#import "CircleImageView.h"
#import "Constants.h"
@implementation CircleImageView

-(void)awakeFromNib{
    [super awakeFromNib];
    self.layer.cornerRadius = self.frame.size.width / 2.0f;
    self.clipsToBounds = YES;
//    self.layer.borderWidth = 0.5f;
//    self.layer.borderColor = [UIColor colorWithRed:SHADOW_COLOR green:SHADOW_COLOR blue:SHADOW_COLOR alpha:0.5].CGColor;
//    
    self.layer.shadowColor = [UIColor colorWithRed:SHADOW_COLOR green:SHADOW_COLOR blue:SHADOW_COLOR alpha:0.5].CGColor;
    self.layer.shadowOpacity = 0.8;
    self.layer.shadowRadius = 5.0;
    self.layer.shadowOffset = CGSizeMake(0.0, 2.0);
    
}


@end
