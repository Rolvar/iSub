//
//  PlaylistSongUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@class iSubAppDelegate, ViewObjectsSingleton;

@interface CurrentPlaylistSongSmallUITableViewCell : UITableViewCell 
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	
	NSIndexPath *indexPath;
	
	UIImageView *deleteToggleImage;
	BOOL isDelete;
	
	UILabel *numberLabel;
	UILabel *songNameLabel;
	UILabel *artistNameLabel;
	UILabel *durationLabel;
}

@property (nonatomic, retain) NSIndexPath *indexPath;

@property (nonatomic, retain) UIImageView *deleteToggleImage;
@property BOOL isDelete;

@property (nonatomic, retain) UILabel *numberLabel;
@property (nonatomic, retain) UILabel *songNameLabel;
@property (nonatomic, retain) UILabel *artistNameLabel;
@property (nonatomic, retain) UILabel *durationLabel;

- (void)toggleDelete;

@end
