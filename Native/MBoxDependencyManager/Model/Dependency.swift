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

    public var mode: Mode {
        if self.git != nil || self.commit != nil || self.branch != nil || self.tag != nil { return .remote }
        if self.path != nil { return .local }
        if self.version != nil || self.source != nil { return .version }
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

    open override var description: String {
        var value = [String]()
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
        return value.joined(separator: ", ")
    }

    open var hashString: String {
        return self.dictionary.keys.sorted().map {
            "\(self.dictionary[$0] ?? "")"
        }.joined().hashed(.md5) ?? "unknown"
    }
}
