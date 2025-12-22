using System;
using OpenMetaverse;
using OpenMetaverse.Packets;
using System.Threading;
using log4net.Config;
using log4net;
using System.Reflection;
using System.IO;
using System.Collections.Generic;

namespace OmvTestHarness
{
    public static class EncounterLogger
    {
        private static string LogPath = "encounter.log";

        public static void Log(string side, string component, string signal, string payload = "")
        {
            string message = $"[ENCOUNTER] [{side}] [{component}] {signal}";
            if (!string.IsNullOrEmpty(payload))
            {
                message += $" | {payload}";
            }

            Console.WriteLine(message);

            try
            {
                File.AppendAllText(LogPath, $"{DateTime.Now:yyyy-MM-dd HH:mm:ss.fff} {message}{Environment.NewLine}");
            }
            catch (Exception) { }
        }
    }

    class Program
    {
        static GridClient client;
        static HashSet<uint> seenObjects = new HashSet<uint>();
        static bool running = true;

        static void Main(string[] args)
        {
            // Configure log4net
            var logRepository = LogManager.GetRepository(Assembly.GetEntryAssembly());
            XmlConfigurator.Configure(logRepository, new System.IO.FileInfo("log4net.config"));

            client = new GridClient();
            RegisterCallbacks();

            bool replMode = false;
            foreach (var arg in args)
            {
                if (arg == "--repl") replMode = true;
            }

            if (replMode || args.Length == 0)
            {
                RunRepl();
            }
            else
            {
                RunLegacy(args);
            }
        }

        static void RegisterCallbacks()
        {
            // Field Mark 14: Login Response
            client.Network.LoginProgress += (sender, e) =>
            {
                EncounterLogger.Log("CLIENT", "LOGIN", $"PROGRESS {e.Status}", e.Message);
            };

            // Field Mark 15: UDP Connection (SimConnected)
            client.Network.SimConnected += (sender, e) =>
            {
                EncounterLogger.Log("CLIENT", "UDP", "CONNECTED", $"Sim: {e.Simulator.Name}, IP: {e.Simulator.IPEndPoint}");
            };

            // Field Mark: Territory Impressions
            client.Network.RegisterCallback(PacketType.RegionHandshake, (sender, e) =>
            {
                RegionHandshakePacket handshake = (RegionHandshakePacket)e.Packet;
                string simName = Utils.BytesToString(handshake.RegionInfo.SimName);
                EncounterLogger.Log("CLIENT", "TERRITORY", "IMPRESSION", $"Region: {simName}, Flags: {handshake.RegionInfo.RegionFlags}");
            });

            // Field Mark: Chatter
            client.Network.RegisterCallback(PacketType.ChatFromSimulator, (sender, e) =>
            {
                ChatFromSimulatorPacket chat = (ChatFromSimulatorPacket)e.Packet;
                string message = Utils.BytesToString(chat.ChatData.Message);
                string fromName = Utils.BytesToString(chat.ChatData.FromName);
                EncounterLogger.Log("CLIENT", "CHAT", "HEARD", $"From: {fromName}, Msg: {message}");
            });

            // Field Mark: Things & Avatars (ObjectUpdate)
            client.Network.RegisterCallback(PacketType.ObjectUpdate, (sender, e) =>
            {
                ObjectUpdatePacket update = (ObjectUpdatePacket)e.Packet;
                foreach (var block in update.ObjectData)
                {
                    if (!seenObjects.Contains(block.ID))
                    {
                        seenObjects.Add(block.ID);
                        string type = (block.PCode == (byte)PCode.Avatar) ? "Avatar" : "Thing";
                        EncounterLogger.Log("CLIENT", "SIGHT", $"PRESENCE {type}", $"LocalID: {block.ID}, PCode: {block.PCode}");
                    }
                }
            });

            // Field Mark: Vanishing
            client.Network.RegisterCallback(PacketType.KillObject, (sender, e) =>
            {
                KillObjectPacket kill = (KillObjectPacket)e.Packet;
                foreach(var block in kill.ObjectData)
                {
                     if (seenObjects.Contains(block.ID))
                     {
                         seenObjects.Remove(block.ID);
                         EncounterLogger.Log("CLIENT", "SIGHT", "VANISHED", $"LocalID: {block.ID}");
                     }
                }
            });
        }

