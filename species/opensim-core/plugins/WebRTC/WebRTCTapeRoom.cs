namespace OpenSim.Voice.WebRTC.Architecture {
    using Guid = OpenMetaverse.UUID;

    public class TapeSpooler : ITapeSpooler {
        public void ProcessIncomingOpus(VoiceSession session, byte[] opusData) {
            session.LastOpusReceivedAt = System.DateTime.UtcNow;

            short[] pcmData = DecodeOpus(session, opusData);

            // BULKHEAD: If the packet was corrupt, RTX, or FEC, we drop it.
            if (pcmData.Length == 0) return;

            // INGEST RATIO TRACKING: 3-Second Sliding Window
            int durationMs = pcmData.Length / 48;
            session.PacingWindow.Enqueue((System.DateTime.UtcNow, durationMs));
            
            while (session.PacingWindow.TryPeek(out var old) && (System.DateTime.UtcNow - old.Time).TotalSeconds > 3) {
                session.PacingWindow.TryDequeue(out _);
            }

            UpdateSessionPowerLevel(session, pcmData);

            if (session.AudioTape == null) {
                // 48,000Hz Mono
                session.AudioTape = new AudioReservoir(48000, 1);
            }

            session.AudioTape.SpoolPCM(pcmData);
        }

        private short[] DecodeOpus(VoiceSession session, byte[] opusData) {
            int frameSize = Concentus.Structs.OpusPacketInfo.GetNumSamples(opusData, 48000);
            
            // If the packet is totally invalid, return empty so we don't spool it
            if (frameSize < 1) return System.Array.Empty<short>(); 

            short[] pcmData = new short[frameSize];
            try {
                int decodedSamples = session.InboundDecoder.Decode(opusData, pcmData, frameSize, false);
                
                if (decodedSamples < 1) return System.Array.Empty<short>();
                
                if (decodedSamples < frameSize) {
                    System.Array.Resize(ref pcmData, decodedSamples);
                }
                return pcmData;
            } catch (System.Exception) {
                // BULKHEAD: Do not spool zeroes for failed decodes. Just drop the packet.
                return System.Array.Empty<short>();
            }
        }

        private void UpdateSessionPowerLevel(VoiceSession session, short[] pcmData) {
            if (pcmData.Length == 0) return;

            double sumOfSquares = 0;
            for (int i = 0; i < pcmData.Length; i++) {
                sumOfSquares += pcmData[i] * pcmData[i];
            }
            double rms = System.Math.Sqrt(sumOfSquares / pcmData.Length);

            int power = (int)((rms / 32768.0) * 127.0);
            session.PowerLevel = System.Math.Max(0, System.Math.Min(127, power));
            
            if (session.PowerLevel > 5) session.IsSpeaking = true;
        }
    }

    public class AudioReservoir : IReservoir {
        private readonly System.Collections.Generic.Queue<short> _tape = new();
        private readonly object _syncRoot = new();
        private readonly int _samplesPerMillisecond;

        // --- THE TAPE BULKHEADS ---
        private const int MIN_SPOOL_MS = 1000;
        private const int MAX_TENSION_MS = 3000;

        public bool IsSpooling { get; private set; } = true;

        public int MillisecondsBuffered {
            get { lock (_syncRoot) return _tape.Count / _samplesPerMillisecond; }
        }

        public long TotalUnderruns { get; private set; } = 0;
        public long TotalOverruns { get; private set; } = 0;

        public AudioReservoir(int sampleRate, int channels) {
            _samplesPerMillisecond = (sampleRate * channels) / 1000;
        }

        public void SpoolPCM(short[] pcmData) {
            lock (_syncRoot) {
                for (int i = 0; i < pcmData.Length; i++) _tape.Enqueue(pcmData[i]);
            }
        }

        public short[] PullPCM(int requestedMilliseconds) {
            int requestedSamples = requestedMilliseconds * _samplesPerMillisecond;
            short[] output = new short[requestedSamples];

            lock (_syncRoot) {
                int currentMs = _tape.Count / _samplesPerMillisecond;

                // 1. HIGH-WATER MARK: Overrun Protection (The Splicer)
                if (currentMs > MAX_TENSION_MS) {
                    TotalOverruns++;
                    int msToDrop = currentMs - MIN_SPOOL_MS; // Snipe back to perfect tension
                    int samplesToDrop = msToDrop * _samplesPerMillisecond;
                    for (int i = 0; i < samplesToDrop; i++) _tape.Dequeue();
                    currentMs = _tape.Count / _samplesPerMillisecond; // Re-evaluate
                }

                // 2. LOW-WATER MARK: Underrun Protection (The Spooler)
                if (IsSpooling) {
                    if (currentMs >= MIN_SPOOL_MS) {
                        IsSpooling = false; // Tension restored, lock released
                    } else {
                        // Dispense absolute silence until tape builds up
                        return output;
                    }
                }

                if (_tape.Count < requestedSamples) {
                    TotalUnderruns++;
                    IsSpooling = true; // The tape snapped. Back to spooling mode.
                }

                for (int i = 0; i < requestedSamples; i++) {
                    output[i] = _tape.Count > 0 ? _tape.Dequeue() : (short)0;
                }
            }
            return output;
        }

        public float PeekFutureRMS(int lookAheadMilliseconds) {
            int samplesToPeek = lookAheadMilliseconds * _samplesPerMillisecond;
            double sumOfSquares = 0;
            int count = 0;

            lock (_syncRoot) {
                foreach (var sample in _tape) {
                    if (count >= samplesToPeek) break;
                    sumOfSquares += sample * sample;
                    count++;
                }
            }

            if (count == 0) return 0f;
            return (float)System.Math.Sqrt(sumOfSquares / count);
        }
    }
}