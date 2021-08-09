//
//  MBoxDependencyManager.swift
//  MBoxDependencyManager
//

import Foundation
import MBoxCore
import MBoxWorkspaceCore

@objc(MBoxDependencyManager)
open class MBoxDependencyManager: NSObject, MBWorkspacePluginProtocol {

    public func registerCommanders() {
        MBCommanderGroup.shared.addCommand(MBCommander.Depend.self)
        MBCommanderGroup.shared.addCommand(MBCommander.Activate.self)
        MBCommanderGroup.shared.addCommand(MBCommander.Deactivate.self)
    }

    public func disablePlugin(workspace: MBWorkspace) throws {

    }

    public func enablePlugin(workspace: MBWorkspace, from version: String?) throws {
        workspace.config.currentFeature.saveChangedDependenciesLock()
    }
}
