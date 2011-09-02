//
//  BookmarksViewController.h
//  iSub
//
//  Created by Ben Baron on 5/10/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@class iSubAppDelegate, ViewObjectsSingleton, MusicSingleton, DatabaseSingleton;

@interface BookmarksViewController : UITableViewController
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
	
	BOOL isNoBookmarksScreenShowing;
	UIImageView *noBookmarksScreen;
	
	UIView *headerView;
	UILabel *bookmarkCountLabel;
	UIButton *deleteBookmarksButton;
	UILabel *deleteBookmarksLabel;
	UILabel *spacerLabel;
	UILabel *editBookmarksLabel;
	UIButton *editBookmarksButton;
}

@end
