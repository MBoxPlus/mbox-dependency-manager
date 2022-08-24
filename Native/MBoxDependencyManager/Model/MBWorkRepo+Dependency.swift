//
//  MBWorkRepo+Dependency.swift
//  MBoxDependencyManager
//
//  Created by Whirlwind on 2021/1/25.
//  Copyright © 2021 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore

private var kMBWorkRepoComponentsKey: UInt8 = 0
private var kMBWorkRepoComponentsByToolKey: UInt8 = 0

extension MBWorkRepo {
    @_dynamicReplacement(for: fetchPackageNames())
    public func dp_fetchPackageNames() -> [String] {
        var names = self.fetchPackageNames()
        names.append(contentsOf: self.components.map(\.name))
        return names
    }

    public var components: [Component] {
        set {
            associateObject(base: self, key: &kMBWorkRepoComponentsKey, value: newValue)
        }
        get {
            return associatedObject(base: self, key: &kMBWorkRepoComponentsKey) {
                return self.componentsByTool.values.flatMap { $0 }.withoutDuplicates()
            }
        }
    }

    public var componentsByTool: [MBDependencyTool: [Component]] {
        set {
            associateObject(base: self, key: &kMBWorkRepoComponentsByToolKey, value: newValue)
        }
        get {
            return associatedObject(base: self, key: &kMBWorkRepoComponentsByToolKey) {
                var v = [MBDependencyTool: [Component]]()
                for component in self.resolveComponents() {
                    component.repo = self
                    var items = v[component.tool] ?? []
                    items.append(component)
                    v[component.tool] = items
                }
                return v
            }
        }
    }

    public func fetchComponents(for tool: MBDependencyTool) -> [Component] {
        return componentsByTool[tool] ?? []
    }

    dynamic
    public func fetchComponent(_ name: String, for tool: MBDependencyTool) -> Component? {
        let components = self.fetchComponents(for: tool)
        if components.isEmpty { return nil }
        return components.first { $0.isName(name) }
    }

    dynamic
    public func fetchComponents(_ names: [String], for tool: MBDependencyTool) -> [Component] {
        let components = self.fetchComponents(for: tool)
        let names = names.map { $0.lowercased() }
        return components.filter { c in
            return names.contains { c.isName($0) }
        }
    }

    public func fetchComponents(_ name: String) -> [Component] {
        return self.components.filter { $0.isName(name) }
    }

    public func activatedComponents(for tool: MBDependencyTool) -> [Component] {
        return self.fetchComponents(for: tool).filter { self.model.isActive($0) }
    }

    dynamic
    public func resolveComponents() -> [Component] {
        return []
    }
}
