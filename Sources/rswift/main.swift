//
//  main.swift
//  R.swift
//
//  Created by Mathijs Kadijk on 11-12-14.
//  From: https://github.com/mac-cain13/R.swift
//  License: MIT License
//

import Foundation
import Commander
import RswiftCore
import XcodeEdit

// Argument convertibles
extension AccessLevel : ArgumentConvertible, CustomStringConvertible {
  public init(parser: ArgumentParser) throws {
    guard let value = parser.shift() else { throw ArgumentError.missingValue(argument: nil) }
    guard let level = AccessLevel(rawValue: value) else { throw ArgumentError.invalidType(value: value, type: "AccessLevel", argument: nil) }

    self = level
  }

  public var description: String {
    return rawValue
  }
}

extension ProcessInfo {
  func environmentVariable(name: String) throws -> String {
    guard let value = self.environment[name] else { throw ArgumentError.missingValue(argument: name) }
    return value
  }
}

// Flags grouped in struct for readability
struct CommanderFlags {
  static let version = Flag("version", description: "Prints version information about this release.")
}

// Default values for non-optional Commander Options
struct EnvironmentKeys {
  static let bundleIdentifier = "PRODUCT_BUNDLE_IDENTIFIER"
  static let productModuleName = "PRODUCT_MODULE_NAME"
  static let scriptInputFileCount = "SCRIPT_INPUT_FILE_COUNT"
  static let scriptOutputFileCount = "SCRIPT_OUTPUT_FILE_COUNT"
  static let target = "TARGET_NAME"
  static let tempDir = "TEMP_DIR"
  static let xcodeproj = "PROJECT_FILE_PATH"
  static let infoPlistFile = "INFOPLIST_FILE"
  static let codeSignEntitlements = "CODE_SIGN_ENTITLEMENTS"

  static let builtProductsDir = SourceTreeFolder.buildProductsDir.rawValue
  static let developerDir = SourceTreeFolder.developerDir.rawValue
  static let platformDir = SourceTreeFolder.platformDir.rawValue
  static let sdkRoot = SourceTreeFolder.sdkRoot.rawValue
  static let sourceRoot = SourceTreeFolder.sourceRoot.rawValue

  static func scriptInputFile(number: Int) -> String {
    return "SCRIPT_INPUT_FILE_\(number)"
  }

  static func scriptOutputFile(number: Int) -> String {
    return "SCRIPT_OUTPUT_FILE_\(number)"
  }
}

// Options grouped in struct for readability
struct CommanderOptions {
  static let generators = Option("generators", default: "", description: "Only run specified generators, comma seperated")
  static let uiTest = Option("generateUITestFile", default: "", description: "Output path for an extra generated file that contains resources commonly used in UI tests such as accessibility identifiers")
  static let importModules = Option("import", default: "", description: "Add extra modules as import in the generated file, comma seperated")
  static let accessLevel = Option("accessLevel", default: AccessLevel.internalLevel, description: "The access level [public|internal] to use for the generated R-file")
  static let rswiftIgnore = Option("rswiftignore", default: ".rswiftignore", description: "Path to pattern file that describes files that should be ignored")
  static let inputOutputFilesValidation = Flag("input-output-files-validation", default: true, flag: nil, disabledName: "disable-input-output-files-validation", disabledFlag: nil, description: "Validate input and output files configured in a build phase")

  // Project specific - Environment variable overrides
  static let xcodeproj: Option<String?> = Option("xcodeproj", default: nil, description: "Defaults to environment variable \(EnvironmentKeys.xcodeproj)")
  static let target: Option<String?> = Option("target", default: nil, description: "Defaults to environment variable \(EnvironmentKeys.target)")
  static let bundleIdentifier: Option<String?> = Option("bundleIdentifier", default: nil, description: "Defaults to environment variable \(EnvironmentKeys.bundleIdentifier)")
  static let productModuleName: Option<String?> = Option("productModuleName", default: nil, description: "Defaults to environment variable \(EnvironmentKeys.productModuleName)")
  static let infoPlistFile: Option<String?> = Option("infoPlistFile", default: nil, description: "Defaults to environment variable \(EnvironmentKeys.infoPlistFile)")
  static let codeSignEntitlements: Option<String?> = Option("codeSignEntitlements", default: nil, description: "Defaults to environment variable \(EnvironmentKeys.codeSignEntitlements)")

