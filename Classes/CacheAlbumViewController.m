//
//  CacheAlbumViewController.m
//  iSub
//
//  Created by Ben Baron on 6/16/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CacheAlbumViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "iPadRootViewController.h"
#import "StackScrollViewController.h"
#import "iSub-Swift.h"

@interface CacheAlbumViewController() <ItemUITableViewCellDelegate>
@end

@implementation CacheAlbumViewController

@synthesize listOfAlbums, listOfSongs, sectionInfo, segments;

static NSInteger trackSort(id obj1, id obj2, void *context)
{
	NSUInteger track1TrackNum = [(NSNumber*)[(NSArray*)obj1 objectAtIndexSafe:1] intValue];
	NSUInteger track2TrackNum = [(NSNumber*)[(NSArray*)obj2 objectAtIndexSafe:1] intValue];
    NSUInteger track1DiscNum = [(NSNumber*)[(NSArray*)obj1 objectAtIndexSafe:2] intValue];
    NSUInteger track2DiscNum = [(NSNumber*)[(NSArray*)obj2 objectAtIndexSafe:2] intValue];
    
    // first check the disc numbers.  if t1d < t2d, ascending
    if (track1DiscNum < track2DiscNum)
        return NSOrderedAscending;
    
    // if they're equal, check the track numbers
    else if (track1DiscNum == track2DiscNum)
    {
        if (track1TrackNum < track2TrackNum)
            return NSOrderedAscending;
        else if (track1TrackNum == track2TrackNum)
            return NSOrderedSame;
        else
            return NSOrderedDescending;
    }
    
    // if t1d > t2d, descending
	else return NSOrderedDescending;
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	// Add the table fade
	if (!self.tableView.tableHeaderView) self.tableView.tableHeaderView = [[UIView alloc] init];		
}


-(void)viewWillAppear:(BOOL)animated 
{
	[super viewWillAppear:animated];
    
	// Add the play all button + shuffle button
	UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 50)];
	headerView.backgroundColor = ISMSHeaderColor;
	
	UILabel *playAllLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 160, 50)];
	playAllLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
	playAllLabel.backgroundColor = [UIColor clearColor];
	playAllLabel.textColor = ISMSHeaderButtonColor;
	playAllLabel.textAlignment = NSTextAlignmentCenter;
	playAllLabel.font = ISMSRegularFont(24);
	playAllLabel.text = @"Play All";
	[headerView addSubview:playAllLabel];
	
	UIButton *playAllButton = [UIButton buttonWithType:UIButtonTypeCustom];
	playAllButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
	playAllButton.frame = CGRectMake(0, 0, 160, 40);
	[playAllButton addTarget:self action:@selector(playAllAction:) forControlEvents:UIControlEventTouchUpInside];
	[headerView addSubview:playAllButton];
	
	UILabel *shuffleLabel = [[UILabel alloc] initWithFrame:CGRectMake(160, 0, 160, 50)];
	shuffleLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth;
	shuffleLabel.backgroundColor = [UIColor clearColor];
	shuffleLabel.textColor = ISMSHeaderButtonColor;
	shuffleLabel.textAlignment = NSTextAlignmentCenter;
	shuffleLabel.font = ISMSRegularFont(24);
	shuffleLabel.text = @"Shuffle";
	[headerView addSubview:shuffleLabel];
	
	UIButton *shuffleButton = [UIButton buttonWithType:UIButtonTypeCustom];
	shuffleButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleWidth;
	shuffleButton.frame = CGRectMake(160, 0, 160, 40);
	[shuffleButton addTarget:self action:@selector(shuffleAction:) forControlEvents:UIControlEventTouchUpInside];
	[headerView addSubview:shuffleButton];
	
	self.tableView.tableHeaderView = headerView;
	
	// Create the section index
	if (self.listOfAlbums.count > 10)
	{
		__block NSArray *secInfo = nil;
		[databaseS.albumListCacheDbQueue inDatabase:^(FMDatabase *db)
		{
			[db executeUpdate:@"DROP TABLE IF EXSITS albumIndex"];
			[db executeUpdate:@"CREATE TEMP TABLE albumIndex (album TEXT)"];
			
			[db beginTransaction];
			for (NSNumber *rowId in self.listOfAlbums)
			{
				@autoreleasepool 
				{
					[db executeUpdate:@"INSERT INTO albumIndex SELECT title FROM albumsCache WHERE rowid = ?", rowId];
				}
			}
			[db commit];
			
			secInfo = [databaseS sectionInfoFromTable:@"albumIndex" inDatabase:db withColumn:@"album"];
			[db executeUpdate:@"DROP TABLE IF EXISTS albumIndex"];
		}];
		
		if (secInfo)
		{
			self.sectionInfo = [NSArray arrayWithArray:secInfo];
			if ([self.sectionInfo count] < 5)
				self.sectionInfo = nil;
			else
				[self.tableView reloadData];
		}
		else
		{
			self.sectionInfo = nil;
		}
	}	
	
	// Set notification receiver for when cached songs are deleted to reload the table
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(cachedSongDeleted) name:ISMSNotification_CachedSongDeleted object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CachedSongDeleted object:nil];
}


