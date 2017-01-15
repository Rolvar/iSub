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
    let itemId = "mediaFolderId"
    
    func mediaFolder(mediaFolderId: Int, serverId: Int, loadSubItems: Bool = false) -> Album? {
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
                print("DB Error: \(error)")
            }
        }
        return success
    }
    
    func folders(mediaFolderId: Int, serverId: Int, isCachedTable: Bool) -> [Folder] {
        var folders = [Folder]()
        DatabaseSingleton.si().songModelReadDbPool.inDatabase { db in
            let table = tableName(repository: self, isCachedTable: isCachedTable)
            let query = "SELECT * FROM \(table) WHERE mediaFolderId = ? AND serverId = ? AND parentFolderId IS NULL"
            do {
                let result = try db.executeQuery(query, mediaFolderId, serverId)
                while result.next() {
                    let folder = Folder(result: result)
                    folders.append(folder)
                }
                result.close()
            } catch {
                print("DB Error: \(error)")
            }
        }
        return folders
    }
    
    func loadSubItems(mediaFolder: MediaFolder) {
        mediaFolder.folders = folders(mediaFolderId: mediaFolder.mediaFolderId, serverId: mediaFolder.serverId, isCachedTable: false)
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
    
    func loadSubItems() {
        repository.loadSubItems(mediaFolder: self)
    }
}