//
//  MGLAppDelegate.h
//  MapGL
//
//  Created by Paul Spencer on 2012-10-03.
//  Copyright (c) 2012 DM Solutions Group Inc. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MGLViewController.h"

@interface MGLAppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (strong, nonatomic) MGLViewController *viewController;

@end
