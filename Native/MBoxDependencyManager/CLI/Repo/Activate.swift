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
        open class override var description: String? {
            return "Activate a or more components"
        }

        open override class var example: String? {
            let action = String(describing: self).lowercased()
            return """
# \(action.capitalizedFirstLetter) all components in all repositories
$ mbox \(action) *

# \(action.capitalizedFirstLetter) all components in the `repo1`
$ mbox \(action) repo1
# or
$ mbox \(action) repo1/*

# \(action.capitalizedFirstLetter) the component named `component1` in the `repo1`
$ mbox \(action) repo1/component1

# If the componment name is same with the repo name, the `name` will used as a component name:
$ mbox \(action) name
# If you want to \(action) the repo `name`, instead of \(action) the component `name`:
$ mbox \(action) name/*
"""
        }

        open class override var arguments: [Argument] {
            var arguments = super.arguments
            arguments << Argument("name", description: "Component Name, '*' is all repositories, 'REPO/*' is all components in the REPO", required: true, plural: true)
            return arguments
        }

        dynamic
        open override class var options: [Option] {
            var options = [Option]()
            options << Option("tool", description: "Use the specified dependency management tool")
            return options + super.options
        }

        open var names: [String] = []
        open var tools: [MBDependencyTool] = []

        open var components: [MBWorkRepo.Component] = []

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
            try super.setup()
            self.names = self.shiftArguments("name")
        }

        open override func validate() throws {
            if self.names.isEmpty  {
                throw ArgumentError.missingArgument("name")
            }
            if self.names.contains("*"), self.names.count > 1 {
                var names = self.names
                names.removeAll("*")
                throw ArgumentError.invalidValue(value: names.joined(separator: "/"), argument: "name")
            }
            try super.validate()
        }

        open override func run() throws {
            try super.run()

            var names = self.names
            if names.contains("*") {
                names = self.config.currentFeature.repos.map { $0.name + "/*" }
            }

            for name in names {
                try self.handle(name: name, tools: self.tools)
            }

            self.config.save()

            self.config.currentFeature.saveChangedDependenciesLock()
        }

        private func handle(name: String, tools: [MBDependencyTool]) throws {
            if name.hasSuffix("/*") {
                let repoName = name.deleteSuffix("/*")
                if let repo = self.fetchRepo(repoName) {
                    for tool in tools {
                        try self.handle(repo: repo, tool: tool)
                    }
                } else {
                    throw UserError("[\(repoName)] Could not find the repository.")
                }
            } else if let components = self.fetchComponents(name, for: tools) {
                for component in components {
                    try self.handle(component: component)
                }
            } else if name.contains("/") {
                var info = name.split(separator: "/")
                let repoName = info.removeFirst()
                let componentName = info.joined(separator: "/")
                guard let repo = self.fetchRepo(name) else {
                    throw UserError("[\(repoName)] Could not find the repository.")
                }
                guard let components = self.fetchComponents(componentName, in: repo, for: tools) else {
                    throw UserError("[\(name)] Could not find the component.")
                }
                for component in components {
                    try self.handle(component: component)
                }
            } else if let repo = self.fetchRepo(name) {
                for tool in tools {
                    try self.handle(repo: repo, tool: tool)
                }
            } else {
                throw UserError("[\(name)] Could not find the component.")
            }
        }

        func fetchRepo(_ name: String) -> MBConfig.Repo? {
            return self.config.currentFeature.findRepo(name: name, searchPackageName: false).first
        }

        func fetchComponents(_ name: String, in repo: MBConfig.Repo? = nil, for tools: [MBDependencyTool]) -> [MBWorkRepo.Component]? {
            let repos = (repo != nil) ? [repo!] : self.config.currentFeature.repos
            for repo in repos {
                if let components = repo.workRepository?.fetchComponents(name) {
                    let filtered = components.filter { tools.contains($0.tool) }
                    if filtered.isEmpty { continue }
                    return filtered
                }
            }
            return nil
        }

        open func handle(repo: MBConfig.Repo, tool: MBDependencyTool) throws {
            repo.activeAllComponents(for: tool)
        }

        open func handle(component: MBWorkRepo.Component) throws {
            component.repo?.model.activateComponent(component)
        }
    }
}
