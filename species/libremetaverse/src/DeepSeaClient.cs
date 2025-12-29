using System;
using OpenMetaverse;
using OpenMetaverse.Packets;
using System.Threading;
using log4net.Config;
using log4net;
using System.Reflection;
using System.IO;
using System.Collections.Generic;
using System.Globalization;

namespace OmvTestHarness
{
    public static class EncounterLogger
    {
        private static string LogPath = Environment.GetEnvironmentVariable("MIMIC_ENCOUNTER_LOG") ?? "";
        private static string TagUA = Environment.GetEnvironmentVariable("TAG_UA") ?? "";

        // The Ritual of the fragment
        public static void Log(string side, string system, string signal, string payload = "")
        {
            // 1. Time: Millisecond precision, strictly ISO.
            string at = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ");

            // 2. Sanitation: Prevent the payload from breaking the fragment.
            // We only fear the double quote.
            if (!string.IsNullOrEmpty(payload))
                payload = payload.Replace("\"", "\\\"");

            // 3. The Injection (Manual formatting for zero-dependency)
            // Keys are short to keep it scannable. Order is chronological/hierarchical.
            // Injected 'ua' as requested.
            string ua_part = !string.IsNullOrEmpty(TagUA) ? $"\"ua\": \"{TagUA}\", " : "";
            string fragment = $"{{ \"at\": \"{at}\", {ua_part}\"via\": \"{side}\", \"sys\": \"{system}\", \"sig\": \"{signal}\", \"val\": \"{payload}\" }}";

            // 4. Emission
            Console.WriteLine(fragment);

            if (!string.IsNullOrEmpty(LogPath))
            {
                try
                {
                    File.AppendAllText(LogPath, fragment + Environment.NewLine);
                }
                catch (Exception) { }
            }
        }
    }

    public class DeepSeaClient
    {
        static GridClient client = default!;
        static HashSet<uint> seenObjects = new HashSet<uint>();
        static bool running = true;
        static string clientName = "DeepSeaClient";
        static string clientVersion = "0.0.0";
        static string subjectiveBecause = "";

        public static void Run(string[] args, string name, string version)
        {
            clientName = name;
            clientVersion = version;

            // Configure log4net
            var logRepository = LogManager.GetRepository(Assembly.GetEntryAssembly());
            XmlConfigurator.Configure(logRepository, new System.IO.FileInfo("log4net.config"));

            string firstName = "Test";
            string lastName = "User";
            string password = "password";
            string loginURI = "http://localhost:9000/";
            bool autoLogin = false;
            int timeout = 0;

            // Parse Args
            for (int i = 0; i < args.Length; i++)
            {
                string arg = args[i];
                if (arg == "--help")
                {
                    PrintUsage();
                    return;
                }
                if (arg == "--version")
                {
                    Console.WriteLine($"{clientName} {clientVersion}");
                    return;
                }
                if (arg == "--firstname" && i + 1 < args.Length) { firstName = args[i + 1]; i++; autoLogin = true; }
                else if (arg == "--lastname" && i + 1 < args.Length) { lastName = args[i + 1]; i++; autoLogin = true; }
                else if (arg == "--password" && i + 1 < args.Length) { password = args[i + 1]; i++; autoLogin = true; }
                else if (arg == "--uri" && i + 1 < args.Length) { loginURI = args[i + 1]; i++; autoLogin = true; }
                else if (arg == "--timeout" && i + 1 < args.Length) { if (int.TryParse(args[i + 1], out timeout)) { i++; } }
            }

            client = new GridClient();
            RegisterCallbacks();

            if (autoLogin)
            {
                Login(firstName, lastName, password, loginURI);
            }

            RunRepl(timeout);
        }

        static void PrintUsage()
        {
            Console.WriteLine($"Usage: {clientName} [options]");
            Console.WriteLine("Options:");
            Console.WriteLine("  --firstname <name>   First name of the agent");
            Console.WriteLine("  --lastname <name>    Last name of the agent");
            Console.WriteLine("  --password <pass>    Password of the agent");
            Console.WriteLine("  --uri <uri>          Login URI (default: http://localhost:9000/)");
            Console.WriteLine("  --timeout <seconds>  Maximum run time in seconds");
            Console.WriteLine("  --help               Show this help message");
            Console.WriteLine("  --version            Show version");
        }

        static void Login(string first, string last, string pass, string uri)
        {
             LoginParams p = client.Network.DefaultLoginParams(first, last, pass, clientName, clientVersion);
             p.URI = uri;
             if (client.Network.Login(p))
             {
                 EncounterLogger.Log("Visitant", "Login", "Success", $"Agent: {client.Self.AgentID}");
             }
             else
             {
                 EncounterLogger.Log("Visitant", "Login", "Fail", client.Network.LoginMessage);
             }
        }

