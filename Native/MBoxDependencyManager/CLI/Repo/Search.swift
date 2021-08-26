//
//  Search.swift
//  MBoxDependencyManager
//
//  Created by Whirlwind on 2020/4/14.
//  Copyright © 2020 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxWorkspaceCore
import MBoxWorkspace

var MBCommanderSearchOnlySeachRemoteFlag: UInt8 = 0

extension MBCommander.Repo.Search {
    open var onlySeachRemote: Bool? {
        set {
            associateObject(base: self, key: &MBCommanderSearchOnlySeachRemoteFlag, value: newValue)
        }
        get {
            associatedObject(base: self, key: &MBCommanderSearchOnlySeachRemoteFlag)
        }
    }

    @_dynamicReplacement(for: flags)
    open class var dp_flags: [Flag] {
        var flags = self.flags
        flags << Flag("only-search-remote", description: "Search repo on remote")
        return flags
    }

    @_dynamicReplacement(for: setup())
    open func dp_setup() throws {
        self.onlySeachRemote = self.shiftFlag("only-search-remote")
        try self.setup()
    }

    @_dynamicReplacement(for: search(name:owner:))
    open func dp_search(name: String, owner: String? = nil) throws -> MBConfig.Repo? {
        var repo: MBConfig.Repo?
        if self.onlySeachRemote != true {
            repo = try self.search(name: name, owner: owner)
        }
        if repo == nil {
            if let dependency = try self.workspace.searchDependency(by: [name]) {
                repo = MBConfig.Repo(feature: self.config.currentFeature)
                repo?.resolveName(dependency.name, path: dependency.path, gitURL: MBGitURL(dependency.git ?? ""))
                repo?.lastGitPointer ?= dependency.gitPointer
                repo?.baseGitPointer ?= dependency.gitPointer
            }
        }
        return repo
    }
}
