//
//  Remove.swift
//  MBoxDependencyManager
//
//  Created by Whirlwind on 2021/8/9.
//  Copyright © 2021 com.bytedance. All rights reserved.
//

import MBoxCore
import MBoxWorkspace

extension MBCommander.Remove {
    @_dynamicReplacement(for: run())
    open func dp_run() throws {
        try self.run()
        self.config.currentFeature.saveChangedDependenciesLock()
    }
}
