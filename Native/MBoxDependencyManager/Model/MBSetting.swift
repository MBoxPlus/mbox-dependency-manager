//
//  MBSetting.swift
//  MBoxDependencyManager
//
//  Created by 詹迟晶 on 2021/2/26.
//  Copyright © 2021 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore

extension MBSetting {

    public class DependencyManager: MBCodableObject {
        @Codable
        public var activateAllComponentsAfterAddRepo: Bool?
    }

    public var dependencyManager: DependencyManager? {
        set {
            self.dictionary["dependency_manager"] = newValue
        }
        get {
            return self.value(forPath: "dependency_manager")
        }
    }
}
