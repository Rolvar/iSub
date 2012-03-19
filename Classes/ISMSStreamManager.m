//
//  ISMSStreamManager.m
//  iSub
//
//  Created by Benjamin Baron on 11/10/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSStreamManager.h"
#import "DatabaseSingleton.h"
#import "FMDatabaseAdditions.h"
#import "Song.h"
#import "NSString+md5.h"
#import "NSMutableURLRequest+SUS.h"
#import "SavedSettings.h"
#import "NSString+URLEncode.h"
#import "MusicSingleton.h"
#import "ISMSStreamHandler.h"
#import "PlaylistSingleton.h"
#import "NSArray+FirstObject.h"
#import "AudioEngine.h"
#import "SUSCoverArtLoader.h"
#import "SUSLyricsDAO.h"
#import "ViewObjectsSingleton.h"
#import "NSArray+Additions.h"
#import "iSubAppDelegate.h"
#import "ISMSCacheQueueManager.h"
#import "NSNotificationCenter+MainThread.h"

#define maxNumOfReconnects 5

@implementation ISMSStreamManager
@synthesize handlerStack, lyricsDAO, lastCachedSong, lastTempCachedSong;

- (ISMSStreamHandler *)handlerForSong:(Song *)aSong
{
	if (!aSong)
		return nil;
	
	for (ISMSStreamHandler *handler in self.handlerStack)
	{
		if ([handler.mySong isEqualToSong:aSong])
		{
			DLog(@"handler.mySong: %@    aSong: %@", handler.mySong.title, aSong.title);
			return handler;
		}
	}
	return nil;
}

- (BOOL)isSongFirstInQueue:(Song *)aSong
{
	if (!aSong)
		return NO;
	
	ISMSStreamHandler *firstHandler = [self.handlerStack firstObjectSafe];
	return [aSong isEqualToSong:firstHandler.mySong];
}

- (BOOL)isSongDownloading:(Song *)aSong
{
	if (!aSong)
		return NO;
	
	return [self handlerForSong:aSong].isDownloading;
}

- (BOOL)isQueueDownloading
{
	for (ISMSStreamHandler *handler in self.handlerStack)
	{
		if (handler.isDownloading)
			return YES;
	}
	return NO;
}

