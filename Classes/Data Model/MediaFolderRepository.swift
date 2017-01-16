//
//  MediaFolderRepository.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

struct MediaFolderRepository: ItemRepository {
    static let si = MediaFolderRepository()
    fileprivate let gr = GenericItemRepository.si
    
    let table = "mediaFolders"
    let cachedTable = "cachedMediaFolders"
    let itemIdField = "mediaFolderId"
    
    func mediaFolder(mediaFolderId: Int, serverId: Int, loadSubItems: Bool = false) -> MediaFolder? {
        return gr.item(repository: self, itemId: mediaFolderId, serverId: serverId, loadSubItems: loadSubItems)
    }
    
    func allMediaFolders(serverId: Int? = nil, isCachedTable: Bool = false) -> [MediaFolder] {
        return gr.allItems(repository: self, serverId: serverId, isCachedTable: isCachedTable)
    }
    
    func deleteAllMediaFolders(serverId: Int?) -> Bool {
        return gr.deleteAllItems(repository: self, serverId: serverId)
    }
    
    func isPersisted(mediaFolder: MediaFolder, isCachedTable: Bool = false) -> Bool {
        return gr.isPersisted(repository: self, item: mediaFolder, isCachedTable: isCachedTable)
    }
    
    func hasCachedSubItems(mediaFolder: MediaFolder) -> Bool {
        return gr.hasCachedSubItems(repository: self, item: mediaFolder)
    }
    
    func delete(mediaFolder: MediaFolder, isCachedTable: Bool = false) -> Bool {
        return gr.delete(repository: self, item: mediaFolder, isCachedTable: isCachedTable)
    }
    
    func replace(mediaFolder: MediaFolder, isCachedTable: Bool = false) -> Bool {
        var success = true
        DatabaseSingleton.si().songModelWritesDbQueue.inDatabase { db in
            do {
                let table = tableName(repository: self, isCachedTable: isCachedTable)
                let query = "REPLACE INTO \(table) VALUES (?, ?, ?)"
                try db.executeUpdate(query, mediaFolder.mediaFolderId, mediaFolder.serverId, mediaFolder.name)
            } catch {
                success = false
                printError(error)
            }
        }
        return success
    }
    
    func loadSubItems(mediaFolder: MediaFolder) {
        mediaFolder.folders = FolderRepository.si.rootFolders(mediaFolderId: mediaFolder.mediaFolderId, serverId: mediaFolder.serverId)
        mediaFolder.songs = SongRepository.si.rootSongs(mediaFolderId: mediaFolder.mediaFolderId, serverId: mediaFolder.serverId)
    }
}

extension MediaFolder: PersistedItem {
    class func item(itemId: Int, serverId: Int, repository: ItemRepository = MediaFolderRepository.si) -> Item? {
        return (repository as? MediaFolderRepository)?.mediaFolder(mediaFolderId: itemId, serverId: serverId)
    }
    
    var isPersisted: Bool {
        return repository.isPersisted(mediaFolder: self)
    }
    
    var hasCachedSubItems: Bool {
        return repository.hasCachedSubItems(mediaFolder: self)
    }
    
    func replace() -> Bool {
        return repository.replace(mediaFolder: self)
    }
    
    func cache() -> Bool {
        return repository.replace(mediaFolder: self, isCachedTable: true)
    }
    
    func delete() -> Bool {
        return repository.delete(mediaFolder: self)
    }
    
    func deleteCache() -> Bool {
        return repository.delete(mediaFolder: self, isCachedTable: true)
    }
    
    func loadSubItems() {
        repository.loadSubItems(mediaFolder: self)
    }
}
