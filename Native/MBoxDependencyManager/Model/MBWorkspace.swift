//
//  MBWorkspace.swift
//  MBoxDependencyManager
//
//  Created by 詹迟晶 on 2020/2/26.
//  Copyright © 2020 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxWorkspaceCore

public protocol MBDependencySearchEngine {
    var engineName: String { get }
    var enginePriority: Int { get }
    func getCurrentDependency(by names: [String]) throws -> Dependency?
    func searchDependency(name: String, version: String?) throws -> (MBConfig.Repo, Date?)?
    func getCurrentDependenciesInSameRepo(by dependency: Dependency) -> [Dependency]
}

extension MBDependencySearchEngine {
    public func getCurrentDependenciesInSameRepo(by dependency: Dependency) -> [Dependency] {
        return []
    }
}

var MBSearchEnginesFlag: UInt8 = 0
extension MBWorkspace {
    @_dynamicReplacement(for: plugins)
    open var dp_plugins: [String: [MBSetting.PluginDescriptor]] {
        var result = self.plugins
        let name = getModuleName(forClass: MBoxDependencyManager.self)
        result[name] ?= []
        result[name]?.append(MBSetting.PluginDescriptor(requiredBy: "Application"))
        return result
    }

    open func searchDependency(by names: [String], createdRepo: MBConfig.Repo? = nil) throws -> MBConfig.Repo? {
        do {
            guard let dp = try getCurrentDependency(by: names) else { return nil }
            let dps = self.getCurrentDependenciesInSameRepo(by: dp)
            if dps.count > 0 {
                UI.log(info: "Found other dependencies \(dps.compactMap({ $0.name ?? "" }).description) in the same repo")
                return try self.repoBy(dependency: dp, sameRepoDependencies: dps, createdRepo: createdRepo)
            } else {
                return try self.repoBy(dependency: dp)
            }
        } catch let error as RuntimeError {
            UI.log(warn: "\(error)")
            return nil
        }
    }

    open func getCurrentDependency(by names: [String]) throws -> Dependency? {
        let engines = self.searchEngines
        if engines.isEmpty {
            UI.log(error: "There is not a valid dependency search engine.")
            return nil
        }
        for engine in engines {
            let desc = names.map { "`\($0)`" }.joined(separator: ", ")
            let dp = UI.log(verbose: "[\(engine.engineName)] Search dependency for \(desc):", resultOutput: { $0?.description ?? "[\(engine.engineName)] Could not find the dependency \(desc)"}) { () -> Dependency? in
                do {
                    return try engine.getCurrentDependency(by: names)
                } catch {
                    UI.log(verbose: error.localizedDescription)
                    return nil
                }
            }
            if let dp = dp { return dp }
        }
        return nil
    }

    open func getCurrentDependenciesInSameRepo(by dependency: Dependency) -> [Dependency] {
        var result = [Dependency]()
        let engines = self.searchEngines
        if engines.isEmpty {
            UI.log(error: "There is not a valid dependency search engine.")
            return result
        }
        for engine in engines {
            result = UI.log(verbose: "[\(engine.engineName)] Search dependency for \(dependency.name ?? ""):") { () -> [Dependency] in
                return engine.getCurrentDependenciesInSameRepo(by: dependency)
            }
            if result.count > 0 { return result }
        }
        return result
    }

    public func repoBy(dependency: Dependency, sameRepoDependencies: [Dependency] = [], createdRepo: MBConfig.Repo? = nil) throws -> MBConfig.Repo? {
        let name = dependency.name!
        var repo = MBConfig.Repo(name: name, feature: self.config.currentFeature)
        var commits = [String]()

        switch dependency.mode {
        case .local:
            var path = dependency.path!.expandingTildeInPath
            if !path.hasPrefix("/") {
                path = self.rootPath.appending(pathComponent: path)
            }
            if !path.isDirectory {
                throw RuntimeError("The path does not exist: \(path)")
            }
            repo.path = path
            UI.log(verbose: "Dependency `\(repo.name)` use local path: `\(dependency.path!)`.")
        case .remote:
            repo.url = dependency.git
            if dependency.commit != nil && sameRepoDependencies.count > 0 {
                commits.append(dependency.commit!)
                let commitMissing = sameRepoDependencies.any { $0.commit == nil}
                if commitMissing {
                    return try searchRepo(by: dependency, dependenciesInSameRepo: sameRepoDependencies, createdRepo: createdRepo)
                } else {
                    let otherCommits = sameRepoDependencies.compactMap { $0.commit }
                    commits.append(contentsOf: otherCommits)
                }
            } else {
                repo.baseGitPointer = dependency.gitPointer
            }
            UI.log(verbose: "Dependency `\(repo.name)` use remote url: `\(repo.url ?? "")` (\(repo.baseGitPointer?.description ?? "")).")
        default:
            return try searchRepo(by: dependency, dependenciesInSameRepo: sameRepoDependencies, createdRepo: createdRepo)
        }

        if createdRepo != nil && commits.count > 1 {
            try UI.section("Calculate the latest commit from these commits: [\(commits.joined(separator: ", "))]") {
                if let latestCommit = try createdRepo!.originRepository?.git?.calculateLatestCommit(commits: commits) {
                    UI.log(info: "Find the latest commit sha: \(latestCommit).")
                    repo.baseGitPointer = .commit(latestCommit)
                } else {
                    UI.log(verbose: "These commits are not in linear history.")
                    if let r = try searchRepo(by: dependency, dependenciesInSameRepo: sameRepoDependencies, createdRepo: createdRepo) {
                        repo = r
                    }
                }
            }

        }
        return repo
    }


