//
//  BBSimpleConnectionQueue.h
//  iSub
//
//  Created by Ben Baron on 12/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@protocol BBSimpleConnectionQueueDelegate;

@interface BBSimpleConnectionQueue : NSObject 
{
	NSMutableArray *connectionStack;
		
	BOOL isRunning;
	
	id <BBSimpleConnectionQueueDelegate> delegate;
}

@property (readonly) NSMutableArray *connectionStack;
@property (readonly) BOOL isRunning;
@property (nonatomic, assign) id <BBSimpleConnectionQueueDelegate> delegate;

- (void)registerConnection:(NSURLConnection *)connection;
- (void)connectionFinished:(NSURLConnection *)connection;
- (void)startQueue;
- (void)stopQueue;
- (void)clearQueue;

@end

@protocol BBSimpleConnectionQueueDelegate <NSObject>
@optional
- (void)connectionQueueDidFinish:(BBSimpleConnectionQueue *)connectionQueue;
@end
