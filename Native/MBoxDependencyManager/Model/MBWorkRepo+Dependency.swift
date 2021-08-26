//
//  MBWorkRepo+Dependency.swift
//  MBoxDependencyManager
//
//  Created by Whirlwind on 2021/1/25.
//  Copyright © 2021 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxWorkspaceCore

private var kMBWorkRepoDependencyNamesKey: UInt8 = 0
private var kMBWorkRepoDependencyNamesByToolKey: UInt8 = 0

extension MBWorkRepo {
    @_dynamicReplacement(for: fetchPackageNames())
    open func dp_fetchPackageNames() -> [String] {
        var names = self.fetchPackageNames()
        names.append(contentsOf: self.dependencyNames)
        return names
    }

    open var dependencyNames: [String] {
        set {
            associateObject(base: self, key: &kMBWorkRepoDependencyNamesKey, value: newValue)
        }
        get {
            return associatedObject(base: self, key: &kMBWorkRepoDependencyNamesKey) {
                return self.dependencyNamesByTool.values.flatMap { $0 }.withoutDuplicates()
            }
        }
    }

    open var dependencyNamesByTool: [MBDependencyTool: [String]] {
        set {
            associateObject(base: self, key: &kMBWorkRepoDependencyNamesByToolKey, value: newValue)
        }
        get {
            return associatedObject(base: self, key: &kMBWorkRepoDependencyNamesByToolKey) {
                var v = [MBDependencyTool: [String]]()
                for (tool, name) in self.resolveDependencyNames() {
                    var items = v[tool] ?? []
                    if !items.contains(name) {
                        items.append(name)
                    }
                    v[tool] = items
                }
                return v
            }
        }
    }

    open func fetchDependencyNames(for tool: MBDependencyTool) -> (tool: MBDependencyTool, dependencies: [String])? {
        for (key, values) in dependencyNamesByTool {
            if tool == key {
                return (tool: tool, dependencies: values)
            }
        }
        return nil
    }

    dynamic
    open func fetchDependency(_ name: String, for tool: MBDependencyTool) -> (tool: MBDependencyTool, dependency: String)? {
        guard let (t, dps) = self.fetchDependencyNames(for: tool) else { return nil }
        let name = dps.first { $0.lowercased() == name.lowercased() }
        if let name = name {
            return (tool: t, dependency: name)
        }
        return nil
    }

    dynamic
    open func fetchDependencies(_ names: [String], for tool: MBDependencyTool) -> (tool: MBDependencyTool, dependencies: [String])? {
        guard let (t, dps) = self.fetchDependencyNames(for: tool) else { return nil }
        let names = names.map { $0.lowercased() }
        let values = dps.filter {
            names.contains($0.lowercased())
        }
        return (tool: t, dependencies: values)
    }

    dynamic
    open func resolveDependencyNames() -> [(tool: MBDependencyTool, name: String)] {
        return []
    }
}
