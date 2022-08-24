//
//  MBConfig.Feature.swift
//  MBoxDependencyManager
//
//  Created by Whirlwind on 2020/1/8.
//  Copyright © 2020 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore

var MBConfigFeatureDependenciesKey: UInt8 = 0
extension MBConfig.Feature {
    @_dynamicReplacement(for: supportFiles)
    public var dp_supportFiles: [String] {
        var files = supportFiles
        files.append(UserDependencyFile.fileName)
        return files
    }

    @_dynamicReplacement(for: prepare(dictionary:))
    public func dp_prepare(dictionary: [String: Any]) -> [String: Any] {
        var dictionary = dictionary
        if let data = dictionary.removeValue(forKey: "dependencies"),
            let dps = try? UserDependencyFile.load(fromObject: data) {
            self.dependencies = dps
        }
        return self.prepare(dictionary: dictionary)
    }

    public var dependencyFilePath: String {
        return Workspace.rootPath.appending(pathComponent: UserDependencyFile.fileName)
    }

    public var dependencies: UserDependencyFile {
        get {
            return associatedObject(base: self, key: &MBConfigFeatureDependenciesKey) {
                if self.isCurrent,
                   let dp = UserDependencyFile.load(fromFile: self.dependencyFilePath) {
                    return dp
                }
                var dp = UserDependencyFile()
                dp.filePath = self.dependencyFilePath
                return dp
            }
        }
        set {
            associateObject(base: self, key: &MBConfigFeatureDependenciesKey, value: newValue)
        }
    }

    public func saveDependencies() throws {
        if !self.dependencies.save() {
            throw RuntimeError("Save Failed: `\(self.dependencies.filePath ?? "Unknown")`")
        }
        if !self.saveChangedDependenciesLock() {
            throw RuntimeError("Save Failed: `\(self.dependenciesLockPath)`")
        }
    }

    private var dependenciesLockPath: String {
        return self.config.workspace.configDir.appending(pathComponent: "dependencies.lock")
    }

    @discardableResult
    public func saveChangedDependenciesLock() -> Bool {
        let path = self.dependenciesLockPath
        return self.changedDependencies().save(filePath: path, sortedKeys: true, prettyPrinted: true)
    }

    public func changedDependencies() -> [String: [String: Any]] {
        var result = [String: [String: Any]]()
        for tool in MBDependencyTool.allTools {
            let dps = self.changedDependencies(for: tool)
            guard !dps.isEmpty else {
                continue
            }
            result[tool.name] = dps
        }
        return result
    }

    dynamic
    public func changedDependencies(for tool: MBDependencyTool) -> [String: Any] {
        let dps = self.config.currentFeature.dependencies.dependencies(for: tool)
        var info = [String: Any]()
        for dp in dps {
            guard let name = dp.name, var dict = dp.toCodableObject() as? [String: Any] else {
                continue
            }
            dict.removeValue(forKey: "name")
            info[name] = dict
        }
        for repo in self.config.currentFeature.repos {
            for component in repo.activatedComponents(for: tool) {
                info[component] = ["path": self.config.workspace.relativePath(repo.workingPath)]
            }
        }
        return info
    }

    @_dynamicReplacement(for: exportHash)
    public var dp_exportHash: [String: Any]? {
        var hash = self.exportHash
        if !self.dependencies.isEmpty {
            hash ?= [:]
            hash?["dependencies"] = self.dependencies
        }
        return hash
    }
}
