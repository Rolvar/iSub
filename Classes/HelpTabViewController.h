//
//  HelpTabViewController.h
//  iSub
//
//  Created by Ben Baron on 6/29/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@class iSubAppDelegate;

@interface HelpTabViewController : UIViewController 
{
	iSubAppDelegate *appDelegate;
	
	IBOutlet UIWebView *helpWebView;
}

@property (nonatomic, retain) UIWebView *helpWebView;

@end
