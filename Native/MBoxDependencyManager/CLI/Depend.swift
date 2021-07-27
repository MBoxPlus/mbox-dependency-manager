//
//  Depend.swift
//  MBoxDependencyManager
//
//  Copyright © 2019 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxWorkspaceCore

extension MBCommander {
    open class Depend: MBCommander {

        open class override var description: String? {
            return "Show/Change dependencies"
        }

        open override class var arguments: [Argument] {
            return [Argument("name", description: "The dependency name", required: false)]
        }

        open override class var options: [Option] {
            var options = super.options
            options << Option("source", description: "Set source")
            options << Option("version", description: "Set version")
            options << Option("git", description: "Set git url")
            options << Option("commit", description: "Set git commit")
            options << Option("tag", description: "Set git tag")
            options << Option("branch", description: "Set git branch")
            options << Option("path", description: "Set local path")

            options << Option("tool", description: "Use the specified dependency management tool")
            return options
        }

        dynamic
        open override class var flags: [Flag] {
            var flags = super.flags
            flags << Flag("binary", description: "Use binary version")
            flags << Flag("source", description: "Use source version")
            flags << Flag("reset", description: "Reset to default version")
            return flags
        }

        open var useBinary: Bool?
        open var reset: Bool?

        open var name: String?

        open var source: String?
        open var version: String?
        open var git: String?
        open var commit: String?
        open var tag: String?
        open var branch: String?
        open var path: String?

        open var tool: MBDependencyTool?

        dynamic
        open override func setup() throws {
            self.useBinary = self.shiftFlag("binary")
            if self.useBinary == nil, let useSource = self.shiftFlag("source") {
                self.useBinary = !useSource
            }
            self.reset = self.shiftFlag("reset")

            self.version = self.shiftOption("version")
            self.source = self.shiftOption("source")
            self.git = self.shiftOption("git")
            self.commit = self.shiftOption("commit")
            self.tag = self.shiftOption("tag")
            self.branch = self.shiftOption("branch")
            self.path = self.shiftOption("path")

            if let name: String = self.shiftOption("tool") {
                let tool: MBDependencyTool = try MBDependencyTool.tool(for: name)
                self.tool = tool
            }

            self.name = self.shiftArgument("name")
            try super.setup()
        }

        open var isEditMode: Bool {
            return self.name != nil && (self.useBinary != nil || self.source != nil || self.version != nil || self.git != nil || self.commit != nil || self.tag != nil || self.branch != nil || self.reset != nil)
        }

        dynamic
        open override func run() throws {
            try super.run()
            if self.reset == true {
                if let name = self.name {
                    self.config.currentFeature.dependencies.remove(dependency: name, in: self.tool)
                } else {
                    self.config.currentFeature.dependencies.removeAll(in: self.tool)
                }
                self.config.currentFeature.dependencies.save()
            } else if self.isEditMode {
                try edit()
                self.config.currentFeature.dependencies.save()
                try show()
            } else if self.name != nil {
                try show()
            } else {
                try showAll()
            }
        }

        open func edit() throws {
            guard let name = self.name else { return }
            for repo in self.config.currentFeature.repos {
                if repo.packageNames.contains(name) {
                    throw RuntimeError("[\(repo)] contains the package `\(name)`, you could not set external dependency when it was added.")
                }
            }
            let dependency: UserDependency = try self.config.currentFeature.dependencies.dependency(for: name, in: self.tool)
            dependency.change(version: self.version, source: self.source, git: self.git, branch: self.branch, commit: self.commit, tag: self.tag, path: self.path, binary: self.useBinary)
        }

        open func showAll() throws {
            let array = self.config.currentFeature.dependencies.array
            if UI.apiFormatter == .none {
                if array.isEmpty {
                    UI.log(info: "No configure custom dependencies.")
                } else {
                    UI.log(info: array.map { $0.description }.joined(separator: "\n"))
                }
            } else {
                UI.log(api: array.toCodableObject() as Any)
            }
        }

        open func show() throws {
            guard let dp = try self.config.currentFeature.dependencies.dependency(for: self.name!, in: self.tool) else {
                UI.log(info: "No configure for dependency `\(self.name!)`.".ANSI(.magenta))
                return
            }
            UI.log(info: dp.description)
        }
    }
}

