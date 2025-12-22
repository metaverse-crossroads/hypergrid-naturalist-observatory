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
        private static string LogPath = "../encounter.log";

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
        static void Main(string[] args)
        {
            // Configure log4net
            var logRepository = LogManager.GetRepository(Assembly.GetEntryAssembly());
            XmlConfigurator.Configure(logRepository, new System.IO.FileInfo("log4net.config"));

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

            GridClient client = new GridClient();
            HashSet<uint> seenObjects = new HashSet<uint>();

            // Field Mark 14: Login Response
            client.Network.LoginProgress += (sender, e) =>
            {
                EncounterLogger.Log("CLIENT", "LOGIN", $"PROGRESS {e.Status}", e.Message);
            };

            // Field Mark 15: UDP Connection (SimConnected)
            client.Network.SimConnected += (sender, e) =>
            {
                EncounterLogger.Log("CLIENT", "UDP", "CONNECTED", $"Sim: {e.Simulator.Name}, IP: {e.Simulator.IPEndPoint}");

                if (mode == "wallflower")
                {
                    EncounterLogger.Log("CLIENT", "BEHAVIOR", "WALLFLOWER", "Disabling Agent Updates (Heartbeat)");
                    client.Settings.SEND_AGENT_UPDATES = false;
                    client.Settings.SEND_PINGS = false;
                }
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

            LoginParams loginParams = client.Network.DefaultLoginParams(firstName, lastName, password, "Mimic", "1.0.0");
            loginParams.URI = loginURI;

            if (client.Network.Login(loginParams))
            {
                EncounterLogger.Log("CLIENT", "LOGIN", "SUCCESS", $"Agent: {client.Self.AgentID}");

                if (rezObject)
                {
                    EncounterLogger.Log("CLIENT", "BEHAVIOR", "REZ", "Creating Object...");
                    // Rez a box
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
                    // Chat something
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
