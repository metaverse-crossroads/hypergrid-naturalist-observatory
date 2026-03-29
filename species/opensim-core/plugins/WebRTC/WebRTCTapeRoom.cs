namespace OpenSim.Voice.WebRTC.Architecture {
    using Guid = OpenMetaverse.UUID;

    public class TapeSpooler : ITapeSpooler {
        public void ProcessIncomingOpus(VoiceSession session, byte[] opusData) {
            session.LastOpusReceivedAt = System.DateTime.UtcNow;

            // 1. Detect true channels from the Opus payload
            int channels = Concentus.Structs.OpusPacketInfo.GetNumEncodedChannels(opusData);
            
            // 2. DYNAMIC CODEC HOT-SWAP (If mic changes from Mono to Stereo)
            if (session.InboundDecoder == null || session.InboundChannels != channels) {
                session.InboundChannels = channels;
                session.InboundDecoder = Concentus.OpusCodecFactory.CreateDecoder(48000, channels);
            }

            short[] pcmData = DecodeOpus(session, opusData);
            if (pcmData.Length == 0) return;

            int durationMs = (pcmData.Length / channels) / 48;
            session.PacingWindow.Enqueue((System.DateTime.UtcNow, durationMs));
            
            while (session.PacingWindow.TryPeek(out var old) && (System.DateTime.UtcNow - old.Time).TotalSeconds > 3) {
                session.PacingWindow.TryDequeue(out _);
            }

            UpdateSessionPowerLevel(session, pcmData);

            // 3. DYNAMIC TAPE HOT-SWAP (Rebuild tape if channel count shifts)
            if (session.AudioTape == null || session.AudioTape.Channels != channels) {
                session.AudioTape = new AudioReservoir(48000, channels);
            }

            session.AudioTape.SpoolPCM(pcmData);
        }
 
        private short[] DecodeOpus(VoiceSession session, byte[] opusData) {
            int frameSize = Concentus.Structs.OpusPacketInfo.GetNumSamples(opusData, 48000);
            if (frameSize < 1) return System.Array.Empty<short>(); 

            // THE TRUNCATION BUG FIX: Concentus returns frameSize PER CHANNEL.
            // We MUST allocate enough room for the fully interleaved L/R array.
            short[] pcmData = new short[frameSize * session.InboundChannels];
            try {
                int decodedSamples = session.InboundDecoder.Decode(opusData, pcmData, frameSize, false);
                if (decodedSamples < 1) return System.Array.Empty<short>();
                
                int totalSamples = decodedSamples * session.InboundChannels;
                if (totalSamples < pcmData.Length) {
                    System.Array.Resize(ref pcmData, totalSamples);
                }
                return pcmData;
            } catch (System.Exception) {
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
        public int Channels { get; private set; }

        public AudioReservoir(int sampleRate, int channels) {
            Channels = channels;
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