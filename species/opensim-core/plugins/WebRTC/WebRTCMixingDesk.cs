namespace OpenSim.Voice.WebRTC.Architecture {
    using Guid = OpenMetaverse.UUID;
    using ConcurrentDict = System.Collections.Concurrent.ConcurrentDictionary<OpenMetaverse.UUID, AgentHeadset>;

    public class SpatialDSP : ISpatialDSP {
        public short[] ProcessShenanigans(short[] rawMonoSpeakerPcm, VoiceSession speaker, VoiceSession listener) {
            short[] stereoOut = new short[rawMonoSpeakerPcm.Length * 2];
            for (int i = 0; i < rawMonoSpeakerPcm.Length; i++) {
                stereoOut[i * 2] = rawMonoSpeakerPcm[i];
                stereoOut[i * 2 + 1] = rawMonoSpeakerPcm[i];
            }
            return stereoOut;
        }
    }

    public class MixingDesk : IMixingDesk {
        private readonly ISwitchboard _switchboard;
        private readonly ConcurrentDict _globalLedger;
        private readonly ISpatialDSP _dspRack;
        private readonly System.Collections.Generic.Dictionary<string, bool> _previousSpeakingState = new();

        public MixingDesk(ISwitchboard switchboard, ConcurrentDict globalLedger) {
            _switchboard = switchboard;
            _globalLedger = globalLedger;
            _dspRack = new SpatialDSP();
        }

        public void Tick(int tickMilliseconds) {
            int monoSampleCount = tickMilliseconds * 48;
            int stereoSampleCount = monoSampleCount * 2;

            var frameSnapshots = new System.Collections.Generic.Dictionary<string, short[]>();

            foreach (var kvp in _globalLedger) {
                AgentHeadset agent = kvp.Value;
                VoiceSession session = agent.GetElectedSession();

                if (session == null || session.AudioTape == null) continue;

                short[] poppedAudio = session.AudioTape.PullPCM(tickMilliseconds);
                frameSnapshots[session.SessionID] = poppedAudio;
            }

            foreach (var listenerKvp in _globalLedger) {
                AgentHeadset listener = listenerKvp.Value;
                VoiceSession listenerSession = listener.GetElectedSession();

                if (listenerSession == null || !listenerSession.HasJoined) continue;

                // Latch Peak Power for the listener so the Nextel Chirp isn't blinded by decay
                listenerSession.PeakPowerLevel = System.Math.Max(listenerSession.PeakPowerLevel, listenerSession.PowerLevel);

                short[] mixBuffer = new short[stereoSampleCount];

                foreach (var speakerKvp in _globalLedger) {
                    AgentHeadset speaker = speakerKvp.Value;
                    VoiceSession speakerSession = speaker.GetElectedSession();

                    // Mix-minus! Do not echo the user's voice back to them!
                    if (speaker.AgentID == listener.AgentID || speakerSession == null) continue;

                    if (frameSnapshots.TryGetValue(speakerSession.SessionID, out short[] monoPcm)) {
                        short[] stereoPcm = _dspRack.ProcessShenanigans(monoPcm, speakerSession, listenerSession);

                        for (int i = 0; i < mixBuffer.Length; i++) {
                            int summed = mixBuffer[i] + stereoPcm[i];
                            mixBuffer[i] = (short)System.Math.Max(short.MinValue, System.Math.Min(short.MaxValue, summed));
                        }
                    }
                }

                // --- NEXTEL TRIGGERS (Network Timeout Evaluation) ---
                bool currentlySpeaking = listenerSession.HasJoined && (System.DateTime.UtcNow - listenerSession.LastOpusReceivedAt).TotalMilliseconds < 500;

                _previousSpeakingState.TryGetValue(listenerSession.SessionID, out bool wasSpeaking);

                if (wasSpeaking && !currentlySpeaking) {
                    bool isHealthyAck = listenerSession.PeakPowerLevel > 5;
                    InjectNextelChirp(mixBuffer, isHealthyAck);
                    
                    if (isHealthyAck) {
                        listenerSession.TotalChirps++;
                        System.Console.WriteLine($"[STUDIO DESK]: {listenerSession.SessionID} released PTT. Injected Nextel ACK (Chirp).");
                    } else {
                        listenerSession.TotalNaks++;
                        System.Console.WriteLine($"[STUDIO DESK]: {listenerSession.SessionID} released PTT (Silence). Injected Nextel NAK (Click).");
                    }
                    
                    listenerSession.PeakPowerLevel = 0; // Reset latch for the next transmission
                }

                _previousSpeakingState[listenerSession.SessionID] = currentlySpeaking;

                // --- OUTBOUND POWER PROOF ---
                double sumOfSquares = 0;
                for (int i = 0; i < mixBuffer.Length; i++) {
                    sumOfSquares += mixBuffer[i] * mixBuffer[i];
                }
                double rms = System.Math.Sqrt(sumOfSquares / mixBuffer.Length);
                listenerSession.OutboundPowerLevel = (int)System.Math.Max(0, System.Math.Min(127, (rms / 32768.0) * 127.0));

                // --- CHUNK AND ENCODE (WebRTC Standard is 20ms) ---
                int frameLengthMono = 960; // 20ms at 48kHz
                int frameLengthStereo = frameLengthMono * 2;
                int chunkCount = mixBuffer.Length / frameLengthStereo;

                for (int chunk = 0; chunk < chunkCount; chunk++) {
                    short[] twentyMsChunk = new short[frameLengthStereo];
                    System.Array.Copy(mixBuffer, chunk * frameLengthStereo, twentyMsChunk, 0, frameLengthStereo);

                    byte[] encodedOpus = EncodeOpus(listenerSession, twentyMsChunk);
                    if (encodedOpus.Length > 0) {
                        _switchboard.DispatchOpusFrame(listenerSession, encodedOpus);
                    }
                }
            }
        }

        private void InjectNextelChirp(short[] mixBuffer, bool healthyUpstream) {
            for (int i = 0; i < mixBuffer.Length; i++) {
                if (healthyUpstream) mixBuffer[i] = (short)(System.Math.Sin(i * 0.1) * 8000);
                else mixBuffer[i] = (short)(i < 100 ? 10000 : 0);
            }
        }

        private byte[] EncodeOpus(VoiceSession session, short[] stereoPcm) {
            int frameSizePerChannel = stereoPcm.Length / 2;
            byte[] opusOutBuffer = new byte[1500];

            try {
                int encodedBytes = session.OutboundEncoder.Encode(stereoPcm, frameSizePerChannel, opusOutBuffer, opusOutBuffer.Length);
                byte[] finalPayload = new byte[encodedBytes];
                System.Array.Copy(opusOutBuffer, finalPayload, encodedBytes);
                return finalPayload;
            } catch (System.Exception) {
                return System.Array.Empty<byte>();
            }
        }
    }
}