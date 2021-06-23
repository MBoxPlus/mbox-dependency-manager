//
//  UserDependencyFile.swift
//  MBoxDependencyManager
//
//  Created by 詹迟晶 on 2020/1/13.
//  Copyright © 2020 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxWorkspaceCore

open class UserDependencyFile: MBCodableArray<UserDependency>, MBYAMLProtocol {
    public static let fileName = "MBox.dependencies.yml"

    public var isEmpty: Bool {
        return self.array.isEmpty
    }

    public var count: Int {
        return self.array.count
    }

    public func removeAll(in tool: MBDependencyTool? = nil) {
        self.array.removeAll { dp -> Bool in
            if dp.isUseTool(tool), let tool = tool {
                dp.tools?.removeAll(tool)
            }
            return dp.tools?.isEmpty ?? true
        }
    }

    public func remove(dependency name: String, in tool: MBDependencyTool? = nil) {
        self.array.removeAll { dp -> Bool in
            guard dp.name == name else { return false }
            if dp.isUseTool(tool), let tool = tool {
                dp.tools?.removeAll(tool)
            }
            return dp.tools?.isEmpty ?? true
        }
    }

    public func add(dependency: UserDependency) {
        self.remove(dependency: dependency.name!)
        self.array.append(dependency)
    }

    public func dependency(for name: String, in tool: MBDependencyTool?) throws -> UserDependency? {
        return self.array.first { dp -> Bool in
            return dp.name == name && dp.isUseTool(tool)
        }
    }

    public func dependency(for name: String, in tool: MBDependencyTool?) throws -> UserDependency {
        if let dp = try self.dependency(for: name, in: tool) { return dp }
        let dp = UserDependency()
        dp.name = name
        self.add(dependency: dp)
        return dp
    }

    public func dependencies(for tool: MBDependencyTool? = nil) -> [UserDependency] {
        return self.array.filter { $0.isUseTool(tool) }
    }
}
