using System.Linq;
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

MainConsole.Instance.Commands.AddCommand(
            "General", false, "env", "env [prop]", "Query .NET Environment.*",
            (module, cmdparams) => {
                // 1. Build a normalized dictionary of all Environment data we care about
                var envData = new Dictionary<string, string>();

                // A. Add Standard Properties via Reflection
                var properties = typeof(Environment).GetProperties(System.Reflection.BindingFlags.Public | System.Reflection.BindingFlags.Static);
                foreach (var p in properties)
                {
                    if (!p.CanRead) continue;
                    try 
                    {
                        var val = p.GetValue(null);
                        envData[p.Name] = val?.ToString() ?? "";
                    }
                    catch { /* ignore specific property read errors */ }
                }

                // B. Add Manual/Special values (Methods like GetCommandLineArgs)
                // Use string.Join to make the array displayable
                envData["CommandLineArgs"] = string.Join(" ", Environment.GetCommandLineArgs());

                // 2. Filter Logic
                // cmdparams[0] is "env", cmdparams[1] is the filter
                string filter = cmdparams.Length > 1 ? cmdparams[1].ToLower() : "";

                var matches = envData.Where(kvp => kvp.Key.ToLower().StartsWith(filter)).ToList();

                // 3. Output Scenarios
                if (matches.Count == 0)
                {
                    MainConsole.Instance.Output($"No Environment members match '{filter}'");
                    return;
                }

                // EXACT MATCH SHORTCUT:
                // If we have exactly one match, output ONLY the value (raw).
                // This allows 'env commandlineargs' to return just the string for parsing.
                if (matches.Count == 1)
                {
                    MainConsole.Instance.Output(matches[0].Value);
                    return;
                }

                // TABLE OUTPUT (Unqualified or Multiple Matches)
                var cdt = new ConsoleDisplayTable();
                cdt.AddColumn("Member", 25);
                cdt.AddColumn("Value", 50);

                foreach (var kvp in matches.OrderBy(k => k.Key))
                {
                    // Basic sanity check to prevent massive text blocks in table view
                    string displayVal = kvp.Value;
                    if (displayVal.Length > 100) displayVal = displayVal.Substring(0, 97) + "...";
                    
                    // Handle NewLine chars so they don't break the table visual
                    displayVal = displayVal.Replace("\r", "\\r").Replace("\n", "\\n");

                    cdt.AddRow(kvp.Key, displayVal);
                }

                MainConsole.Instance.Output(cdt.ToString());
            }
        );

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
    public string Version => "0.0.1";
}

}//ns
