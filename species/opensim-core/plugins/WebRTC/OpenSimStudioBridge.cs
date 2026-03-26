/*
$ ./bin/cs++ species/opensim-core/plugins/WebRTC/*.cs vivarium/opensim-core-0.9.3/bin/WebRTC.OpenSimStudioBridge.dll \
     -r:SIPSorcery.dll -r:SIPSorceryMedia.Abstractions.dll -r:Microsoft.Extensions.Logging.Abstractions.dll
*/

[assembly: Mono.Addins.Addin("WebRTC.OpenSimStudioBridge", "1.0")]
[assembly: Mono.Addins.AddinDependency("OpenSim", OpenSim.VersionInfo.VersionNumber)]
[assembly: Mono.Addins.AddinDependency("OpenSim.Region.Framework", OpenSim.VersionInfo.VersionNumber)]

namespace Humbletim.Observatory {
    using UUID = OpenMetaverse.UUID;
    using OpenMetaverse.StructuredData;
    using EncounterLogger = OpenSim.Framework.EncounterLogger;
    using System.Linq;

    // Bring in our pristine Studio math
    using OpenSim.Voice.WebRTC.Architecture;

    public class ObservatoryTelemetry {
        public string ViewerSession;
        public UUID AgentID;
        public SIPSorcery.Net.RTCPeerConnection PeerConnection;
        public System.Action Teardown;
        
        // --- RTCP DOWNSTREAM HEALTH METRICS ---
        public byte PeakFractionLost; // High-water mark to prevent concealment
        public int TotalPacketsLost;
        public uint LastJitter;
    }

    [Mono.Addins.Extension(Path = "/OpenSim/RegionModules", NodeName = "RegionModule", Id = "WebRTC.OpenSimStudioBridge")]
    [Mono.Addins.Extension(Path = "/OpenSim/Startup", Id = "WebRTC.OpenSimStudioBridge", NodeName = "Plugin")]
    public class OpenSimStudioBridge : OpenSim.IApplicationPlugin, OpenSim.Region.Framework.Interfaces.ISharedRegionModule {
        private static readonly log4net.ILog m_log = log4net.LogManager.GetLogger(System.Reflection.MethodBase.GetCurrentMethod().DeclaringType);

        public static System.Collections.Generic.Dictionary<string, ObservatoryTelemetry> m_activeSessions = new();
        private System.Collections.Generic.Dictionary<UUID, humbletim.MindBinder> m_binders = new();

        // --- THE STUDIO ENGINE ---
        public static WebRTCVoiceEngine m_studioEngine;

        #region IApplicationPlugin Lifecycle

        public string Version => "0.0.1";
        public string Name => "OpenSimStudioBridge";

        public void Initialise() { }

        public void Initialise(OpenSim.OpenSimBase openSim) {
            var scene = openSim.SceneManager.CurrentOrFirstScene;
            if (scene != null) OnRegionsReady(openSim.SceneManager);
            else openSim.SceneManager.OnRegionsReadyStatusChange += OnRegionsReady;
        }

        public void Dispose() { }

        #endregion

        #region ISharedRegionModule Lifecycle

        public System.Type ReplaceableInterface => null;
        public bool IsSharedModule => true;

