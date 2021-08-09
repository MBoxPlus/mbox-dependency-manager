//
//  UserDependency.swift
//  MBoxDependencyManager
//
//  Created by 詹迟晶 on 2020/1/7.
//  Copyright © 2020 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxWorkspaceCore

open class UserDependency: Dependency {

    @Codable
    public var tools: [MBDependencyTool]?

    func isUseTool(_ tool: MBDependencyTool?) -> Bool {
        guard let tools = self.tools else { return true }
        if let tool = tool {
            return tools.contains(tool)
        }
        return true
    }

    public override var description: String {
        var value = super.description
        value = "\(name!): \(value)"
        guard let tools = self.tools else { return value }
        return "\(value), by \(tools.map { "`\($0)`" }.joined(separator: ", "))"
    }
}

//var MBWorkspaceDependencySetKey: UInt8 = 0
//extension MBWorkspace {
//    public var dependencySet: DependencySet {
//        set {
//            associateObject(base: self, key: &MBWorkspaceDependencySetKey, value: newValue)
//        }
//        get {
//            return associatedObject(base: self, key: &MBWorkspaceDependencySetKey) {
//                return try! DependencySet.load(fromFile: self.rootPath.appending(pathComponent: DependencySet.fileName))
//            }
//        }
//    }
//}
