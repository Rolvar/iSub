//
//  HomeAlbumViewController.h
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewController.h"
#import "ISMSLoaderDelegate.h"

@class ISMSArtist, ISMSAlbum, ISMSQuickAlbumsLoader;
@interface HomeAlbumViewController : CustomUITableViewController <ISMSLoaderDelegate>

@property (nonatomic, strong) ISMSQuickAlbumsLoader *loader;

@property (nonatomic, strong) NSMutableArray *listOfAlbums;
@property (nonatomic, copy) NSString *modifier;
@property (nonatomic) NSUInteger offset;
@property (nonatomic) BOOL isMoreAlbums;
@property (nonatomic) BOOL isLoading;

@end
