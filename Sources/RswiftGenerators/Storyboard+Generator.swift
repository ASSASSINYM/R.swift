//
//  StoryboardResource+Generator.swift
//  
//
//  Created by Tom Lokhorst on 2022-06-24.
//

import Foundation
import RswiftResources

extension StoryboardResource {
    public static func generateStruct(storyboards: [StoryboardResource], prefix: SwiftIdentifier) -> Struct {
        let structName = SwiftIdentifier(name: "storyboard")
        let qualifiedName = prefix + structName

        let warning: (String) -> Void = { print("warning:", $0) }

        let groupedStoryboards = storyboards.grouped(bySwiftIdentifier: { $0.name })
        groupedStoryboards.reportWarningsForDuplicatesAndEmpties(source: "storyboard", result: "storyboard", warning: warning)

        let structs = groupedStoryboards.uniques
            .map { $0.generateStruct(prefix: qualifiedName, warning: warning) }
            .sorted { $0.name < $1.name }

        let comments = ["This `\(qualifiedName.value)` struct is generated, and contains static references to \(structs.count) storyboards."]

        return Struct(comments: comments, name: structName) {
            structs
        }
    }
}

extension StoryboardResource {

    func generateStruct(prefix: SwiftIdentifier, warning: (String) -> Void) -> Struct {
        let nameIdentifier = SwiftIdentifier(rawValue: "name")

        // View controllers with identifiers
        let grouped = viewControllers
          .compactMap { (vc) -> (identifier: String, vc: StoryboardResource.ViewController)? in
            guard let storyboardIdentifier = vc.storyboardIdentifier else { return nil }
            return (storyboardIdentifier, vc)
          }
          .grouped(bySwiftIdentifier: { $0.identifier })

        grouped.reportWarningsForDuplicatesAndEmpties(source: "view controller", result: "view controller identifier", warning: warning)

        let skip = grouped.uniques
            .map(\.identifier)
            .first { SwiftIdentifier(rawValue: $0) == nameIdentifier }
        if let skip = skip {
            warning("Skipping 1 view controller because symbol '\(skip)' conflicts with reserved name '\(nameIdentifier.value)'")
        }

        let letbindings = grouped.uniques
            .filter { (id, _) in SwiftIdentifier(rawValue: id) != nameIdentifier }
            .map { (id, vc) in vc.generateLetBinding(identifier: id) }
            .sorted { $0.name < $1.name }

        let letName = LetBinding(
            isStatic: true,
            name: nameIdentifier,
            valueCodeString: "\"\(name)\"")

        let identifier = SwiftIdentifier(name: name)
        let storyboardIdentifier = TypeReference(module: .host, rawName: "StoryboardIdentifier")

        return Struct(
            comments: ["Storyboard `\(name)`."],
            name: identifier,
            protocols: [storyboardIdentifier]
        ) {
            letName

            letbindings
        }
    }
}

extension StoryboardResource.ViewController {

    func generateLetBinding(identifier: String) -> LetBinding {
        let type = TypeReference(module: .host, rawName: "ViewControllerIdentifier<\(self.type.rawName)>")
        let code = #"ViewControllerIdentifier(identifier: "\#(identifier)")"#
        return LetBinding(
            isStatic: true,
            name: SwiftIdentifier(name: identifier),
            typeReference: type,
            valueCodeString: code)
    }
}