        static void RegisterCallbacks()
        {
            // Field Mark 14: Login Response
            client.Network.LoginProgress += (sender, e) =>
            {
                EncounterLogger.Log("Visitant", "Login", $"Progress {e.Status}", e.Message);
            };

            // Field Mark 15: UDP Connection (SimConnected)
            client.Network.SimConnected += (sender, e) =>
            {
                EncounterLogger.Log("Visitant", "UDP", "Connected", $"Sim: {e.Simulator.Name}, IP: {e.Simulator.IPEndPoint}");
            };

            // Field Mark: Alerts
            client.Network.RegisterCallback(PacketType.AlertMessage, (sender, e) =>
            {
                AlertMessagePacket alert = (AlertMessagePacket)e.Packet;
                string message = Utils.BytesToString(alert.AlertData.Message);
                EncounterLogger.Log("Visitant", "Alert", "Received", message);
            });

            // Field Mark: Territory Impressions
            client.Network.RegisterCallback(PacketType.RegionHandshake, (sender, e) => {
                RegionHandshakePacket handshake = (RegionHandshakePacket)e.Packet;
                string simName = Utils.BytesToString(handshake.RegionInfo.SimName);
                EncounterLogger.Log("Visitant", "Territory", "Impression", $"Region: {simName}, Flags: {handshake.RegionInfo.RegionFlags}");
            });

            // Field Mark: Chatter (INSTRUMENTED FOR DIALECT PROBE)
            client.Network.RegisterCallback(PacketType.ChatFromSimulator, (sender, e) => {
                ChatFromSimulatorPacket chat = (ChatFromSimulatorPacket)e.Packet;
                // [OBSERVATORY] DIALECT PROBE START
                byte[] raw = chat.ChatData.Message; // Raw bytes from wire
                string dialect = "Unknown";
                if (raw.Length > 0) {
                    if (raw[raw.Length - 1] == 0x00)
                        dialect = "NullTerminated"; // OpenSim is sending a null!
                    else
                        dialect = "ExplicitLength"; // OpenSim is clean.
                } else {
                    dialect = "Empty";
                }
                EncounterLogger.Log("Visitant", "Packet", "ChatDialectInbound",
                    $"Dialect:{dialect}, Reliable:{e.Packet.Header.Reliable}, Zerocoded:{e.Packet.Header.Zerocoded}, RawLen:{raw.Length}, LastByte:{(raw.Length > 0 ? raw[raw.Length-1].ToString("X2") : "XX")}");
                // [OBSERVATORY] DIALECT PROBE END

                string message = Utils.BytesToString(chat.ChatData.Message);
                string fromName = Utils.BytesToString(chat.ChatData.FromName);
                EncounterLogger.Log("Visitant", "Chat", "Heard", $"From: {fromName}, Msg: {message}");
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
                        EncounterLogger.Log("Visitant", "Sight", $"Presence {type}", $"LocalID: {block.ID}, PCode: {block.PCode}");
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
                         EncounterLogger.Log("Visitant", "Sight", "Vanished", $"LocalID: {block.ID}");
                     }
                }
            });
        }

        static void RunRepl(int timeout)
        {
            Console.WriteLine($" {clientName} REPL. Commands: LOGIN, CHAT, REZ, SLEEP, WHOAMI, WHO, WHERE, WHEN, SUBJECTIVE_WHY, SUBJECTIVE_BECAUSE, SUBJECTIVE_LOOK, SUBJECTIVE_GOTO, POS, LOGOUT, EXIT");
            DateTime startTime = DateTime.Now;

            // For timeout checking we might need a non-blocking read or a timer.
            // Console.ReadLine blocks.
            // If a timeout is specified, we'll use a Reader thread or Task to handle input so we can check timeout.
            // However, a simpler approach for a test harness is to check timeout after each command or use a Timer to kill the process.

            Timer? exitTimer = null;
            if (timeout > 0)
            {
                exitTimer = new Timer((state) => {
                    EncounterLogger.Log("Visitant", "System", "Timeout", "Max run time reached.");
                    Environment.Exit(0);
                }, null, timeout * 1000, Timeout.Infinite);
            }

            while (running)
            {
                string? line = Console.ReadLine();
                if (line == null) // EOF
                {
                    running = false;
                    break;
                }
                if (string.IsNullOrWhiteSpace(line)) continue;

                EncounterLogger.Log("Visitant", "DEBUG", "Stdin", $"Read: '{line}'");

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
                            Login(first, last, pass, uri);
                            break;

                        case "SLEEP":
                            if (float.TryParse(arg, NumberStyles.Float, CultureInfo.InvariantCulture, out float seconds))
                            {
                                Thread.Sleep((int)(seconds * 1000));
                                EncounterLogger.Log("Visitant", "System", "Sleep", $"Slept {seconds}s");
                            }
                            else
                            {
                                Console.WriteLine("Usage: SLEEP float_seconds");
                            }
                            break;

                        case "WHOAMI":
                            if (client.Network.Connected)
                                EncounterLogger.Log("Visitant", "Self", "Identity", $"Name: {client.Self.Name}, UUID: {client.Self.AgentID}");
                            else
                                Console.WriteLine("Not connected.");
                            break;

                        case "WHO":
                            if (client.Network.Connected && client.Network.CurrentSim != null)
                            {
                                client.Network.CurrentSim.ObjectsAvatars.ForEach(avatar =>
                                {
                                    EncounterLogger.Log("Visitant", "Sight", "Avatar", $"Name: {avatar.Name}, UUID: {avatar.ID}, LocalID: {avatar.LocalID}");
                                });
                            }
                            else
                                Console.WriteLine("Not connected.");
                            break;

                        case "WHERE":
                            if (client.Network.Connected && client.Network.CurrentSim != null)
                            {
                                EncounterLogger.Log("Visitant", "Navigation", "Location", $"Sim: {client.Network.CurrentSim.Name}, Pos: {client.Self.SimPosition}, Global: {client.Self.GlobalPosition}");
                            }
                            else
                                Console.WriteLine("Not connected.");
                            break;

                        case "WHEN":
                            EncounterLogger.Log("Visitant", "Chronology", "Time", $"GridTime: {DateTime.UtcNow.ToString("O")}");
                            break;

                        case "SUBJECTIVE_WHY":
                            EncounterLogger.Log("Visitant", "Cognition", "Why", subjectiveBecause);
                            break;

                        case "SUBJECTIVE_BECAUSE":
                            subjectiveBecause = arg;
                            EncounterLogger.Log("Visitant", "Cognition", "Because", "Updated");
                            break;

                        case "SUBJECTIVE_LOOK":
                            if (client.Network.Connected && client.Network.CurrentSim != null)
                            {
                                int avatars = client.Network.CurrentSim.ObjectsAvatars.Count;
                                int primitives = client.Network.CurrentSim.ObjectsPrimitives.Count;
                                EncounterLogger.Log("Visitant", "Sight", "Observation", $"Avatars: {avatars}, Primitives: {primitives}");
                            }
                            else
                                Console.WriteLine("Not connected.");
                            break;

                        case "SUBJECTIVE_GOTO":
                            // SUBJECTIVE_GOTO x,y,z
                            // Spec implies interpreted movement. We'll implement direct AutoPilot for now.
                            if (client.Network.Connected)
                            {
                                string[] coords = arg.Split(',');
                                if (coords.Length >= 2 &&
                                    float.TryParse(coords[0], NumberStyles.Float, CultureInfo.InvariantCulture, out float x) &&
                                    float.TryParse(coords[1], NumberStyles.Float, CultureInfo.InvariantCulture, out float y))
                                {
                                    float z = client.Self.SimPosition.Z;
                                    if (coords.Length > 2) float.TryParse(coords[2], NumberStyles.Float, CultureInfo.InvariantCulture, out z);

                                    EncounterLogger.Log("Visitant", "Action", "Move", $"Dest: {x},{y},{z}");
                                    client.Self.AutoPilot(x, y, z);
                                }
                                else
                                {
                                    Console.WriteLine("Usage: SUBJECTIVE_GOTO x,y[,z]");
                                }
                            }
                            else
                                Console.WriteLine("Not connected.");
                            break;

                        case "POS":
                            // POS x,y,z - Slam absolute position (Teleport)
                            if (client.Network.Connected && client.Network.CurrentSim != null)
                            {
                                string[] coords = arg.Split(',');
                                if (coords.Length >= 3 &&
                                    float.TryParse(coords[0], NumberStyles.Float, CultureInfo.InvariantCulture, out float x) &&
                                    float.TryParse(coords[1], NumberStyles.Float, CultureInfo.InvariantCulture, out float y) &&
                                    float.TryParse(coords[2], NumberStyles.Float, CultureInfo.InvariantCulture, out float z))
                                {
                                    EncounterLogger.Log("Visitant", "Action", "Teleport", $"Dest: {x},{y},{z}");
                                    client.Self.Teleport(client.Network.CurrentSim.Name, new Vector3(x, y, z));
                                }
                                else
                                {
                                    Console.WriteLine("Usage: POS x,y,z");
                                }
                            }
                            else
                                Console.WriteLine("Not connected.");
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
                                EncounterLogger.Log("Visitant", "Behavior", "Rez", "Creating Object...");
                                Primitive.ConstructionData data = new Primitive.ConstructionData();
                                data.ProfileCurve = ProfileCurve.Square;
                                client.Objects.AddPrim(client.Network.CurrentSim, data, UUID.Zero, client.Self.SimPosition + new Vector3(0, 0, 2), new Vector3(0.5f, 0.5f, 0.5f), Quaternion.Identity);
                            }
                            else
                                Console.WriteLine("Not connected.");
                            break;

                        case "WAIT":
                            // Legacy wait alias for SLEEP
                            if (int.TryParse(arg, out int ms))
                            {
                                Thread.Sleep(ms);
                            }
                            break;

                        case "LOGOUT":
                            if (client.Network.Connected)
                            {
                                EncounterLogger.Log("Visitant", "Logout", "REPL", "Director requested logout");
                                client.Network.Logout();
                            }
                            break;

                        case "EXIT":
                            EncounterLogger.Log("Visitant", "Exit", "REPL", "Director requested exit");
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
    }
}
