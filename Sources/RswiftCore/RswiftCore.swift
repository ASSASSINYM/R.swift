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
    case data
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
    let accessLevel: AccessLevel
    let importModules: [String]
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
        accessLevel: AccessLevel,
        importModules: [String],
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
        self.accessLevel = accessLevel
        self.importModules = importModules
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
            warning: { print("warning: [R.swift]", $0) }
        )

        let structName = SwiftIdentifier(rawValue: "_R")
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

        let generateString = generators.contains(.string) && !stringStruct.isEmpty
        let generateData = generators.contains(.data) && !dataStruct.isEmpty
        let generateColor = generators.contains(.color) && !colorStruct.isEmpty
        let generateImage = generators.contains(.image) && !imageStruct.isEmpty
        let generateInfo = generators.contains(.info) && !infoStruct.isEmpty
        let generateEntitlements = generators.contains(.entitlements) && !entitlementsStruct.isEmpty
        let generateFont = generators.contains(.font) && !fontStruct.isEmpty
        let generateFile = generators.contains(.file) && !fileStruct.isEmpty
        let generateSegue = generators.contains(.segue) && !segueStruct.isEmpty
        let generateId = generators.contains(.id) && !idStruct.isEmpty
        let generateNib = generators.contains(.nib) && !nibStruct.isEmpty
        let generateReuseIdentifier = generators.contains(.reuseIdentifier) && !reuseIdentifierStruct.isEmpty
        let generateStoryboard = generators.contains(.storyboard) && !storyboardStruct.isEmpty

        let validateLines = [
            generateFont ? "try self.font.validate()" : "",
            generateNib ? "try self.nib.validate()" : "",
            generateStoryboard ? "try self.storyboard.validate()" : "",
        ]
        .filter { $0 != "" }
        .joined(separator: "\n")

        let validate = Function(
            comments: [],
            name: SwiftIdentifier(name: "validate"),
            params: [],
            returnThrows: true,
            returnType: .init(module: .stdLib, rawName: "Void"),
            valueCodeString: validateLines
        )

        var s = Struct(name: structName) {
            Init.bundle
            projectStruct

            if generateString {
                stringStruct.generateBundleVarGetter(name: "string")
                stringStruct.generateBundleFunction(name: "string")
                stringStruct
            }

            if generateData {
                dataStruct.generateBundleVarGetter(name: "data")
                dataStruct.generateBundleFunction(name: "data")
                dataStruct
            }

            if generateColor {
                colorStruct.generateBundleVarGetter(name: "color")
                colorStruct.generateBundleFunction(name: "color")
                colorStruct
            }

            if generateImage {
                imageStruct.generateBundleVarGetter(name: "image")
                imageStruct.generateBundleFunction(name: "image")
                imageStruct
            }

            if generateInfo {
                infoStruct.generateBundleVarGetter(name: "info")
                infoStruct.generateBundleFunction(name: "info")
                infoStruct
            }

            if generateEntitlements {
                entitlementsStruct.generateLetBinding()
                entitlementsStruct
            }

            if generateFont {
                fontStruct.generateLetBinding()
                fontStruct
            }

            if generateFile {
                fileStruct.generateBundleVarGetter(name: "file")
                fileStruct.generateBundleFunction(name: "file")
                fileStruct
            }

            if generateSegue {
                segueStruct.generateLetBinding()
                segueStruct
            }

            if generateId {
                idStruct.generateLetBinding()
                idStruct
            }

            if generateNib {
                nibStruct.generateBundleVarGetter(name: "nib")
                nibStruct.generateBundleFunction(name: "nib")
                nibStruct
            }

            if generateReuseIdentifier {
                reuseIdentifierStruct.generateLetBinding()
                reuseIdentifierStruct
            }

            if generateStoryboard {
                storyboardStruct.generateBundleVarGetter(name: "storyboard")
                storyboardStruct.generateBundleFunction(name: "storyboard")
                storyboardStruct
            }

            validate
        }

        if accessLevel == .publicLevel {
            s.setAccessControl(.public)
        }

        let imports = Set(s.allModuleReferences.compactMap(\.name))
            .union(importModules)
            .subtracting([productModuleName].compactMap { $0 })
            .sorted()
            .map { "import \($0)" }
            .joined(separator: "\n")

        let mainLet = "\(accessLevel == .publicLevel ? "public " : "")let R = _R(bundle: Bundle(for: BundleClass.self))"

        let str = s.prettyPrint()
        let code = """
        \(imports)

        \(str)

        private class BundleClass {}
        \(mainLet)
        """
        try code.write(to: outputURL, atomically: true, encoding: .utf8)
        /*
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
        */

        let _ = Date().timeIntervalSince(start)
//        print("TOTAL", Date().timeIntervalSince(start))
//        print()
    }
}
