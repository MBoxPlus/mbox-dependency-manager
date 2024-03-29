//
//  Import.swift
//  MBoxDependencyManager
//
//  Created by Whirlwind on 2020/2/24.
//  Copyright © 2020 com.bytedance. All rights reserved.
//

import Foundation
import MBoxCore

extension MBCommander.Feature.Import {
    @_dynamicReplacement(for: switchFeature(args:))
    public func dp_switchFeature(args: [String]) throws {
        var args = args
        if !self.feature.dependencies.isEmpty {
            args << "--dependencies"
            var dps = [String: [String: Any]]()
            for dp in self.feature.dependencies.array {
                if let v = dp.toCodableObject() as? [String: Any] {
                    dps[dp.name!] = v
                }
            }
            try args << dps.toString(coder: .json, prettyPrinted: false)
        } else if self.feature.isNew == true {
            args << "--dependencies={}"
        }
        try self.switchFeature(args: args)
    }
}
