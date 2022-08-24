//
//  MBWorkRepo.Component.swift
//  MBoxDependencyManager
//
//  Created by 詹迟晶 on 2022/7/4.
//  Copyright © 2022 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxWorkspaceCore

extension MBWorkRepo {
    open class Component {
        open weak var repo: MBWorkRepo!
        open var repoConfig: MBConfig.Repo { return self.repo.model }
        open var tool: MBDependencyTool
        open var name: String

        open lazy var path: String = self.repo.path

        open var spec: Any?
        open var specPath: String?
        open var specAbsolutePath: String?
        open var specParser: ((String) -> Any?)?

        public init(name: String, tool: MBDependencyTool, repo: MBWorkRepo) {
            self.repo = repo
            self.tool = tool
            self.name = name
        }

        @discardableResult
        public func withSpec(_ spec: Any? = nil, path: String? = nil, parser: ((String)->(Any?))? = nil) -> Self {
            self.spec = spec
            self.specPath = path
            self.specParser = parser
            if let specPath = self.specPath {
                self.specAbsolutePath = repo.path.appending(pathComponent: specPath)
                self.path = repo.path.appending(pathComponent: specPath).deletingLastPathComponent
            }
            return self
        }

        dynamic
        open func isName(_ name: String) -> Bool {
            if self.name.lowercased() == name.lowercased() {
                return true
            }
            if name.contains("/") {
                var names = name.split(separator: "/")
                let repoName = String(names.removeFirst())
                if self.repo.name.lowercased() != repoName.lowercased() {
                    return false
                }
                return names.joined(separator: "/").lowercased() == self.name.lowercased()
            }
            return false
        }

        open var dictionary: [String: String] {
            return [
                "name": self.name,
                "path": self.path,
                "tool": self.tool.description
            ]
        }
    }
}

extension MBWorkRepo.Component: Equatable {
    public static func == (lhs: MBWorkRepo.Component, rhs: MBWorkRepo.Component) -> Bool {
        if !lhs.isName(rhs.name) || lhs.tool != rhs.tool {
            return false
        }
        if let lhsPath = lhs.specPath, let rhsPath = rhs.specPath {
            return lhsPath == rhsPath
        }
        return true
    }

}
