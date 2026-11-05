import Foundation
import TreewiseModuleCatalog
import TreewiseModuleXPC

// The service that runs name modules, without access to the network or the user's
// files (ADR 0057). It holds no logic of its own, so the sandbox applies to all of it.
let server = ModuleHostServer(modules: ModuleCatalog.modules)
let listener = NSXPCListener.service()
listener.delegate = server
listener.resume()
