//
//  MBoxDependencyManager.swift
//  MBoxDependencyManager
//

import Foundation
import MBoxCore

@objc(MBoxDependencyManager)
open class MBoxDependencyManager: NSObject, MBPluginProtocol {

    public func registerCommanders() {
        MBCommanderGroup.shared.addCommand(MBCommander.Depend.self)
        MBCommanderGroup.shared.addCommand(MBCommander.Activate.self)
        MBCommanderGroup.shared.addCommand(MBCommander.Deactivate.self)
    }
}
