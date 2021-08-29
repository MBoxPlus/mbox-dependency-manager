//
//  Deactivate.swift
//  MBoxDependencyManager
//
//  Created by Whirlwind on 2020/12/3.
//  Copyright © 2020 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore
import MBoxWorkspaceCore

extension MBCommander {
    open class Deactivate: Activate {

        open class override var description: String? {
            return "Deactivate a or more components"
        }

        open override class var example: String? {
            return """
# Deactivate all components in the `repo1`
$ mbox deactivate repo1

# Deactivate the component named `component1` in the `repo1`
$ mbox deactivate repo1/component1
"""
        }

        open override func handle(tools: [MBDependencyTool]) throws {
            for tool in tools {
                for repo in self.config.currentFeature.repos {
                    repo.deactiveAllComponents(for: tool)
                }
            }
        }

        open override func handle(components: [Component]) throws {
            for component in components {
                if let name = component.name {
                    UI.log(info: "[\(component.repo)] Deactivate component `\(name)` for \(component.tool)") {
                        component.repo.deactivateComponent(name, for: component.tool)
                    }
                } else {
                    UI.log(info: "[\(component.repo)] Deactivate all components for \(component.tool)") {
                        component.repo.deactiveAllComponents(for: component.tool)
                    }
                }
            }
        }
    }
}
