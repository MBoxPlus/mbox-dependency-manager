//
//  Dependency.swift
//  MBoxCocoapods
//
//  Created by Whirlwind on 2019/7/27.
//  Copyright © 2019 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxGit
import MBoxWorkspaceCore

open class Dependency: MBCodableObject {
    public enum Mode {
        case version
        case local
        case remote
        case binarySwitch
        case unknown
    }

    @Codable
    public var name: String?
    public var rootName: String? {
        guard let value = name?.split(separator: "/").first else { return nil }
        return String(value)
    }

    @Codable
    public var version: String?

    @Codable
    public var source: String?

    @Codable
    public var git: String?

    @Codable
    public var branch: String?

    @Codable
    public var commit: String?

    @Codable
    public var tag: String?

    @Codable
    public var path: String?

    @Codable
    public var binary: Bool?

    @Codable
    public var http: String?

    @Codable
    public var type: String?

    @Codable
    public var date: Date?

    @Codable
    public var homepage: String?

    public var mode: Mode {
        if self.git != nil || self.commit != nil || self.branch != nil || self.tag != nil { return .remote }
        if self.version != nil || self.source != nil { return .version }
        if self.path != nil { return .local }
        if self.binary != nil { return .binarySwitch }
        return .unknown
    }

    public var isExternal: Bool {
        let m = self.mode
        return m != .version && m != .binarySwitch
    }

    private func clearGit() {
        self.git = nil
        self.commit = nil
        self.branch = nil
        self.tag = nil
    }

    public func change(version: String? = nil,
                       source: String? = nil,
                       git: String? = nil,
                       branch: String? = nil,
                       commit: String? = nil,
                       tag: String? = nil,
                       path: String? = nil,
                       binary: Bool? = nil) {
        if binary != nil || version != nil || source != nil {
            self.clearGit()
            self.path = nil
            if let binary = binary {
                self.binary = binary
            }
            if let version = version {
                self.version = version
            }
            if let source = source {
                self.source = source
            }
        } else if git != nil || branch != nil || commit != nil || tag != nil {
            self.path = nil
            self.version = nil
            self.source = nil
            self.binary = nil
            if let git = git {
                self.git = git
            }
            if let branch = branch {
                self.branch = branch
            }
            if let commit = commit {
                self.commit = commit
            }
            if let tag = tag {
                self.tag = tag
            }
        } else if let path = path {
            self.clearGit()
            self.version = nil
            self.source = nil
            self.binary = nil
            self.path = path
        }
    }

    public var gitPointer: GitPointer? {
        get {
            if let branch = branch {
                return .branch(branch)
            } else if let commit = commit {
                return .commit(commit)
            } else if let tag = tag {
                return .tag(tag)
            } else {
                return nil
            }
        }
        set {
            self.branch = nil
            self.commit = nil
            self.tag = nil
            guard let value = newValue else {
                return
            }
            switch value {
            case .branch(let v):
                self.branch = v
            case .commit(let v):
                self.commit = v
            case .tag(let v):
                self.tag = v
            case .unknown(_): break
            @unknown default: break
            }
        }
    }

    open override var description: String {
        var value = [String]()
        if let name = self.name {
            value.append("`\(name)`")
        }
        if let version = self.version {
            value.append(version)
        }
        if let source = self.source {
            value.append("source `\(source)`")
        }
        if let git = self.git {
            value.append("from `\(git)`")
        }
        if let branch = self.branch {
            value.append("branch `\(branch)`")
        }
        if let commit = self.commit {
            value.append("commit `\(commit)`")
        }
        if let tag = self.tag {
            value.append("tag `\(tag)`")
        }
        if let path = self.path {
            value.append("path `\(path)`")
        }
        if let binary = self.binary {
            value.append(binary ? "using binary" : "using source code")
        }
        if let date = self.date {
            value.append("at \(date.string())")
        }
        return value.joined(separator: ", ")
    }

    open var hashString: String {
        return self.dictionary.keys.sorted().map {
            "\(self.dictionary[$0] ?? "")"
        }.joined().hashed(.md5) ?? "unknown"
    }

    open func merging(other: Dependency?) -> Dependency {
        guard let other = other else { return self.copy() as! Dependency }
        let dict = self.dictionary.merging(other.dictionary) { (_, new) in new }
        return Dependency(dictionary: dict)
    }

    open func merge(other: Dependency?) {
        guard let other = other else { return }
        self.dictionary.merge(other.dictionary) { (_, new) in new }
    }
}

extension MBConfig.Repo {
    public convenience init(feature: MBConfig.Feature, dependency: Dependency) {
        self.init(feature: feature)
        self.name = dependency.name!
        self.baseGitPointer = dependency.gitPointer
        self.url = dependency.git
        if let path = dependency.path {
            self.path = path
        }
    }
}
