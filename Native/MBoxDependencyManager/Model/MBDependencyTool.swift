//
//  MBDependencyTool.swift
//  MBoxDependencyManager
//
//  Created by 詹迟晶 on 2021/1/25.
//  Copyright © 2021 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore


public class MBDependencyTool {
    required public init() {
    }

    public convenience init(_ name: String) {
        self.init()
        self.name = name
    }

    public static func load(fromObject object: Any) throws -> Self {
        guard let name = object as? String else {
            throw NSError(domain: "Convert Error", code: 0, userInfo: [NSLocalizedDescriptionKey: "类型不匹配 \(self): \(object)"])
        }
        return MBDependencyTool(name) as! Self
    }

    public var name: String = ""

    dynamic
    public static var allTools: [MBDependencyTool] {
        return []
    }

    public static func tool(for name: String) throws -> MBDependencyTool {
        guard let v = self.allTools.first(where: { $0 == name }) else {
            throw RuntimeError("The `\(name)` is not found.")
        }
        return v
    }
}

extension MBDependencyTool: Hashable {
    public func hash(into hasher: inout Hasher) {
        self.name.hash(into: &hasher)
    }
}

extension MBDependencyTool: CustomStringConvertible {
    public var description: String {
        return self.name
    }
}

extension MBDependencyTool: Comparable {
    public static func < (lhs: MBDependencyTool, rhs: MBDependencyTool) -> Bool {
        return lhs.name < rhs.name
    }

    public static func == (lhs: MBDependencyTool, rhs: MBDependencyTool) -> Bool {
        return lhs.name.lowercased() == rhs.name.lowercased()
    }

    public static func == (lhs: MBDependencyTool, rhs: String) -> Bool {
        return lhs.name.lowercased() == rhs.lowercased()
    }
}

extension MBDependencyTool: CodableType {
    public static func defaultValue() -> Self {
        return MBDependencyTool() as! Self
    }
}

extension MBDependencyTool: MBCodable {
    public func toCodableObject() -> Any? {
        return self.name
    }
}
