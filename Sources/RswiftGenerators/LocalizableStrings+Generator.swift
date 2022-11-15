//
//  LocalizableStrings+Generator.swift
//  
//
//  Created by Tom Lokhorst on 2022-06-24.
//

import Foundation
import RswiftResources

extension LocalizableStrings {
    public static func generateStruct(resources: [LocalizableStrings], developmentLanguage: String?, prefix: SwiftIdentifier) -> Struct {
        let structName = SwiftIdentifier(name: "string", lowercaseStartingCharacters: false)
        let qualifiedName = prefix + structName
        let warning: (String) -> Void = { print("warning: [R.swift]", $0) }

        let localized = Dictionary(grouping: resources, by: \.filename)
        let groupedLocalized = localized.grouped(bySwiftIdentifier: \.key)

        groupedLocalized.reportWarningsForDuplicatesAndEmpties(source: "strings file", result: "file", warning: warning)

        let structs = groupedLocalized.uniques
            .compactMap { (filename, resources) -> Struct? in
                generateStruct(
                    filename: filename,
                    resources: resources,
                    developmentLanguage: developmentLanguage,
                    prefix: qualifiedName,
                    warning: warning
                )
            }

        let comments = ["This `\(qualifiedName.value)` struct is generated, and contains static references to \(groupedLocalized.uniques.count) localization tables."]

        return Struct(comments: comments, name: structName, additionalModuleReferences: [.rswiftResources]) {
            Init.bundle

            for name in groupedLocalized.uniques.map(\.0) {
                generateBundleLocaleVarGetter(name: SwiftIdentifier(name: name))
                generateBundleLocaleFunction(name: SwiftIdentifier(name: name))
                generatePreferredLanguagesFunction(name: SwiftIdentifier(name: name), tableName: name)
            }
            structs
        }
    }

    private static func generateStruct(filename: String, resources: [LocalizableStrings], developmentLanguage: String?, prefix: SwiftIdentifier, warning: (String) -> Void) -> Struct? {

        let structName = SwiftIdentifier(name: filename)
        let qualifiedName = prefix + structName

        let strings = computeStringsWithParams(filename: filename, resources: resources, developmentLanguage: developmentLanguage, warning: warning)
        let vargetters = strings.map { $0.generateVarGetter() }

        // only functions with named parameters
        let functions = strings
            .filter { $0.params.contains { $0.name != nil } }
            .map { $0.generateFunction() }

        let comments = ["This `\(qualifiedName.value)` struct is generated, and contains static references to \(vargetters.count) localization keys."]

        return Struct(comments: comments, name: structName) {
            Init.bundleLocale
            vargetters
            functions
        }
    }

    public static func generateBundleLocaleVarGetter(name: SwiftIdentifier) -> VarGetter {
        VarGetter(
            name: name,
            typeReference: TypeReference(module: .host, rawName: name.value),
            valueCodeString: ".init(bundle: bundle, locale: bundle.firstPreferredLocale)"
        )
    }

    public static func generateBundleLocaleFunction(name: SwiftIdentifier) -> Function {
        Function(
            comments: [],
            name: name,
            params: [
                .init(name: "bundle", localName: nil, typeReference: .bundle, defaultValue: nil),
                .init(name: "locale", localName: nil, typeReference: .locale, defaultValue: nil),
            ],
            returnType: TypeReference(module: .host, rawName: name.value),
            valueCodeString: ".init(bundle: bundle, locale: locale)"
        )
    }

    public static func generatePreferredLanguagesFunction(name: SwiftIdentifier, tableName: String) -> Function {
        Function(
            comments: [],
            name: name,
            params: [
                .init(name: "preferredLanguages", localName: nil, typeReference: TypeReference(module: .stdLib, rawName: "[String]"), defaultValue: nil),
            ],
            returnType: TypeReference(module: .host, rawName: name.value),
            valueCodeString: """
                let (bundle, locale) = bundle.firstBundleAndLocale(tableName: "\(tableName.escapedStringLiteral)", preferredLanguages: preferredLanguages) ?? (bundle, bundle.firstPreferredLocale)
                return .init(bundle: bundle, locale: locale)
                """
        )
    }

