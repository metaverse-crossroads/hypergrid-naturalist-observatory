namespace OpenSim.Voice.WebRTC.Architecture {
    using Guid = OpenMetaverse.UUID;
    using ConcurrentDict = System.Collections.Concurrent.ConcurrentDictionary<OpenMetaverse.UUID, AgentHeadset>;
    using System.Linq;

    /// <summary>
    /// The Main Engine Block.
    /// Bootstraps the 3 Rooms, owns the Ledger, and drives the optical clock loop.
    /// </summary>
    public class WebRTCVoiceEngine {
        public ConcurrentDict GlobalLedger { get; }
        public WebRTCSwitchboard Switchboard { get; }
        public TapeSpooler Spooler { get; }
        public MixingDesk Mixer { get; }

        private System.Threading.Thread _clockThread;
        private System.Threading.Thread _sweeperThread;
        private System.Threading.Thread _rosterThread;
        private volatile bool _isRunning = false;

        public WebRTCVoiceEngine() {
            Switchboard = new WebRTCSwitchboard();
            GlobalLedger = Switchboard.GlobalLedger;

            Mixer = new MixingDesk(Switchboard, GlobalLedger);
            Spooler = new TapeSpooler();

            Switchboard.OnEncryptedOpusReceived += Spooler.ProcessIncomingOpus;
        }

        public void Start() {
            if (_isRunning) return;
            _isRunning = true;

            _clockThread = new System.Threading.Thread(ClockLoop) { Name = "WebRTC_Mixer_Clock", IsBackground = true, Priority = System.Threading.ThreadPriority.AboveNormal };
            _sweeperThread = new System.Threading.Thread(SweeperLoop) { Name = "WebRTC_Janitor", IsBackground = true, Priority = System.Threading.ThreadPriority.Lowest };
            _rosterThread = new System.Threading.Thread(RosterLoop) { Name = "WebRTC_Roster", IsBackground = true, Priority = System.Threading.ThreadPriority.BelowNormal };

            _clockThread.Start();
            _sweeperThread.Start();
            _rosterThread.Start();

            System.Console.WriteLine("[WebRTC Voice] Engine Started. The Studio is live.");
        }

        public void Stop() {
            _isRunning = false;
            _clockThread?.Join(500);
            _sweeperThread?.Join(500);
            _rosterThread?.Join(500);
            System.Console.WriteLine("[WebRTC Voice] Engine Stopped.");
        }

        /// <summary>
        /// The isolated, clock-aligned tick loop. Room 3 lives entirely in here.
        /// </summary>
        private void ClockLoop() {
            int tickIntervalMs = 100;

            // ABSOLUTE PACING: We abandon TickCount64 (legacy Mono incompatible).
            // We lock to a continuous Stopwatch to prevent the thread from dying and halting Room 3.
            var sw = System.Diagnostics.Stopwatch.StartNew();
            long nextTickTime = tickIntervalMs;

            while (_isRunning) {
                long now = sw.ElapsedMilliseconds;

                if (now - nextTickTime > 3000) {
                    System.Console.WriteLine($"[WebRTC Voice] CLOCK WARP: Thread starved for {now - nextTickTime}ms. Warping clock.");
                    nextTickTime = now;
                }

                // THE ACCUMULATOR: Guarantee we process every missed tick exactly once.
                while (now >= nextTickTime) {
                    try {
                        Mixer.Tick(tickIntervalMs);
                    } catch (System.Exception ex) {
                        System.Console.WriteLine($"[WebRTC Voice] Mixing Desk Exception: {ex.Message}");
                    }
                    nextTickTime += tickIntervalMs;
                }

                now = sw.ElapsedMilliseconds;
                long sleepTime = nextTickTime - now;

                if (sleepTime > 0) {
                    System.Threading.Thread.Sleep((int)sleepTime);
                }
            }
        }

        private void RosterLoop() {
            var previousRoster = new System.Collections.Generic.HashSet<Guid>();

            while (_isRunning) {
                System.Threading.Thread.Sleep(500); // 2Hz Roster Broadcast
                var now = System.DateTime.UtcNow;

                var currentRoster = new System.Collections.Generic.HashSet<Guid>();

                // 1. Global Decay & Gather Current Roster
                foreach (var agentKvp in GlobalLedger) {
                    var session = agentKvp.Value.GetElectedSession();
                    if (session == null || !session.HasJoined) continue;

                    currentRoster.Add(agentKvp.Key);

                    // Power Decay: If we haven't seen an Opus frame in 500ms, force decay
                    if ((now - session.LastOpusReceivedAt).TotalMilliseconds > 500) {
                        session.PowerLevel = (int)(session.PowerLevel * 0.5);
                        if (session.PowerLevel < 5) session.IsSpeaking = false;
                    }
                }

                // 2. Epoch Evaluation
                bool isEpoch = !previousRoster.SetEquals(currentRoster);
                var departedAgents = previousRoster.Except(currentRoster).ToList();

                if (currentRoster.Count > 0 || departedAgents.Count > 0) {
                    var sb = new System.Text.StringBuilder("{");
                    bool hasEntries = false;

                    // Add active speakers
                    foreach (var agentId in currentRoster) {
                        if (GlobalLedger.TryGetValue(agentId, out var agentHeadset)) {
                            var session = agentHeadset.GetElectedSession();
                            if (session != null) {
                                if (hasEntries) sb.Append(",");
                                sb.Append($"\"{agentId}\":{{");
                                
                                // Blast newcomer presence during an epoch
                                if (isEpoch) sb.Append("\"j\":{\"p\":true},");
                                
                                sb.Append($"\"v\":{session.IsSpeaking.ToString().ToLower()},\"p\":{session.PowerLevel}}}");
                                hasEntries = true;
                            }
                        }
                    }

                    // Append the trailing edge 'l': true for departing agents
                    foreach (var departed in departedAgents) {
                        if (hasEntries) sb.Append(",");
                        sb.Append($"\"{departed}\":{{\"l\":true}}");
                        hasEntries = true;
                    }

                    sb.Append("}");

                    if (hasEntries) {
                        string payload = sb.ToString();
                        // System.Console.WriteLine($"[WebRTC Voice] hasEntries ${sb.ToString()}");
                        foreach (var agentId in currentRoster) {
                            if (GlobalLedger.TryGetValue(agentId, out var agentHeadset)) {
                                var session = agentHeadset.GetElectedSession();
                                if (session != null) {
                                    Switchboard.DispatchJson(session, payload);
                                }
                            }
                        }
                    }
                }

                if (isEpoch) {
                    previousRoster = new System.Collections.Generic.HashSet<Guid>(currentRoster);
                }
            }
        }

        /// <summary>
        /// The Garbage Collector for the Pocket Universe.
        /// </summary>
        private void SweeperLoop() {
            while (_isRunning) {
                System.Threading.Thread.Sleep(5000); // Run every 5 seconds
                var now = System.DateTime.UtcNow;

                foreach (var agentKvp in GlobalLedger) {
                    AgentHeadset headset = agentKvp.Value;
                    var keysToRemove = new System.Collections.Generic.List<string>();

                    foreach (var sessionKvp in headset.Sessions) {
                        VoiceSession session = sessionKvp.Value;

                        // Phase 1 Sweep Logic: We only cull sessions that never completed the handshake.
                        // Active sessions rely on Bridge PC State to trigger teardown.
                        bool isZombieNoShow = !session.HasJoined && (now - session.CreatedAt).TotalSeconds > 15;

                        if (isZombieNoShow) {
                            keysToRemove.Add(session.SessionID);
                        }
                        
                        // DECAY SPEAKING STATE
                        if (session.IsSpeaking && (now - session.LastOpusReceivedAt).TotalMilliseconds > 1000) {
                            session.IsSpeaking = false;
                            session.PowerLevel = 0;
                        }
                    }

                    foreach (string key in keysToRemove) {
                        if (headset.Sessions.TryRemove(key, out var deadSession)) {
                            Switchboard.DispatchSessionAborted(deadSession, "Janitor Culled Zombie Pipe.");
                        }
                    }
                }
            }
        }
    }
}