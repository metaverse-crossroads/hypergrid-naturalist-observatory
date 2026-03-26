namespace OpenSim.Voice.WebRTC.Architecture {
    using Guid = OpenMetaverse.UUID;

    /// <summary>
    /// Represents the physical user wearing the headset.
    /// Survives sim crossings and transient network drops.
    /// </summary>
    public class AgentHeadset {
        public Guid AgentID { get; }

        public System.Collections.Concurrent.ConcurrentDictionary<string, VoiceSession> Sessions { get; } = new();

        // Global Health Assessments
        public long TotalRogueFramesReceived { get; set; }

        public AgentHeadset(Guid agentId) {
            AgentID = agentId;
        }

        public VoiceSession GetElectedSession() {
            foreach (var kvp in Sessions) {
                if (kvp.Value.HasJoined) return kvp.Value;
            }

            var enumerator = Sessions.Values.GetEnumerator();
            return enumerator.MoveNext() ? enumerator.Current : null;
        }
    }

    /// <summary>
    /// Represents a specific, transient WebRTC pipe to a specific Region/Parcel.
    /// </summary>
    public class VoiceSession {
        public string SessionID { get; }
        public AgentHeadset Owner { get; }

        public bool HasJoined { get; set; }

        public System.Collections.Concurrent.ConcurrentDictionary<string, object> TelemetryStash { get; } = new();

        public IReservoir AudioTape { get; set; }

        // --- DYNAMIC STATE ---
        public bool IsSpeaking { get; set; }
        public int PowerLevel { get; set; }
        public int PeakPowerLevel { get; set; } // Latches power for the Nextel ACK/NAK evaluation
        public int OutboundPowerLevel { get; set; } 

        // --- TIMESTAMPS & PROOFS FOR TELEMETRY AND JANITOR ---
        public System.DateTime CreatedAt { get; } = System.DateTime.UtcNow;
        public System.DateTime LastActivityAt { get; set; } = System.DateTime.UtcNow;
        public System.DateTime LastOpusReceivedAt { get; set; } = System.DateTime.MinValue;
        
        // --- 3-SECOND SLIDING PACING WINDOW ---
        public System.Collections.Concurrent.ConcurrentQueue<(System.DateTime Time, int Ms)> PacingWindow { get; } = new();
        public double PreviousRatio { get; set; }

        // --- NEXTEL HEALTH METRICS ---
        public long TotalChirps { get; set; }
        public long TotalNaks { get; set; }

        // --- THE CODECS ---
        public Concentus.IOpusDecoder InboundDecoder { get; }
        public Concentus.IOpusEncoder OutboundEncoder { get; }

        public VoiceSession(string sessionId, AgentHeadset owner) {
            SessionID = sessionId;
            Owner = owner;
            HasJoined = false;
            IsSpeaking = false;
            PowerLevel = 0;
            OutboundPowerLevel = 0;

            InboundDecoder = Concentus.OpusCodecFactory.CreateDecoder(48000, 1);
            OutboundEncoder = Concentus.OpusCodecFactory.CreateEncoder(48000, 2, Concentus.Enums.OpusApplication.OPUS_APPLICATION_VOIP);
        }
    }
}