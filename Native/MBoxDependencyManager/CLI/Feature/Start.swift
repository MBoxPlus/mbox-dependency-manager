//
//  Start.swift
//  MBoxDependencyManager
//
//  Created by Whirlwind on 2020/1/14.
//  Copyright © 2020 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore

var MBCommanderFeatureStartDependenciesKey: UInt8 = 0
extension MBCommander.Feature.Start {
    @_dynamicReplacement(for: options)
    public class var dp_options: [Option] {
        var options = self.options
        options << Option("dependencies", description: "Create a new feature with a custom dependency list. It is a JSON String, eg: {\"Aweme\": {\"version\": \"1.0\"}}")
        return options
    }

    @_dynamicReplacement(for: setup())
    public func dp_setup() throws {
        if let json: String = self.shiftOption("dependencies") {
            let hash = try [String: [String: Any]].load(fromString: json, coder: .json)
            self.dependencies = hash.map { map -> UserDependency in
                let dp = UserDependency(dictionary: map.value)
                dp.name = map.key
                return dp
            }
        }
        try self.setup()
    }

    public var dependencies: [UserDependency]? {
        set {
            associateObject(base: self, key: &MBCommanderFeatureStartDependenciesKey, value: newValue)
        }
        get {
            associatedObject(base: self, key: &MBCommanderFeatureStartDependenciesKey)
        }
    }

    @_dynamicReplacement(for: applyFeature(_:oldFeature:isCreate:))
    public func dp_applyFeature(_ newFeature: MBConfig.Feature, oldFeature: MBConfig.Feature, isCreate: Bool) throws {
        try self.applyFeature(newFeature, oldFeature: oldFeature, isCreate: isCreate)
        guard let dps = self.dependencies else {
            return
        }
        UI.section("Replace dependencies:") {
            if dps.isEmpty {
                UI.log(info: "No any dependencies.")
            } else {
                UI.log(info: dps.map { "- \($0.description)" }.joined(separator: "\n"))
            }
            newFeature.dependencies.array = dps
            newFeature.dependencies.save(filePath: newFeature.dependencyFilePath)
        }
    }

    @_dynamicReplacement(for: run())
    public func dp_run() throws {
        try self.run()
        self.config.currentFeature.saveChangedDependenciesLock()
    }
}
