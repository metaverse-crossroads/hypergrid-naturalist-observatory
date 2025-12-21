using System;
using System.Security.Cryptography;
using System.Text;

namespace Sequencer
{
    class Program
    {
        static void Main(string[] args)
        {
            if (args.Length == 0)
            {
                Console.Error.WriteLine("Usage: Sequencer <command> [args]");
                Environment.Exit(1);
            }

            string command = args[0];
            try
            {
                if (command == "gen-user") GenUser(args);
                else if (command == "gen-prim") GenPrim(args);
                else
                {
                    Console.Error.WriteLine($"Unknown command: {command}");
                    Environment.Exit(1);
                }
            }
            catch (Exception ex)
            {
                Console.Error.WriteLine($"Error: {ex.Message}");
                Environment.Exit(1);
            }
        }

        static string GetArg(string[] args, string name)
        {
            for (int i = 0; i < args.Length; i++)
            {
                if (args[i] == name && i + 1 < args.Length) return args[i + 1];
            }
            throw new ArgumentException($"Missing argument: {name}");
        }

        static void GenUser(string[] args)
        {
            string first = GetArg(args, "--first");
            string last = GetArg(args, "--last");
            string pass = GetArg(args, "--pass");
            string uuid = GetArg(args, "--uuid");

            string salt = "12345678901234567890123456789012";
            string md5Pass = ComputeMD5(pass);
            string finalHash = ComputeMD5($"{md5Pass}:{salt}");
            string serviceURLs = "HomeURI= InventoryServerURI= AssetServerURI=";
            long created = DateTimeOffset.UtcNow.ToUnixTimeSeconds();

            Console.WriteLine($"INSERT OR IGNORE INTO UserAccounts (PrincipalID, ScopeID, FirstName, LastName, Email, ServiceURLs, Created, UserLevel, UserFlags, active) VALUES ('{uuid}', '00000000-0000-0000-0000-000000000000', '{first}', '{last}', '{first.ToLower()}{last.ToLower()}@example.com', '{serviceURLs}', {created}, 0, 0, 1);");
            Console.WriteLine($"INSERT OR IGNORE INTO auth (UUID, passwordHash, passwordSalt, accountType) VALUES ('{uuid}', '{finalHash}', '{salt}', 'UserAccount');");

            string rootFolderUUID = Guid.NewGuid().ToString();
            Console.WriteLine($"INSERT OR IGNORE INTO inventoryfolders (folderID, agentID, parentFolderID, folderName, type, version) VALUES ('{rootFolderUUID}', '{uuid}', '00000000-0000-0000-0000-000000000000', 'My Inventory', 8, 1);");
        }

        static void GenPrim(string[] args)
        {
            string owner = GetArg(args, "--owner");
            string region = GetArg(args, "--region");
            string posX = GetArg(args, "--posX");
            string posY = GetArg(args, "--posY");
            string posZ = GetArg(args, "--posZ");

            string primUUID = Guid.NewGuid().ToString();
            long created = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
            string textureHex = "8955674724CB43ED920B47CAED15465F0000000000000000803F000000803F0000000000000000000000000000000000000000000000000000000000000000";

            Console.WriteLine($"INSERT OR IGNORE INTO prims (UUID, RegionUUID, CreationDate, Name, SceneGroupID, CreatorID, OwnerID, GroupID, LastOwnerID, RezzerID, PositionX, PositionY, PositionZ, OwnerMask, NextOwnerMask, GroupMask, EveryoneMask, BaseMask) VALUES ('{primUUID}', '{region}', {created}, 'MimicBox', '{primUUID}', '{owner}', '{owner}', '00000000-0000-0000-0000-000000000000', '{owner}', '00000000-0000-0000-0000-000000000000', {posX}, {posY}, {posZ}, 2147483647, 2147483647, 0, 0, 2147483647);");
            Console.WriteLine($"INSERT OR IGNORE INTO primshapes (UUID, Shape, ScaleX, ScaleY, ScaleZ, PCode, PathBegin, PathEnd, PathScaleX, PathScaleY, PathShearX, PathShearY, PathSkew, PathCurve, PathRadiusOffset, PathRevolutions, PathTaperX, PathTaperY, PathTwist, PathTwistBegin, ProfileBegin, ProfileEnd, ProfileCurve, ProfileHollow, State, Texture, ExtraParams) VALUES ('{primUUID}', 1, 0.5, 0.5, 0.5, 9, 0, 0, 100, 100, 0, 0, 0, 16, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, X'{textureHex}', X'');");
        }

        static string ComputeMD5(string input)
        {
            using (MD5 md5 = MD5.Create())
            {
                byte[] inputBytes = Encoding.ASCII.GetBytes(input);
                byte[] hashBytes = md5.ComputeHash(inputBytes);
                return BitConverter.ToString(hashBytes).Replace("-", "").ToLower();
            }
        }
    }
}
