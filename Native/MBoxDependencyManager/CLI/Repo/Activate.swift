//
//  Activate.swift
//  MBoxWorkspace
//
//  Created by Whirlwind on 2020/12/2.
//  Copyright © 2020 bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxWorkspaceCore

extension MBCommander {
    open class Activate: Repo {
        open class Component: Equatable {
            public static func == (lhs: MBCommander.Activate.Component, rhs: MBCommander.Activate.Component) -> Bool {
                return lhs.name == rhs.name &&
                    lhs.repo == rhs.repo &&
                    lhs.tool == rhs.tool
            }

            open var name: String?
            open var tool: MBDependencyTool
            open var repo: MBConfig.Repo
            public init(name: String? = nil, for tool: MBDependencyTool, in repo: MBConfig.Repo) {
                self.name = name
                self.tool = tool
                self.repo = repo
            }
        }

        open class override var description: String? {
            return "Activate a or more components"
        }

        open class override var arguments: [Argument] {
            var arguments = super.arguments
            arguments << Argument("name", description: "Repo/Component Name", required: true)
            return arguments
        }

        dynamic
        open override class var options: [Option] {
            var options = [Option]()
            options << Option("tool", description: "Use the specified dependency management tool")
            return options + super.options
        }

        open override class var flags: [Flag] {
            var flags = super.flags
            flags << Flag("all", description: "All Components")
            return flags
        }

        open var names: [String] = []
        open var all: Bool = false
        open var tools: [MBDependencyTool] = []

        open var components: [Component] = []

        open override func setup() throws {
            if let tools: [String] = self.shiftOptions("tool") {
                for tool in tools {
                    let t = try MBDependencyTool.tool(for: tool)
                    if !self.tools.contains(t) {
                        self.tools.append(t)
                    }
                }
            } else {
                self.tools = MBDependencyTool.allTools
            }
            self.all = self.shiftFlag("all")
            try super.setup()
            self.names = self.shiftArguments("name")
        }

        open override func validate() throws {
            if !self.all && self.names.isEmpty  {
                throw UserError("Require component names, or you can use `--all` to handle all components.")
            }
            try super.validate()
        }

        open override func run() throws {
            try super.run()
            if self.all {
                try self.handle(tools: self.tools)
            } else {
                self.components = try self.fetchComponents(self.names, for: self.tools)
                try self.handle(components: self.components)
            }
            self.config.save()

            self.config.currentFeature.saveChangedDependenciesLock()
        }

        open func handle(tools: [MBDependencyTool]) throws {
            for tool in tools {
                for repo in self.config.currentFeature.repos {
                    repo.activeAllComponents(for: tool)
                }
            }
        }

        open func handle(components: [Component]) throws {
            for component in components {
                if let name = component.name {
                    component.repo.activateComponent(name, for: component.tool)
                } else {
                    component.repo.activeAllComponents(for: component.tool)
                }
            }
        }

        open func fetchRepo(_ name: String) -> MBConfig.Repo? {
            return self.config.currentFeature.repos.first {
                $0.name.lowercased() == name.lowercased()
            }
        }

        open func fetchDependency(_ name: String, for tool: MBDependencyTool) -> Component? {
            for r in self.config.currentFeature.repos {
                if let workRepo = r.workRepository,
                   let (t, d) = workRepo.fetchDependency(name, for: tool) {
                    return Component(name: d, for: t, in: r)
                }
            }
            return nil
        }

        open func fetchComponent(_ name: String, for tool: MBDependencyTool) throws -> Component {
            var info = name.split(separator: "/")
            let repoName = String(info.removeFirst())
            var componentName = info.joined(separator: "/")
            var repo: MBConfig.Repo?
            if let r = self.fetchRepo(repoName) {
                repo = r
            } else {
                componentName = name
            }
            if let repo = repo {
                if componentName.isEmpty {
                    if let workRepo = repo.workRepository,
                       let (t, d) = workRepo.fetchDependency(repoName, for: tool) {
                        return Component(name: d, for: t, in: repo)
                    }
                    return Component(for: tool, in: repo)
                }
                if let workRepo = repo.workRepository,
                   let (t, d) = workRepo.fetchDependency(componentName, for: tool) {
                    return Component(name: d, for: t, in: repo)
                }
                throw UserError("Could not find component which named `\(componentName)` in repo `\(repo.name)`.")
            } else {
                if let component = self.fetchDependency(componentName, for: tool) {
                    return component
                }
                throw UserError("Could not find component which named `\(name)`.")
            }
        }

        open func fetchComponents(_ names: [String], for tools: [MBDependencyTool]) throws -> [Component] {
            var v = [Component]()
            for name in names {
                var found = false
                for tool in tools {
                    guard let component = try? self.fetchComponent(name, for: tool) else {
                        continue
                    }
                    found = true
                    if component.name == nil {
                        // Activate all components
                        v.removeAll {
                            $0.repo == component.repo && $0.tool == component.tool
                        }
                        v.append(component)
                        continue
                    }
                    if v.contains(where: {
                        $0.name == nil && $0.name == component.name && $0.tool == component.tool
                    }) {
                        // All components already be activated
                        continue
                    }
                    if !v.contains(where: { $0 == component }) {
                        v.append(component)
                    }
                }
                if !found {
                    throw UserError("Could not find component which named `\(name)`.")
                }
            }
            return v.sorted {
                $0.repo.name >= $1.repo.name &&
                    $0.tool >= $1.tool &&
                    ($0.name ?? "") >= ($1.name ?? "")
            }
        }

    }
}
