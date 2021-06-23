//
//  Status.swift
//  MBoxDependencyManager
//
//  Created by 詹迟晶 on 2020/1/9.
//  Copyright © 2020 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxWorkspaceCore
import MBoxWorkspace

extension MBCommander.Status {
    open class Dependencies: MBCommanderStatus {
        public static var supportedAPI: [MBCommander.Status.APIType] {
            return [.none]
        }

        public static var title: String {
            return "dependencies"
        }

        public required init(feature: MBConfig.Feature) {
            self.feature = feature
        }

        public var feature: MBConfig.Feature

        public func textRows() throws -> [Row]? {
            if self.feature.dependencies.isEmpty { return nil }
            return self.feature.dependencies.array.map { Row(column: $0.description) }
        }
    }

    @_dynamicReplacement(for: allSections)
    public class var dp_allSections: [MBCommanderStatus.Type] {
        var result = self.allSections
        result << Dependencies.self
        return result
    }
}

extension MBCommander.Status.Repos {
    @_dynamicReplacement(for: repoRows(for:))
    open func dp_repoRows(for repo: MBConfig.Repo) throws -> [Row]? {
        var value = try self.repoRows(for: repo) ?? []
        let styleBlock: (String, Bool) -> String = { (string, active) in
            if active {
                return string.ANSI(.bold).ANSI(.black, bright: true)
            } else {
                return string.ANSI(.strikethrough).ANSI(.black, bright: true)
            }
        }
        guard let workRepo = repo.workRepository else {
            return value
        }
        for (tool, names) in workRepo.dependencyNamesByTool.sorted(by: \.key) {
            for name in names.sorted() {
                let isActive = repo.isActive(component: name, for: tool)
                let row = Row(columns: ["[\(tool)]", name].map { styleBlock($0, isActive) })
                row.selectedPrefix = styleBlock("+", isActive)
                row.unselectedPrefix = styleBlock("-", isActive)
                row.selected = isActive
                value.append(row)
            }
        }
        return value
    }

    @_dynamicReplacement(for: repoAPI(for:))
    open func dp_repoAPI(for repo: MBConfig.Repo) throws -> [String: Any]? {
        var value = try self.repoAPI(for: repo) ?? [:]
        guard let workRepo = repo.workRepository else {
            return value
        }
        let dpsMap = workRepo.dependencyNamesByTool
        if dpsMap.count == 0 {
            return value
        }
        var v = [[String: Any]]()
        for (tool, dps) in dpsMap {
            v << dps.map {
                ["name": $0,
                 "tool": tool.name,
                 "active": repo.isActive(component: $0, for: tool)]
            }
        }
        value["components"] = v
        return value
    }

}
