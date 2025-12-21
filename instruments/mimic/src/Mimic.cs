using System;
using OpenMetaverse;
using OpenMetaverse.Packets;
using System.Threading;
using log4net.Config;
using log4net;
using System.Reflection;
using System.IO;

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

            // Parse Args
            for (int i = 0; i < args.Length; i++)
            {
                if (args[i] == "--mode" && i + 1 < args.Length) mode = args[i + 1];
                if (args[i] == "--user" && i + 1 < args.Length) firstName = args[i + 1];
                if (args[i] == "--lastname" && i + 1 < args.Length) lastName = args[i + 1];
                if (args[i] == "--password" && i + 1 < args.Length) password = args[i + 1];
            }

            if (mode == "rejection") password = "badpassword";

            if (mode == "gen-data")
            {
                GenerateData();
                return;
            }

            EncounterLogger.Log("CLIENT", "LOGIN", "START", $"URI: {loginURI}, User: {firstName} {lastName}, Mode: {mode}");

            GridClient client = new GridClient();

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
                    // In "Wallflower" mode, we want to connect but then silence the heartbeats
                    // LibreMetaverse usually sends AgentUpdate automatically. We need to suppress it.
                    // The easiest way is to set the update interval to infinity or very high.
                    // However, LibOMV settings are powerful.

                    // Actually, let's just NOT respond to anything.
                    // But LibOMV handles a lot in background threads.

                    // Let's log that we are going silent.
                    EncounterLogger.Log("CLIENT", "BEHAVIOR", "WALLFLOWER", "Disabling Agent Updates (Heartbeat)");
                    client.Settings.SEND_AGENT_UPDATES = false; // Don't send updates
                    client.Settings.SEND_PINGS = false; // Don't send pings
                }
            };

            // Field Mark 18: Region Handshake
            client.Network.RegisterCallback(PacketType.RegionHandshake, (sender, e) =>
            {
                EncounterLogger.Log("CLIENT", "UDP", "RECV RegionHandshake", $"Size: {e.Packet.Length}");
            });

            // Field Mark 22: LayerData (Terrain)
            client.Network.RegisterCallback(PacketType.LayerData, (sender, e) =>
            {
                EncounterLogger.Log("CLIENT", "UDP", "RECV LayerData", $"Size: {e.Packet.Length}");
            });

            // Field Mark 23: ObjectUpdate
            client.Network.RegisterCallback(PacketType.ObjectUpdate, (sender, e) =>
            {
                EncounterLogger.Log("CLIENT", "UDP", "RECV ObjectUpdate", $"Size: {e.Packet.Length}");
            });

            // Event Queue (Field Mark 20)
            client.Network.EventQueueRunning += (sender, e) =>
            {
                 EncounterLogger.Log("CLIENT", "CAPS", "EQ RUNNING", $"Sim: {e.Simulator.Name}");
            };

            LoginParams loginParams = client.Network.DefaultLoginParams(firstName, lastName, password, "Mimic", "1.0.0");
            loginParams.URI = loginURI;

            // Mode: Ghost - Disconnect immediately after HTTP login, before UDP?
            // LibOMV Login() does XMLRPC then connects UDP. It's a blocking call that does both.
            // To ghost, we might need to interrupt it, or...
            // Actually, we can just close the client right after login returns success?
            // The "Ghost" scenario implies we *don't* send UDP UseCircuitCode.
            // But LibOMV sends it inside Login().

            // For the sake of this harness, "Ghost" might just mean "Login, then Exit Immediately".
            // If we want to *truly* ghost (get Circuit but don't use it), we'd need to modify LibOMV or do manual XMLRPC.
            // Manual XMLRPC is too much work.
            // Let's stick to "Login Success -> Immediate Exit" which means the server sees a login but maybe the UDP connection is cut short.

            if (client.Network.Login(loginParams))
            {
                EncounterLogger.Log("CLIENT", "LOGIN", "SUCCESS", $"Agent: {client.Self.AgentID}");

                if (mode == "ghost")
                {
                    EncounterLogger.Log("CLIENT", "BEHAVIOR", "GHOST", "Vanishing immediately...");
                    Environment.Exit(0); // Harsh exit
                }

                if (mode == "wallflower")
                {
                    // Wait for the server to timeout us
                    EncounterLogger.Log("CLIENT", "BEHAVIOR", "WALLFLOWER", "Waiting for server timeout...");
                    Thread.Sleep(90000); // 90 seconds (Server timeout default is often 60s)
                }
                else
                {
                    // Standard stay connected for a bit
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

        static void GenerateData()
        {
            // 1. User Injection (Visitant One)
            InjectUser("aa5ea169-321b-4632-b4fa-50933f3013f1", "Visitant", "One", "password");

            // 2. User Injection (Visitant Two)
            InjectUser("bb5ea169-321b-4632-b4fa-50933f3013f2", "Visitant", "Two", "password");

            // 3. Object Injection
            string userUUID = "aa5ea169-321b-4632-b4fa-50933f3013f1"; // Owner is Visitant One
            string primUUID = UUID.Random().ToString();
            string regionUUID = "11111111-2222-3333-4444-555555555555";

            Primitive cube = new Primitive();
            cube.PrimData.PathCurve = PathCurve.Line;
            cube.PrimData.ProfileCurve = ProfileCurve.Square;
            cube.Scale = new Vector3(0.5f, 0.5f, 0.5f);
            cube.Position = new Vector3(128, 128, 40); // High up
            cube.Textures = new Primitive.TextureEntry(new UUID("89556747-24cb-43ed-920b-47caed15465f"));

            // Texture Blob
            byte[] textureBytes = cube.Textures.GetBytes();
            string textureHex = BitConverter.ToString(textureBytes).Replace("-", "");

            Console.WriteLine("-- Object Injection");
            Console.WriteLine($"INSERT OR IGNORE INTO prims (UUID, RegionUUID, CreationDate, Name, SceneGroupID, CreatorID, OwnerID, GroupID, LastOwnerID, RezzerID, PositionX, PositionY, PositionZ, OwnerMask, NextOwnerMask, GroupMask, EveryoneMask, BaseMask) VALUES ('{primUUID}', '{regionUUID}', {DateTimeOffset.UtcNow.ToUnixTimeSeconds()}, 'MimicBox', '{primUUID}', '{userUUID}', '{userUUID}', '{UUID.Zero}', '{userUUID}', '{UUID.Zero}', 128, 128, 40, 2147483647, 2147483647, 0, 0, 2147483647);");

            // PrimShapes
            // Shape=1 (Square), PathCurve=16 (Straight), PathScale=100
            Console.WriteLine($"INSERT OR IGNORE INTO primshapes (UUID, Shape, ScaleX, ScaleY, ScaleZ, PCode, PathBegin, PathEnd, PathScaleX, PathScaleY, PathShearX, PathShearY, PathSkew, PathCurve, PathRadiusOffset, PathRevolutions, PathTaperX, PathTaperY, PathTwist, PathTwistBegin, ProfileBegin, ProfileEnd, ProfileCurve, ProfileHollow, State, Texture, ExtraParams) VALUES ('{primUUID}', 1, 0.5, 0.5, 0.5, 9, 0, 0, 100, 100, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, X'{textureHex}', X'');");
        }

        static string ComputeMD5(string input)
        {
            using (System.Security.Cryptography.MD5 md5 = System.Security.Cryptography.MD5.Create())
            {
                byte[] inputBytes = System.Text.Encoding.ASCII.GetBytes(input);
                byte[] hashBytes = md5.ComputeHash(inputBytes);
                return BitConverter.ToString(hashBytes).Replace("-", "").ToLower();
            }
        }

        static void InjectUser(string uuid, string first, string last, string pass)
        {
            string salt = "12345678901234567890123456789012";
            string md5Pass = ComputeMD5(pass);
            string finalHash = ComputeMD5($"{md5Pass}:{salt}");
            string serviceURLs = "HomeURI= InventoryServerURI= AssetServerURI=";

            Console.WriteLine($"INSERT OR IGNORE INTO UserAccounts (PrincipalID, ScopeID, FirstName, LastName, Email, ServiceURLs, Created, UserLevel, UserFlags, active) VALUES ('{uuid}', '00000000-0000-0000-0000-000000000000', '{first}', '{last}', '{first.ToLower()}{last.ToLower()}@example.com', '{serviceURLs}', {DateTimeOffset.UtcNow.ToUnixTimeSeconds()}, 0, 0, 1);");
            Console.WriteLine($"INSERT OR IGNORE INTO auth (UUID, passwordHash, passwordSalt, accountType) VALUES ('{uuid}', '{finalHash}', '{salt}', 'UserAccount');");

            string rootFolderUUID = UUID.Random().ToString();
            Console.WriteLine($"INSERT OR IGNORE INTO inventoryfolders (folderID, agentID, parentFolderID, folderName, type, version) VALUES ('{rootFolderUUID}', '{uuid}', '00000000-0000-0000-0000-000000000000', 'My Inventory', 8, 1);");
        }
    }
}