- (void)cachedSongDeleted
{
	NSUInteger segment = self.segments.count;
	
	self.listOfAlbums = [NSMutableArray arrayWithCapacity:1];
	self.listOfSongs = [NSMutableArray arrayWithCapacity:1];
	
	NSMutableString *query = [NSMutableString stringWithFormat:@"SELECT md5, segs, seg%lu, track FROM cachedSongsLayout JOIN cachedSongs USING(md5) WHERE seg1 = ? ", (long)(segment+1)];
	for (int i = 2; i <= segment; i++)
	{
		[query appendFormat:@" AND seg%i = ? ", i];
	}
	[query appendFormat:@"GROUP BY seg%lu ORDER BY seg%lu COLLATE NOCASE", (long)(segment+1), (long)(segment+1)];
	
	[databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db)
	{
		FMResultSet *result = [db executeQuery:query withArgumentsInArray:segments];
		while ([result next])
		{
			@autoreleasepool 
			{
				NSString *md5 = [result stringForColumnIndex:0];
				NSInteger segs = [result intForColumnIndex:1];
				NSString *seg = [result stringForColumnIndex:2];
				NSInteger track = [result intForColumnIndex:3];
                NSInteger discNumber = [result intForColumn:@"discNumber"];
				
				if (segs > (segment + 1))
				{
					if (md5 && seg)
					{
                        NSArray *albumEntry = @[md5, seg];
						[self.listOfAlbums addObject:albumEntry];
					}
				}
				else
				{
					if (md5)
					{
                        NSArray *songEntry = @[md5, @(track), @(discNumber)];
						[self.listOfSongs addObject:songEntry];
						
						BOOL multipleSameTrackNumbers = NO;
						NSMutableArray *trackNumbers = [NSMutableArray arrayWithCapacity:self.listOfSongs.count];
						for (NSArray *song in self.listOfSongs)
						{
							NSNumber *track = [song objectAtIndexSafe:1];
							
							if ([trackNumbers containsObject:track])
							{
								multipleSameTrackNumbers = YES;
								break;
							}
							
							if (track)
								[trackNumbers addObject:track];
						}
						
						// Sort by track number
						if (!multipleSameTrackNumbers)
							[self.listOfSongs sortUsingFunction:trackSort context:NULL];
					}
				}
			}
		}
		[result close];
	}];
	
	// If the table is empty, pop back one view, otherwise reload the table data
	if (self.listOfAlbums.count + self.listOfSongs.count == 0)
	{
		if (IS_IPAD())
		{
			// TODO: implement this properly
			//[appDelegateS.ipadRootViewController.stackScrollViewController popToRootViewController];
		}
		else
		{
			// Handle the moreNavigationController stupidity
			if (appDelegateS.currentTabBarController.selectedIndex == 4)
			{
				[appDelegateS.currentTabBarController.moreNavigationController popToViewController:[appDelegateS.currentTabBarController.moreNavigationController.viewControllers objectAtIndexSafe:1] animated:YES];
			}
			else
			{
				[(UINavigationController*)appDelegateS.currentTabBarController.selectedViewController popToRootViewControllerAnimated:YES];
			}
		}
	}
	else
	{
		[self.tableView reloadData];
	}
}

