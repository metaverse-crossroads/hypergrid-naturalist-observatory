/*
$ . species/opensim-core/plugins/oscsc.bash
$ oscsc species/opensim-core/plugins/WebRTCSIPSorcery.cs vivarium/opensim-core-0.9.3/bin/WebRTCSIPSorcery.dll
*/

using System;
using System.Collections;
using System.Collections.Generic;
using System.Threading.Tasks;
using log4net;
using Nini.Config;
using Mono.Addins;

using OpenSim.Framework;
using OpenSim.Framework.Servers.HttpServer;
using OpenSim.Region.Framework.Interfaces;
using OpenSim.Region.Framework.Scenes;
using OpenSim;
using OpenMetaverse;
using OpenMetaverse.StructuredData;

using SIPSorcery.Net;
using SIPSorceryMedia.Abstractions;

[assembly: Addin("WebRTCSIPSorcery", "1.0")]
[assembly: AddinDependency("OpenSim", "0.0")]
[assembly: AddinDependency("OpenSim.Region.Framework", OpenSim.VersionInfo.VersionNumber)]

namespace Humbletim.Observatory
{
    [Extension(Path = "/OpenSim/RegionModules", NodeName = "RegionModule", Id = "WebRTCSIPSorcery")]
    [Extension(Path = "/OpenSim/Startup", Id = "WebRTCSIPSorcery", NodeName = "Plugin")]
    public class WebRTCSIPSorcery : ISharedRegionModule, IApplicationPlugin {
        // IApplicationPlugin
        public void Dispose() { }
        // public string Name => "HumbletimUsersPlugin";
        public string Version => "0.0.1";
        private void OnRegionsReady(SceneManager sceneManager) {
            if (!sceneManager.AllRegionsReady) {
                m_log.Error("[OBSERVATORY]: Regions are NO Tready");
                return;
            }
            m_log.Error("[OBSERVATORY]: scenes available! adding commands");
            MainConsole.Instance.Commands.AddCommand(
                "humbletim", false, "sorcery", "sorcery", "Exit immediately without shutdown",
                (module, cmdparams) => Environment.Exit(1) //(Environment.FailFast("Brutal exit requested")
            );
        }
        public void Initialise(OpenSimBase openSim)  {
            m_log.Info("[OBSERVATORY]: Initialise(OpenSimBase) called");
            Scene scene = openSim.SceneManager.CurrentOrFirstScene;
            if (scene != null) {
                m_log.Error("[OBSERVATORY]: scenes available");
                OnRegionsReady(openSim.SceneManager);
            } else {
                m_log.Error("[OBSERVATORY]: No scenes available");
                openSim.SceneManager.OnRegionsReadyStatusChange += OnRegionsReady;
            }
        }
        public void Initialise()  {
            m_log.Info("[OBSERVATORY]: Initialise() called");
        }

        // /IApplicationPlugin
  
        private static readonly ILog m_log = LogManager.GetLogger(System.Reflection.MethodBase.GetCurrentMethod().DeclaringType);
        private List<Scene> m_scenes = new List<Scene>();

        public string Name { get { return "WebRTCSIPSorcery"; } }
        public Type ReplaceableInterface { get { return null; } }
        public bool IsSharedModule { get { return true; } }

        public void Initialise(IConfigSource source) {
            m_log.Info("[OBSERVATORY]: WebRTCSIPSorcery Mock Initialising - No config needed.");
        }

        public void AddRegion(Scene scene) {
            m_scenes.Add(scene);
            
            // Hook into the Caps for ProvisionVoiceAccountRequest
            scene.EventManager.OnRegisterCaps += OnRegisterCaps;
        }

        public void RemoveRegion(Scene scene) {
            scene.EventManager.OnRegisterCaps -= OnRegisterCaps;
        }
        
        public void RegionLoaded(Scene scene) {
            // Advertise the WebRTC protocol identifier to connecting clients
            ISimulatorFeaturesModule featuresModule = scene.RequestModuleInterface<ISimulatorFeaturesModule>();
            
            if (featuresModule != null) {
                featuresModule.AddFeature("VoiceServerType", OSD.FromString("webrtc"));
                m_log.Info("[OBSERVATORY]: Advertised VoiceServerType='webrtc' via ISimulatorFeaturesModule");
            } else {
                m_log.Warn("[OBSERVATORY]: ISimulatorFeaturesModule not found on scene.");
            }
        }
        
        public void PostInitialise() { }
        public void Close() { }