  // Xcode build - Environment variable overrides
  static let builtProductsDir: Option<String?> = Option("builtProductsDir", default: nil, description: "Defaults to environment variable \(EnvironmentKeys.builtProductsDir)")
  static let developerDir: Option<String?> = Option("developerDir", default: nil, description: "Defaults to environment variable \(EnvironmentKeys.developerDir)")
  static let platformDir: Option<String?> = Option("platformDir", default: nil, description: "Defaults to environment variable \(EnvironmentKeys.platformDir)")
  static let sdkRoot: Option<String?> = Option("sdkRoot", default: nil, description: "Defaults to environment variable \(EnvironmentKeys.sdkRoot)")
  static let tempDir: Option<String?> = Option("tempDir", default: nil, description: "Defaults to environment variable \(EnvironmentKeys.tempDir)")
  static let sourceRoot: Option<String?> = Option("sourceRoot", default: nil, description: "Defaults to environment variable \(EnvironmentKeys.sourceRoot)")
}

// Options grouped in struct for readability
struct CommanderArguments {
  static let outputPath = Argument<String>("outputPath", description: "Output path for the generated file")
}

func parseGenerators(_ string: String) -> ([RswiftGenerator], [String]) {
  var generators: [Generator] = []
  var unknowns: [String] = []

  let parts = string.components(separatedBy: ",")
    .map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }
    .filter { !$0.isEmpty }

  for part in parts {
    if let generator = RswiftGenerator(rawValue: part) {
      generators.append(generator)
    } else {
      unknowns.append(part)
    }
  }

  return (generators, unknowns)
}

