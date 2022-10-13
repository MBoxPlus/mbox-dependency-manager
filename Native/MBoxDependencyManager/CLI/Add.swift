//
//  Add.swift
//  MBoxDependencyManager
//
//  Created by Whirlwind on 2020/4/10.
//  Copyright © 2020 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxWorkspace

var MBCommanderAddComponent: UInt8 = 0
var MBCommanderAddTool: UInt8 = 0
var MBCommanderDisableAllComponents: UInt8 = 0
var MBCommanderActivateAllComponents: UInt8 = 0
extension MBCommander.Add {
    public func convertTools(_ tools: [String]?, in repo: MBConfig.Repo) -> (used: [MBDependencyTool], unused: [MBDependencyTool]) {
        guard let workRepo = repo.workRepository else {
            return (used: [], unused: [])
        }
        let allTools = Array(workRepo.componentsByTool.keys)
        guard let userTools = tools else {
            return (used: allTools, unused: [])
        }
        let used = userTools.compactMap { t -> MBDependencyTool? in
            for at in allTools {
                if at == t {
                    return at
                }
            }
            UI.log(warn: "Could not find dependency tool \(t).")
            return nil
        }
        return (used: used,
                unused: allTools.filter { !used.contains($0) }
        )
    }

    //                              --activate    | --no-actiavte   |  Default
    // add repo                     activate all  |  disable all    |  activate all

    // add component                activate all  |  activate one   |  activate one
    // add repo --component         actiavte all  |  activate one   |  actiavte one
    // add component --component    actiavte all  |  activate one   |  actiavte one
    //
    // If the `NAME` is both a repo name and a component name, first be repo.
    public func willActivatedComponents(_ repo: MBWorkRepo) -> [String]? {
        var activateAll: Bool?
        if let activateAllComponents = self.activateAllComponents {
            UI.log(verbose: "[\(repo)] Activate all components: \(activateAllComponents), by `-\(activateAllComponents ? "" : "-no")-activate-all-components`")
            activateAll = activateAllComponents
        } else if self.isFirstAdd == true,
                  let activateAllComponents = repo.setting.dependencyManager?.activateAllComponentsAfterAddRepo {
            UI.log(verbose: "[\(repo)] Activate all components: \(activateAllComponents), by the setting `dependency_manager.activate_all_components_after_add_repo` in repo")
            activateAll = activateAllComponents
        } else if self.isFirstAdd == true,
                  let activateAllComponents = MBSetting.merged.dependencyManager?.activateAllComponentsAfterAddRepo {
            UI.log(verbose: "[\(repo)] Activate all components: \(activateAllComponents), by the global/workspace setting")
            activateAll = activateAllComponents
        }
        if let activateAll = activateAll {
            if activateAll {
                return [] // All
            } else if !self.searchedByComponentName, self.components == nil {
                return nil // None
            }
        } else if self.searchedByRepoName, self.components == nil {
            return [] // All
        }
        var components = self.components
        if components == nil, let name = self.name {
            components = [name]
        }
        if let components  = components {
            UI.log(info: "[\(repo)] Activate components:", items: components)
            return components
        } else {
            return [] // All
        }
    }
    
    @_dynamicReplacement(for: run())
    public func dp_run() throws {
        try self.run()
        try self.dependenciesConfig()
    }

    dynamic
    public func dependenciesConfig() throws{
        self.cleanLocalDependencies()

        if let repo = self.addedRepo, let workRepo = repo.workRepository {
            let components = self.willActivatedComponents(workRepo)
            let (usedTools, unusedTools) = self.convertTools(self.tools, in: repo)
            if let components = components {
                if components.isEmpty { // Activate All
                    repo.activeAllComponents(for: usedTools)
                    if self.isFirstAdd == true {
                        repo.deactiveAllComponents(for: unusedTools)
                    }
                } else {
                    for tool in usedTools {
                        repo.activateComponents(components, for: tool, override: self.isFirstAdd!)
                    }
                    if self.isFirstAdd == true {
                        repo.deactiveAllComponents(for: unusedTools)
                    }
                }
            } else { // Deactivate All
                let allTools = Array(workRepo.componentsByTool.keys)
                repo.deactiveAllComponents(for: allTools)
            }
        }
        self.config.save()
        self.config.currentFeature.saveChangedDependenciesLock()
    }

    @_dynamicReplacement(for: searchRepo(by:))
    public func dp_searchRepo(by name: String) throws -> MBConfig.Repo? {
        var repo = try self.searchRepo(by: name)
        if repo == nil,
           let dependency = try self.workspace.searchDependency(by: [name]) {
            repo = MBConfig.Repo(feature: self.config.currentFeature, dependency: dependency)
        }
        return repo
    }

    @_dynamicReplacement(for: options)
    public class var dp_Option: [Option] {
        var options = self.options
        options << Option("component", description: "Activate a component, only for `URL`/`PATH`")
        options << Option("tool", description: "Use the specified dependency management tool")
        return options
    }

    @_dynamicReplacement(for: flags)
    public class var dp_flags: [Flag] {
        var flags = self.flags
        flags << Flag("activate-all-components", description: "Activate all components. Default value will be true if add a repo, while default value will be false if add a component. Use `mbox config dependency_manager.activate_all_components_after_add_repo true/false` to change the default behavior.")
        return flags
    }


    @_dynamicReplacement(for: setup())
    public func dp_setup() throws {
        self.activateAllComponents = self.shiftFlag("activate-all-components")
        self.components = self.shiftOptions("component")
        self.tools = self.shiftOptions("tool")
        try self.setup()
    }

    public var components: [String]? {
        set {
            associateObject(base: self, key: &MBCommanderAddComponent, value: newValue)
        }
        get {
            return associatedObject(base: self, key: &MBCommanderAddComponent)
        }
    }

    public var tools: [String]? {
        set {
            associateObject(base: self, key: &MBCommanderAddTool, value: newValue)
        }
        get {
            return associatedObject(base: self, key: &MBCommanderAddTool)
        }
    }

    public var activateAllComponents: Bool? {
        set {
            associateObject(base: self, key: &MBCommanderActivateAllComponents, value: newValue)
        }
        get {
            return associatedObject(base: self, key: &MBCommanderActivateAllComponents)
        }
    }

    @_dynamicReplacement(for: fetchCommitToCheckout(repo:))
    public func dp_fetchCommitToCheckout(repo: MBConfig.Repo) throws {
        try self.fetchCommitToCheckout(repo: repo)
        let components = self.components ?? []
        if let dependency = try self.workspace.searchDependency(by: components, createdRepo: repo) {
            repo.url ?= dependency.git
            if let path = dependency.path {
                repo.path = path
            }
            repo.baseGitPointer ?= dependency.gitPointer
        }
    }

    public func cleanLocalDependencies() {
        UI.section("Remove Local Dependency") {
            self.addedRepo?.packageNames.forEach { name in
                UI.log(verbose: "removing `\(name)`") {
                    self.config.currentFeature.dependencies.remove(dependency: name)
                }
            }
            self.config.currentFeature.dependencies.save()
        }
    }

    public var searchedByRepoName: Bool {
        guard let name = self.name else { return false }
        if let repo = self.addedRepo,
           repo.name.lowercased() == name.lowercased() {
            return true
        }
        if let repo = self.addedRepo?.workRepository,
           repo.name.lowercased() == name.lowercased() {
            return true
        }
        return false
    }

    public var searchedByComponentName: Bool {
        guard let name = self.name?.lowercased(),
              let repo = self.addedRepo?.workRepository else {
            return false
        }
        return repo.components.contains {
            $0.isName(name)
        }
    }
}
