//
//  MBConfig.Repo+Components.swift
//  MBoxDependencyManager
//
//  Created by Whirlwind on 2020/12/2.
//  Copyright © 2020 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore

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

    public var components: [Component] {
        set {
            self.setValue(newValue, forPath: "components")
        }
        get {
            return self.value(forPath: "components")
        }
    }

    public func activatedComponents(for tool: MBDependencyTool) -> [String] {
        if let component = self.components.first(where: { $0.tool == tool }) {
            return component.active
        }
        guard let workRepo = self.workRepository else { return [] }
        return workRepo.fetchComponents(for: tool).map(\.name)
    }

    public func isActive(_ component: MBWorkRepo.Component) -> Bool {
        guard let c = self.components.first(where: {
            $0.tool == component.tool
        }) else {
            return true
        }
        return c.active.contains { component.isName($0) }
    }

    public func fetchComponent(for tool: MBDependencyTool, fetchDefaults: Bool = true) -> Component {
        if let component = self.components.first(where: { $0.tool == tool }) {
            return component
        }
        let component = Component(tool: tool)
        if fetchDefaults, let dps = self.workRepository?.fetchComponents(for: tool) {
            component.active = dps.map(\.name)
        }
        self.components.append(component)
        return component
    }

    public func activateComponent(_ component: MBWorkRepo.Component) {
        UI.log(info: "[\(self)] Activate component `\(component.name)` for \(component.tool)") {
            let config = self.fetchComponent(for: component.tool)
            if !config.active.contains(component.name) {
                config.active.append(component.name)
            }
        }
    }

    public func activateComponents(_ names: [String], for tool: MBDependencyTool, override: Bool = false) {
        guard let dps = self.workRepository?.fetchComponents(names, for: tool),
              !dps.isEmpty else {
            return
        }
        let tool = dps.first!.tool
        let component = self.fetchComponent(for: tool, fetchDefaults: !override)
        if override {
            UI.log(info: "[\(self)] (Override) Activate components \(dps.map { "`\($0.name)`" }.joined(separator: ", ")) for \(tool)") {
                component.active = dps.map(\.name)
            }
        } else {
            UI.log(info: "[\(self)] (Append) Activate components \(dps.map { "`\($0.name)`" }.joined(separator: ", ")) for \(tool)") {
                component.active.append(contentsOf: dps.map(\.name))
            }
        }
        component.active.removeDuplicates()
    }

    public func deactivateComponent(_ component: MBWorkRepo.Component) {
        UI.log(info: "[\(self)] Deactivate component `\(component.name)` for \(component.tool)") {
            let componentConfig = self.fetchComponent(for: component.tool)
            componentConfig.active.removeAll(component.name)
        }
    }

    public func activeAllComponents(for tool: MBDependencyTool) {
        UI.log(info: "[\(self)] Activate all components for \(tool)") {
            self.components.removeAll { $0.tool == tool }
        }
    }

    public func activeAllComponents(for tools: [MBDependencyTool]) {
        for tool in tools {
            self.activeAllComponents(for: tool)
        }
    }

    public func deactiveAllComponents(for tool: MBDependencyTool) {
        UI.log(info: "[\(self)] Deactivate all components for \(tool)") {
            let component = self.fetchComponent(for: tool, fetchDefaults: false)
            component.active = []
        }
    }

    public func deactiveAllComponents(for tools: [MBDependencyTool]) {
        for tool in tools {
            self.deactiveAllComponents(for: tool)
        }
    }
}