        public void Initialise(Nini.Config.IConfigSource source) {
            var cfg = source.Configs["WebRTCSIPSorcery"];
            bool Verbose = cfg != null && cfg.GetBoolean("Verbose", false);
            if (Verbose) SIPSorcery.LogFactory.Set(new humbletim.SipsorceryLoggerFactory());

            // --- IGNITE THE STUDIO ---
            if (m_studioEngine == null) {
                m_log.Info("[STUDIO BRIDGE]: Powering on the WebRTC Mixing Studio...");
                m_studioEngine = new WebRTCVoiceEngine();
                m_studioEngine.Start();

                // --- WIRE UP THE OUTBOUND DISPATCH ---
                // When Room 3 finishes a mix, it hands us Opus frames to broadcast
                m_studioEngine.Switchboard.OnDispatchOpus += (targetSession, opusBytes) => {
                    if (m_activeSessions.TryGetValue(targetSession.SessionID, out var tel)) {
                        // The Mixing Desk slices down to strict 20ms chunks (960 samples @ 48kHz)
                        try { tel.PeerConnection.SendAudio(960, opusBytes); } catch { }
                    }
                };

                // When Room 1 wants to send Data Channel JSON (like roster sync)
                m_studioEngine.Switchboard.OnDispatchJson += (targetSession, json) => {
                    if (m_activeSessions.TryGetValue(targetSession.SessionID, out var tel)) {
                        var dc = System.Linq.Enumerable.FirstOrDefault(tel.PeerConnection.DataChannels);
                        if (dc != null && dc.readyState == SIPSorcery.Net.RTCDataChannelState.open) {
                            try { dc.send(json); } catch { }
                        }
                    }
                };

                m_studioEngine.Switchboard.OnRogueFrameDropped += (session, reason) => m_log.WarnFormat("[STUDIO BOUNCER]: Session {0} - {1}", session.SessionID, reason);
                m_studioEngine.Switchboard.OnSessionAborted += (session, reason) => m_log.WarnFormat("[STUDIO BOUNCER]: Session {0} ABORTED - {1}", session.SessionID, reason);
                
                // Logging explicitly updated with SessionID
                m_studioEngine.Switchboard.OnDataChannelJsonReceived += (session, json) => m_log.InfoFormat("[STUDIO DATA]: Session {0} {1}", session.SessionID, json);

                // Optional: A noisy heartbeat just to prove RTP is surviving the Bouncer and reaching Room 2
                if (Verbose) m_studioEngine.Switchboard.OnEncryptedOpusReceived += (session, payload) => m_log.DebugFormat("[STUDIO INGEST]: +{0} bytes from {1}", payload.Length, session.SessionID);
            }
        }

        public void AddRegion(OpenSim.Region.Framework.Scenes.Scene scene) {
            var binder = new humbletim.MindBinder();
            lock (m_binders) m_binders[scene.RegionInfo.RegionID] = binder;
            binder.Bind(scene, "OnClientClosed", (UUID agentId, OpenSim.Region.Framework.Scenes.Scene s) => {
                var session = System.Linq.Enumerable.FirstOrDefault(m_activeSessions.Values, x => x.AgentID == agentId);
                session?.Teardown?.Invoke();
            });

            binder.Bind(scene, "OnRegisterCaps", (UUID agentID, OpenSim.Framework.Capabilities.Caps caps) => {
                string pvarUrl = "/CAPS/" + UUID.Random();
                string vsrUrl = "/CAPS/" + UUID.Random();
                var regionID = scene.RegionInfo.RegionID;
                caps.RegisterHandler("ProvisionVoiceAccountRequest",
                    new OpenSim.Framework.Servers.HttpServer.RestStreamHandler("POST", pvarUrl,
                        (req, path, prm, httpReq, httpRes) => HandleProvisionVoiceAccountRequest(req, agentID, regionID),
                        "ProvisionVoiceAccountRequest", agentID.ToString()));

                caps.RegisterHandler("VoiceSignalingRequest",
                    new OpenSim.Framework.Servers.HttpServer.RestStreamHandler("POST", vsrUrl,
                        (req, path, prm, httpReq, httpRes) => HandleVoiceSignalingRequest(req, agentID, regionID),
                        "VoiceSignalingRequest", agentID.ToString()));
            });
        }

        public void RemoveRegion(OpenSim.Region.Framework.Scenes.Scene scene) {
            lock (m_binders) {
                if (m_binders.TryGetValue(scene.RegionInfo.RegionID, out var binder)) {
                    binder.UnbindAll();
                    m_binders.Remove(scene.RegionInfo.RegionID);
                }
            }
        }