    open var searchEngines: [MBDependencySearchEngine] {
        return associatedObject(base: self, key: &MBSearchEnginesFlag) {
            let engines = self.setupSearchEngines()
            if engines.isEmpty { return self.setupSearchEngines() }
            return engines.sorted { (a, b) -> Bool in
                a.enginePriority > b.enginePriority
            }
        }
    }

    dynamic
    open func setupSearchEngines() -> [MBDependencySearchEngine] {
        return []
    }

    open func searchRepo(by dependency: Dependency, dependenciesInSameRepo: [Dependency], createdRepo: MBConfig.Repo?) throws -> MBConfig.Repo? {
        guard let dependencyName = dependency.name else {
            UI.log(error: "Dependency's name is nil.")
            return nil
        }

        let engines = self.searchEngines
        if engines.isEmpty {
            UI.log(error: "There is not a valid dependency search engine.")
            return nil
        }
        var dependencyRepo: MBConfig.Repo?
        var createTimeByCommitId = Dictionary<String, Date?>()

        UI.log(verbose: "Search dependency \(dependencyName) and other same repo dependencies \(dependenciesInSameRepo.compactMap({ $0.name }).joined(separator: ", ")):")
        for engine in engines {
            UI.log(verbose: "[\(engine.engineName)] Query \(dependencyName):")
            do {
                if let (repo, createTime) = try engine.searchDependency(name: dependencyName, version: dependency.version) {
                    UI.log(verbose: "\(repo.name): \(repo.url ?? "") \(repo.baseGitPointer?.description ?? "")")
                    guard repo.baseGitPointer != nil else {
                        continue
                    }
                    dependencyRepo = repo
                    if repo.baseGitPointer?.isCommit == true {
                        createTimeByCommitId.setValue(createTime, forKeyPath: repo.baseGitPointer!.value)
                        if createTime != nil {
                            break
                        }
                    }
                }
            } catch {
                UI.log(verbose: error.localizedDescription)
            }
        }

        dependenciesInSameRepo.forEach { otherDependency in
            guard let depName = otherDependency.name else {
                return
            }
            for engine in engines {
                UI.log(verbose: "[\(engine.engineName)] Query \(depName):")
                do {
                    if let (repo, createTime) = try engine.searchDependency(name: depName, version: otherDependency.version) {
                        UI.log(verbose: "\(repo.name): \(repo.url ?? "") \(repo.baseGitPointer?.description ?? "") \(createTime?.description ?? "")")
                        if repo.baseGitPointer != nil && repo.baseGitPointer?.isCommit == true {
                            createTimeByCommitId.setValue(createTime, forKeyPath: repo.baseGitPointer!.value)
                            if createTime != nil {
                                break
                            }
                        }
                    }
                } catch {
                    UI.log(verbose: error.localizedDescription)
                }
            }
        }

        if createdRepo != nil &&
            dependenciesInSameRepo.count > 0 &&
            createTimeByCommitId.count > 0 {
            try UI.section("Calculate the latest commit from these commits: [\(createTimeByCommitId.keys.joined(separator: ", "))]") {
                if let latestCommit = try createdRepo!.originRepository?.git?.calculateLatestCommit(commits: Array(createTimeByCommitId.keys)) {
                    UI.log(info: "Find the latest commit sha: \(latestCommit) sorted by linear git history.")
                    dependencyRepo?.baseGitPointer = .commit(latestCommit)
                } else {
                    var commitAndDate: (String, Date)?
                    createTimeByCommitId.forEach { (commit, d) in
                        guard let date = d else {
                            return
                        }
                        if commitAndDate == nil || date > commitAndDate!.1 {
                            commitAndDate = (commit, date)
                        }
                    }
                    if let commitAndDate = commitAndDate {
                        UI.log(info: "Find the latest commit sha: \(commitAndDate.0) created at \(commitAndDate.1.description) sorted by created time.")
                        dependencyRepo?.baseGitPointer = .commit(commitAndDate.0)
                    }
                }
            }

        }


        return dependencyRepo
    }

    open func searchRepo(by names: [String], version: String? = nil) throws -> MBConfig.Repo? {
        let engines = self.searchEngines
        if engines.isEmpty {
            UI.log(error: "There is not a valid dependency search engine.")
            return nil
        }
        for name in names {
            for engine in engines {
                let repo: MBConfig.Repo? = UI.log(verbose: "[\(engine.engineName)] Query \(name) \(version ?? ""):") {
                    do {
                        if let (repo, _) = try engine.searchDependency(name: name, version: version) {
                            UI.log(verbose: "\(repo.name): \(repo.url ?? "") \(repo.baseGitPointer?.description ?? "")")
                            if repo.baseGitPointer != nil || version == nil {
                                return repo
                            }
                        }
                    } catch {
                        UI.log(verbose: error.localizedDescription)
                    }
                    return nil
                }
                if let repo = repo { return repo }
            }
        }
        return nil
    }
}
