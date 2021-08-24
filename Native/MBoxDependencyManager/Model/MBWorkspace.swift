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
    func getCurrentDependenciesInSameRepo(by dependency: Dependency) -> [Dependency]
    func resolveDependency(name: String, version: String?, url: String?) throws -> Dependency?
    func getReleaseDate(name: String, version: String?, url: String?) throws -> Date?
}

extension MBDependencySearchEngine {
    public func getCurrentDependenciesInSameRepo(by dependency: Dependency) -> [Dependency] {
        return []
    }
    public func getReleaseDate(name: String, version: String?, url: String?) throws -> Date? {
        return nil
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

    open func getCurrentDependency(by names: [String]) throws -> Dependency? {
        let title = names.map { "`\($0)`" }.joined(separator: ", ")
        return self.lookupEngines(title, { $0?.description ?? "Could not find the dependency \(title)"}) { engine in
            return try engine.getCurrentDependency(by: names)
        }
    }

    open func getCurrentDependenciesInSameRepo(by dependency: Dependency) -> [Dependency] {
        return self.lookupEngines("Search dependencies with \(dependency.name!)", { ($0 ?? []).map { "- " + $0.description }.joined(separator: "\n") }) { engine in
            let value = engine.getCurrentDependenciesInSameRepo(by: dependency)
            return value.count == 0 ? nil : value
        } ?? []
    }

    open func searchDependency(by names: [String], createdRepo: MBConfig.Repo? = nil) throws -> Dependency? {
        do {
            let dp0 = try UI.log(verbose: "Search dependencies:") {
                return try getCurrentDependency(by: names)
            }
            guard let dp = dp0 else { return nil }
            var dps = UI.log(verbose: "Search other dependencies in repository:") {
                return self.getCurrentDependenciesInSameRepo(by: dp)
            }
            if let dupDp = dps.first(where: { $0.name == dp.name }) {
                dp.merge(other: dupDp)
                dps.removeAll(dupDp)
            }
            dps.insert(dp, at: 0)
            return try UI.log(verbose: "Resolve dependencies:") {
                return try self.resolveDependencies(dps, createdRepo: createdRepo)
            }
        } catch let error as RuntimeError {
            UI.log(warn: "\(error)")
            return nil
        }
    }

    private func resolveDependencies(_ dependencies: [Dependency], createdRepo: MBConfig.Repo? = nil) throws -> Dependency? {
        let dependencies = dependencies.compactMap { try? self.resolveDependency($0, createdRepo: createdRepo) }
        if let dependency = dependencies.first(where: { $0.mode == .local }) {
            return dependency
        }

        guard dependencies.count > 1 else {
            return dependencies.first
        }

        if let repo = createdRepo {
            let commits = Array(Set(dependencies.compactMap { $0.commit }))
            if commits.count == 1 {
                UI.log(info: "Use the unique commit SHA: \(commits.first!).")
                let result = dependencies.first!.copy() as! Dependency
                result.gitPointer = .commit(commits.first!)
                return result
            } else if commits.count > 1 {
                let result = try UI.log(verbose: "Calculate the latest commit from these commits: [\(commits.joined(separator: ", "))]") { () -> Dependency? in
                    guard let latestCommit = try repo.originRepository?.git?.calculateLatestCommit(commits: commits) else {
                        return nil
                    }
                    UI.log(info: "Found the latest commit SHA: \(latestCommit) sorted by linear git history.")
                    let result = dependencies.first!.copy() as! Dependency
                    result.gitPointer = .commit(latestCommit)
                    return result
                }
                if result != nil { return result }
            }
        }

        let commitAndDate = dependencies.compactMap { dependency -> (String, Date)? in
            guard let date = dependency.date, let commit = dependency.commit else { return nil }
            return (commit, date)
        }.max { $0.1 > $1.1 }

        if let commitAndDate = commitAndDate {
            UI.log(info: "Found the latest commit SHA: \(commitAndDate.0) created at \(commitAndDate.1.description) sorted by created time.")
            let result = dependencies.first!.copy() as! Dependency
            result.gitPointer = .commit(commitAndDate.0)
            return result
        }

        return dependencies.first
    }

    // MARK: - Search Engine Service
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

    private func lookupEngines<T>(_ title: String,
                                  _ resultOutput: ((T?) -> String?)? = nil,
                                  block: (MBDependencySearchEngine) throws -> T?) -> T? {
        let engines = self.searchEngines
        if engines.isEmpty {
            UI.log(error: "There is not a valid dependency search engine.")
            return nil
        }
        var result: (T?) -> String?
        if let resultOutput = resultOutput {
            result = resultOutput
        } else {
            result = { _ in return nil }
        }
        for engine in engines {
            let value: T? = UI.log(verbose: "[\(engine.engineName)] \(title):",
                                   resultOutput: result) {
                do {
                    if let value = try block(engine) {
                        return value
                    }
                } catch {
                    UI.log(verbose: error.localizedDescription)
                }
                return nil
            }
            if let value = value { return value }
        }
        return nil
    }

    open func resolveDependency(_ dependency: Dependency, createdRepo: MBConfig.Repo? = nil) throws -> Dependency? {
        let result: Dependency?
        switch dependency.mode {
        case .local:
            result = try self.resolveLocalDependency(dependency, createdRepo: createdRepo)
        case .remote:
            result = try self.resolveRemoteDependency(dependency, createdRepo: createdRepo)
        case .version:
            result = try resolveVersionDependency(dependency, createdRepo: createdRepo)
        default: result = nil
        }
        return dependency.merging(other: result)
    }

    private func resolveLocalDependency(_ dependency: Dependency, createdRepo: MBConfig.Repo? = nil) throws -> Dependency? {
        var path = dependency.path!.expandingTildeInPath
        if !path.hasPrefix("/") {
            path = self.rootPath.appending(pathComponent: path)
        }
        if !path.isDirectory {
            throw RuntimeError("The path does not exist: \(path)")
        }
        return dependency
    }

    private func resolveRemoteDependency(_ dependency: Dependency, createdRepo: MBConfig.Repo? = nil) throws -> Dependency? {
        return nil
    }

    private func resolveVersionDependency(_ dependency: Dependency, createdRepo: MBConfig.Repo? = nil) throws -> Dependency? {
        let name = dependency.name!
        let version = dependency.version!
        var lastDependency: Dependency?

        let result = self.lookupEngines("Query dependency \(name)",
                                        { result in
                                            if let result = result {
                                                return result.description
                                            }
                                            if let lastDependency = lastDependency {
                                                return "\(lastDependency.name!): No date avaliable"
                                            }
                                            return "Could not find the dependency \(name)."
                                        }) { engine -> Dependency? in
            guard let dep = try engine.resolveDependency(name: name, version: version, url: createdRepo?.url),
                  dep.gitPointer != nil else { return nil }
            dep.name ?= name
            if let urlString1 = createdRepo?.url, let urlString2 = dep.git,
               let url1 = MBGitURL(urlString1),
               let url2 = MBGitURL(urlString2),
               url1 != url2 {
                UI.log(warn: "Resolve version conflict: \(dep).\n The git url does NOT match `\(urlString1)`")
                return nil
            }
            if dep.date != nil {
                return dep
            }
            lastDependency = dep
            return nil
        }

        return result ?? lastDependency
    }

}
