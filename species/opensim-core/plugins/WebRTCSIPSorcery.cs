/*
$. species/opensim-core/plugins/oscsc.bash$ oscsc species/opensim-core/plugins/WebRTCSIPSorcery.cs vivarium/opensim-core-0.9.3/bin/WebRTCSIPSorcery.dll \
     -r:SIPSorcery.dll -r:SIPSorceryMedia.Abstractions.dll -r:Microsoft.Extensions.Logging.Abstractions.dll  \
     -r:Concentus.dll -r:NAudio.Core.dll
*/

using System;
using System.Collections.Generic;
using System.Linq;
using System.Reflection;

[assembly: Mono.Addins.Addin("WebRTCSIPSorcery", "1.0")]
[assembly: Mono.Addins.AddinDependency("OpenSim", OpenSim.VersionInfo.VersionNumber)]
[assembly: Mono.Addins.AddinDependency("OpenSim.Region.Framework", OpenSim.VersionInfo.VersionNumber)]

namespace Humbletim.Observatory {
    using UUID = OpenMetaverse.UUID;
    using OpenMetaverse.StructuredData;

    public static class EncounterLogger
    {
        public static void Log(string side, string system, string signal, string payload = "")
        {
            string at = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ");
            if (!string.IsNullOrEmpty(payload)) payload = payload.Replace("\"", "\\\"");
            string ua_part = "\"ua\": \"species/opensim-core/0.9.3\", ";
            string fragment = $"{{ \"at\": \"{at}\", {ua_part}\"via\": \"{side}\", \"sys\": \"{system}\", \"sig\": \"{signal}\", \"val\": \"{payload}\" }}";
            Console.WriteLine(fragment);
        }
    }

    #region Telemetry & State Models

    public class ObservatoryTelemetry {
        public bool selfTalking = false;
        public int selfTalk = 0;
        public string ViewerSession;
        public SIPSorcery.Net.RTCPeerConnection PeerConnection;
        public long AudioPacketsReceived = 0;
        public long TotalAudioBytes = 0;
        public long ActiveVoiceFrames = 0;
        public long SilenceFrames = 0;
        public int LastPayloadSize = 0;
        public DateTime LastAudioActivity = DateTime.MinValue;
        public ushort LastRtpSequence = 0;

        // NAudio's bridge between the Network (Push) and the Mixer (Pull)
        public NAudio.Wave.BufferedWaveProvider NetworkInbox;
        // A dedicated N-1 mixer specifically for this agent
        public NAudio.Wave.SampleProviders.MixingSampleProvider PersonalMixer;
        // Stored so the global pump can encode the output
        public Concentus.IOpusEncoder OutboundEncoder;

        public UUID AgentID;
        public int CurrentPowerLevel = 0;
        public bool IsTalking = false;

        // Store the exact NAudio wrapper reference so we can cleanly remove it later
        public NAudio.Wave.ISampleProvider OutboundSampleProvider;
        public Action Teardown;
    }

    #endregion

    [Mono.Addins.Extension(Path = "/OpenSim/RegionModules", NodeName = "RegionModule", Id = "WebRTCSIPSorcery")]
    [Mono.Addins.Extension(Path = "/OpenSim/Startup", Id = "WebRTCSIPSorcery", NodeName = "Plugin")]
    public class WebRTCSIPSorcery : OpenSim.IApplicationPlugin, OpenSim.Region.Framework.Interfaces.ISharedRegionModule {
        private static readonly log4net.ILog m_log = log4net.LogManager.GetLogger(System.Reflection.MethodBase.GetCurrentMethod().DeclaringType);

        // Static dictionary to bridge the OpenSim plugin instances
        private static Dictionary<string, ObservatoryTelemetry> m_activeSessions = new();
        private static List<OpenSim.Region.Framework.Scenes.Scene> m_scenes = new();
        private Dictionary<UUID, humbletim.MindBinder> m_binders = new();
        public static Nini.Config.IConfig m_cfg;

        #region IApplicationPlugin Lifecycle

        public string Version => "0.0.1";
        public string Name => "WebRTCSIPSorcery";

        public void Initialise() {
            m_log.Info("[OBSERVATORY]: Initialise() called");
        }

        public void Initialise(OpenSim.OpenSimBase openSim) {
            m_log.Info("[OBSERVATORY]: Initialise(OpenSimBase) called");
            var scene = openSim.SceneManager.CurrentOrFirstScene;
            if (scene != null) {
                m_log.Error("[OBSERVATORY]: scenes available");
                OnRegionsReady(openSim.SceneManager);
            } else {
                m_log.Error("[OBSERVATORY]: No scenes available");
                openSim.SceneManager.OnRegionsReadyStatusChange += OnRegionsReady;
            }
        }