let generate = command(
  CommanderOptions.generators,
  CommanderOptions.uiTest,
  CommanderOptions.importModules,
  CommanderOptions.accessLevel,
  CommanderOptions.rswiftIgnore,
  CommanderOptions.inputOutputFilesValidation,

  CommanderOptions.xcodeproj,
  CommanderOptions.target,
  CommanderOptions.bundleIdentifier,
  CommanderOptions.productModuleName,
  CommanderOptions.infoPlistFile,
  CommanderOptions.codeSignEntitlements,

  CommanderOptions.builtProductsDir,
  CommanderOptions.developerDir,
  CommanderOptions.platformDir,
  CommanderOptions.sdkRoot,
  CommanderOptions.tempDir,
  CommanderOptions.sourceRoot,

  CommanderArguments.outputPath
) {
  generatorNames,
  uiTestOutputPath,
  importModules,
  accessLevel,
  rswiftIgnore,
  inputOutputFilesValidation,

  xcodeprojOption,
  targetOption,
  bundleIdentifierOption,
  productModuleNameOption,
  infoPlistFileOption,
  codeSignEntitlementsOption,

  builtProductsDirOption,
  developerDirOption,
  platformDirOption,
  sdkRootOption,
  tempDirOption,
  sourceRootOption,

  outputPath in

  // Touch last run file
  do {
    let tempDirPath = try ProcessInfo().environmentVariable(name: EnvironmentKeys.tempDir)
    let lastRunFile = URL(fileURLWithPath: tempDirPath).appendingPathComponent(Rswift.lastRunFile)
    try Date().description.write(to: lastRunFile, atomically: true, encoding: .utf8)
  } catch {
    warn("Failed to write out to '\(Rswift.lastRunFile)', this might cause Xcode to not run the R.swift build phase: \(error)")
  }

  let processInfo = ProcessInfo()

  let xcodeprojPath = try xcodeprojOption ?? processInfo.environmentVariable(name: EnvironmentKeys.xcodeproj)
  let targetName = try targetOption ?? processInfo.environmentVariable(name: EnvironmentKeys.target)
  let bundleIdentifier = try bundleIdentifierOption ?? processInfo.environmentVariable(name: EnvironmentKeys.bundleIdentifier)
  let productModuleName = try productModuleNameOption ?? processInfo.environmentVariable(name: EnvironmentKeys.productModuleName)
  let infoPlistFile = try infoPlistFileOption ?? processInfo.environmentVariable(name: EnvironmentKeys.infoPlistFile)
  let codeSignEntitlements = codeSignEntitlementsOption ?? processInfo.environment[EnvironmentKeys.codeSignEntitlements]

  let builtProductsDirPath = try builtProductsDirOption ?? processInfo.environmentVariable(name: EnvironmentKeys.builtProductsDir)
  let developerDirPath = try developerDirOption ?? processInfo.environmentVariable(name: EnvironmentKeys.developerDir)
  let sourceRootPath = try sourceRootOption ?? processInfo.environmentVariable(name: EnvironmentKeys.sourceRoot)
  let sdkRootPath = try sdkRootOption ?? processInfo.environmentVariable(name: EnvironmentKeys.sdkRoot)
  let tempDir = try tempDirOption ?? processInfo.environmentVariable(name: EnvironmentKeys.tempDir)
  let platformPath = try platformDirOption ?? processInfo.environmentVariable(name: EnvironmentKeys.platformDir)

  let outputURL = URL(fileURLWithPath: outputPath)
  let uiTestOutputURL = uiTestOutputPath.count > 0 ? URL(fileURLWithPath: uiTestOutputPath) : nil
  let rswiftIgnoreURL = URL(fileURLWithPath: sourceRootPath).appendingPathComponent(rswiftIgnore, isDirectory: false)

  let (knownGenerators, unknownGenerators) = parseGenerators(generatorNames)
  if !unknownGenerators.isEmpty {
    warn("Unknown generator options: \(unknownGenerators.joined(separator: ", "))")
    if knownGenerators.isEmpty {
      warn("No known generators, falling back to all generators")
    }
  }
  let generators = knownGenerators.isEmpty ? RswiftGenerator.allCases : knownGenerators

  let modules = importModules
    .components(separatedBy: ",")
    .map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }
    .filter { !$0.isEmpty }
    .map { Module.custom(name: $0) }

  let lastRunURL = URL(fileURLWithPath: tempDir).appendingPathComponent(Rswift.lastRunFile)

  let scriptInputFileCountString = try processInfo.environmentVariable(name: EnvironmentKeys.scriptInputFileCount)
  guard let scriptInputFileCount = Int(scriptInputFileCountString) else {
    throw ArgumentError.invalidType(value: scriptInputFileCountString, type: "Int", argument: EnvironmentKeys.scriptInputFileCount)
  }
  let scriptInputFiles: [String] = try (0..<scriptInputFileCount)
    .map(EnvironmentKeys.scriptInputFile)
    .map(processInfo.environmentVariable)

  let scriptOutputFileCountString = try processInfo.environmentVariable(name: EnvironmentKeys.scriptOutputFileCount)
  guard let scriptOutputFileCount = Int(scriptOutputFileCountString) else {
    throw ArgumentError.invalidType(value: scriptOutputFileCountString, type: "Int", argument: EnvironmentKeys.scriptOutputFileCount)
  }
    let scriptOutputFiles: [String] = try (0..<scriptOutputFileCount)
    .map(EnvironmentKeys.scriptOutputFile)
    .map(processInfo.environmentVariable)

  if inputOutputFilesValidation {

    let errors = validateRswiftEnvironment(
      outputURL: outputURL,
      uiTestOutputURL: uiTestOutputURL,
      sourceRootPath: sourceRootPath,
      scriptInputFiles: scriptInputFiles,
      scriptOutputFiles: scriptOutputFiles,
      lastRunURL: lastRunURL,
      podsRoot: processInfo.environment["PODS_ROOT"],
      podsTargetSrcroot: processInfo.environment["PODS_TARGET_SRCROOT"],
      commandLineArguments: CommandLine.arguments)

    guard errors.isEmpty else {
      for error in errors {
        fail(error)
      }
      warn("For updating to R.swift 5.0, read our migration guide: https://github.com/mac-cain13/R.swift/blob/master/Documentation/Migration.md")
      exit(EXIT_FAILURE)
    }
  }

  let callInformation = CallInformation(
    outputURL: outputURL,
    uiTestOutputURL: uiTestOutputURL,
    rswiftIgnoreURL: rswiftIgnoreURL,

    generators: generators,
    accessLevel: accessLevel,
    imports: modules,

    xcodeprojURL: URL(fileURLWithPath: xcodeprojPath),
    targetName: targetName,
    bundleIdentifier: bundleIdentifier,
    productModuleName: productModuleName,
    infoPlistFile: URL(fileURLWithPath: infoPlistFile),
    codeSignEntitlements: codeSignEntitlements.map { URL(fileURLWithPath: $0) },

    scriptInputFiles: scriptInputFiles,
    scriptOutputFiles: scriptOutputFiles,
    lastRunURL: lastRunURL,

    builtProductsDirURL: URL(fileURLWithPath: builtProductsDirPath),
    developerDirURL: URL(fileURLWithPath: developerDirPath),
    sourceRootURL: URL(fileURLWithPath: sourceRootPath),
    sdkRootURL: URL(fileURLWithPath: sdkRootPath),
    platformURL: URL(fileURLWithPath: platformPath)
  )

  try RswiftCore(callInformation).run()
}


// Start parsing the launch arguments
let group = Group()
group.addCommand("generate", "Generates R.generated.swift file", generate)
group.run(Rswift.version)
