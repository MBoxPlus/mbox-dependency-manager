//
//  DependencyManager.swift
//  MBoxDependencyManager
//
//  Created by Whirlwind on 2022/9/13.
//  Copyright © 2022 com.bytedance. All rights reserved.
//

import Foundation
import MBoxWorkspace

extension MBCommander {
    open class DependencyManager: Exec {
        open class override var description: String? {
            return "Redirect to \(self) with MBox environment"
        }

        dynamic
        open override func setupCMD() throws -> (MBCMD, [String]) {
            return try super.setupCMD()
        }

        dynamic
        open override func run() throws {
            try super.run()
        }
    }
}
