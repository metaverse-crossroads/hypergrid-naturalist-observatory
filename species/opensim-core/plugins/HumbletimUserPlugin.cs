
using System;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.IO;
using System.Xml;
using System.Net;
using System.Reflection;
using System.Timers;
using System.Threading;
using log4net;
using Nini.Config;
using Nwc.XmlRpc;
using OpenMetaverse;
using Mono.Addins;
using OpenSim;
using OpenSim.Framework;
using OpenSim.Framework.Console;
using OpenSim.Framework.Servers;
using OpenSim.Framework.Servers.HttpServer;
using OpenSim.Region.CoreModules.World.Terrain;
using OpenSim.Region.Framework.Interfaces;
using OpenSim.Region.Framework.Scenes;
using OpenSim.Services.Interfaces;
using PresenceInfo = OpenSim.Services.Interfaces.PresenceInfo;
using GridRegion = OpenSim.Services.Interfaces.GridRegion;
using PermissionMask = OpenSim.Framework.PermissionMask;
using RegionInfo = OpenSim.Framework.RegionInfo;

using OpenSim.Services.UserAccountService;
using OpenSim.Region.CoreModules.ServiceConnectorsOut.UserAccounts;  // Add this line

namespace OpenSim.ApplicationPlugins.RemoteController {

[Extension(Path = "/OpenSim/Startup", Id = "LoadRegions", NodeName = "Plugin")]

public class HumbletimUsersPlugin : IApplicationPlugin
{
    private static readonly ILog m_log = LogManager.GetLogger(MethodBase.GetCurrentMethod().DeclaringType);
    public void Initialise()
    {
        m_log.Error("[USERLIST]: Initialise() called without OpenSimBase - this should not happen!");
        throw new PluginNotInitialisedException(Name);
    }

    private void OnRegionsReady(SceneManager sceneManager) {
        if (!sceneManager.AllRegionsReady) {
            m_log.Info("[USERLIST]: Regions are NO Tready");
            return;
        }

        Scene scene = sceneManager.CurrentOrFirstScene;
        if (scene == null) {
            m_log.Info("[USERLIST]: !scene");
            return;
        }
        var userService = scene.UserAccountService;
        m_log.InfoFormat("[USERLIST]: Service type is: {0}", userService.GetType().FullName);
        if (userService == null) {
            m_log.Info("[USERLIST]: !userService");
            return;
        }

        m_log.Info("[USERLIST]: Found UserAccountService, registering 'show all users' command");
        MainConsole.Instance.Commands.AddCommand(
            "General", false, "die", "die", "Exit immediately without shutdown",
            (module, cmdparams) => Environment.Exit(1) //(Environment.FailFast("Brutal exit requested")
        );

        MainConsole.Instance.Commands.AddCommand("Users", false, "show all users", "show all users", "Show all registered users from database",
            (module, cmdparams) => {
                var users = userService.GetUserAccounts(UUID.Zero, "%%%");//"active = 1");
                var cdt = new ConsoleDisplayTable();
                cdt.AddColumn("UUID", 36);
                cdt.AddColumn("Name", 30);
                cdt.AddColumn("Email", 40);
                cdt.AddColumn("Created", 20);
                cdt.AddColumn("Level", 6);
                foreach (UserAccount user in users) {
                    cdt.AddRow(user.PrincipalID, user.Name, user.Email,
                            Utils.UnixTimeToDateTime(user.Created).ToString("yyyy-MM-dd"),
                            user.UserLevel.ToString());
                }
                MainConsole.Instance.Output(cdt.ToString());
                // MainConsole.Instance.Output("Total users: {0}", users.Count);
        });
    }

    public void Initialise(OpenSimBase openSim)  {
        m_log.Info("[USERLIST]: Initialise(OpenSimBase) called - starting initialization");
        // Get UserAccountService from the first scene
        Scene scene = openSim.SceneManager.CurrentOrFirstScene;
        if (scene != null) {
            m_log.Error("[USERLIST]: scenes available");
            OnRegionsReady(openSim.SceneManager);
        } else {
            m_log.Error("[USERLIST]: No scenes available");
            // Register for scene ready event
            openSim.SceneManager.OnRegionsReadyStatusChange += OnRegionsReady;
        }


    }

    // Minimal implementations of other required methods
    public void PostInitialise() { }
    public void Dispose() { }
    public string Name => "HumbletimUsersPlugin";
    public string Version => "0.0.0";
}

}//ns
