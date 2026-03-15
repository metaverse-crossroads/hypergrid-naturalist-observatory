/*
$ . species/opensim-core/plugins/oscsc.bash
$ oscsc species/opensim-core/plugins/MyModule.cs vivarium/opensim-core-master/bin/MyModule.dll
*/

using System;
using OpenSim.Framework;
using OpenSim.Region.Framework.Interfaces;
using OpenSim.Region.Framework.Scenes;
using Nini.Config;
using Mono.Addins;

[assembly: Addin("MyModule", "1.0")]
[assembly: AddinDependency("OpenSim.Region.Framework", OpenSim.VersionInfo.VersionNumber)]

namespace MyNamespace {
    [Extension(Path = "/OpenSim/RegionModules", NodeName = "RegionModule", Id = "MyModule")]
    public class MyModule : ISharedRegionModule  {
        public string Name { get { return "MyModule"; } }
        public Type ReplaceableInterface { get { return null; } }
        public bool IsSharedModule { get { return true; } }

        public void Initialise(IConfigSource source) {
            Console.WriteLine("[MYMODULE]: Initialise called!");
        }

        public void PostInitialise() { }
        public void Close() { }
        public void AddRegion(Scene scene) { }
        public void RemoveRegion(Scene scene) { }
        public void RegionLoaded(Scene scene) { }
    }
}
