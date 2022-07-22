//
//  StoryboardIdentifier.swift
//  
//
//  Created by Tom Lokhorst on 2022-07-22.
//

import Foundation

public protocol StoryboardIdentifier {
    static var identifier: String { get }
}

public struct ViewControllerIdentifier<ViewController> {
    public let identifier: String

    public init(identifier: String) {
        self.identifier = identifier
    }
}

public struct SegueIdentifier<Segue, Source, Destination> {
    public let identifier: String

    public init(identifier: String) {
        self.identifier = identifier
    }
}
