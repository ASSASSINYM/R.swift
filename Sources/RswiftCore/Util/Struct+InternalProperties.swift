//
//  Struct+InternalProperties.swift
//  R.swift
//
//  Created by Mathijs Kadijk on 06-10-16.
//  Copyright © 2016 Mathijs Kadijk. All rights reserved.
//

import Foundation

extension Struct {
  func addingInternalProperties(forBundleIdentifier bundleIdentifier: String) -> Struct {

    let internalProperties = [
      Let(
        comments: [],
        accessModifier: .filePrivate,
        isStatic: true,
        name: "hostingBundle",
        typeDefinition: .inferred(Type._Bundle),
        value: "Bundle(for: R.Class.self)"),
      Let(
        comments: [],
        accessModifier: .filePrivate,
        isStatic: true,
        name: "applicationLocale",
        typeDefinition: .inferred(Type._Locale),
        value: "hostingBundle.preferredLocalizations.first.flatMap(Locale.init) ?? Locale.current")
    ]

    let internalClasses = [
      Class(accessModifier: .filePrivate, type: Type(module: .host, name: "Class"))
    ]

    let internalFunctions = [
      Function(
        availables: [],
        comments: ["Find first language and bundle for which the table exists"],
        accessModifier: .filePrivate,
        isStatic: true,
        name: "localeBundle",
        generics: nil,
        parameters: [
          .init(name: "tableName", type: Type._String),
          .init(name: "preferredLanguages", type: Type._Array.withGenericArgs([Type._String]))
        ],
        doesThrow: false,
        returnType: Type._Tuple.withGenericArgs([Type._Locale, Type._Bundle]).asOptional(),
        body: """
          var languages = preferredLanguages
            .map(Locale.init)
            .filter { locale in
              return hostingBundle.localizations.contains(locale.identifier)
                || hostingBundle.localizations.contains(locale.languageCode ?? "")
            }
            .flatMap { locale -> [String] in
              if let language = locale.languageCode {
                return [locale.identifier, language]
              }
              return [locale.identifier]
            }

          if languages.isEmpty {
            if let developmentLocalization = hostingBundle.developmentLocalization {
              languages = [developmentLocalization]
            }
          } else {
            // Insert Base as second item
            if languages.count > 1 {
              languages.insert("Base", at: 1)
            } else {
              languages.append("Base")
            }

            // Add development language as backstops
            if let developmentLocalization = hostingBundle.developmentLocalization {
              languages.append(developmentLocalization)
            }
          }

          // Find first language for which table exists
          // Note: key might not exist in chosen language (in that case, key will be shown)
          for language in languages {
            if let lproj = hostingBundle.url(forResource: language, withExtension: "lproj"),
               let lbundle = Bundle(url: lproj)
            {
              let strings = lbundle.url(forResource: tableName, withExtension: "strings")
              let stringsdict = lbundle.url(forResource: tableName, withExtension: "stringsdict")

              if strings != nil || stringsdict != nil {
                return (Locale(identifier: language), lbundle)
              }
            }
          }

          // If table is available in main bundle, don't look for localized resources
          let strings = hostingBundle.url(forResource: tableName, withExtension: "strings", subdirectory: nil, localization: nil)
          let stringsdict = hostingBundle.url(forResource: tableName, withExtension: "stringsdict", subdirectory: nil, localization: nil)

          if strings != nil || stringsdict != nil {
            return (applicationLocale, hostingBundle)
          }

          // If table is not found for requested languages, key will be shown
          return nil
          """,
        os: [])
    ]

    var externalStruct = self
    externalStruct.properties.append(contentsOf: internalProperties)
    externalStruct.functions.append(contentsOf: internalFunctions)
    externalStruct.classes.append(contentsOf: internalClasses)

    return externalStruct
  }
}
