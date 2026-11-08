import Foundation
import TreewiseModuleCatalog
import TreewiseModuleXPC

// The service that runs name modules, without access to the network or the user's
// files (ADR 0057). It holds no logic of its own, so the sandbox applies to all of it;
// only the probe build adds a module that tries the sandbox (`tools/build.sh probe`).
#if TREEWISE_PROBE
    let server = ModuleHostServer(modules: ModuleCatalog.modules + [SandboxProbeModule()])
#else
    let server = ModuleHostServer(modules: ModuleCatalog.modules)
#endif
let listener = NSXPCListener.service()
listener.delegate = server
listener.resume()