        public void Dispose() { }

        #endregion

        #region ISharedRegionModule Lifecycle

        public Type ReplaceableInterface => null;
        public bool IsSharedModule => true;

        public void Initialise(Nini.Config.IConfigSource source) {
            m_cfg = source.Configs["WebRTCSIPSorcery"];
            m_log.Info($"[OBSERVATORY]: WebRTCSIPSorcery Mock Initialising - No config needed. {m_cfg}");
            if (m_cfg != null && m_cfg.GetBoolean("Verbose", false)) {
                SIPSorcery.LogFactory.Set(new humbletim.SipsorceryLoggerFactory());
            }
        }

        public void AddRegion(OpenSim.Region.Framework.Scenes.Scene scene) {
            var binder = new humbletim.MindBinder();
            lock (m_binders) m_binders[scene.RegionInfo.RegionID] = binder;
            m_scenes.Add(scene);

            binder.Bind(scene, "OnParcelPropertiesUpdate", (OpenSim.Framework.LandUpdateArgs args, int localID, OpenSim.Framework.IClientAPI remoteClient) => {
                m_log.InfoFormat($"[VOICELOG]: Parcel {localID} set to use {0}", (args.ParcelFlags & (uint)OpenMetaverse.ParcelFlags.UseEstateVoiceChan) != 0 ? "ESTATE" : "PARCEL");
            });

            binder.Bind(scene, "OnMakeRootAgent", (OpenSim.Region.Framework.Scenes.ScenePresence sp) => {
                m_log.Info($"[VOICE]: Provisioning endpoint for {sp.Name} ({sp.UUID})");
            });

            binder.Bind(scene, "OnMakeChildAgent", (OpenSim.Region.Framework.Scenes.ScenePresence sp) => {
                m_log.Info($"[VOICE]: Halting local audio mix for {sp.Name} (Departed)");
            });

            binder.Bind(scene, "OnClientClosed", (UUID agentId, OpenSim.Region.Framework.Scenes.Scene s) => {
                m_log.Info($"[VOICE]: Destroying endpoint for {agentId}");
                var session = m_activeSessions.Values.FirstOrDefault(x => x.AgentID == agentId);
                session?.Teardown?.Invoke();
            });

            binder.Bind(scene, "OnAvatarEnteringNewParcel", (OpenSim.Region.Framework.Scenes.ScenePresence sp, int localLandID, UUID regionID) => {
                OpenSim.Framework.ILandObject parcel = scene.LandChannel.GetLandObject(localLandID);
                m_log.Info($"[VOICE]: {sp.Name} entered parcel '{parcel.LandData.Name}'");
            });

            var imModule = scene.RequestModuleInterface<OpenSim.Region.Framework.Interfaces.IMessageTransferModule>();
            if (imModule != null) {
                binder.Bind(imModule, "OnUndeliveredMessage", (OpenSim.Framework.GridInstantMessage msg) => {
                    if (msg.dialog == 43) {
                        m_log.Info($"[VOICE]: Intercepted direct call from {msg.fromAgentID} to {msg.toAgentID}");
                    }
                });
            }

            binder.Bind(scene, "OnRegisterCaps", (UUID agentID, OpenSim.Framework.Capabilities.Caps caps) => {
                string pvarUrl = "/CAPS/" + UUID.Random();
                string vsrUrl = "/CAPS/" + UUID.Random();

                caps.RegisterHandler("ProvisionVoiceAccountRequest",
                    new OpenSim.Framework.Servers.HttpServer.RestStreamHandler("POST", pvarUrl,
                        (request, path, param, httpRequest, httpResponse) =>
                            HandleProvisionVoiceAccountRequest(request, agentID),
                        "ProvisionVoiceAccountRequest", agentID.ToString()));

                caps.RegisterHandler("VoiceSignalingRequest",
                    new OpenSim.Framework.Servers.HttpServer.RestStreamHandler("POST", vsrUrl,
                        (request, path, param, httpRequest, httpResponse) =>
                            HandleVoiceSignalingRequest(request, agentID),
                        "VoiceSignalingRequest", agentID.ToString()));

                m_log.InfoFormat("[OBSERVATORY]: Registered PVAR ({0}) and VSR ({1}) for {2}", pvarUrl, vsrUrl, agentID);
                EncounterLogger.Log("Simulant", "VOICE", "PROVISION_CAP", $"Registered PVAR and VSR for {agentID}");
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
            if (featuresModule == null) {
                m_log.Warn("[OBSERVATORY]: ISimulatorFeaturesModule not found on scene.");
            } else {
                featuresModule.AddFeature("VoiceServerType", OSD.FromString("webrtc"));
                m_log.Info("[OBSERVATORY]: Advertised VoiceServerType='webrtc' via ISimulatorFeaturesModule");
            }
        }

        public void PostInitialise() { }
        public void Close() { }

        #endregion

        #region Console Commands & VAD

        private void OnRegionsReady(OpenSim.Region.Framework.Scenes.SceneManager sceneManager) {
            if (!sceneManager.AllRegionsReady) {
                m_log.Info("[OBSERVATORY]: Regions are NOT ready yet, deferring till ready state change");
                return;
            }
            m_log.Info("[OBSERVATORY]: scenes available! adding commands");
            registerCommands();
        }

        private void registerCommands() {
            OpenSim.Framework.MainConsole.Instance.Commands.AddCommand(
                "humbletim", false, "sorcery", "sorcery", "Dump WebRTC Naturalist Observatory Telemetry",
                (module, cmdparams) =>  {
                    m_log.Info("\n=== WebRTC Observatory Telemetry ===");
                    m_log.Info(OSDParser.SerializeJsonString(getVADMap(), true));
                    if (m_activeSessions.Count == 0) {
                        m_log.Info("  No active WebRTC sessions.");
                    } else {
                        foreach (var kvp in m_activeSessions) {
                            var tel = kvp.Value;
                            var pc = tel.PeerConnection;

                            double timeSinceLastPacket = (DateTime.Now - tel.LastAudioActivity).TotalSeconds;
                            string activeStatus = (tel.AudioPacketsReceived > 0 && timeSinceLastPacket < 2.0) ? "ACTIVE" : "SILENT";

                            m_log.InfoFormat("Session: {0}", tel.ViewerSession);
                            m_log.InfoFormat("  State:      Peer [{0}] | ICE [{1}]", pc.connectionState, pc.iceConnectionState);
                            m_log.InfoFormat("  Mic Status: {0} (Power: {1}; v:{2}; st:{3}, sting:{4})", activeStatus, tel.CurrentPowerLevel, tel.IsTalking, tel.selfTalk, tel.selfTalking);
                            m_log.InfoFormat("  Data Rx:    {0} pkts ({1} bytes) [Voice: {2} | Silence: {3}]",
                                tel.AudioPacketsReceived, tel.TotalAudioBytes, tel.ActiveVoiceFrames, tel.SilenceFrames);
                            m_log.InfoFormat("  Last Size:  {0} bytes {0:F2} seconds ago", tel.LastPayloadSize, tel.LastAudioActivity != DateTime.MinValue ? timeSinceLastPacket : -1);
                        }
                    }
                    m_log.Info("====================================\n");
                }
            );
        }

        private static OSDMap getVADMap() {
            var map = new OSDMap();
            lock (m_activeSessions) {
                foreach (var s in m_activeSessions.Values) {
                    var stat = new OSDMap {
                        ["p"] = s.CurrentPowerLevel,
                        ["v"] = s.IsTalking,
                    };
                    map[s.AgentID.ToString()] = stat;
                }
            }
            return map;
        }

        private static int voices() {
            int voices = 0;
            lock (m_activeSessions) {
                foreach (var s in m_activeSessions.Values) {
                    if (s.IsTalking) voices++;
                }
            }
            return voices;
        }

        #endregion

        #region Media & Audio Pipeline

        private static bool _pumpStarted = StartPump();

        private static bool StartPump() {
            var t = new System.Threading.Thread(McuLoop) {
                IsBackground = true,
                Priority = System.Threading.ThreadPriority.Highest, // Bypassing ThreadPool delays
                Name = "WebRTC_MCU_Pump"
            };
            t.Start();
            return true;
        }

        private static void McuLoop() {
            m_log.Info("[OBSERVATORY]: Master MCU Audio Pump Thread started (Precision Clock).");

            float[] mixFloatBuffer = new float[960 * 2]; // 20ms stereo float
            short[] mixShortBuffer = new short[960 * 2]; // 20ms stereo short
            byte[] opusOutBuffer = new byte[1500];

            int tickCount = 0;
            var sw = System.Diagnostics.Stopwatch.StartNew();
            double nextTick = sw.Elapsed.TotalMilliseconds;

            Action __decayStats = () => {
                lock (m_activeSessions) {
                    foreach (var s in m_activeSessions.Values) {
                        s.CurrentPowerLevel = (int)(s.CurrentPowerLevel * 0.5f);
                        if (s.CurrentPowerLevel <= 2) {
                            s.CurrentPowerLevel = 0;
                            s.IsTalking = false;
                        }
                    }
                }
            };
            while (true) {
                nextTick += 20.0;

                // --- PRECISION GOVERNOR ---
                // Wait for the exact microsecond. No bursting allowed.
                double delay = nextTick - sw.Elapsed.TotalMilliseconds;
                if (delay > 2.0) {
                    System.Threading.Thread.Sleep((int)(delay - 1.0)); // Yield CPU politely
                }
                while (sw.Elapsed.TotalMilliseconds < nextTick) {
                    System.Threading.Thread.SpinWait(10); // Precise micro-wait
                }

                // --- ANTI-BURST TRIPWIRE ---
                // If the OS heavily starved us, do NOT rapidly loop to catch up.
                // Skip the lost time and resync the clock.
                if (sw.Elapsed.TotalMilliseconds > nextTick + 50) {
                    m_log.WarnFormat("[OBS_CHOP_TEST]: ⚠️ OS thread starvation! Skipped {0}ms. Preventing catch-up burst.", Math.Round(sw.Elapsed.TotalMilliseconds - nextTick));
                    nextTick = sw.Elapsed.TotalMilliseconds;
                }

                tickCount++;
                bool broadcastVAD = (tickCount % 5 == 0);
                string vadJsonPayload = null;

                lock (m_activeSessions) {
                    if (broadcastVAD && m_activeSessions.Count > 0) {
                        vadJsonPayload = OSDParser.SerializeJsonString(getVADMap());
                        // __decayStats();
                    }
                    bool isSolo = !(m_activeSessions.Count > 1);

                    foreach (var session in m_activeSessions.Values) {
                        if (session.PeerConnection.connectionState != SIPSorcery.Net.RTCPeerConnectionState.connected) continue;
                        if (!isSolo) session.selfTalk = -1;
                        if (session.selfTalk == +1 && !session.selfTalking) {
                            m_log.InfoFormat("session.selfTalk == +1 || session.PersonalMixer.AddMixerInput(session.OutboundSampleProvider) {0}", session.ViewerSession);
                            session.PersonalMixer.AddMixerInput(session.OutboundSampleProvider);
                            session.selfTalking = true;
                        }
                        if (session.selfTalk == -1 && session.selfTalking) {
                            m_log.InfoFormat("session.selfTalk == -1 || session.PersonalMixer.RemoveMixerInput(session.OutboundSampleProvider) {0}", session.ViewerSession);
                            session.PersonalMixer.RemoveMixerInput(session.OutboundSampleProvider);
                            session.selfTalking = false;
                        }

                        int floatsRead = session.PersonalMixer.Read(mixFloatBuffer, 0, mixFloatBuffer.Length);
                        if (floatsRead > 0) {
                            for (int i = 0; i < floatsRead; i++) {
                                mixShortBuffer[i] = (short)Math.Clamp(mixFloatBuffer[i] * short.MaxValue, short.MinValue, short.MaxValue);
                            }

                            int encodedBytes = session.OutboundEncoder.Encode(mixShortBuffer, floatsRead / 2, opusOutBuffer, opusOutBuffer.Length);
                            byte[] finalPayload = new byte[encodedBytes];
                            Array.Copy(opusOutBuffer, finalPayload, encodedBytes);

                            try {
                                session.PeerConnection.SendAudio((uint)(floatsRead / 2), finalPayload);

                                if (broadcastVAD && vadJsonPayload != null) {
                                    var dc = session.PeerConnection.DataChannels.FirstOrDefault();
                                    if (dc != null && dc.readyState == SIPSorcery.Net.RTCDataChannelState.open) {
                                        dc.send(vadJsonPayload);
                                    }
                                }
                            } catch { /* Swallow discrete send failures */ }
                        }
                    }
                }
            }
        }

        private static void bindSession(ObservatoryTelemetry telemetry) {
            var pc = telemetry.PeerConnection;

            telemetry.OutboundEncoder = Concentus.OpusCodecFactory.CreateEncoder(48000, 2, Concentus.Enums.OpusApplication.OPUS_APPLICATION_VOIP);
            var waveFormat = NAudio.Wave.WaveFormat.CreateIeeeFloatWaveFormat(48000, 2);
            var pcm16Format = new NAudio.Wave.WaveFormat(48000, 16, 2);

            telemetry.NetworkInbox = new NAudio.Wave.BufferedWaveProvider(pcm16Format) {
                BufferDuration = TimeSpan.FromMilliseconds(1000),
                DiscardOnBufferOverflow = true
            };

            // PRECISE INITIAL CUSHION: Pre-fill exactly 60ms of digital silence to absorb startup jitter
            byte[] silencePadding = new byte[3840 * 3];
            telemetry.NetworkInbox.AddSamples(silencePadding, 0, silencePadding.Length);

            telemetry.PersonalMixer = new NAudio.Wave.SampleProviders.MixingSampleProvider(waveFormat) {
                ReadFully = true
            };

            // Reverting back to direct pipeline, JitterGate removed.
            telemetry.OutboundSampleProvider = NAudio.Wave.WaveExtensionMethods.ToSampleProvider(telemetry.NetworkInbox);

            Action<ObservatoryTelemetry> crossWirePeers = (tel) => {
                lock (m_activeSessions) {
                    foreach (var existingSession in m_activeSessions.Values) {
                        if (existingSession.ViewerSession == tel.ViewerSession) {
                            continue;
                        }
                        existingSession.PersonalMixer.AddMixerInput(tel.OutboundSampleProvider);
                        tel.PersonalMixer.AddMixerInput(existingSession.OutboundSampleProvider);
                    }
                }
            };

            telemetry.Teardown = () => {
                m_log.InfoFormat("[OBSERVATORY]: Executing Clean Teardown for {0}", telemetry.ViewerSession);
                try { telemetry.PeerConnection.Close("Normal Teardown"); } catch { }

                lock (m_activeSessions) {
                    foreach (var other in m_activeSessions.Values) {
                        other.PersonalMixer.RemoveMixerInput(telemetry.OutboundSampleProvider);
                    }
                    m_activeSessions.Remove(telemetry.ViewerSession);
                    broadcastAllExcept(new OSDMap{
                        [telemetry.ViewerSession] = new OSDMap{
                            ["l"] = new OSDMap{ ["p"] = true },
                        }
                    }, null);
                    if (m_activeSessions.Count == 1) {
                        var session = m_activeSessions.Values.FirstOrDefault();
                        m_log.InfoFormat("highlandered -- selfTalk +1 {0}", session.ViewerSession);
                        session.selfTalk = +1;
                    } else {
                        foreach (var session in m_activeSessions.Values) {
                            session.selfTalk = -1;
                        }
                    }
                    // if (existingSession.echo == +1) {

                }
            };

            crossWirePeers(telemetry);

            var opusEncoder = Concentus.OpusCodecFactory.CreateEncoder(48000, 2, Concentus.Enums.OpusApplication.OPUS_APPLICATION_VOIP);
            var opusDecoder = Concentus.OpusCodecFactory.CreateDecoder(48000, 2);

            pc.OnRtpPacketReceived += (System.Net.IPEndPoint remote, SIPSorcery.Net.SDPMediaTypesEnum media, SIPSorcery.Net.RTPPacket rtp) => {
                if (media != SIPSorcery.Net.SDPMediaTypesEnum.audio) return;

                telemetry.AudioPacketsReceived++;
                telemetry.TotalAudioBytes += rtp.Payload.Length;
                telemetry.LastPayloadSize = rtp.Payload.Length;
                telemetry.LastAudioActivity = DateTime.Now;

                if (rtp.Payload.Length > 10) telemetry.ActiveVoiceFrames++;
                else telemetry.SilenceFrames++;

                int frameSizePerChannel = Concentus.Structs.OpusPacketInfo.GetNumSamples(rtp.Payload.AsSpan(0, rtp.Payload.Length), ((Concentus.Structs.OpusDecoder)opusDecoder).SampleRate);

                short[] pcmBuffer = new short[frameSizePerChannel * 2];
                int decodedSamplesPerChannel = opusDecoder.Decode(rtp.Payload, pcmBuffer, frameSizePerChannel, false);

                if (m_activeSessions.Count == 1) {
                    humbletim.Funsies.panForFunsies(ref pcmBuffer);
                }

                float rms = humbletim.Audio.calculateRMS(ref pcmBuffer);
                telemetry.CurrentPowerLevel = (int)Math.Clamp(rms * 128, 0, 127);
                telemetry.IsTalking = telemetry.CurrentPowerLevel > 5;

                byte[] byteBuffer = new byte[pcmBuffer.Length * 2];
                Buffer.BlockCopy(pcmBuffer, 0, byteBuffer, 0, byteBuffer.Length);

                telemetry.NetworkInbox.AddSamples(byteBuffer, 0, byteBuffer.Length);
            };
        }

        #endregion

        #region WebRTC / SIP Signaling Handlers

        static Action<OSD, string> broadcastAllExcept = (vad, vs) => {
            string vadJsonPayload = OSDParser.SerializeJsonString(vad);
            if (vs == null) m_log.InfoFormat("broadcastAllExcept({0})", vadJsonPayload);
            lock (m_activeSessions) {
                foreach (var session in m_activeSessions.Values) {
                    if (session.PeerConnection.connectionState != SIPSorcery.Net.RTCPeerConnectionState.connected) continue;
                    var dc = session.PeerConnection.DataChannels.FirstOrDefault();
                    if (dc != null && dc.readyState == SIPSorcery.Net.RTCDataChannelState.open) {
                        try { dc.send(vadJsonPayload); } catch { }
                    }
                }
            }
        };


        private string HandleProvisionVoiceAccountRequest(string request, UUID agentID) {
            m_log.InfoFormat("[OBSERVATORY]: Trapped ProvisionVoiceAccountRequest from {0}", agentID);
            m_log.InfoFormat("[OBSERVATORY]: ProvisionVoiceAccountRequest Payload Length: {0}", request?.Length ?? 0);
            EncounterLogger.Log("Simulant", "VOICE", "PROVISION_REQUEST", $"Trapped ProvisionVoiceAccountRequest from {agentID}");

            if (string.IsNullOrEmpty(request)) {
                m_log.Error("[OBSERVATORY]: ABORT - Request payload is empty!");
                return "";
            }

            OSD parsedOsd = null;
            try { parsedOsd = OSDParser.DeserializeLLSDXml(request); }
            catch (Exception ex) { m_log.ErrorFormat("[OBSERVATORY]: XML Parse Exception: {0}", ex.Message); }

            if (parsedOsd == null || !(parsedOsd is OSDMap)) {
                m_log.ErrorFormat("[OBSERVATORY]: parsedOsd Payload null or not OSDMap: {0}", request);
                return "";
            }

            OSDMap requestMap = (OSDMap)parsedOsd;
            m_log.InfoFormat("[OBSERVATORY]: Raw Request: {0}", OSDParser.SerializeJsonString(requestMap));

            if (requestMap.TryGetValue("voice_server_type", out OSD vst)) {
                if (vst.AsString().ToLower() != "webrtc") {
                    m_log.InfoFormat("[OBSERVATORY]: Discarding legacy {0} request.", vst.AsString());
                    return "<llsd><undef /></llsd>";
                }
            }

            if (requestMap.ContainsKey("logout") && requestMap["logout"].AsBoolean()) {
                m_log.Info("[OBSERVATORY]: Viewer requested WebRTC logout. Closing session.");
                var session = m_activeSessions.Values.FirstOrDefault(x => x.AgentID == agentID);
                session?.Teardown?.Invoke();
                return "<llsd><undef /></llsd>";
            }

            if (!requestMap.ContainsKey("jsep") || !(requestMap["jsep"] is OSDMap)) {
                m_log.Error("[OBSERVATORY]: ABORT - Payload missing 'jsep' dictionary!");
                return "";
            }

            OSDMap jsepMap = (OSDMap)requestMap["jsep"];
            string offerSdp = jsepMap["sdp"].AsString();
            string viewerSession = requestMap.ContainsKey("viewer_session") && !string.IsNullOrEmpty(requestMap["viewer_session"].AsString())
                ? requestMap["viewer_session"].AsString()
                : UUID.Random().ToString();

            m_log.Info("[OBSERVATORY]: Successfully parsed SDP Offer!");

            var pc = new SIPSorcery.Net.RTCPeerConnection(new SIPSorcery.Net.RTCConfiguration { X_UseRtpFeedbackProfile = true });

            var audioFormats = new List<SIPSorcery.Net.SDPAudioVideoMediaFormat> {
                new SIPSorcery.Net.SDPAudioVideoMediaFormat(SIPSorcery.Net.SDPMediaTypesEnum.audio, 111, "opus/48000/2", "minptime=10;useinbandfec=1"),
            };
            pc.addTrack(new SIPSorcery.Net.MediaStreamTrack(SIPSorcery.Net.SDPMediaTypesEnum.audio, false, audioFormats, SIPSorcery.Net.MediaStreamStatusEnum.SendRecv));

            pc.ondatachannel += (dc) => {
                m_log.InfoFormat("[OBSERVATORY]: SCTP Data Channel Opened! Label: {0}", dc.label);
                dc.onmessage += (dataChannel, protocol, data) => {
                    string json = System.Text.Encoding.UTF8.GetString(data);
                    m_log.InfoFormat("[OBSERVATORY]: DataChannel Message IN: {0}", json);
                    OSD parsedMsgOsd = OSDParser.DeserializeJson(json);
                    if (parsedMsgOsd is OSDMap msg) {
                        if (msg.ContainsKey("j")) {
                            m_log.Info("[OBSERVATORY]: !!!!! RELAYING JOIN !!!!!");
                            broadcastAllExcept(new OSDMap {  [agentID.ToString()] = msg }, viewerSession);
                        }
                    }
                };
            };

            // pc.onconnectionstatechange += (state) => m_log.InfoFormat("[OBSERVATORY]: [STATE] Peer Connection -> {0}", state);
            // pc.oniceconnectionstatechange += (state) => m_log.InfoFormat("[OBSERVATORY]: [STATE] ICE Connection -> {0}", state);
            // pc.onicegatheringstatechange += (state) => m_log.InfoFormat("[OBSERVATORY]: [STATE] ICE Gathering -> {0}", state);
            // pc.onsignalingstatechange += () => m_log.InfoFormat("[OBSERVATORY]: [STATE] Signaling -> {0}", pc.signalingState);

            var telemetry = new ObservatoryTelemetry {
                ViewerSession = viewerSession,
                AgentID = agentID,
                PeerConnection = pc,
                LastAudioActivity = DateTime.MinValue
            };

            m_log.InfoFormat("[OBSERVATORY]: m_activeSessions[{0}] = {1}", viewerSession, telemetry);
            if (m_activeSessions.Count == 1) {
                var session = m_activeSessions.Values.FirstOrDefault();
                m_log.InfoFormat("highlandered.. -- selfTalk +1 {0}", session.ViewerSession);
                session.selfTalk = +1;
            }

            m_activeSessions[viewerSession] = telemetry;
            bindSession(telemetry);

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
                } catch (Exception ex) {
                    m_log.ErrorFormat("[OBSERVATORY]: SIPSorcery SDP Exception: {0}\n{1}", ex.Message, ex.StackTrace);
                    return null;
                }
            }).GetAwaiter().GetResult();

