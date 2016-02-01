//
//  PlayingViewController.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewController.h"
#import "ISMSLoaderDelegate.h"

@class SUSNowPlayingDAO;
@interface PlayingViewController : CustomUITableViewController <ISMSLoaderDelegate>

@property (nonatomic) BOOL isNothingPlayingScreenShowing;
@property (nonatomic, strong) UIImageView *nothingPlayingScreen;
@property (nonatomic, strong) NSMutableData *receivedData;
@property (nonatomic, strong) SUSNowPlayingDAO *dataModel;
@property (nonatomic) BOOL reloading;

- (void)cancelLoad;

@end
