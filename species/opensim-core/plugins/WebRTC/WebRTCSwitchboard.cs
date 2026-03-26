namespace OpenSim.Voice.WebRTC.Architecture {
    using Guid = OpenMetaverse.UUID;

    /// <summary>
    /// Room 1: The Bouncer and The Router.
    /// Terminates the network edge, enforces handshakes, and routes clean data inward.
    /// </summary>
    public class WebRTCSwitchboard : ISwitchboard {
        public System.Collections.Concurrent.ConcurrentDictionary<Guid, AgentHeadset> GlobalLedger { get; } = new();

        public event System.Action<VoiceSession, byte[]> OnEncryptedOpusReceived;
        public event System.Action<VoiceSession, string> OnDataChannelJsonReceived;
        public event System.Action<VoiceSession, string> OnSessionAborted;
        public event System.Action<VoiceSession, string> OnRogueFrameDropped;

        public event System.Action<VoiceSession, byte[]> OnDispatchOpus;
        public event System.Action<VoiceSession, string> OnDispatchJson;

        public void RegisterSession(Guid agentId, string sessionId) {
            var headset = GlobalLedger.GetOrAdd(agentId, id => new AgentHeadset(id));
            var session = new VoiceSession(sessionId, headset);
            headset.Sessions.TryAdd(sessionId, session);
        }

        public void PrototypeCallback_OnRtpPacket(VoiceSession session, byte[] payload) {
            if (!session.HasJoined) {
                session.Owner.TotalRogueFramesReceived++;
                OnRogueFrameDropped?.Invoke(session, "RTP arrived before Data Channel Join. Packet dropped.");
                return;
            }

            session.LastActivityAt = System.DateTime.UtcNow;

            OnEncryptedOpusReceived?.Invoke(session, payload);
        }

        public void PrototypeCallback_OnDataChannelMessage(VoiceSession session, string json) {
            if (json.Contains("\"j\"") && json.Contains("\"p\":true")) {
                session.HasJoined = true;
            }

            session.LastActivityAt = System.DateTime.UtcNow;

            // Blindly union into the Expando Stash for Phase 2 BYOSM spatialization
            session.TelemetryStash["latest_raw_json"] = json;

            OnDataChannelJsonReceived?.Invoke(session, json);
        }

        public void DispatchOpusFrame(VoiceSession targetSession, byte[] outboundOpus) {
            OnDispatchOpus?.Invoke(targetSession, outboundOpus);
        }

        public void DispatchJson(VoiceSession targetSession, string json) {
            OnDispatchJson?.Invoke(targetSession, json);
        }

        public void DispatchSessionAborted(VoiceSession targetSession, string reason) {
            OnSessionAborted?.Invoke(targetSession, reason);
        }
    }
}