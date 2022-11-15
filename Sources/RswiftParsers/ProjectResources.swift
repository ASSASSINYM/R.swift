//
//  ProjectResources.swift
//  
//
//  Created by Tom Lokhorst on 2022-07-29.
//

import Foundation
import XcodeEdit
import RswiftResources

public struct ProjectResources {
    public let assetCatalogs: [AssetCatalog]
    public let files: [FileResource]
    public let fonts: [FontResource]
    public let images: [ImageResource]
    public let localizableStrings: [LocalizableStrings]
    public let nibs: [NibResource]
    public let storyboards: [StoryboardResource]
    public let infoPlists: [PropertyListResource]
    public let codeSignEntitlements: [PropertyListResource]

    public static func parseXcodeproj(
        xcodeproj: Xcodeproj,
        targetName: String,
        rswiftIgnoreURL: URL?,
        infoPlistFile: URL?,
        codeSignEntitlements: URL?,
        sourceTreeURLs: SourceTreeURLs,
        parseFontsAsFiles: Bool,
        parseImagesAsFiles: Bool,
        warning: (String) -> Void
    ) throws -> ProjectResources {
        let ignoreFile = rswiftIgnoreURL.flatMap { try? IgnoreFile(ignoreFileURL: $0) } ?? IgnoreFile()

        let buildConfigurations = try xcodeproj.buildConfigurations(forTarget: targetName)

        let paths = try xcodeproj.resourcePaths(forTarget: targetName)
        let urls = paths
            .map { $0.url(with: sourceTreeURLs.url(for:)) }
            .filter { !ignoreFile.matches(url: $0) }

        let infoPlists = try buildConfigurations.compactMap { config -> PropertyListResource? in
            guard let url = infoPlistFile else { return nil }
            return try parse(with: warning) {
                try PropertyListResource.parse(url: url, buildConfigurationName: config.name)
            }
        }

        let codeSignEntitlements = try buildConfigurations.compactMap { config -> PropertyListResource? in
            guard let url = codeSignEntitlements else { return nil }
            return try parse(with: warning) { try PropertyListResource.parse(url: url, buildConfigurationName: config.name) }
        }

        return try parseURLs(
            urls: urls,
            infoPlists: infoPlists,
            codeSignEntitlements: codeSignEntitlements,
            parseFontsAsFiles: parseFontsAsFiles,
            parseImagesAsFiles: parseImagesAsFiles,
            warning: warning
        )
    }

    public static func parseURLs(
        urls: [URL],
        infoPlists: [PropertyListResource],
        codeSignEntitlements: [PropertyListResource],
        parseFontsAsFiles: Bool,
        parseImagesAsFiles: Bool,
        warning: (String) -> Void
    ) throws -> ProjectResources {

        let assetCatalogs = try urls
            .filter { AssetCatalog.supportedExtensions.contains($0.pathExtension) }
            .compactMap { url in try parse(with: warning) { try AssetCatalog.parse(url: url) } }

        let dontParseFileForFonts = !parseFontsAsFiles
        let dontParseFileForImages = !parseImagesAsFiles
        let files = try urls
            .filter { !FileResource.unsupportedExtensions.contains($0.pathExtension) }
            .filter { !(dontParseFileForFonts && FontResource.supportedExtensions.contains($0.pathExtension)) }
            .filter { !(dontParseFileForImages && ImageResource.supportedExtensions.contains($0.pathExtension)) }
            .compactMap { url in try parse(with: warning) { try FileResource.parse(url: url) } }

        let fonts = try urls
            .filter { FontResource.supportedExtensions.contains($0.pathExtension) }
            .compactMap { url in try parse(with: warning) { try FontResource.parse(url: url) } }

        let images = try urls
            .filter { ImageResource.supportedExtensions.contains($0.pathExtension) }
            .compactMap { url in try parse(with: warning) { try ImageResource.parse(url: url, assetTags: nil) } }

        let localizableStrings = try urls
            .filter { LocalizableStrings.supportedExtensions.contains($0.pathExtension) }
            .compactMap { url in try parse(with: warning) { try LocalizableStrings.parse(url: url) } }

        let nibs = try urls
            .filter { NibResource.supportedExtensions.contains($0.pathExtension) }
            .compactMap { url in try parse(with: warning) { try NibResource.parse(url: url) } }

        let storyboards = try urls
            .filter { StoryboardResource.supportedExtensions.contains($0.pathExtension) }
            .compactMap { url in try parse(with: warning) { try StoryboardResource.parse(url: url) } }

        return ProjectResources(
            assetCatalogs: assetCatalogs,
            files: files,
            fonts: fonts,
            images: images,
            localizableStrings: localizableStrings,
            nibs: nibs,
            storyboards: storyboards,
            infoPlists: infoPlists,
            codeSignEntitlements: codeSignEntitlements
        )
    }
}

private func parse<R>(with warning: (String) -> Void, closure: () throws -> R) throws -> R? {
    do {
        return try closure()
    } catch let error as ResourceParsingError {
        warning(error.description)
        return nil
    }
}
