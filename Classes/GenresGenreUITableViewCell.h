//
//  ArtistUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 5/7/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@class CellOverlay, iSubAppDelegate, ViewObjectsSingleton, MusicSingleton, DatabaseSingleton;

@interface GenresGenreUITableViewCell : UITableViewCell 
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
	
	UIScrollView *genreNameScrollView;
	UILabel *genreNameLabel;
	
	BOOL isOverlayShowing;
	CellOverlay *overlayView;
	
	CGPoint startTouchPosition;
	BOOL swiping;
	BOOL hasSwiped;
	BOOL fingerIsMovingLeftOrRight;
	BOOL fingerMovingVertically;
}

@property (nonatomic, retain) UIScrollView *genreNameScrollView;
@property (nonatomic, retain) UILabel *genreNameLabel;

@property BOOL isOverlayShowing;
@property (nonatomic, retain) CellOverlay *overlayView;


- (BOOL)isTouchGoingLeftOrRight:(UITouch *)touch;
- (void)lookForSwipeGestureInTouches:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)hideOverlay;
- (void)showOverlay;

// Empty function
- (void)toggleDelete;

@end
