namespace Humbletim.Observatory {
    using UUID = OpenMetaverse.UUID;
    using EncounterLogger = OpenSim.Framework.EncounterLogger;

    // Bring in our pristine Studio math
    using OpenSim.Voice.WebRTC.Architecture;

    [Mono.Addins.Extension(Path = "/OpenSim/RegionModules", NodeName = "RegionModule", Id = "WebRTC.OpenSimStudio")]
    public class OpenSimStudio : OpenSim.Region.CoreModules.Avatar.Chat.ChatModule, OpenSim.Region.Framework.Interfaces.ISharedRegionModule {
        private static readonly log4net.ILog m_log = log4net.LogManager.GetLogger(System.Reflection.MethodBase.GetCurrentMethod().DeclaringType);

        public string Version => "0.0.1";
        // public string Name => "OpenSimStudio";

        // public override System.Type ReplaceableInterface = null;//{  get { return typeof(OpenMetaverse.IChatModule); } }  
        public bool IsSharedModule => true;
 
        // Override base class m_enabled to always be true  
        protected new bool m_enabled = true;  
  
        public override void Initialise(Nini.Config.IConfigSource configSource) {  
            // NEVER call base.Initialise - it will disable this module  
            m_log.Info("[OpenSimStudio]: Always enabled module initializing");  
        }  
        public override void AddRegion(OpenSim.Region.Framework.Scenes.Scene scene) {  
            base.AddRegion(scene);  
        }  
        public override void OnNewClient(OpenSim.Framework.IClientAPI client) {  
            m_log.InfoFormat("[OBSERVATORY]: OnNewClient({0})", client);
            // Hook into client chat BEFORE base class to intercept early  
            client.OnChatFromClient += InterceptChatFromClient;  
            // Let base ChatModule also handle the client  
            // base.OnNewClient(client);  
        }  
        private void InterceptChatFromClient(System.Object sender, OpenSim.Framework.OSChatMessage c) {  
            // Check if this message starts with our prefix  
            m_log.InfoFormat("[OBSERVATORY]: InterceptChatFromClient({0}, {1})", sender, c);
            if (!c.Message.StartsWith("#")) { 
                // For non-prefixed messages, let ChatModule handle normally  
                base.OnChatFromClient(sender, c);  
                return;
            }

            string command = c.Message.Substring("#".Length).Trim();  
            string response = ProcessCommand(command);  
            SendPrivateResponse(c.Sender, response);  
        }  
  
        private string ProcessCommand(string command) {  
            switch (command.ToLower())  
            {  
                case "help":  
                    return "Available commands: help, status, time";  
                case "status":  
                {
                    var m_studioEngine = OpenSimStudioBridge.m_studioEngine;
                    if (m_studioEngine == null) {
                        m_log.Info("\n[OBSERVATORY] Engine is offline.");
                        return "offline";
                    }

                    var sb = new System.Text.StringBuilder();
                    sb.AppendLine("\n--- STUDIO OBSERVATORY METRICS ---");
                    
                    foreach (var agentKvp in m_studioEngine.GlobalLedger) {
                        var agent = agentKvp.Value;
                        sb.AppendLine($"[Agent: {agent.AgentID}]");
                        
                        foreach (var sessionKvp in agent.Sessions) {
                            var s = sessionKvp.Value;
                            OpenSimStudioBridge.m_activeSessions.TryGetValue(s.SessionID, out var rtcp);
                            
                            // Calculate Pacing
                            var q = s.PacingWindow.ToArray();
                            string pacing = "[Silent]";
                            if (q.Length > 1) {
                                double windowMs = (q[q.Length - 1].Time - q[0].Time).TotalMilliseconds;
                                if (windowMs > 0) {
                                    double ratio = System.Linq.Enumerable.Sum(q, x => x.Ms) / windowMs;
                                    string trend = (ratio - s.PreviousRatio) > 0.001 ? "[++]" : (ratio - s.PreviousRatio) < -0.001 ? "[--]" : "[==]";
                                    s.PreviousRatio = ratio;
                                    pacing = $"{ratio:F4}x {trend}";
                                }
                            }

                            double idleMs = (System.DateTime.UtcNow - s.LastOpusReceivedAt).TotalMilliseconds;
                            string rtcpStr = rtcp != null ? $"Loss: {rtcp.PeakFractionLost}/255 ({rtcp.TotalPacketsLost} Total) | Jitter: {rtcp.LastJitter}" : "No RTCP";
                            int bufMs = s.AudioTape?.MillisecondsBuffered ?? 0;
                            bool spooling = s.AudioTape?.IsSpooling ?? false;
                            long underruns = s.AudioTape?.TotalUnderruns ?? 0;
                            long overruns = s.AudioTape?.TotalOverruns ?? 0;

                            sb.AppendLine($"  > Pipe:   {s.SessionID} [Joined: {s.HasJoined} | Speaking: {s.IsSpeaking}]");
                            sb.AppendLine($"  > Ingest: Pacing: {pacing} | Last: {idleMs:F0}ms ago | Rogue: {agent.TotalRogueFramesReceived}");
                            sb.AppendLine($"  > Tape:   {bufMs}ms (Spooling: {spooling}) | Underruns: {underruns} | Overruns: {overruns}");
                            sb.AppendLine($"  > Output: Pwr In: {s.PowerLevel,-3} | Pwr Out: {s.OutboundPowerLevel,-3} | RTCP {rtcpStr}");
                        }
                    }
                    return sb.ToString();
                }
                // break;
                    // return "System operational";  
                case "time":  
                    return System.DateTime.Now.ToString();  
                default:  
                    return $"Unknown command: {command}";  
            }  
        }  
  
        private void SendPrivateResponse(OpenSim.Framework.IClientAPI client, string message) {  
            client.SendChatMessage(  
                message,  
                (byte)OpenSim.Framework.ChatTypeEnum.Whisper,  
                OpenMetaverse.Vector3.Zero,  
                "CommandSystem",  
                UUID.Zero,  
                UUID.Zero,  
                (byte)OpenMetaverse.ChatSourceType.Object,  
                (byte)OpenMetaverse.ChatAudibleLevel.Fully  
            );  
        }  
  

    }
}

  
  
 