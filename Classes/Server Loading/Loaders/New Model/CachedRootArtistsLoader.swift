//
//  CachedRootArtistsLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class CachedRootArtistsLoader: CachedDatabaseLoader {
    var artists = [Artist]()
    
    override var items: [Item] {
        return artists
    }
    
    override var associatedObject: Any? {
        return nil
    }
    
    override func loadModelsFromDatabase() -> Bool {
        artists = ArtistRepository.si.allArtists(isCachedTable: true)
        return true
    }
}