        private void OnRegisterCaps(UUID agentID, OpenSim.Framework.Capabilities.Caps caps)
        {
            string capUrl = "/CAPS/" + UUID.Random();
            
            // Register our custom CAP handler
            caps.RegisterHandler("ProvisionVoiceAccountRequest",
                new RestStreamHandler("POST", capUrl,
                    (request, path, param, httpRequest, httpResponse) =>
                        HandleProvisionVoiceAccountRequest(request, agentID),
                    "ProvisionVoiceAccountRequest", agentID.ToString()));
        }

private string HandleProvisionVoiceAccountRequest(string request, UUID agentID)
        {
            m_log.InfoFormat("[OBSERVATORY]: Trapped ProvisionVoiceAccountRequest from {0}", agentID);
            
            // THE WIRETAP: Show us exactly what Firestorm is sending
            m_log.InfoFormat("[OBSERVATORY]: Raw Payload Length: {0}", request?.Length ?? 0);
            m_log.InfoFormat("[OBSERVATORY]: Raw Payload: \n{0}", request);

            if (string.IsNullOrEmpty(request))
            {
                m_log.Error("[OBSERVATORY]: ABORT - Request payload is empty!");
                return "";
            }

            // 1. Defensive Parsing
            OSD parsedOsd = null;
            try
            {
                parsedOsd = OSDParser.DeserializeLLSDXml(request);
            }
            catch (Exception ex)
            {
                m_log.ErrorFormat("[OBSERVATORY]: XML Parse Exception: {0}", ex.Message);
            }

            if (parsedOsd == null || !(parsedOsd is OSDMap)) return "";
            
            OSDMap requestMap = (OSDMap)parsedOsd;

            // Gracefully reject legacy Vivox requests
            if (requestMap.TryGetValue("voice_server_type", out OSD vst))
            {
                if (vst.AsString().ToLower() != "webrtc")
                {
                    m_log.InfoFormat("[OBSERVATORY]: Discarding legacy {0} request.", vst.AsString());
                    return "<llsd><undef /></llsd>";
                }
            }
            
            // NEW: Gracefully handle Viewer Logout requests
            if (requestMap.ContainsKey("logout") && requestMap["logout"].AsBoolean())
            {
                m_log.Info("[OBSERVATORY]: Viewer requested WebRTC logout. Closing session.");
                return "<llsd><undef /></llsd>";
            }

            // Ensure jsep exists before trying to access its children
            if (!requestMap.ContainsKey("jsep") || !(requestMap["jsep"] is OSDMap))
            {
                m_log.Error("[OBSERVATORY]: ABORT - Payload missing 'jsep' dictionary!");
                return "";
            }

            OSDMap jsepMap = (OSDMap)requestMap["jsep"];
            string offerSdp = jsepMap["sdp"].AsString();
            string viewerSession = requestMap.ContainsKey("viewer_session") ? requestMap["viewer_session"].AsString() : "UNKNOWN";

            m_log.Info("[OBSERVATORY]: Successfully parsed SDP Offer!");

            // 2. Initialize the SIPSorcery WebRTC Peer Connection
            RTCConfiguration config = new RTCConfiguration();
            RTCPeerConnection pc = new RTCPeerConnection(config);

            // 3. Attach a Dummy Audio Track
            var audioFormat = new AudioFormat(AudioCodecsEnum.OPUS, 111);
            var audioTrack = new MediaStreamTrack(audioFormat, MediaStreamStatusEnum.SendRecv);
            pc.addTrack(audioTrack);

            // 4. Trap the Data Channel
            pc.ondatachannel += (dc) => {
                m_log.Info("[OBSERVATORY]: SCTP Data Channel Opened!");
                dc.onmessage += (dataChannel, protocol, data) => {
                    string json = System.Text.Encoding.UTF8.GetString(data);
                    m_log.InfoFormat("[OBSERVATORY]: Firestorm DataChannel JSON: {0}", json);
                };
            };

            // 5. Connection State Logging
            pc.onconnectionstatechange += (state) => {
                m_log.InfoFormat("[OBSERVATORY]: Peer Connection State -> {0}", state);
            };

            // 6. Perform the Crypto/SDP Handshake
            var result = Task.Run(async () =>
            {
                var offerResult = pc.setRemoteDescription(new RTCSessionDescriptionInit { type = RTCSdpType.offer, sdp = offerSdp });
                var answer = pc.createAnswer(null);
                await pc.setLocalDescription(answer);
                return answer.sdp;
            }).Result;

            // 7. THE FIX: Clever OSDMap instantiation to prevent silent key drops
            OSDMap response = new OSDMap {
                ["jsep"] = new OSDMap {
                    ["type"] = "answer",
                    ["sdp"] = result
                },
                ["viewer_session"] = viewerSession
            };

            return OSDParser.SerializeLLSDXmlString(response);
        }
    }
}