// Main worker method
- (void)cancelAllStreamsExcept:(NSArray *)handlersToSkip
{
	// Cancel the handlers
	for (ISMSStreamHandler *handler in self.handlerStack)
	{
		if (![handlersToSkip containsObject:handler])
		{
			if (handler.isDownloading)
			{
				if (!cacheQueueManagerS.isQueueDownloading)
					[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
			}
			
			// If we're trying to resume, cancel the request
			[NSObject cancelPreviousPerformRequestsWithTarget:self 
													 selector:@selector(resumeHandler:)
													   object:handler];
			
			// Cancel the handler
			[handler cancel];
		}
	}
	
	[self saveHandlerStack];
}

// Convenience method
- (void)cancelAllStreamsExceptForSongs:(NSArray *)songsToSkip
{
	// If songsToSkip == nil, just cancel all handlers
	if (!songsToSkip)
	{
		[self cancelAllStreams];
		return;
	}
	
	// Gather the handler objects to cancel
	NSMutableArray *handlersToSkip = [NSMutableArray arrayWithCapacity:[songsToSkip count]];
	for (Song *aSong in songsToSkip)
	{
		ISMSStreamHandler *handler = [self handlerForSong:aSong];
		if (handler)
			[handlersToSkip addObject:[self handlerForSong:aSong]];
	}
	
	// Cancel the other handlers
	[self cancelAllStreamsExcept:handlersToSkip];
}

// Convenience method
- (void)cancelAllStreamsExceptForSong:(Song *)aSong
{
	// If aSong == nil, just cancel all handlers
	if (![self handlerForSong:aSong])
	{
		[self cancelAllStreams];
		return;
	}
	
	// Create the handler array with the one object
	NSArray *handlersToSkip = [NSArray arrayWithObject:[self handlerForSong:aSong]];
	
	// Cancel the other handlers
	[self cancelAllStreamsExcept:handlersToSkip];
}

// Convenience method
- (void)cancelAllStreams
{
	[self cancelAllStreamsExcept:nil];
}

// Main worker method
- (void)cancelStreamAtIndex:(NSUInteger)index
{
	if (index < [self.handlerStack count])
	{
		// Find the handler object and cancel it
		ISMSStreamHandler *handler = [self.handlerStack objectAtIndexSafe:index];
		
		if (handler.isDownloading)
		{
			if (!cacheQueueManagerS.isQueueDownloading)
				[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
		}
		
		[handler cancel];
		
		// If we're trying to resume, cancel the request
		[NSObject cancelPreviousPerformRequestsWithTarget:self 
												 selector:@selector(resumeHandler:)
												   object:handler];
	}
	
	[self saveHandlerStack];
}

// Convenience method
- (void)cancelStream:(ISMSStreamHandler *)handler
{
	// If handler == nil, do nothing
	if (!handler)
		return;
	
	// Get the handler index
	NSUInteger index = [self.handlerStack indexOfObject:handler];
	
	// Cancel the handler
	[self cancelStreamAtIndex:index];
}

// Convenience method
- (void)cancelStreamForSong:(Song *)aSong
{
	// If aSong == nil, do nothing
	if (!aSong)
		return;
	
	// Cancel the handler
	[self cancelStream:[self handlerForSong:aSong]];
}

// Main worker method
- (void)removeAllStreamsExcept:(NSArray *)handlersToSkip
{
	// Cancel the handlers
	[self cancelAllStreamsExcept:handlersToSkip];
	
	// Remove the handlers
	NSArray *handlers = [NSArray arrayWithArray:self.handlerStack];
	for (ISMSStreamHandler *handler in handlers)
	{
		if (![handlersToSkip containsObject:handler])
		{
			[self.handlerStack removeObject:handler];
			[handler.mySong removeFromCachedSongsTable];
		}
	}
	
	// Start the next handler
	if ([self.handlerStack count] > 0)
	{
		// Get the first handler
		ISMSStreamHandler *handler = [self.handlerStack firstObject];
		
		// If it's not already downloading, start downloading
		if (!handler.isDownloading)
		{
			[handler start];
		}
	}
	
	[self saveHandlerStack];
}

// Convenience method
- (void)removeAllStreamsExceptForSongs:(NSArray *)songsToSkip
{
	// If songsToSkip == nil, remove all handlers
	if (!songsToSkip)
	{
		[self removeAllStreams];
		return;
	}
	
	// Gather the handler objects to skip
	NSMutableArray *handlersToSkip = [NSMutableArray arrayWithCapacity:[songsToSkip count]];
	for (Song *aSong in songsToSkip)
	{
		ISMSStreamHandler *handler = [self handlerForSong:aSong];
		if (handler) 
			[handlersToSkip addObject:[self handlerForSong:aSong]];
	}
	
	// Remove the other handlers
	[self removeAllStreamsExcept:handlersToSkip];
}

// Convenience method
- (void)removeAllStreamsExceptForSong:(Song *)aSong
{
	// If aSong == nil, remove all handlers
	if (![self handlerForSong:aSong])
	{
		[self removeAllStreams];
		return;
	}
	
	// Get the handler to skip
	NSArray *handlersToSkip = [NSArray arrayWithObject:[self handlerForSong:aSong]];
	
	// Remove the other handlers
	[self removeAllStreamsExcept:handlersToSkip];
}

// Convenience method
- (void)removeAllStreams
{
	[self cancelAllStreams];
	[self removeAllStreamsExcept:nil];
}

// Main worker method
- (void)removeStreamAtIndex:(NSUInteger)index
{
	if (index < [self.handlerStack count])
	{
		[self cancelStreamAtIndex:index];
		
		ISMSStreamHandler *handler = [self.handlerStack objectAtIndex:index];
		if (!handler.mySong.isFullyCached)
			[handler.mySong removeFromCachedSongsTable];
		[self.handlerStack removeObjectAtIndex:index];
	}
	
	[self saveHandlerStack];
}

// Convenience method
- (void)removeStream:(ISMSStreamHandler *)handler
{
	// If handler == nil, do nothing
	if (!handler)
		return;
	
	// Remove the handler
	[self removeStreamAtIndex:[self.handlerStack indexOfObject:handler]];
}

// Convenience method
- (void)removeStreamForSong:(Song *)aSong
{
	// If aSong == nil, do nothing
	if (!aSong)
		return;
	
	// Remove the handler
	[self removeStream:[self handlerForSong:aSong]];
}

- (void)resumeQueue
{
	[self resumeHandler:[self.handlerStack firstObjectSafe]];
}

- (void)resumeHandler:(ISMSStreamHandler *)handler
{
	if (!handler)
		return; 
	
	// As an added check, verify that this handler is still in the stack
	if ([self isSongInQueue:handler.mySong])
	{
		[handler start:YES];
	}
}

- (void)startHandler:(ISMSStreamHandler *)handler resume:(BOOL)resume
{
	if (!handler)
		return;
	
	[handler start:resume];
	[lyricsDAO loadLyricsForArtist:handler.mySong.artist andTitle:handler.mySong.title];
}

- (void)startHandler:(ISMSStreamHandler *)handler
{
	if (!handler)
		return;
	
	[self startHandler:handler resume:NO];
}

- (void)saveHandlerStack
{
	NSData *data = [NSKeyedArchiver archivedDataWithRootObject:self.handlerStack];
	if (data)
	{
		[[NSUserDefaults standardUserDefaults] setObject:data forKey:@"handlerStack"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
}

- (void)loadHandlerStack
{	
	NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:@"handlerStack"];
	if (data) 
		self.handlerStack = [NSKeyedUnarchiver unarchiveObjectWithData:data];

	for (ISMSStreamHandler *handler in self.handlerStack)
	{
		handler.delegate = self;
	}
}

#pragma mark Download

- (void)queueStreamForSong:(Song *)song byteOffset:(unsigned long long)byteOffset secondsOffset:(double)secondsOffset atIndex:(NSUInteger)index isTempCache:(BOOL)isTemp isStartDownload:(BOOL)isStartDownload
{
	if (!song)
		return;
	
	ISMSStreamHandler *handler = [[ISMSStreamHandler alloc] initWithSong:song 
															byteOffset:byteOffset
														 secondsOffset:secondsOffset
																isTemp:isTemp
															  delegate:self];
	if (![self.handlerStack containsObject:handler])
	{
		[self.handlerStack insertObject:handler atIndex:index];
		[handler release];
		
		if ([self.handlerStack count] == 1 && isStartDownload)
		{
			[self startHandler:handler];
		}
		
		// Also download the album art
		if (song.coverArtId)
		{
			SUSCoverArtLoader *playerArt = [[SUSCoverArtLoader alloc] initWithDelegate:self coverArtId:song.coverArtId isLarge:YES];
			if (![playerArt downloadArtIfNotExists])
				[playerArt release];
			
			SUSCoverArtLoader *tableArt = [[SUSCoverArtLoader alloc] initWithDelegate:self coverArtId:song.coverArtId isLarge:NO];
			if (![tableArt downloadArtIfNotExists])
				[tableArt release];
		}
	}
	
	[self saveHandlerStack];
}

- (void)queueStreamForSong:(Song *)song atIndex:(NSUInteger)index isTempCache:(BOOL)isTemp isStartDownload:(BOOL)isStartDownload
{	
	[self queueStreamForSong:song byteOffset:0 secondsOffset:0.0 atIndex:index isTempCache:isTemp isStartDownload:isStartDownload];
}

- (void)queueStreamForSong:(Song *)song byteOffset:(unsigned long long)byteOffset secondsOffset:(double)secondsOffset isTempCache:(BOOL)isTemp isStartDownload:(BOOL)isStartDownload
{
	[self queueStreamForSong:song byteOffset:byteOffset secondsOffset:secondsOffset atIndex:[self.handlerStack count] isTempCache:isTemp isStartDownload:isStartDownload];
}

- (void)queueStreamForSong:(Song *)song isTempCache:(BOOL)isTemp isStartDownload:(BOOL)isStartDownload
{	
	[self queueStreamForSong:song byteOffset:0 secondsOffset:0.0 atIndex:[self.handlerStack count] isTempCache:isTemp isStartDownload:isStartDownload];
}

- (BOOL)isSongInQueue:(Song *)aSong
{
	BOOL isSongInQueue = NO;
	for (ISMSStreamHandler *handler in self.handlerStack)
	{
		if ([handler.mySong isEqualToSong:aSong])
		{
			isSongInQueue = YES;
			break;
		}
	}
	return isSongInQueue;
}

- (void)fillStreamQueue:(BOOL)isStartDownload
{	
	NSUInteger numStreamsToQueue = 1;
	if (settingsS.isNextSongCacheEnabled)
	{
		numStreamsToQueue = ISMSNumberOfStreamsToQueue;
	}
	
	if ([self.handlerStack count] < numStreamsToQueue)
	{
		NSInteger currentIndex = playlistS.currentIndex;
		for (int i = currentIndex; i < currentIndex + numStreamsToQueue; i++)
		{
			Song *aSong = [playlistS songForIndex:i];
			if (aSong && ![self isSongInQueue:aSong] && !aSong.isFullyCached && !viewObjectsS.isOfflineMode)
			{
				// The cache queue is downloading this song, remove it before continuing
				if ([cacheQueueManagerS.currentQueuedSong isEqualToSong:aSong])
				{
					[cacheQueueManagerS removeCurrentSong];
				}	
				
				// Queue the song for download
				[self queueStreamForSong:aSong isTempCache:!settingsS.isSongCachingEnabled isStartDownload:isStartDownload];
			}
		}
	}
}

- (void)fillStreamQueue
{
	[self fillStreamQueue:YES];
}

- (void)songCachingToggled
{
	if (settingsS.isSongCachingEnabled)
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(fillStreamQueue) 
													 name:ISMSNotification_SongPlaybackEnded 
												   object:nil];
	else
		[[NSNotificationCenter defaultCenter] removeObserver:self 
														name:ISMSNotification_SongPlaybackEnded 
													  object:nil];
}

- (void)currentPlaylistIndexChanged
{
	// TODO: Fix this logic, it's wrong
	// Verify that the last song is not constantly retrying to connect, 
	// so the current song can download and play
	[self removeStreamForSong:playlistS.prevSong];
}

- (void)currentPlaylistOrderChanged
{
	Song *currentSong = playlistS.currentSong;
	Song *nextSong = playlistS.nextSong;
	NSMutableArray *songsToSkip = [NSMutableArray arrayWithCapacity:2];
	if (currentSong) [songsToSkip addObject:currentSong];
	if (nextSong) [songsToSkip addObject:nextSong];
	
	[self removeAllStreamsExceptForSongs:songsToSkip];
	[self fillStreamQueue:audioEngineS.isStarted];
}

#pragma mark - ISMSStreamHandler delegate

- (void)ISMSStreamHandlerStarted:(ISMSStreamHandler *)handler
{
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;

	if (handler.isTempCache)
		self.lastTempCachedSong = nil;
}

- (void)ISMSStreamHandlerPartialPrecachePaused:(ISMSStreamHandler *)handler
{
	if (!cacheQueueManagerS.isQueueDownloading)
		[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
}

- (void)ISMSStreamHandlerPartialPrecacheUnpaused:(ISMSStreamHandler *)handler
{
	[UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

- (void)ISMSStreamHandlerStartPlayback:(ISMSStreamHandler *)handler
{	
	// Update the last cached song
	self.lastCachedSong = handler.mySong;
	
	Song *currentSong = playlistS.currentSong;
	Song *nextSong = playlistS.nextSong;
	
	DLog(@"starting playback for %@  file size: %llu", handler.mySong, handler.totalBytesTransferred);
	
	if ([handler.mySong isEqualToSong:currentSong])
	{
		[audioEngineS start];
		
		// Only for temp cached files
		if (handler.isTempCache)
		{
			DLog(@"byteOffset: %llu   secondsOffset: %f", handler.byteOffset, handler.secondsOffset);
			audioEngineS.startByteOffset = handler.byteOffset;
			audioEngineS.startSecondsOffset = handler.secondsOffset;;
		}
	}
	else if ([handler.mySong isEqualToSong:nextSong])
	{
		//DLog(@"preparing next song stream");
		[audioEngineS prepareNextSongStream];
	}
	
	[self saveHandlerStack];
}

- (void)ISMSStreamHandlerConnectionFailed:(ISMSStreamHandler *)handler withError:(NSError *)error
{
	if (!cacheQueueManagerS.isQueueDownloading)
		[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;

	//DLog(@"stream handler failed: %@", handler);
	if (handler.numOfReconnects < maxNumOfReconnects)
	{
		//DLog(@"retrying stream handler");
		// Less than max number of reconnections, so try again 
		handler.numOfReconnects++;
		// Retry connection after a delay to prevent a tight loop
		[self performSelector:@selector(resumeHandler:) withObject:handler afterDelay:1.5];
		//[self startHandler:handler resume:YES];
	}
	else
	{
		//DLog(@"removing stream handler");
		//DLog(@"handlerStack: %@", self.handlerStack);
		// Tried max number of times so remove
		[self removeStream:handler];
	}
}

- (void)ISMSStreamHandlerConnectionFinished:(ISMSStreamHandler *)handler
{	
	if (!cacheQueueManagerS.isQueueDownloading)
		[UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
	
	if (handler.totalBytesTransferred < 500)
	{
		// Show an alert and delete the file, this was not a song but an XML error
		// TODO: Parse with TBXML and display proper error
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"No song data returned. This could be because your Subsonic API trial has expired, this song is not an mp3 and the Subsonic transcoding plugins failed, or another reason." delegate:appDelegateS cancelButtonTitle:@"OK" otherButtonTitles: nil];
		[alert show];
		[alert release];
		[[NSFileManager defaultManager] removeItemAtPath:handler.filePath error:NULL];
	}
	else
	{		
		// Mark song as cached
		//DLog(@"Stream handler connection did finish for %@", mySong);
		if (!handler.isTempCache)
			handler.mySong.isFullyCached = YES;
	}
	
	// Update the last cached song
	self.lastCachedSong = handler.mySong;
		
	if (handler.isTempCache)
		self.lastTempCachedSong = handler.mySong;
	
	// Remove the handler from the stack
	[self removeStream:handler];
		
	// Start the next handler which is now the first object
	if ([self.handlerStack count] > 0)
	{
		ISMSStreamHandler *handler = (ISMSStreamHandler *)[self.handlerStack firstObjectSafe];
		[self startHandler:handler];
	}
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_StreamHandlerSongDownloaded];
}

#pragma mark - SUSLoader handler

- (void)loadingFailed:(SUSLoader *)theLoader withError:(NSError *)error
{
	theLoader.delegate = nil;
    [theLoader release];
}

- (void)loadingFinished:(SUSLoader *)theLoader
{
	theLoader.delegate = nil;
    [theLoader release];
}

#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
	DLog(@"received memory warning");
	
	
}

#pragma mark - Singleton methods

static ISMSStreamManager *sharedInstance = nil;

- (void)setup
{
	// Load the handler stack, it may have been full when iSub was closed
	[self loadHandlerStack];
	handlerStack = handlerStack ? handlerStack : [[NSMutableArray alloc] initWithCapacity:0];
	if ([handlerStack count] > 0)
	{
		if ([(ISMSStreamHandler *)[handlerStack firstObject] isTempCache])
		{
			[self removeAllStreams];
		}
		else
		{
			for (ISMSStreamHandler *handler in handlerStack)
			{
				// Resume any handlers that were downloading when iSub closed
				if (handler.isDownloading && !handler.isTempCache)
				{
					[handler start:YES];
				}
			}
		}
	}
	
	lastCachedSong = nil;
	lyricsDAO = [[SUSLyricsDAO alloc] initWithDelegate:self]; 
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(songCachingToggled) 
												 name:ISMSNotification_SongCachingEnabled object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(songCachingToggled) 
												 name:ISMSNotification_SongCachingDisabled object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(currentPlaylistIndexChanged) 
												 name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];
	
	if (settingsS.isSongCachingEnabled)
		[[NSNotificationCenter defaultCenter] addObserver:self 
												 selector:@selector(fillStreamQueue) 
													 name:ISMSNotification_SongPlaybackEnded object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(currentPlaylistOrderChanged) 
												 name:ISMSNotification_RepeatModeChanged object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(currentPlaylistOrderChanged) 
												 name:ISMSNotification_CurrentPlaylistOrderChanged object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(currentPlaylistOrderChanged) 
												 name:ISMSNotification_CurrentPlaylistShuffleToggled object:nil];
	
	[[NSNotificationCenter defaultCenter] addObserver:self 
											 selector:@selector(didReceiveMemoryWarning) 
												 name:UIApplicationDidReceiveMemoryWarningNotification 
											   object:nil];
}

+ (ISMSStreamManager *)sharedInstance
{
    @synchronized(self)
    {
        if (sharedInstance == nil)
			[[self alloc] init];
    }
    return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone 
{
    @synchronized(self) 
	{
        if (sharedInstance == nil) 
		{
            sharedInstance = [super allocWithZone:zone];
            return sharedInstance;  // assignment and return on first allocation
        }
    }
    return nil; // on subsequent allocation attempts return nil
}

-(id)init 
{
	if ((self = [super init]))
	{
		[self setup];
		sharedInstance = self;
	}
    
	return self;
}


- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain 
{
    return self;
}

- (unsigned)retainCount 
{
    return UINT_MAX;  // denotes an object that cannot be released
}

- (oneway void)release 
{
    //do nothing
}

- (id)autorelease 
{
    return self;
}


@end
