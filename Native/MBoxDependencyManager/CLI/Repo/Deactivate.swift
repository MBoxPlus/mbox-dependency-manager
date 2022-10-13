//
//  Deactivate.swift
//  MBoxDependencyManager
//
//  Created by Whirlwind on 2020/12/3.
//  Copyright © 2020 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore

extension MBCommander {
    open class Deactivate: Activate {

        open class override var description: String? {
            return "Deactivate a or more components"
        }

        open override func handle(repo: MBConfig.Repo, tool: MBDependencyTool) throws {
            repo.deactiveAllComponents(for: tool)
        }

        open override func handle(component: MBWorkRepo.Component) throws {
            component.repo?.model.deactivateComponent(component)
        }
    }
}