    // Ahem, this code is a bit of a mess. It might need cleaning up... ;-)
    private static func computeStringsWithParams(filename: String, resources: [LocalizableStrings], developmentLanguage: String?, warning: (String) -> Void) -> [StringWithParams] {

        var allParams: [String: [(LocaleReference, String, [StringParam])]] = [:]
        let primaryLanguage: String?
        let primaryKeys: Set<String>?
        let bases = resources.filter { $0.locale.isBase }
        let developments = resources.filter { $0.locale.localeDescription == developmentLanguage }

        if !bases.isEmpty {
            primaryKeys = Set(bases.flatMap { $0.dictionary.keys })
            primaryLanguage = "Base"
        } else if !developments.isEmpty {
            primaryKeys = Set(developments.flatMap { $0.dictionary.keys })
            primaryLanguage = developmentLanguage
        } else {
            primaryKeys = nil
            primaryLanguage = developmentLanguage
        }

        // Warnings about duplicates and empties
        for ls in resources {
            let filenameLocale = ls.locale.debugDescription(filename: filename)
            let groupedKeys = ls.dictionary.keys.grouped(bySwiftIdentifier: { $0 })

            groupedKeys.reportWarningsForDuplicatesAndEmpties(source: "string", container: "in \(filenameLocale)", result: "key", warning: warning)

            // Save uniques
            for key in groupedKeys.uniques {
                if let value = ls.dictionary[key] {
                    if let _ = allParams[key] {
                        allParams[key]?.append((ls.locale, value.originalValue, value.params))
                    }
                    else {
                        allParams[key] = [(ls.locale, value.originalValue, value.params)]
                    }
                }
            }
        }

        // Warnings about missing translations
        for (locale, lss) in Dictionary(grouping: resources, by: \.locale) {
            let filenameLocale = locale.debugDescription(filename: filename)
            let sourceKeys = primaryKeys ?? Set(allParams.keys)

            let missing = sourceKeys.subtracting(lss.flatMap { $0.dictionary.keys })

            if missing.isEmpty {
                continue
            }

            let paddedKeys = missing.sorted().map { "'\($0)'" }
            let paddedKeysString = paddedKeys.joined(separator: ", ")

            warning("Strings file \(filenameLocale) is missing translations for keys: \(paddedKeysString)")
        }

        // Warnings about extra translations
        for (locale, lss) in Dictionary(grouping: resources, by: \.locale) {
            let filenameLocale = locale.debugDescription(filename: filename)
            let sourceKeys = primaryKeys ?? Set(allParams.keys)

            let usedKeys = Set(lss.flatMap { $0.dictionary.keys })
            let extra = usedKeys.subtracting(sourceKeys)

            if extra.isEmpty {
                continue
            }

            let paddedKeys = extra.sorted().map { "'\($0)'" }
            let paddedKeysString = paddedKeys.joined(separator: ", ")

            if let primaryLanguage {
                warning("Strings file \(filenameLocale) has extra translations (not in \(primaryLanguage)) for keys: \(paddedKeysString)")
            } else {
                warning("Strings file \(filenameLocale) has extra translations for keys: \(paddedKeysString)")
            }
        }

        // Only include translation if it exists in the primary language
        func includeTranslation(_ key: String) -> Bool {
            if let primaryKeys = primaryKeys {
                return primaryKeys.contains(key)
            }

            return true
        }

        var results: [StringWithParams] = []
        var badFormatSpecifiersKeys = Set<String>()

        let filteredSortedParams = allParams
            .map { $0 }
            .filter { includeTranslation($0.0) }
            .sorted(by: { $0.0 < $1.0 })

        // Unify format specifiers
        for (key, keyParams) in filteredSortedParams  {
            var params: [StringParam] = []
            var areCorrectFormatSpecifiers = true

            for (locale, _, ps) in keyParams {
                if ps.contains(where: { $0.spec == FormatSpecifier.topType }) {
                    let name = locale.debugDescription(filename: filename)
                    warning("Skipping string \(key) in \(name), not all format specifiers are consecutive")

                    areCorrectFormatSpecifiers = false
                }
            }

            if !areCorrectFormatSpecifiers { continue }

            for (_, _, ps) in keyParams {
                if let unified = params.unify(ps) {
                    params = unified
                }
                else {
                    badFormatSpecifiersKeys.insert(key)

                    areCorrectFormatSpecifiers = false
                }
            }

            if !areCorrectFormatSpecifiers { continue }

            let vals = keyParams.map { ($0.0, $0.1) }
            let values = StringWithParams(key: key, params: params, tableName: filename, values: vals, developmentLanguage: developmentLanguage)
            results.append(values)
        }

        for badKey in badFormatSpecifiersKeys.sorted() {
            let fewParams = allParams.filter { $0.0 == badKey }.map { $0.1 }

            if let params = fewParams.first {
                let locales = params.compactMap { $0.0.localeDescription }.joined(separator: ", ")
                warning("Skipping string for key \(badKey) (\(filename)), format specifiers don't match for all locales: \(locales)")
            }
        }

        return results
    }

}

