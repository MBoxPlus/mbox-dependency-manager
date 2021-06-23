//
//  MBConfig.Feature.swift
//  MBoxDependencyManager
//
//  Created by 詹迟晶 on 2020/1/8.
//  Copyright © 2020 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxWorkspaceCore

var MBConfigFeatureDependenciesKey: UInt8 = 0
extension MBConfig.Feature {
    @_dynamicReplacement(for: supportFiles)
    open var dp_supportFiles: [String] {
        var files = supportFiles
        files.append(UserDependencyFile.fileName)
        return files
    }

    @_dynamicReplacement(for: prepare)
    open func dp_prepare(dictionary: [String: Any]) -> [String: Any] {
        var dictionary = dictionary
        if let data = dictionary.removeValue(forKey: "dependencies"),
            let dps = try? UserDependencyFile.load(fromObject: data) {
            self.dependencies = dps
        }
        return self.prepare(dictionary: dictionary)
    }

    open var dependencyFilePath: String {
        return Workspace.rootPath.appending(pathComponent: UserDependencyFile.fileName)
    }

    open var dependencies: UserDependencyFile {
        get {
            return associatedObject(base: self, key: &MBConfigFeatureDependenciesKey) {
                if let dp = UserDependencyFile.load(fromFile: self.dependencyFilePath) { return dp }
                var dp = UserDependencyFile()
                dp.filePath = self.dependencyFilePath
                return dp
            }
        }
        set {
            associateObject(base: self, key: &MBConfigFeatureDependenciesKey, value: newValue)
        }
    }

    @_dynamicReplacement(for: exportHash)
    open var dp_exportHash: [String: Any] {
        var hash = self.exportHash
        if !self.dependencies.isEmpty {
            hash["dependencies"] = self.dependencies
        }
        return hash
    }
}
