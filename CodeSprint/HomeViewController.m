//
//  HomeViewController.m
//  CodeSprint
//
//  Created by Vincent Chau on 6/22/16.
//  Copyright © 2016 Vincent Chau. All rights reserved.
//

#import "HomeViewController.h"
#import <AFNetworking.h>
#import <UIImageView+AFNetworking.h>
#import "FirebaseManager.h"
#import "SettingsTableViewCell.h"
#import "Constants.h"
@interface HomeViewController () <UITableViewDelegate, UITableViewDataSource>

@property (weak, nonatomic) IBOutlet UIImageView *profilePictureImageView;
@property (weak, nonatomic) IBOutlet UITableView *menuTableView;
@property (weak, nonatomic) IBOutlet UIStackView *homeStackView;


@end

@implementation HomeViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self setupViews];
    self.menuTableView.dataSource = self;
    self.menuTableView.delegate = self;
    
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/
#pragma mark - Helper Methods
-(void)setupViews{
    NSURLRequest *request = [NSURLRequest requestWithURL:[FirebaseManager sharedInstance].photoUrl];
    [self.profilePictureImageView setImageWithURLRequest:request placeholderImage:nil success:^(NSURLRequest * _Nonnull request, NSHTTPURLResponse * _Nullable response, UIImage * _Nonnull image) {
        self.profilePictureImageView.image = image;

    } failure:^(NSURLRequest * _Nonnull request, NSHTTPURLResponse * _Nullable response, NSError * _Nonnull error) {
        NSLog(@"error in downloading image");
    }];
}

#pragma mark - UITableViewDelegate
-(UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath{
    SettingsTableViewCell* cell = [tableView dequeueReusableCellWithIdentifier:@"OptionsCell" forIndexPath:indexPath];
    
    [cell configureCellForIndexPath:indexPath];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    return cell;
}
-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath{
    
}
-(CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath{
    return 78.0f;
}
-(NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section{
    return 4;
}
-(NSInteger)numberOfSectionsInTableView:(UITableView *)tableView{
    return 1;
}

@end