            if (string.IsNullOrEmpty(result)) {
                m_log.Error("[OBSERVATORY]: Handshake failed. Returning undef to viewer.");
                return "<llsd><undef /></llsd>";
            }

            OSDMap response = new OSDMap {
                ["voice_server_type"] = "webrtc",
                ["viewer_session"] = viewerSession,
                ["session_handle"] = viewerSession,
                ["channel_uri"] = "http://127.0.0.1:8000/mock_signaling",
                ["channel_credentials"] = "mock_token",
                ["jsep"] = new OSDMap {
                    ["type"] = "answer",
                    ["sdp"] = result
                }
            };

            m_log.InfoFormat("[OBSERVATORY]: Raw ProvisionVoiceAccountRequest Response: {0}", OSDParser.SerializeJsonString(response));

            return OSDParser.SerializeLLSDXmlString(response);
        }

        private string HandleVoiceSignalingRequest(string request, UUID agentID) {
            m_log.InfoFormat("[OBSERVATORY]: Trapped VoiceSignalingRequest from {0} {1}", agentID, request);

            if (string.IsNullOrEmpty(request)) return "";

            try {
                OSD parsedOsd = OSDParser.DeserializeLLSDXml(request);
                if (parsedOsd is OSDMap requestMap) {
                    string viewerSession = requestMap.ContainsKey("viewer_session") ? requestMap["viewer_session"].AsString() : "UNKNOWN";
                    if (m_activeSessions.TryGetValue(viewerSession, out ObservatoryTelemetry tel)) {
                        var pc = tel.PeerConnection;
                        Action<OSDMap> InjectCandidate = (candMap) => {
                            if (!candMap.ContainsKey("candidate")) return;

                            string candStr = candMap["candidate"].AsString();
                            if (string.IsNullOrEmpty(candStr)) return;

                            if (!candStr.StartsWith("candidate:", StringComparison.OrdinalIgnoreCase)) {
                                m_log.WarnFormat("[OBSERVATORY]: [SANITIZER] Appended missing 'candidate:' prefix to -> {0}", candStr);
                                candStr = "candidate:" + candStr;
                            }

                            try  {
                                pc.addIceCandidate(new SIPSorcery.Net.RTCIceCandidateInit {
                                    candidate = candStr,
                                    sdpMid = candMap.ContainsKey("sdpMid") ? candMap["sdpMid"].AsString() : "0",
                                    sdpMLineIndex = (ushort)(candMap.ContainsKey("sdpMLineIndex") ? candMap["sdpMLineIndex"].AsInteger() : 0)
                                });
                            } catch (Exception ex) {
                                m_log.ErrorFormat("[OBSERVATORY]: SIPSorcery REJECTED Candidate '{0}'. Reason: {1}", candStr, ex.Message);
                            }
                        };

                        if (requestMap.ContainsKey("candidate") && requestMap["candidate"] is OSDMap singleCandMap) {
                            InjectCandidate(singleCandMap);
                        }

                        if (requestMap.ContainsKey("candidates") && requestMap["candidates"] is OSDArray candArray) {
                            int injected = 0;
                            foreach (OSD candOsd in candArray) {
                                if (candOsd is OSDMap candMap) {
                                    InjectCandidate(candMap);
                                    injected++;
                                }
                            }
                            m_log.InfoFormat("[OBSERVATORY]: Attempted injection of {0} ICE candidates into SIPSorcery for session {1}", injected, viewerSession);
                        }
                    } else {
                        m_log.WarnFormat("[OBSERVATORY]: Received ICE candidates for unknown session {0}", viewerSession);
                    }
                }
            } catch (Exception ex) {
                m_log.ErrorFormat("[OBSERVATORY]: VSR Parse Exception: {0}", ex.Message);
            }

            OSDMap response = new OSDMap { ["voice_server_type"] = "webrtc" };
            m_log.InfoFormat("[OBSERVATORY]: VoiceSignalingRequest // Raw Response: {0}", OSDParser.SerializeJsonString(response));
            return OSDParser.SerializeLLSDXmlString(response);
        }

