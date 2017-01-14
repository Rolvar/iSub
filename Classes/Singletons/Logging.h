//
//  Logging.h
//  iSub
//
//  Created by Benjamin Baron on 1/10/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

@interface Logging: NSObject

+ (NSString *)latestLogFileName;
+ (NSString *)zipAllLogFiles;
+ (void)startRedirectingLogToFile;
+ (void)stopRedirectingLogToFile;

@end