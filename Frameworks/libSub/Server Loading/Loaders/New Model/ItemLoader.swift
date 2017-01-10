//
//  ItemLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/4/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

protocol ItemLoader {
    weak var delegate: ApiLoaderDelegate? { get set }
    var completionHandler: ApiLoaderCompletionHandler? { get set }
    
    var associatedObject: Any? { get }
    
    var items: [ISMSItem] { get }
    
    var state: ApiLoaderState { get }
    
    func persistModels()
    func loadModelsFromDatabase() -> Bool
    
    func start()
    func cancel()
}