        #endregion

    } // WebRTCSIPSorcery
} // namespace Humbletim.Observatory


namespace humbletim {
    using Microsoft.Extensions.Logging;

    #region External Helpers & Bindings

    public class SipsorceryLogger : ILogger {
        private static readonly log4net.ILog m_log = log4net.LogManager.GetLogger(System.Reflection.MethodBase.GetCurrentMethod().DeclaringType);
        public IDisposable BeginScope<TState>(TState state) => null;
        public bool IsEnabled(LogLevel logLevel) => true;
        public void Log<TState>(LogLevel logLevel, EventId eventId, TState state, Exception exception, Func<TState, Exception, string> formatter) {
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
        private List<Action> _unsubscribers = new List<Action>();

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
            return (MemberInfo)t.GetType().GetEvents(flags).FirstOrDefault(e => e.Name.IndexOf(q, StringComparison.OrdinalIgnoreCase) >= 0)
                ?? t.GetType().GetFields(flags).FirstOrDefault(f => typeof(Delegate).IsAssignableFrom(f.FieldType) && f.Name.IndexOf(q, StringComparison.OrdinalIgnoreCase) >= 0);
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
                if (target is EventInfo ev) {
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

    class Audio {
        public static float calculateRMS(ref short[] pcmBuffer) {
            float sumSq = 0;
            for (int i = 0; i < pcmBuffer.Length; i++) {
                float norm = pcmBuffer[i] / 32768f;
                sumSq += norm * norm;
            }
            return (float)Math.Sqrt(sumSq / pcmBuffer.Length);
        }
    }

    class Funsies {
        public static void panForFunsies(ref short[] pcmBuffer) {
            double timeSeconds = DateTime.UtcNow.TimeOfDay.TotalSeconds;
            float panPosition = (float)Math.Sin(timeSeconds * 3.0);

            double angle = (panPosition + 1.0) * Math.PI / 4.0;
            float leftVolume = (float)Math.Cos(angle);
            float rightVolume = (float)Math.Sin(angle);

            for (int i = 0; i < pcmBuffer.Length; i += 2) {
                float monoSample = (pcmBuffer[i] + pcmBuffer[i + 1]) / 2f;
                pcmBuffer[i] = (short)Math.Clamp(monoSample * leftVolume, short.MinValue, short.MaxValue);
                pcmBuffer[i+1] = (short)Math.Clamp(monoSample * rightVolume, short.MinValue, short.MaxValue);
            }
        }
    }

    #endregion
}