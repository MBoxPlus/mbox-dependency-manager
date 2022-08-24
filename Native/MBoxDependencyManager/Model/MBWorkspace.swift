//
//  MBWorkspace.swift
//  MBoxDependencyManager
//
//  Created by Whirlwind on 2020/2/26.
//  Copyright © 2020 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore

public protocol MBDependencySearchEngine {
    var engineName: String { get }
    var enginePriority: Int { get }
    func searchDependencies(by names: [String]) throws -> [Dependency]
    func resolveDependency(name: String, version: String?, url: String?) throws -> Dependency?
    func getReleaseDate(name: String, version: String?, url: String?) throws -> Date?
}

extension MBDependencySearchEngine {
    public func getReleaseDate(name: String, version: String?, url: String?) throws -> Date? {
        return nil
    }
}

var MBSearchEnginesFlag: UInt8 = 0
extension MBWorkspace {
    public func searchCurrentDependencies(by names: [String]) throws -> [Dependency] {
        let title = names.map { "`\($0)`" }.joined(separator: ", ")
        return try self.lookupEngines(title) { engine in
            let dps = try engine.searchDependencies(by: names)
            if !dps.isEmpty {
                UI.log(verbose: "Find dependencies:", items: dps.map { $0.description })
                return dps
            } else {
                UI.log(verbose: "Could not find dependencies.")
                return nil
            }
        } ?? []
    }

    private func searchAllDependencies(by names: [String]) throws -> [Dependency] {
        let title = names.map { "`\($0)`" }.joined(separator: ", ")
        return try self.lookupEngines(title, { $0?.description ?? "Could not find the dependency \(title)"}) { engine in
            return try names.compactMap {
                try engine.resolveDependency(name: $0, version: nil, url: nil)
            }
        } ?? []
    }

    public func searchDependency(by names: [String], createdRepo: MBConfig.Repo? = nil) throws -> Dependency? {
        do {
            var dps = try UI.log(verbose: "Search current dependencies:") {
                return try searchCurrentDependencies(by: names)
            }
            if dps.isEmpty {
                dps = try UI.log(verbose: "Search all dependencies:") {
                    return try searchAllDependencies(by: names)
                }
            }
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

        if let repo = createdRepo, let git = repo.originRepository?.git {
            var tagCache = [String: String]()
            for dependency in dependencies where dependency.tag != nil && dependency.commit == nil {
                let commit = try tagCache[dependency.tag!] ?? git.commit(for: .tag(dependency.tag!))
                tagCache[dependency.tag!] = commit
                dependency.commit = commit
            }
            let commits = Array(Set(dependencies.compactMap { $0.commit }))
            if commits.count == 1 {
                UI.log(info: "Use the unique commit SHA: \(commits.first!).")
                let result = dependencies.first!.copy() as! Dependency
                result.gitPointer = .commit(commits.first!)
                return result
            } else if commits.count > 1 {
                let result = try UI.log(verbose: "Calculate the latest commit from these commits: [\(commits.joined(separator: ", "))]") { () -> Dependency? in
                    guard let latestCommit = try git.calculateLatestCommit(commits: commits) else {
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
        }.max { $0.1 < $1.1 }

        if let commitAndDate = commitAndDate {
            UI.log(info: "Found the latest commit SHA: \(commitAndDate.0) created at \(commitAndDate.1.description) sorted by created time.")
            let result = dependencies.first!.copy() as! Dependency
            result.gitPointer = .commit(commitAndDate.0)
            return result
        }

        return dependencies.first
    }

    // MARK: - Search Engine Service
    public var searchEngines: [MBDependencySearchEngine] {
        return associatedObject(base: self, key: &MBSearchEnginesFlag) {
            let engines = self.setupSearchEngines()
            if engines.isEmpty { return self.setupSearchEngines() }
            return engines.sorted { (a, b) -> Bool in
                a.enginePriority > b.enginePriority
            }
        }
    }

    dynamic
    public func setupSearchEngines() -> [MBDependencySearchEngine] {
        return []
    }

    private func lookupEngines<T>(_ title: String,
                                  _ resultOutput: ((T?) -> String?)? = nil,
                                  block: (MBDependencySearchEngine) throws -> T?) throws -> T? {
        let engines = self.searchEngines
        if engines.isEmpty {
            throw RuntimeError("There is not a valid dependency search engine.")
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

    public func resolveDependency(_ dependency: Dependency, createdRepo: MBConfig.Repo? = nil) throws -> Dependency? {
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
        let url = createdRepo?.url ?? dependency.git

        let result = try self.lookupEngines("Query dependency \(name)") { engine -> Dependency? in
            guard let dep = try engine.resolveDependency(name: name, version: version, url: url),
                  dep.gitPointer != nil else {
                return nil
            }
            if let urlString1 = url,
               let urlString2 = dep.git,
               let url1 = MBGitURL(urlString1),
               let url2 = MBGitURL(urlString2),
               url1 != url2 {
                UI.log(warn: "Resolve version conflict: \(dep).\n The git url does NOT match `\(urlString1)`")
                return nil
            }
            dep.name ?= name
            if dep.date != nil {
                return dep
            }
            lastDependency = dep
            return nil
        }
        if let result = result ?? lastDependency {
            return result
        }
        UI.log(verbose: "Could not find the dependency \(name).")
        return nil
    }

}

extension MBWorkspace {
    @_dynamicReplacement(for: workspaceIndex())
    public func dp_workspaceIndex() -> [String: [(name: String, path: String)]] {
        var result = self.workspaceIndex()
        for tool in MBDependencyTool.allTools {
            let components = self.workRepos.flatMap { $0.activatedComponents(for: tool) }
            let name = tool.name.lowercased()
            var items = result[name] ?? []
            items << components.map { (name: $0.name, path: $0.path) }
            result[name] = items
        }
        return result
    }
}
