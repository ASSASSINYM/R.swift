//
//  ImageResource+Generator.swift
//  
//
//  Created by Tom Lokhorst on 2022-06-24.
//

import Foundation
import RswiftResources

extension ImageResource {
    public static func generateStruct(catalogs: [AssetCatalog], resources: [ImageResource], prefix: SwiftIdentifier) -> Struct {
        // Multiple resources can share same name,
        // for example: Colors.jpg and Colors@2x.jpg are both named "Colors.jpg"
        // Deduplicate these
        let namedResources = Dictionary(grouping: resources, by: \.name).values.map(\.first!)

        var merged: AssetCatalog.Namespace = catalogs.map(\.root).reduce(.init(), { $0.merging($1) })
        merged.images += namedResources

        return generateStruct(namespace: merged, name: SwiftIdentifier(name: "image"), prefix: prefix)
    }

    public static func generateStruct(namespace: AssetCatalog.Namespace, name: SwiftIdentifier, prefix: SwiftIdentifier) -> Struct {
        let structName = name
        let qualifiedName = prefix + structName
        let warning: (String) -> Void = { print("warning:", $0) }

        let groupedResources = namespace.images.grouped(bySwiftIdentifier: { $0.name })
        groupedResources.reportWarningsForDuplicatesAndEmpties(source: "image", result: "image", warning: warning)

        let letbindings = groupedResources.uniques.map { $0.generateLetBinding() }
        let otherIdentifiers = groupedResources.uniques.map { SwiftIdentifier(name: $0.name) }

        let mergedNamespaces = AssetCatalogMergedNamespaces(all: namespace.subnamespaces, otherIdentifiers: otherIdentifiers)
        mergedNamespaces.printWarningsForDuplicates(result: "image", warning: warning)

        let structs = mergedNamespaces.namespaces
            .sorted { $0.key < $1.key }
            .map { (name, namespace) in
                ImageResource.generateStruct(
                    namespace: namespace,
                    name: name,
                    prefix: qualifiedName
                )
            }
            .filter { !$0.isEmpty }
 
        let comment = [
            "This `\(qualifiedName.value)` struct is generated, and contains static references to \(letbindings.count) images",
            structs.isEmpty ? "" : ", and \(structs.count) namespaces",
            "."
        ].joined()

        let comments = [comment]
        return Struct(comments: comments, name: structName) {
            letbindings
            structs
        }
    }
}

extension ImageResource {
    func generateLetBinding() -> LetBinding {
        let locs = locale.map { $0.codeString() } ?? "nil"
        let odrt = onDemandResourceTags?.debugDescription ?? "nil"
        let fullname = (path + [name]).joined(separator: "/")
        let code = "ImageResource(name: \"\(fullname)\", locale: \(locs), onDemandResourceTags: \(odrt))"
        return LetBinding(
            comments: ["Image `\(fullname)`."],
            isStatic: true,
            name: SwiftIdentifier(name: name),
            valueCodeString: code)
    }
}
