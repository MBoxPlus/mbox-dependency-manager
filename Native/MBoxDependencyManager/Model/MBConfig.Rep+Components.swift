//
//  MBConfig.Repo.swift
//  MBoxDependencyManager
//
//  Created by Whirlwind on 2020/12/2.
//  Copyright © 2020 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxWorkspaceCore

extension MBConfig.Repo {

    open class Component: MBCodableObject {
        @Codable
        open var tool: MBDependencyTool
        @Codable
        open var active: [String]

        convenience init(tool: MBDependencyTool) {
            self.init()
            self.tool = tool
        }
    }

    open var components: [Component] {
        set {
            self.setValue(newValue, forPath: "components")
        }
        get {
            return self.value(forPath: "components")
        }
    }

    open func activatedComponents(for tool: MBDependencyTool) -> [String] {
        if let component = self.components.first(where: { $0.tool == tool }) {
            return component.active
        }
        return self.workRepository?.fetchDependencyNames(for: tool)?.dependencies ?? []
    }

    open func isActive(component: String, for tool: MBDependencyTool) -> Bool {
        guard let c = self.components.first(where: {
            $0.tool == tool
        }) else {
            return true
        }
        return ((c.active.first { $0.lowercased() == component.lowercased() }) != nil)
    }

    open func fetchComponent(for tool: MBDependencyTool, fetchDefaults: Bool = true) -> Component {
        if let component = self.components.first(where: { $0.tool == tool }) {
            return component
        }
        let component = Component(tool: tool)
        if fetchDefaults, let dps = self.workRepository?.fetchDependencyNames(for: tool)?.dependencies {
            component.active = dps
        }
        self.components.append(component)
        return component
    }

    open func activateComponent(_ name: String, for tool: MBDependencyTool) {
        UI.log(info: "[\(self)] Activate component `\(name)` for \(tool)") {
            let component = self.fetchComponent(for: tool)
            if !component.active.contains(name) {
                component.active.append(name)
            }
        }
    }

    open func activateComponents(_ names: [String], for tool: MBDependencyTool, override: Bool = false) {
        guard let dps = self.workRepository?.fetchDependencies(names, for: tool) else {
            return
        }
        let component = self.fetchComponent(for: dps.tool, fetchDefaults: !override)
        if override {
            UI.log(info: "[\(self)] (Override) Activate components \(dps.dependencies.map { "`\($0)`" }.joined(separator: ", ")) for \(dps.tool)") {
                component.active = dps.dependencies
            }
        } else {
            UI.log(info: "[\(self)] (Append) Activate components \(dps.dependencies.map { "`\($0)`" }.joined(separator: ", ")) for \(dps.tool)") {
                component.active.append(contentsOf: dps.dependencies)
            }
        }
        component.active.removeDuplicates()
    }

    open func deactivateComponent(_ name: String, for tool: MBDependencyTool) {
        UI.log(info: "[\(self)] Deactivate component `\(name)` for \(tool)") {
            let component = self.fetchComponent(for: tool)
            component.active.removeAll(name)
        }
    }

    open func activeAllComponents(for tool: MBDependencyTool) {
        UI.log(info: "[\(self)] Activate all components for \(tool)") {
            self.components.removeAll { $0.tool == tool }
        }
    }

    open func activeAllComponents(for tools: [MBDependencyTool]) {
        for tool in tools {
            self.activeAllComponents(for: tool)
        }
    }

    open func deactiveAllComponents(for tool: MBDependencyTool) {
        UI.log(info: "[\(self)] Deactivate all components for \(tool)") {
            let component = self.fetchComponent(for: tool, fetchDefaults: false)
            component.active = []
        }
    }

    open func deactiveAllComponents(for tools: [MBDependencyTool]) {
        for tool in tools {
            self.deactiveAllComponents(for: tool)
        }
    }
}
