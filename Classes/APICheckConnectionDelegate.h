//
//  APICheckConnectionDelegate.h
//  iSub
//
//  Created by Ben Baron on 12/14/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@interface APICheckConnectionDelegate : NSObject 
{
	NSMutableData *receivedData;
}

@property (nonatomic, retain) NSMutableData *receivedData;


@end
