//
//  Add.swift
//  MBoxDependencyManager
//
//  Created by 詹迟晶 on 2020/4/10.
//  Copyright © 2020 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxWorkspaceCore

var MBCommanderAddComponent: UInt8 = 0
var MBCommanderAddTool: UInt8 = 0
var MBCommanderDisableAllComponents: UInt8 = 0
var MBCommanderActivateAllComponents: UInt8 = 0
extension MBCommander.Add {
    open func convertTools(_ tools: [String]?, in repo: MBConfig.Repo) -> (used: [MBDependencyTool], unused: [MBDependencyTool]) {
        guard let workRepo = repo.workRepository else {
            return (used: [], unused: [])
        }
        let allTools = Array(workRepo.dependencyNamesByTool.keys)
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

    //                          --activate    | --no-actiavte   |  Default
    // add repo                 activate all  |  disable all    |  activate all

    // add component            activate all  |  activate one   |  activate one
    // add repo --component     actiavte all  |  activate one   |  actiavte one
    open func willActivateAllComponents(_ repo: MBWorkRepo) -> Bool {
        var activateAll: Bool?
        if let activateAllComponents = self.activateAllComponents {
            UI.log(info: "Value of activate_all_components is `\(activateAllComponents)` for the `\(repo.name)` according to command flags!")
            activateAll = activateAllComponents
        } else if self.isFirstAdd == true,
                  let activateAllComponents = repo.setting.dependencyManager?.activateAllComponentsAfterAddRepo {
            UI.log(info: "Value of activate_all_components is `\(activateAllComponents)` for the `\(repo.name)` according to the `dependency_manager.activate_all_components_after_add_repo` in the `\(self.workspace.relativePath(repo.setting.filePath!))`!")
            activateAll = activateAllComponents
        } else if self.isFirstAdd == true,
                  let activateAllComponents = MBSetting.merged.dependencyManager?.activateAllComponentsAfterAddRepo {
            UI.log(info: "Value of activate_all_components is `\(activateAllComponents)` for the `\(repo.name)` according to the global/workspace settings!")
            activateAll = activateAllComponents
        }
        if let result = activateAll {
            return result
        } else if !self.searchedByComponentName() {
            return true
        }
        return false
    }

    @_dynamicReplacement(for: run())
    open func dp_run() throws {
        try self.run()
        self.cleanLocalDependencies()

        if let repo = self.addedRepo, let workRepo = repo.workRepository {
            let activateAll = self.willActivateAllComponents(workRepo)
            let (usedTools, unusedTools) = self.convertTools(self.tools, in: repo)
            if activateAll {
                repo.activeAllComponents(for: usedTools)
                if self.isFirstAdd == true {
                    repo.deactiveAllComponents(for: unusedTools)
                }
            } else if self.searchedByComponentName() {
                var components = self.components
                if components == nil, let name = self.name {
                    components = [name]
                }
                if let components = components {
                    for tool in usedTools {
                        repo.activateComponents(components, for: tool, override: self.isFirstAdd!)
                    }
                }
                if self.isFirstAdd == true {
                    repo.deactiveAllComponents(for: unusedTools)
                }
            } else {
                let allTools = Array(workRepo.dependencyNamesByTool.keys)
                repo.deactiveAllComponents(for: allTools)
            }
        }
        self.config.save()
    }

    @_dynamicReplacement(for: searchRepo(by:))
    open func dp_searchRepo(by name: String) throws -> MBConfig.Repo? {
        var repo = try self.searchRepo(by: name)
        if repo == nil {
            repo = try self.workspace.searchRepo(by: [name])
        }
        return repo
    }

    @_dynamicReplacement(for: options)
    open class var dp_Option: [Option] {
        var options = self.options
        options << Option("component", description: "Activate a component, only for `URL`/`PATH`")
        options << Option("tool", description: "Use the specified dependency management tool")
        return options
    }

    @_dynamicReplacement(for: flags)
    open class var dp_flags: [Flag] {
        var flags = self.flags
        flags << Flag("activate-all-components", description: "Activate all component. Default value will be true if add a repo, while default value will be false if add a component. Use `mbox config dependency_manager.activate_all_components_after_add_repo true/false` to change the default behavior.")
        flags << Flag("disable-all-components", description: "Deprecated. Please use `--activate-all-components` instead.")
        return flags
    }


    @_dynamicReplacement(for: setup())
    open func dp_setup() throws {
        self.activateAllComponents = self.shiftFlag("activate-all-components")
        if self.activateAllComponents == nil,
           let disableAllComponents = self.shiftFlag("disable-all-components") {
            self.activateAllComponents = !disableAllComponents
        }
        self.components = self.shiftOptions("component")
        self.tools = self.shiftOptions("tool")
        try self.setup()
    }

    open var components: [String]? {
        set {
            associateObject(base: self, key: &MBCommanderAddComponent, value: newValue)
        }
        get {
            return associatedObject(base: self, key: &MBCommanderAddComponent)
        }
    }

    open var tools: [String]? {
        set {
            associateObject(base: self, key: &MBCommanderAddTool, value: newValue)
        }
        get {
            return associatedObject(base: self, key: &MBCommanderAddTool)
        }
    }

    open var activateAllComponents: Bool? {
        set {
            associateObject(base: self, key: &MBCommanderActivateAllComponents, value: newValue)
        }
        get {
            return associatedObject(base: self, key: &MBCommanderActivateAllComponents)
        }
    }

    @_dynamicReplacement(for: fetchCommitToCheckout(repo:))
    open func dp_fetchCommitToCheckout(repo: MBConfig.Repo) throws {
        try self.fetchCommitToCheckout(repo: repo)
        if let components = self.components {
            repo.additionalPackageNames.append(contentsOf: components)
        }
        if let repo2 = try self.workspace.searchDependency(by: repo.packageNames, createdRepo: repo) {
            repo.url ?= repo2.url
            if let path = repo2._path {
                repo.path = path
            }
            repo.baseGitPointer ?= repo2.baseGitPointer
        }
    }

    open func cleanLocalDependencies() {
        UI.section("Remove Local Dependency") {
            self.addedRepo?.packageNames.forEach { name in
                UI.log(verbose: "removing `\(name)`") {
                    self.config.currentFeature.dependencies.remove(dependency: name)
                }
            }
            self.config.currentFeature.dependencies.save()
        }
    }

    open func searchedByComponentName() -> Bool {
        if self.components?.count ?? 0 > 0 {
            return true
        }
        if let name = self.name,
           let repo = self.addedRepo?.workRepository,
           repo.dependencyNames.first(where: { $0.lowercased() == name.lowercased() }) != nil {
          return true
        }
        return false
    }
}
