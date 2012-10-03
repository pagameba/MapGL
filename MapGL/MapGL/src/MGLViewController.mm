//
//  MSMapViewController.m
//  awesomeness
//
//  Created by Paul Spencer on 2012-10-01.
//  Copyright (c) 2012 DM Solutions Group Inc. All rights reserved.
//

#import "MGLViewController.h"
#import "MGLView.h"

@interface MGLViewController ()

@end

@implementation MGLViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    self.view = [[MGLView alloc] init];
    
    self.view.opaque = YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
