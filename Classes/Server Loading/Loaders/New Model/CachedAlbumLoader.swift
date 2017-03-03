//
//  CachedAlbumLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

final class CachedAlbumLoader: CachedDatabaseLoader {
    let albumId: Int64
    let serverId: Int64
    
    var songs = [Song]()
    var songsDuration = 0
    
    override var items: [Item] {
        return songs
    }
    
    override var associatedItem: Item? {
        return AlbumRepository.si.album(albumId: albumId, serverId: serverId)
    }
    
    init(albumId: Int64, serverId: Int64) {
        self.albumId = albumId
        self.serverId = serverId
        super.init()
    }
    
    override func loadModelsFromDatabase() -> Bool {
        songs = SongRepository.si.songs(albumId: albumId, serverId: serverId, isCachedTable: true)
        songsDuration = songs.reduce(0) { totalDuration, song -> Int in
            if let duration = song.duration {
                return totalDuration + duration
            }
            return totalDuration
        }
        return true
    }
}