- (void)playAllAction:(id)sender
{	
	[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
	[self performSelector:@selector(loadPlayAllPlaylist:) withObject:@"NO" afterDelay:0.05];
}

- (void)shuffleAction:(id)sender
{
	[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Shuffling"];
	[self performSelector:@selector(loadPlayAllPlaylist:) withObject:@"YES" afterDelay:0.05];
}


- (void)loadPlayAllPlaylist:(NSString *)shuffle
{		
	NSUInteger segment = [segments count];
	
	BOOL isShuffle = [shuffle isEqualToString:@"YES"];
	
	if (settingsS.isJukeboxEnabled)
	{
		[databaseS resetJukeboxPlaylist];
		[jukeboxS jukeboxClearRemotePlaylist];
	}
	else
	{
		[databaseS resetCurrentPlaylistDb];
	}
	
	NSMutableString *query = [NSMutableString stringWithString:@"SELECT md5 FROM cachedSongsLayout JOIN cachedSongs USING(md5) WHERE seg1 = ? "];
	for (int i = 2; i <= segment; i++)
	{
		[query appendFormat:@" AND seg%i = ? ", i];
	}
	[query appendString:@"ORDER BY seg1, seg2, seg3, seg4, seg5, seg6, seg7, seg8 COLLATE NOCASE"];
	
	NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:50];
	[databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db)
	{
		FMResultSet *result = [db executeQuery:query withArgumentsInArray:segments];
		while ([result next])
		{
			@autoreleasepool 
			{
				NSString *md5 = [result stringForColumnIndex:0];
				if (md5) [songMd5s addObject:md5];
			}
		}
		[result close];
	}];
	
	for (NSString *md5 in songMd5s)
	{
		@autoreleasepool 
		{
			ISMSSong *aSong = [ISMSSong songFromCacheDbQueue:md5];
			[aSong addToCurrentPlaylistDbQueue];
		}
	}
	
	if (isShuffle)
	{
		playlistS.isShuffle = YES;
		
		[databaseS resetShufflePlaylist];
		[databaseS.currentPlaylistDbQueue inDatabase:^(FMDatabase *db)
		{
			[db executeUpdate:@"INSERT INTO shufflePlaylist SELECT * FROM currentPlaylist ORDER BY RANDOM()"];
		}];
	}
	else
	{
		playlistS.isShuffle = NO;
	}
			
	// Must do UI stuff in main thread
	[EX2Dispatch runInMainThreadAndWaitUntilDone:NO block:^ { [self loadPlayAllPlaylist2]; }];
}


- (void)playAllPlaySong
{	
	[musicS playSongAtPosition:0];
	
	if (IS_IPAD())
	{
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowPlayer];
	}
	else
	{
		iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
		streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
	}
}


- (void)loadPlayAllPlaylist2
{
	[viewObjectsS hideLoadingScreen];

	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
	
	[self playAllPlaySong];
}


- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark Table view methods

