//
//  SavedSettings.h
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//




@interface SavedSettings : NSObject 
{
	NSUserDefaults *userDefaults;
	
	NSMutableArray *serverList;
	NSString *urlString;
	NSString *username;
	NSString *password;
	
	BOOL isPopupsEnabled;
	BOOL isJukeboxEnabled;
	BOOL isScreenSleepEnabled;
	
	// State Saving
	BOOL isPlaying;	
	BOOL isShuffle;
	NSInteger currentPlaylistPosition;
	NSInteger repeatMode;
	NSInteger bitRate;
}

// Server Login Settings
@property (nonatomic, retain) NSMutableArray *serverList;
@property (nonatomic, retain) NSString *urlString;
@property (nonatomic, retain) NSString *username;
@property (nonatomic, retain) NSString *password;

// Root Folders Settings
@property (nonatomic, retain) NSDate *rootFoldersReloadTime;
@property (nonatomic, retain) NSNumber *rootFoldersSelectedFolderId;

// Lite Version Properties
@property (readonly) BOOL isPlaylistUnlocked;
@property (readonly) BOOL isJukeboxUnlocked;
@property (readonly) BOOL isCacheUnlocked;

@property BOOL isForceOfflineMode;
@property NSInteger recoverSetting;
@property NSInteger maxBitrateWifi;
@property NSInteger maxBitrate3G;
@property BOOL isSongCachingEnabled;
@property BOOL isNextSongCacheEnabled;
@property NSInteger cachingType;
@property unsigned long long maxCacheSize;
@property unsigned long long minFreeSpace;
@property BOOL isAutoDeleteCacheEnabled;
@property NSInteger autoDeleteCacheType;
@property NSInteger cachedSongCellColorType;
@property BOOL isTwitterEnabled;
@property BOOL isLyricsEnabled;
@property BOOL isSongsTabEnabled;
@property BOOL isAutoShowSongInfoEnabled;
@property BOOL isAutoReloadArtistsEnabled;
@property float scrobblePercent;
@property BOOL isScrobbleEnabled;
@property BOOL isRotationLockEnabled;
@property BOOL isJukeboxEnabled;
@property BOOL isScreenSleepEnabled;
@property BOOL isPopupsEnabled;
@property BOOL isUpdateCheckEnabled;
@property BOOL isUpdateCheckQuestionAsked;
@property BOOL isNewSearchAPI;
@property (readonly) BOOL isTestServer;

// State Saving
@property BOOL isRecover;
@property NSUInteger seekTime;

// Document Paths
@property (readonly) NSString *documentsPath;
@property (readonly) NSString *databasePath;
@property (readonly) NSString *cachePath;
@property (readonly) NSString *tempCachePath;

- (NSString *) formatFileSize:(unsigned long long int)size;

- (void)setupSaveState;
- (void)loadState;
- (void)saveState;

+ (SavedSettings *)sharedInstance;

@end
