namespace OpenSim.Voice.WebRTC.Architecture {
    using Guid = OpenMetaverse.UUID;

    #region Room 1: The Switchboard (Signaling & Transport)

    /// <summary>
    /// The absolute edge of the system. Terminates Data Channels and RTP.
    /// OpenSim's Bridge hooks directly into this interface.
    /// </summary>
    public interface ISwitchboard {
        // --- Ledger Registration ---
        void RegisterSession(Guid agentId, string sessionId);

        // --- Switchboard -> Room 2 & Ledger (Ingest) ---
        event System.Action<VoiceSession, byte[]> OnEncryptedOpusReceived;
        event System.Action<VoiceSession, string> OnDataChannelJsonReceived;

        // --- Switchboard -> OpenSim Log (Health Assessments) ---
        event System.Action<VoiceSession, string> OnSessionAborted; 
        event System.Action<VoiceSession, string> OnRogueFrameDropped;

        // --- Outbound Network Edge Events (Studio -> Bridge) ---
        event System.Action<VoiceSession, byte[]> OnDispatchOpus;
        event System.Action<VoiceSession, string> OnDispatchJson;

        // --- Room 3 -> Switchboard (Dispatch) ---
        void DispatchOpusFrame(VoiceSession targetSession, byte[] outboundOpus);
        void DispatchJson(VoiceSession targetSession, string json);
        void DispatchSessionAborted(VoiceSession targetSession, string reason);
    }

    #endregion

    #region Room 2: The Tape Room (Ingest & Spooling)

    public interface ITapeSpooler {
        void ProcessIncomingOpus(VoiceSession session, byte[] opusData);
    }

    public interface IReservoir {
        // Thread-safe ingest from ITapeSpooler
        void SpoolPCM(short[] pcmData);

        // Mutative pull for Room 3.
        short[] PullPCM(int requestedMilliseconds);

        // Room 3 Look-Ahead VAD Support (Peeks into the future without mutating the tape)
        float PeekFutureRMS(int lookAheadMilliseconds);

        // Health Assessments (Dimensions of Uniformity & Tension)
        int MillisecondsBuffered { get; }
        long TotalUnderruns { get; } 
        long TotalOverruns { get; }  
        bool IsSpooling { get; }     
    }

    #endregion

    #region Room Pi: The FX Rack (BYOSM)

    public interface ISpatialDSP {
        short[] ProcessShenanigans(short[] rawMonoSpeakerPcm, VoiceSession speaker, VoiceSession listener);
    }

    #endregion

    #region Room 3: The Mixing Desk

    /// <summary>
    /// The isolated clock loop driving the N-1 production.
    /// Runs on its own relaxed absolute thread.
    /// </summary>
    public interface IMixingDesk {
        void Tick(int tickMilliseconds);
    }

    #endregion
}