        public void RegionLoaded(OpenSim.Region.Framework.Scenes.Scene scene) {
            var featuresModule = scene.RequestModuleInterface<OpenSim.Region.Framework.Interfaces.ISimulatorFeaturesModule>();
            featuresModule?.AddFeature("VoiceServerType", OSD.FromString("webrtc"));
        }

        public void PostInitialise() { }
        public void Close() { m_studioEngine?.Stop(); }

        private void OnRegionsReady(OpenSim.Region.Framework.Scenes.SceneManager sceneManager) {
            OpenSim.Framework.MainConsole.Instance.Commands.AddCommand(
                "WebRTC", false, "status", "status", "Dump WebRTC Naturalist Observatory Telemetry",
                (module, cmdparams) => {
                    if (m_studioEngine == null) {
                        m_log.Info("\n[OBSERVATORY] Engine is offline.");
                        return;
                    }

                    var sb = new System.Text.StringBuilder();
                    sb.AppendLine("\n--- STUDIO OBSERVATORY METRICS ---");
                    
                    foreach (var agentKvp in m_studioEngine.GlobalLedger) {
                        var agent = agentKvp.Value;
                        sb.AppendLine($"[Agent: {agent.AgentID}]");
                        
                        foreach (var sessionKvp in agent.Sessions) {
                            var s = sessionKvp.Value;
                            m_activeSessions.TryGetValue(s.SessionID, out var rtcp);
                            
                            // Calculate Pacing
                            var q = s.PacingWindow.ToArray();
                            string pacing = "[Silent]";
                            if (q.Length > 1) {
                                double windowMs = (q[q.Length - 1].Time - q[0].Time).TotalMilliseconds;
                                if (windowMs > 0) {
                                    double ratio = q.Sum(x => x.Ms) / windowMs;
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
                    m_log.Info(sb.ToString());
                }
            );
        }

        #endregion

        #region WebRTC / SIP Signaling Handlers

        private string HandleProvisionVoiceAccountRequest(string request, UUID agentID, UUID regionID) {
            if (string.IsNullOrEmpty(request)) return "";
            OSD parsedOsd = OSDParser.DeserializeLLSDXml(request);
            if (!(parsedOsd is OSDMap requestMap)) return "";

            if (requestMap.ContainsKey("logout") && requestMap["logout"].AsBoolean()) {
                var s = System.Linq.Enumerable.FirstOrDefault(m_activeSessions.Values, x => x.AgentID == agentID);
                s?.Teardown?.Invoke();
                return "<llsd><undef /></llsd>";
            }

            if (!requestMap.ContainsKey("jsep")) {
                m_log.ErrorFormat("[OBSERVATORY]: HandleProvisionVoiceAccountRequest({0}, {1}) => !jsep", request, agentID);
                return "<llsd><undef /></llsd>";
            }
            OSDMap jsepMap = (OSDMap)requestMap["jsep"];
            string offerSdp = jsepMap["sdp"].AsString();
            string viewerSession = requestMap.ContainsKey("viewer_session") ? requestMap["viewer_session"].AsString() : UUID.Random().ToString();

            var pc = new SIPSorcery.Net.RTCPeerConnection(new SIPSorcery.Net.RTCConfiguration { X_UseRtpFeedbackProfile = true });

            var audioFormats = new System.Collections.Generic.List<SIPSorcery.Net.SDPAudioVideoMediaFormat> {
                new SIPSorcery.Net.SDPAudioVideoMediaFormat(SIPSorcery.Net.SDPMediaTypesEnum.audio, 111, "opus/48000/2", "minptime=10;useinbandfec=1"),
            };
            pc.addTrack(new SIPSorcery.Net.MediaStreamTrack(SIPSorcery.Net.SDPMediaTypesEnum.audio, false, audioFormats, SIPSorcery.Net.MediaStreamStatusEnum.SendRecv));

            // Register the human and the pipe into the Studio Ledger
            m_studioEngine.Switchboard.RegisterSession(agentID, viewerSession);

            // Fetch the newly created VoiceSession pipe so we can route packets to it
            VoiceSession thisStudioPipe = null;
            if (m_studioEngine.GlobalLedger.TryGetValue(agentID, out var agent)) {
                agent.Sessions.TryGetValue(viewerSession, out thisStudioPipe);
            }

            pc.ondatachannel += (dc) => {
                dc.onmessage += (dataChannel, protocol, data) => {
                    string json = System.Text.Encoding.UTF8.GetString(data);

                    // Route Data Channel JSON inward to the Studio Bouncer
                    if (thisStudioPipe != null) {
                        m_studioEngine.Switchboard.PrototypeCallback_OnDataChannelMessage(thisStudioPipe, json);
                    }
                };
            };

            pc.OnRtpPacketReceived += (System.Net.IPEndPoint remote, SIPSorcery.Net.SDPMediaTypesEnum media, SIPSorcery.Net.RTPPacket rtp) => {
                if (media != SIPSorcery.Net.SDPMediaTypesEnum.audio) return;

                // Route raw Opus frames inward to the Studio Bouncer
                if (thisStudioPipe != null) {
                    m_studioEngine.Switchboard.PrototypeCallback_OnRtpPacket(thisStudioPipe, rtp.Payload);
                }
            };
            
            // --- NEW: Hook into the RTCP Receiver Reports ---
            pc.OnReceiveReport += (re, media, compoundPacket) => {
                if (m_activeSessions.TryGetValue(viewerSession, out var tel)) {
                    System.Action<string, SIPSorcery.Net.ReceptionReportSample> addReport = (hint, report) => {
                        tel.PeakFractionLost = System.Math.Max(tel.PeakFractionLost, report.FractionLost);
                        tel.TotalPacketsLost = report.PacketsLost;
                        tel.LastJitter = report.Jitter;
                    };

                    // The compound packet can contain different RTCP packet types  
                    // Check if it contains a Receiver Report  
                    if (compoundPacket.ReceiverReport != null) {  
                        foreach (var report in compoundPacket.ReceiverReport.ReceptionReports) addReport("ReceiverReport", report);
                    }  
                    
                    if (compoundPacket.SenderReport != null) {  
                        foreach (var report in compoundPacket.SenderReport.ReceptionReports) addReport("SenderReport", report);
                    }  
                }
            };

            // --- NEW: Bind the Janitor to the underlying WebRTC State ---
            pc.onconnectionstatechange += (state) => {
                if (state == SIPSorcery.Net.RTCPeerConnectionState.closed || 
                    state == SIPSorcery.Net.RTCPeerConnectionState.failed ||
                    state == SIPSorcery.Net.RTCPeerConnectionState.disconnected) {
                    m_log.Info($"[OBSERVATORY]: PC State changed to {state} for {viewerSession}. Tearing down.");
                    if (m_activeSessions.TryGetValue(viewerSession, out var tel)) {
                        tel.Teardown?.Invoke();
                    }
                }
            };

            var telemetry = new ObservatoryTelemetry {
                ViewerSession = viewerSession,
                AgentID = agentID,
                PeerConnection = pc,
                Teardown = () => {
                    try { pc.Close("Normal Teardown"); } catch { }
                    m_activeSessions.Remove(viewerSession);
                    if (agent != null) agent.Sessions.TryRemove(viewerSession, out _);
                }
            };
            m_activeSessions[viewerSession] = telemetry;

            var result = System.Threading.Tasks.Task.Run(async () => {
                try {
                    m_log.Info("[OBSERVATORY]: Attempting to set remote description...");

                    var setResult = pc.setRemoteDescription(new SIPSorcery.Net.RTCSessionDescriptionInit { type = SIPSorcery.Net.RTCSdpType.offer, sdp = offerSdp });
                    if (setResult != SIPSorcery.Net.SetDescriptionResultEnum.OK) {
                        m_log.ErrorFormat("[OBSERVATORY]: SIPSorcery rejected the SDP Offer! Reason: {0}", setResult);
                        return null;
                    }

                    pc.IceRole = SIPSorcery.Net.IceRolesEnum.passive;

                    m_log.Info("[OBSERVATORY]: Creating answer...");
                    var answer = pc.createAnswer(null);

                    m_log.Info("[OBSERVATORY]: Setting local description...");
                    await pc.setLocalDescription(answer).ConfigureAwait(false);

                    m_log.Info("[OBSERVATORY]: Waiting for SIPSorcery ICE gathering to bundle candidates...");
                    int timeout = 3000;
                    while (pc.iceGatheringState != SIPSorcery.Net.RTCIceGatheringState.complete && timeout > 0) {
                        await System.Threading.Tasks.Task.Delay(50).ConfigureAwait(false);
                        timeout -= 50;
                    }
                    m_log.InfoFormat("[OBSERVATORY]: SDP Generation Complete. Final ICE gathering state: {0}", pc.iceGatheringState);
                    EncounterLogger.Log("Simulant", "VOICE", "SDP_COMPLETE", $"SDP Generation Complete for {viewerSession}");
                    return pc.currentLocalDescription.sdp.ToString();
                } catch (System.Exception ex) {
                    m_log.ErrorFormat("[OBSERVATORY]: SIPSorcery SDP Exception: {0}\n{1}", ex.Message, ex.StackTrace);
                    return null;
                }
            }).GetAwaiter().GetResult();

            if (string.IsNullOrEmpty(result)) return "<llsd><undef /></llsd>";

            OSDMap response = new OSDMap {
                ["voice_server_type"] = "webrtc",
                ["viewer_session"] = viewerSession,
                ["session_handle"] = viewerSession,
                ["channel_uri"] = regionID.ToString(),// "http://127.0.0.1:8000/mock_signaling",
                ["channel_credentials"] = "mock_token",
                ["jsep"] = new OSDMap { ["type"] = "answer", ["sdp"] = result }
            };

            return OSDParser.SerializeLLSDXmlString(response);
        }

        private string HandleVoiceSignalingRequest(string request, UUID agentID, UUID regionID) {
            if (string.IsNullOrEmpty(request)) return "";
            try {
                OSD parsedOsd = OSDParser.DeserializeLLSDXml(request);
                if (parsedOsd is OSDMap requestMap) {
                    string viewerSession = requestMap.ContainsKey("viewer_session") ? requestMap["viewer_session"].AsString() : "UNKNOWN";
                    if (m_activeSessions.TryGetValue(viewerSession, out ObservatoryTelemetry tel)) {

                        System.Action<OSDMap> InjectCandidate = (candMap) => {
                            if (!candMap.ContainsKey("candidate")) return;
                            string candStr = candMap["candidate"].AsString();
                            if (string.IsNullOrEmpty(candStr)) return;
                            if (!candStr.StartsWith("candidate:", System.StringComparison.OrdinalIgnoreCase)) candStr = "candidate:" + candStr;

                            try {
                                tel.PeerConnection.addIceCandidate(new SIPSorcery.Net.RTCIceCandidateInit {
                                    candidate = candStr,
                                    sdpMid = candMap.ContainsKey("sdpMid") ? candMap["sdpMid"].AsString() : "0",
                                    sdpMLineIndex = (ushort)(candMap.ContainsKey("sdpMLineIndex") ? candMap["sdpMLineIndex"].AsInteger() : 0)
                                });
                            } catch { }
                        };

                        if (requestMap.ContainsKey("candidate") && requestMap["candidate"] is OSDMap singleCandMap) InjectCandidate(singleCandMap);
                        if (requestMap.ContainsKey("candidates") && requestMap["candidates"] is OSDArray candArray) {
                            foreach (OSD candOsd in candArray) if (candOsd is OSDMap candMap) InjectCandidate(candMap);
                        }
                    }
                }
            } catch { }

            return OSDParser.SerializeLLSDXmlString(new OSDMap { ["voice_server_type"] = "webrtc" });
        }

        #endregion
    }
}

namespace humbletim {
    using System;
    using Microsoft.Extensions.Logging;
    using System.Reflection;

    public class SipsorceryLogger : ILogger {
        private static readonly log4net.ILog m_log = log4net.LogManager.GetLogger(System.Reflection.MethodBase.GetCurrentMethod().DeclaringType);
        public IDisposable BeginScope<TState>(TState state) => null;
        public bool IsEnabled(LogLevel logLevel) => true;
        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, System.Exception exception, System.Func<TState, Exception, string> formatter) {
            m_log.InfoFormat("[SIPSORCERY_ENGINE] {0}: {1}", logLevel, formatter(state, exception));
            if (exception != null) m_log.ErrorFormat("[SIPSORCERY_ENGINE_EX] {0}", exception.ToString().Replace("\r\n", "\\r\\n"));
        }
    }

    public class SipsorceryLoggerFactory : ILoggerFactory {
        public void AddProvider(ILoggerProvider provider) { }
        public ILogger CreateLogger(string categoryName) => new SipsorceryLogger();
        public void Dispose() { }
    }

    public class MindBinder {
        private static readonly log4net.ILog m_log = log4net.LogManager.GetLogger(MethodBase.GetCurrentMethod().DeclaringType);
        private System.Collections.Generic.List<Action> _unsubscribers = new();

        public void Bind<T>(object src, string q, Action<T> h) => bindInternal(src, q, h);
        public void Bind<T1, T2>(object src, string q, Action<T1, T2> h) => bindInternal(src, q, h);
        public void Bind<T1, T2, T3>(object src, string q, Action<T1, T2, T3> h) => bindInternal(src, q, h);

        public void UnbindAll() {
            _unsubscribers.ForEach(u => u());
            _unsubscribers.Clear();
        }

        private MemberInfo FindBindable(object t, string q) {
            if (t == null) return null;
            var flags = BindingFlags.Instance | BindingFlags.Public;
            return (MemberInfo)System.Linq.Enumerable.FirstOrDefault(t.GetType().GetEvents(flags), e => e.Name.IndexOf(q, StringComparison.OrdinalIgnoreCase) >= 0)
                ?? System.Linq.Enumerable.FirstOrDefault(t.GetType().GetFields(flags), f => typeof(Delegate).IsAssignableFrom(f.FieldType) && f.Name.IndexOf(q, StringComparison.OrdinalIgnoreCase) >= 0);
        }

        private void bindInternal(object baseSrc, string query, Delegate handler) {
            object src = baseSrc;
            MemberInfo target = null;

            if (baseSrc.GetType().GetProperty("EventManager", BindingFlags.Instance | BindingFlags.Public) is PropertyInfo em) {
                var emInst = em.GetValue(baseSrc);
                target = FindBindable(emInst, query);
                if (target != null) src = emInst;
            }

            if (target == null) target = FindBindable(baseSrc, query);

            if (target == null) {
                m_log.Error($"[MAGIC BINDER]: Failed to find '{query}' on {baseSrc.GetType().Name}.");
                return;
            }

            try {
                if (target is System.Reflection.EventInfo ev) {
                    var d = Delegate.CreateDelegate(ev.EventHandlerType, handler.Target, handler.Method);
                    ev.AddEventHandler(src, d);
                    _unsubscribers.Add(() => ev.RemoveEventHandler(src, d));
                } else if (target is FieldInfo fi) {
                    var d = Delegate.CreateDelegate(fi.FieldType, handler.Target, handler.Method);
                    fi.SetValue(src, Delegate.Combine((Delegate)fi.GetValue(src), d));
                    _unsubscribers.Add(() => fi.SetValue(src, Delegate.Remove((Delegate)fi.GetValue(src), d)));
                }
            } catch (Exception ex) {
                m_log.Error($"[MAGIC BINDER]: Mismatch for '{query}' on {src.GetType().Name}.", ex);
            }
        }
    }
}