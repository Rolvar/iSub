//
//  CacheSingleton.h
//  iSub
//
//  Created by Ben Baron on 8/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#define cacheS [CacheSingleton sharedInstance]

@interface CacheSingleton : NSObject

@property (retain) NSTimer *cacheCheckTimer;
@property NSTimeInterval cacheCheckInterval;
@property (readonly) unsigned long long totalSpace;
@property (readonly) unsigned long long cacheSize;
@property (readonly) unsigned long long freeSpace;
@property (readonly) NSUInteger numberOfCachedSongs;

+ (CacheSingleton *)sharedInstance;

- (void)startCacheCheckTimer;
- (void)startCacheCheckTimerWithInterval:(NSTimeInterval)interval;
- (void)stopCacheCheckTimer;
- (void)clearTempCache;
- (void)findCacheSize;


@end