private struct StringWithParams {
    let key: String
    let params: [StringParam]
    let tableName: String
    let values: [(LocaleReference, String)]
    let developmentLanguage: String?

    func generateVarGetter() -> VarGetter {
        VarGetter(
            comments: self.comments,
            name: SwiftIdentifier(name: key),
            typeReference: typeReference,
            valueCodeString: varValueCodeString
        )
    }

    func generateFunction() -> Function {
        Function(
            comments: self.comments,
            name: SwiftIdentifier(name: key),
            params: zip(params.indices, params).map { (ix, p) in
                .init(name: p.name ?? "_", localName: "value\(ix + 1)", typeReference: p.spec.typeReference, defaultValue: nil)
            },
            returnType: .string,
            valueCodeString: funcBodyCodeString
        )
    }


    private var varValueCodeString: String {
        #".init(key: "\#(key.escapedStringLiteral)", tableName: "\#(tableName)", bundle: bundle, locale: locale, defaultValue: "\#(fallbackValue.escapedStringLiteral)", comment: nil)"#
    }

    private var funcBodyCodeString: String {
        let ps = params.indices.map { "value\($0 + 1)" }
        let args = ["format: format", "locale: locale"] + ps

        return """
        let format = NSLocalizedString("\(key.escapedStringLiteral)", tableName: "\(tableName)", bundle: bundle, value: "\(fallbackValue.escapedStringLiteral)", comment: "")
        return String(\(args.joined(separator: ", ")))
        """
    }

    private var typeReference: TypeReference {
        TypeReference(module: .rswiftResources, name: "StringResource\(params.isEmpty ? "" : "\(params.count)")", genericArgs: params.map(\.spec.typeReference))
    }

    private var typeName: String {
        "StringResource"
        + (params.isEmpty ? "" : "\(params.count)<\(params.map(\.spec.typeReference.name).joined(separator: ", "))>")
    }

    private var primaryLanguageValues: [(LocaleReference, String)] {
        values.filter { $0.0.isBase } + values.filter { $0.0.localeDescription == developmentLanguage }
    }

    private var fallbackValue: String {
        (primaryLanguageValues + values).first?.1 ?? ""
    }

    private var comments: [String] {
        var results: [String] = []

        let anyNone = values.contains { $0.0.isNone }
        let vs = primaryLanguageValues + values

        // Value
        if let (locale, value) = vs.first {
            if let localeDescription = locale.localeDescription {
                let str = "\(localeDescription) translation: \(value)".commentString
                results.append(str)
            }
            else {
                let str = "Value: \(value)".commentString
                results.append(str)
            }
        }

        // Key
        if !results.isEmpty {
            results.append("")
        }
        results.append("Key: \(key)".commentString)

        // Locales
        if !anyNone {
            if !results.isEmpty {
                results.append("")
            }

            let locales = values.compactMap { $0.0.localeDescription }
            results.append("Locales: \(locales.joined(separator: ", "))")
        }

        return results
    }
}
