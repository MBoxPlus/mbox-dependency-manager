//
//  Deactivate.swift
//  MBoxDependencyManager
//
//  Created by 詹迟晶 on 2020/12/3.
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

        open override func handle(components: [Component]) throws {
            for component in self.components {
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
