//
//  RswiftCore.swift
//  rswift
//
//  Created by Tom Lokhorst on 2021-04-16.
//

import Foundation
import ArgumentParser
import XcodeEdit
import RswiftParsers
import RswiftResources
import RswiftGenerators

public enum Generator: String, CaseIterable, ExpressibleByArgument {
    case image
    case string
    case color
    case file
    case font
    case nib
    case segue
    case storyboard
    case reuseIdentifier
    case entitlements
    case info
    case id
}

public enum AccessLevel: String, ExpressibleByArgument {
  case publicLevel = "public"
  case internalLevel = "internal"
  case filePrivate = "fileprivate"
  case privateLevel = "private"
}


public struct RswiftCore {
    let outputURL: URL
    let generators: [Generator]
    let xcodeprojURL: URL
    let targetName: String
    let productModuleName: String?
    let infoPlistFile: URL?
    let codeSignEntitlements: URL?

    let sourceTreeURLs: SourceTreeURLs

    let rswiftIgnoreURL: URL

    public init(
        outputURL: URL,
        generators: [Generator],
        xcodeprojURL: URL,
        targetName: String,
        productModuleName: String?,
        infoPlistFile: URL?,
        codeSignEntitlements: URL?,
        rswiftIgnoreURL: URL,
        sourceTreeURLs: SourceTreeURLs
    ) {
        self.outputURL = outputURL
        self.generators = generators
        self.xcodeprojURL = xcodeprojURL
        self.targetName = targetName
        self.productModuleName = productModuleName
        self.infoPlistFile = infoPlistFile
        self.codeSignEntitlements = codeSignEntitlements

        self.rswiftIgnoreURL = rswiftIgnoreURL

        self.sourceTreeURLs = sourceTreeURLs
    }

    // Temporary function for use during development
    public func developRun() throws {
        let start = Date()

        let project = try Project.parseTarget(
            name: targetName,
            xcodeprojURL: xcodeprojURL,
            rswiftIgnoreURL: rswiftIgnoreURL,
            infoPlistFile: infoPlistFile,
            codeSignEntitlements: codeSignEntitlements,
            sourceTreeURLs: sourceTreeURLs,
            warning: { print("[warning]", $0) }
        )

        let structName = SwiftIdentifier(rawValue: "_S")
        let qualifiedName = structName

        let segueStruct = Segue.generateStruct(
            storyboards: project.storyboards,
            prefix: qualifiedName
        )

        let imageStruct = ImageResource.generateStruct(
            catalogs: project.assetCatalogs,
            toplevel: project.images,
            prefix: qualifiedName
        )
        let colorStruct = ColorResource.generateStruct(
            catalogs: project.assetCatalogs,
            prefix: qualifiedName
        )
        let dataStruct = DataResource.generateStruct(
            catalogs: project.assetCatalogs,
            prefix: qualifiedName
        )

        let fileStruct = FileResource.generateStruct(
            resources: project.files,
            prefix: qualifiedName
        )

        let idStruct = AccessibilityIdentifier.generateStruct(
            nibs: project.nibs,
            storyboards: project.storyboards,
            prefix: qualifiedName
        )

        let fontStruct = FontResource.generateStruct(
            resources: project.fonts,
            prefix: qualifiedName
        )

        let storyboardStruct = StoryboardResource.generateStruct(
            storyboards: project.storyboards,
            prefix: qualifiedName
        )

        let infoStruct = PropertyListResource.generateInfoStruct(
            resourceName: "info",
            plists: project.infoPlists,
            prefix: qualifiedName
        )

        let entitlementsStruct = PropertyListResource.generateStruct(
            resourceName: "entitlements",
            plists: project.codeSignEntitlements,
            prefix: qualifiedName
        )

        let nibStruct = NibResource.generateStruct(
            nibs: project.nibs,
            prefix: qualifiedName
        )

        let reuseIdentifierStruct = Reusable.generateStruct(
            nibs: project.nibs,
            storyboards: project.storyboards,
            prefix: qualifiedName
        )

        let stringStruct = LocalizableStrings.generateStruct(
            resources: project.localizableStrings,
            developmentLanguage: project.xcodeproj.developmentRegion,
            prefix: qualifiedName
        )

        let projectStruct = Struct(name: SwiftIdentifier(name: "project")) {
            LetBinding(name: SwiftIdentifier(name: "developmentRegion"), valueCodeString: #""\#(project.xcodeproj.developmentRegion)""#)

            if let knownAssetTags = project.xcodeproj.knownAssetTags {
                LetBinding(name: SwiftIdentifier(name: "knownAssetTags"), valueCodeString: "\(knownAssetTags)")
            }
        }

        let s = Struct(name: structName) {
            Init.bundle
            projectStruct

            stringStruct.generateBundleVarGetter(name: "string")
            stringStruct.generateBundleFunction(name: "string")
            stringStruct

            dataStruct.generateBundleVarGetter(name: "data")
            dataStruct.generateBundleFunction(name: "data")
            dataStruct

            colorStruct.generateBundleVarGetter(name: "color")
            colorStruct.generateBundleFunction(name: "color")
            colorStruct

            imageStruct.generateBundleVarGetter(name: "image")
            imageStruct.generateBundleFunction(name: "image")
            imageStruct

            infoStruct.generateBundleVarGetter(name: "info")
            infoStruct.generateBundleFunction(name: "info")
            infoStruct

            entitlementsStruct.generateLetBinding()
            entitlementsStruct

            fontStruct.generateLetBinding()
            fontStruct

            fileStruct.generateBundleVarGetter(name: "file")
            fileStruct.generateBundleFunction(name: "file")
            fileStruct

            segueStruct.generateLetBinding()
            segueStruct

            idStruct.generateLetBinding()
            idStruct

            nibStruct.generateBundleVarGetter(name: "nib")
            nibStruct.generateBundleFunction(name: "nib")
            nibStruct

            reuseIdentifierStruct.generateLetBinding()
            reuseIdentifierStruct

            storyboardStruct.generateBundleVarGetter(name: "storyboard")
            storyboardStruct.generateBundleFunction(name: "storyboard")
            storyboardStruct
        }

        try s.prettyPrint().write(to: outputURL, atomically: true, encoding: .utf8)
        print(s.prettyPrint())

        print()

        print("let S = _S(bundle: Bundle.main)")
        print("")
        print("extension R {")
        print("  static let string = S.string")
        print("  static let data = S.data")
        print("  static let color = S.color")
        print("  static let image = S.image")
        print("  static let font = S.font")
        print("  static let segue = S.segue")
        print("  static let file = S.file")
        print("  static let storyboard = S.storyboard")
        print("  static let entitlements = S.entitlements")
        print("  static let info = S.info")
        print("  static let nib = S.nib")
        print("  static let reuseIdentifier = S.reuseIdentifier")
        print("  static let id = S.id")
        print("}")

        print("TOTAL", Date().timeIntervalSince(start))
        print()
    }
}