        static void RunRepl()
        {
            Console.WriteLine(" Mimic REPL. Commands: LOGIN, CHAT, REZ, WAIT, LOGOUT, EXIT");
            while (running)
            {
                string line = Console.ReadLine();
                if (string.IsNullOrWhiteSpace(line)) continue;

                string[] parts = line.Split(' ', 2);
                string cmd = parts[0].ToUpper();
                string arg = parts.Length > 1 ? parts[1] : "";

                try
                {
                    switch (cmd)
                    {
                        case "LOGIN":
                            // LOGIN First Last Pass [URI]
                            var loginArgs = arg.Split(' ');
                            if (loginArgs.Length < 3)
                            {
                                Console.WriteLine("Usage: LOGIN First Last Pass [URI]");
                                break;
                            }
                            string first = loginArgs[0];
                            string last = loginArgs[1];
                            string pass = loginArgs[2];
                            string uri = loginArgs.Length > 3 ? loginArgs[3] : "http://localhost:9000/";

                            LoginParams p = client.Network.DefaultLoginParams(first, last, pass, "Mimic", "1.0.0");
                            p.URI = uri;
                            if (client.Network.Login(p))
                            {
                                EncounterLogger.Log("CLIENT", "LOGIN", "SUCCESS", $"Agent: {client.Self.AgentID}");
                            }
                            else
                            {
                                EncounterLogger.Log("CLIENT", "LOGIN", "FAIL", client.Network.LoginMessage);
                            }
                            break;

                        case "CHAT":
                            if (client.Network.Connected)
                                client.Self.Chat(arg, 0, ChatType.Normal);
                            else
                                Console.WriteLine("Not connected.");
                            break;

                        case "REZ":
                            if (client.Network.Connected)
                            {
                                EncounterLogger.Log("CLIENT", "BEHAVIOR", "REZ", "Creating Object...");
                                Primitive.ConstructionData data = new Primitive.ConstructionData();
                                data.ProfileCurve = ProfileCurve.Square;
                                client.Objects.AddPrim(client.Network.CurrentSim, data, UUID.Zero, client.Self.SimPosition + new Vector3(0, 0, 2), new Vector3(0.5f, 0.5f, 0.5f), Quaternion.Identity);
                            }
                            else
                                Console.WriteLine("Not connected.");
                            break;

                        case "WAIT":
                            if (int.TryParse(arg, out int ms))
                            {
                                Thread.Sleep(ms);
                            }
                            break;

                        case "LOGOUT":
                            if (client.Network.Connected)
                            {
                                EncounterLogger.Log("CLIENT", "LOGOUT", "INITIATE");
                                client.Network.Logout();
                            }
                            break;

                        case "EXIT":
                            running = false;
                            break;

                        default:
                            Console.WriteLine($"Unknown command: {cmd}");
                            break;
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine($"Error executing {cmd}: {ex.Message}");
                }
            }
        }

        static void RunLegacy(string[] args)
        {
            string firstName = "Test";
            string lastName = "User";
            string password = "password";
            string loginURI = "http://localhost:9000/";
            string mode = "standard";
            bool rezObject = false;

            // Parse Args
            for (int i = 0; i < args.Length; i++)
            {
                if (args[i] == "--mode" && i + 1 < args.Length) mode = args[i + 1];
                if (args[i] == "--user" && i + 1 < args.Length) firstName = args[i + 1];
                if (args[i] == "--lastname" && i + 1 < args.Length) lastName = args[i + 1];
                if (args[i] == "--password" && i + 1 < args.Length) password = args[i + 1];
                if (args[i] == "--rez") rezObject = true;
            }

            if (mode == "rejection") password = "badpassword";

            EncounterLogger.Log("CLIENT", "LOGIN", "START", $"URI: {loginURI}, User: {firstName} {lastName}, Mode: {mode}");

            // Handle Wallflower mode specific config
            if (mode == "wallflower")
            {
                // This logic was in SimConnected in original code, but we can't easily contextualize the callback in legacy mode
                // without passing state.
                // Wait, SimConnected logic in Main() relied on capture.
                // Re-implementing Wallflower logic for Legacy mode:
                client.Network.SimConnected += (s, e) => {
                     if (mode == "wallflower")
                    {
                        EncounterLogger.Log("CLIENT", "BEHAVIOR", "WALLFLOWER", "Disabling Agent Updates (Heartbeat)");
                        client.Settings.SEND_AGENT_UPDATES = false;
                        client.Settings.SEND_PINGS = false;
                    }
                };
            }

            LoginParams loginParams = client.Network.DefaultLoginParams(firstName, lastName, password, "Mimic", "1.0.0");
            loginParams.URI = loginURI;

            if (client.Network.Login(loginParams))
            {
                EncounterLogger.Log("CLIENT", "LOGIN", "SUCCESS", $"Agent: {client.Self.AgentID}");

                if (rezObject)
                {
                    EncounterLogger.Log("CLIENT", "BEHAVIOR", "REZ", "Creating Object...");
                    Primitive.ConstructionData data = new Primitive.ConstructionData();
                    data.ProfileCurve = ProfileCurve.Square;
                    client.Objects.AddPrim(client.Network.CurrentSim, data, UUID.Zero, client.Self.SimPosition + new Vector3(0,0,2), new Vector3(0.5f, 0.5f, 0.5f), Quaternion.Identity);
                    EncounterLogger.Log("CLIENT", "BEHAVIOR", "REZ", "Sent AddPrim");
                }

                if (mode == "ghost")
                {
                    EncounterLogger.Log("CLIENT", "BEHAVIOR", "GHOST", "Vanishing immediately...");
                    Environment.Exit(0);
                }

                if (mode == "wallflower")
                {
                    EncounterLogger.Log("CLIENT", "BEHAVIOR", "WALLFLOWER", "Waiting for server timeout...");
                    Thread.Sleep(90000);
                }
                else
                {
                    if (mode == "chatter")
                    {
                        client.Self.Chat("Hello World!", 0, ChatType.Normal);
                    }

                    Thread.Sleep(5000);
                    EncounterLogger.Log("CLIENT", "LOGOUT", "INITIATE");
                    client.Network.Logout();
                }
            }
            else
            {
                EncounterLogger.Log("CLIENT", "LOGIN", "FAIL", client.Network.LoginMessage);
            }
        }
    }
}