// Following 2 methods handle the right side index
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView 
{
	NSMutableArray *indexes = [[NSMutableArray alloc] init];
	for (int i = 0; i < self.sectionInfo.count; i++)
	{
		[indexes addObject:[[self.sectionInfo objectAtIndexSafe:i] objectAtIndexSafe:0]];
	}
	return indexes;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index 
{
	if (index == 0)
	{
		[tableView scrollRectToVisible:CGRectMake(0, 50, 320, 40) animated:NO];
	}
	else
	{
		NSUInteger row = [[[self.sectionInfo objectAtIndexSafe:(index - 1)] objectAtIndexSafe:1] intValue];
		NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
		[tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
	}
	
	return -1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	return (self.listOfAlbums.count + self.listOfSongs.count);
}


// Customize the height of individual rows to make the album rows taller to accomidate the album art.
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath 
{
    return ISMSNormalize(indexPath.row < self.listOfAlbums.count ? ISMSAlbumCellHeight : ISMSSongCellHeight);
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{		
	// Set up the cell...
	if (indexPath.row < self.listOfAlbums.count)
	{
		static NSString *cellIdentifier = @"CacheAlbumCell";
		ItemUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (!cell)
		{
			cell = [[ItemUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            cell.alwaysShowCoverArt = YES;
            cell.delegate = self;
		}
		
		NSString *md5 = [[self.listOfAlbums objectAtIndexSafe:indexPath.row] objectAtIndexSafe:0];
		cell.coverArtId = [databaseS.songCacheDbQueue stringForQuery:@"SELECT coverArtId FROM cachedSongs WHERE md5 = ?", md5];
		cell.title = [[self.listOfAlbums objectAtIndexSafe:indexPath.row] objectAtIndexSafe:1];
        
		cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
        
		return cell;
	}
	else
	{
		static NSString *cellIdentifier = @"CacheSongCell";
		ItemUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (!cell)
		{
			cell = [[ItemUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
			cell.accessoryType = UITableViewCellAccessoryNone;
            cell.delegate = self;
            cell.showDeleteButton = YES;
		}
		
		NSUInteger a = indexPath.row - self.listOfAlbums.count;
		NSString *md5 = [[self.listOfSongs objectAtIndexSafe:a] objectAtIndexSafe:0];
		
		ISMSSong *aSong = [ISMSSong songFromCacheDbQueue:md5];
        
        cell.associatedObject = aSong;
        
        cell.trackNumber = aSong.track;
			
		cell.title = aSong.title;
		
        cell.subTitle = aSong.artistName ? aSong.artistName : @"";
        
        cell.duration = aSong.duration;
        
		cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];	
		
		return cell;
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{	
	if (!indexPath)
		return;
	
	if (viewObjectsS.isCellEnabled)
	{
		if (indexPath.row < self.listOfAlbums.count)
		{		
			NSUInteger segment = [segments count] + 1;
			
			CacheAlbumViewController *cacheAlbumViewController = [[CacheAlbumViewController alloc] initWithNibName:@"CacheAlbumViewController" bundle:nil];
			cacheAlbumViewController.title = [[listOfAlbums objectAtIndexSafe:indexPath.row] objectAtIndexSafe:1];
			cacheAlbumViewController.listOfAlbums = [NSMutableArray arrayWithCapacity:1];
			cacheAlbumViewController.listOfSongs = [NSMutableArray arrayWithCapacity:1];

			NSMutableString *query = [NSMutableString stringWithFormat:@"SELECT md5, segs, seg%lu, track, cachedSongs.discNumber FROM cachedSongsLayout JOIN cachedSongs USING(md5) WHERE seg1 = ? ", (long)(segment+1)];
			for (int i = 2; i <= segment; i++)
			{
				[query appendFormat:@" AND seg%i = ? ", i];
			}
			[query appendFormat:@"GROUP BY seg%lu ORDER BY seg%lu COLLATE NOCASE", (long)(segment+1), (long)(segment+1)];
			//DLog(@"query: %@", query);

			NSMutableArray *newSegments = [NSMutableArray arrayWithArray:segments];
			[newSegments addObject:cacheAlbumViewController.title];
			cacheAlbumViewController.segments = [NSArray arrayWithArray:newSegments];
			//DLog(@"newSegments: %@", newSegments);
			
			[databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db)
			{
				FMResultSet *result = [db executeQuery:query withArgumentsInArray:newSegments];
				while ([result next])
				{
					@autoreleasepool
					{
						NSString *md5 = [result stringForColumnIndex:0];
						NSInteger segs = [result intForColumnIndex:1];
						NSString *seg = [result stringForColumnIndex:2];
						NSInteger track = [result intForColumnIndex:3];
                        NSInteger discNumber = [result intForColumn:@"discNumber"];
						
						if (segs > (segment + 1))
						{
							if (md5 && seg)
							{
								NSArray *albumEntry = @[md5, seg];
								[cacheAlbumViewController.listOfAlbums addObject:albumEntry];
							}
						}
						else
						{
							if (md5)
							{
                                NSMutableArray *songEntry = [NSMutableArray arrayWithObjects:md5, @(track), nil];
                                
                                if (discNumber != 0)
                                {
                                    [songEntry addObject:@(discNumber)];
                                }
                                
								[cacheAlbumViewController.listOfSongs addObject:songEntry];
								
								BOOL multipleSameTrackNumbers = NO;
								NSMutableArray *trackNumbers = [NSMutableArray arrayWithCapacity:cacheAlbumViewController.listOfSongs.count];
								for (NSArray *song in cacheAlbumViewController.listOfSongs)
								{
									NSNumber *track = [song objectAtIndexSafe:1];
                                    NSNumber *disc = [song objectAtIndexSafe:2];
									
                                    // Wow, that got messy quick.  In the second part we're checking that the entry at the index
                                    // of the object we found doesn't have the same disc number as the one we're about to add.  If
                                    // it does, we have a problem, but if not, we can add it anyway and let the sort method sort it
                                    // out.  Hahah.  See what I did there?
									if ([trackNumbers containsObject:track] &&
                                        (disc == nil || [[cacheAlbumViewController.listOfSongs[[trackNumbers indexOfObject:track]] objectAtIndexSafe:2] isEqual:disc]))
									{
										multipleSameTrackNumbers = YES;
										break;
									}
									
									[trackNumbers addObject:track];
								}
								
								// Sort by track number
								if (!multipleSameTrackNumbers)
									[cacheAlbumViewController.listOfSongs sortUsingFunction:trackSort context:NULL];
							}
						}
					}
				}
				[result close];
			}];
			
			[self pushViewControllerCustom:cacheAlbumViewController];
		}
		else
		{			
			NSUInteger a = indexPath.row - self.listOfAlbums.count;
			
			if (settingsS.isJukeboxEnabled)
			{
				[databaseS resetJukeboxPlaylist];
				[jukeboxS jukeboxClearRemotePlaylist];
			}
			else
			{
				[databaseS resetCurrentPlaylistDb];
			}
			for (NSArray *song in self.listOfSongs)
			{
				ISMSSong *aSong = [ISMSSong songFromCacheDbQueue:[song objectAtIndexSafe:0]];
				[aSong addToCurrentPlaylistDbQueue];
			}
						
			playlistS.isShuffle = NO;
			
			[musicS playSongAtPosition:a];
			
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
			
			[self showPlayer];
		}
	}
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}

#pragma mark - ItemUITableViewCell Delegate -

- (void)tableCellDownloadButtonPressed:(ItemUITableViewCell *)cell
{
}

- (void)tableCellDeleteButtonPressed:(ItemUITableViewCell *)cell
{
    id associatedObject = cell.associatedObject;
    if ([associatedObject isKindOfClass:[ISMSSong class]])
    {
        [(ISMSSong *)cell.associatedObject removeFromCachedSongsTableDbQueue];
        
        [cacheS findCacheSize];
        
        // Reload the cached songs table
        [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CachedSongDeleted];
    }
    else if ([associatedObject isKindOfClass:[ISMSAlbum class]])
    {
        [viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Deleting"];
        [self performSelector:@selector(deleteAllSongs:) withObject:cell afterDelay:0.05];
    }
    
    [cell.overlayView disableDownloadButton];
}

- (void)deleteAllSongs:(ItemUITableViewCell *)cell
{
    NSMutableArray *newSegments = [NSMutableArray arrayWithArray:segments];
    [newSegments addObject:cell.title];
    
    NSUInteger segment = [newSegments count];
    
    NSMutableString *query = [NSMutableString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? "];
    for (int i = 2; i <= segment; i++)
    {
        [query appendFormat:@" AND seg%i = ? ", i];
    }
    
    DLog(@"query: %@, parameter: %@", query, newSegments);
    NSMutableArray *songMd5s = [[NSMutableArray alloc] initWithCapacity:0];
    [databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db)
     {
         FMResultSet *result = [db executeQuery:query withArgumentsInArray:newSegments];
         while ([result next])
         {
             @autoreleasepool
             {
                 NSString *md5 = [result stringForColumnIndex:0];
                 if (md5) [songMd5s addObject:md5];
             }
         }
         [result close];
     }];
    
    DLog(@"songMd5s: %@", songMd5s);
    for (NSString *md5 in songMd5s)
    {
        @autoreleasepool
        {
            [ISMSSong removeSongFromCacheDbQueueByMD5:md5];
        }
    }
    
    [cacheS findCacheSize];
    
    // Reload the cached songs table
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CachedSongDeleted];
    
    if (!cacheQueueManagerS.isQueueDownloading)
        [cacheQueueManagerS startDownloadQueue];
    
    // Hide the loading screen
    [viewObjectsS hideLoadingScreen];
}

- (void)tableCellQueueButtonPressed:(ItemUITableViewCell *)cell
{
    id associatedObject = cell.associatedObject;
    if ([associatedObject isKindOfClass:[ISMSSong class]])
    {
        [(ISMSSong *)cell.associatedObject addToCurrentPlaylistDbQueue];
        [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
    }
    else if ([associatedObject isKindOfClass:[ISMSAlbum class]])
    {
        [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
        [self performSelector:@selector(queueAllSongs:) withObject:cell afterDelay:0.05];
    }
}

- (void)queueAllSongs:(ItemUITableViewCell *)cell
{
    NSMutableArray *newSegments = [NSMutableArray arrayWithArray:segments];
    [newSegments addObject:cell.title];
    
    NSUInteger segment = [newSegments count];
    
    NSMutableString *query = [NSMutableString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE segs = %lu ", (long)(segment+1)];
    for (int i = 1; i <= segment; i++)
    {
        [query appendFormat:@" AND seg%i = ? ", i];
    }
    [query appendFormat:@"ORDER BY seg%lu COLLATE NOCASE", (long)segment+1];
    
    NSMutableArray *songMd5s = [NSMutableArray arrayWithCapacity:20];
    [databaseS.songCacheDbQueue inDatabase:^(FMDatabase *db)
     {
         FMResultSet *result = [db executeQuery:query withArgumentsInArray:newSegments];
         while ([result next])
         {
             NSString *md5 = [result stringForColumnIndex:0];
             if (md5) [songMd5s addObject:md5];
         }
         [result close];
     }];
    
    for (NSString *md5 in songMd5s)
    {
        @autoreleasepool
        {
            ISMSSong *aSong = [ISMSSong songFromCacheDbQueue:md5];
            [aSong addToCurrentPlaylistDbQueue];
        }
    }
    
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
    
    // Hide the loading screen
    [viewObjectsS hideLoadingScreen];
}


@end

