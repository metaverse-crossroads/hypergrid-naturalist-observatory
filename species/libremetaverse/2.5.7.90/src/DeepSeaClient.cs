/*
./bin/cs++ species/libremetaverse/src/DeepSeaCommon.cs species/libremetaverse/2.5.7.90/src/DeepSeaClient.cs \
    vivarium/libremetaverse-2.5.7.90/DeepSeaClient_Project/bin/Release/net8.0/DeepSeaClient.exe
*/

using System;
using System.IO;
using System.Linq;
using System.Threading;
using System.Collections.Generic;
using OpenMetaverse;
using OpenMetaverse.Packets;
using LibreMetaverse.Voice.WebRTC;
using LibreMetaverse;
using OmvTestHarness;

namespace OmvTestHarness
{
    public class DeepSeaClientWithVoice : DeepSeaClient
    {
        private VoiceManager voice;
        private AutoResetEvent eventQueueRunningEvent = new AutoResetEvent(false);

        protected override void RunRepl(int timeout)
        {
            Console.WriteLine($" {clientName} REPL. Extended Commands: VOICE_CONNECT, VOICE_DISCONNECT, VOICE_PLAY <wav>, VOICE_STOP");
            base.RunRepl(timeout);
        }

        protected override void RegisterCallbacks()
        {
            base.RegisterCallbacks();

            client.Network.EventQueueRunning += (sender, e) =>
            {
                eventQueueRunningEvent.Set();
            };
        }

        protected override bool HandleCustomCommand(string cmd, string arg)
        {
            try
            {
                if (cmd == "VOICE_CONNECT")
                {
                    if (!client.Network.Connected || client.Network.CurrentSim == null)
                    {
                        Console.WriteLine("Not connected to a region.");
                        return true;
                    }

                    EncounterLogger.Log("Visitant", "VOICE", "INIT", "Initializing WebRTC Voice Session");

                    if (voice == null)
                    {
                        voice = new VoiceManager(client);
                        voice.PeerAudioUpdated += (id, state) =>
                        {
                            if (state.Power != null || state.VoiceActive != null) EncounterLogger.Log("Visitant", "VOICE", "AUDIO_UPDATE", $"Peer: {id}, Power: {state.Power}, VAD: {state.VoiceActive}");
                        };
                    }

                    // Wait a bit for event queue if not already running
                    eventQueueRunningEvent.WaitOne(TimeSpan.FromSeconds(5), false);

                    EncounterLogger.Log("Visitant", "VOICE", "PROVISION_REQUEST", $"Requesting provisional account from {client.Network.CurrentSim.Name}");

                    var connectTask = voice.ConnectPrimaryRegion();
                    connectTask.Wait(TimeSpan.FromSeconds(30)); // Synchronously wait for test harness

                    if (connectTask.IsCompleted && connectTask.Result)
                    {
                        EncounterLogger.Log("Visitant", "VOICE", "PROVISION_SUCCESS", $"Connected to voice in '{client.Network.CurrentSim.Name}'");
                    }
                    else
                    {
                        EncounterLogger.Log("Visitant", "VOICE", "PROVISION_FAILURE", $"Failed to connect voice to '{client.Network.CurrentSim.Name}'");
                    }
                    return true;
                }
                else if (cmd == "VOICE_DISCONNECT")
                {
                    if (voice == null || !voice.connected)
                    {
                        Console.WriteLine("Voice not connected.");
                        return true;
                    }
                    voice.Disconnect();
                    voice = null;
                }
                else if (cmd == "VOICE_PLAY")
                {
                    if (voice == null || !voice.connected)
                    {
                        Console.WriteLine("Voice not connected.");
                        return true;
                    }

                    string wavPath = arg.Trim();
                    if (!string.IsNullOrEmpty(wavPath) && !File.Exists(wavPath) &&
                        Environment.GetEnvironmentVariable("REPO_ROOT") != null && File.Exists(Environment.GetEnvironmentVariable("REPO_ROOT")+"/"+wavPath)) {
                        wavPath = Environment.GetEnvironmentVariable("REPO_ROOT")+"/"+wavPath;
                    }
                    if (!string.IsNullOrEmpty(wavPath) && File.Exists(wavPath))
                    {
                        EncounterLogger.Log("Visitant", "VOICE", "PLAY_WAV", $"Playing {wavPath}");
                        voice.PlayWavAsMic(wavPath, loop: true);
                    }
                    else
                    {
                        EncounterLogger.Log("Visitant", "VOICE", "PLAY_FAILURE", $"WAV file not found: {wavPath} (REPO_ROOT={Environment.GetEnvironmentVariable("REPO_ROOT")})");
                    }
                    return true;
                }
                else if (cmd == "VOICE_STOP")
                {
                    if (voice != null)
                    {
                        voice.StopWavAsMic();
                        EncounterLogger.Log("Visitant", "VOICE", "STOP_WAV", "WAV playback stopped");
                    }
                    return true;
                }
            }
            catch (Exception ex)
            {
                EncounterLogger.Log("Visitant", "VOICE", "ERROR", $"Voice command failed: {ex.Message}");
            }

            return base.HandleCustomCommand(cmd, arg);
        }
    }

    class Program {

        static HarmonyLib.Harmony harmony = new("com.yourcompany.sdl3fix");

        static void InjectPrefix(string targetMethod, System.Delegate _prefix) {
            var prefix = _prefix.Method;
            var original = HarmonyLib.AccessTools.Method(typeof(SIPSorceryMedia.SDL3.SDL3Helper), targetMethod)
                ?? throw new System.Exception($"FAILED TO FIND {targetMethod} METHOD");
            System.Console.WriteLine($"[HARMONY] Hooking: {original.Name} -> {prefix.Name}");
            _ = harmony.Patch(original, prefix: new HarmonyLib.HarmonyMethod(prefix))
                ?? throw new System.Exception($"FAILED TO PATCH {targetMethod} - SIGNATURE MISMATCH");
        }

        static void InjectTranspiler(System.Type targetClass, string targetMethod, System.Delegate _transpiler) {
            var transpiler = _transpiler.Method;
            var original = HarmonyLib.AccessTools.Method(targetClass, targetMethod)
                ?? throw new System.Exception($"FAILED TO FIND {targetClass}.{targetMethod} METHOD");
            System.Console.WriteLine($"[HARMONY] Transpiling: {original.DeclaringType?.Name}.{original.Name} -> {transpiler.Name}");
            _ = harmony.Patch(original, transpiler: new HarmonyLib.HarmonyMethod(transpiler))
                ?? throw new System.Exception($"FAILED TO PATCH {targetClass}.{targetMethod} - SIGNATURE MISMATCH");
            System.Console.WriteLine($"[HARMONY] Successfully patched {targetClass}.{targetMethod}");
        }

        public static void SIPSorcery_SDL3_monkeypatch(bool ForceStereoMic = false) {
            bool GetAudioSpec_ForceStereoMic(ref int clockRate, ref byte channels) { byte before = channels;
                channels = 2;
                System.Console.WriteLine($"[HARMONY] GetAudioSpec_ForceStereoMic({clockRate}, {before} => forced to {channels})");
                return true;
            }

            bool OpenAudioDeviceStreamHandle_Logger(uint deviceId, ref SDL3.SDL.SDL_AudioSpec audioSpec, SIPSorceryMedia.SDL3.SDL3Helper.SDL_AudioStreamHandleCallback callback) {
                System.Console.WriteLine($"[HARMONY] OpenAudioDeviceStreamHandle_Logger(deviceId={deviceId}, audioSpec={audioSpec}#{audioSpec.channels}ch, callback={callback})...");
                return true;
            }

            if (ForceStereoMic) InjectPrefix("GetAudioSpec", GetAudioSpec_ForceStereoMic);
            InjectPrefix("OpenAudioDeviceStreamHandle", OpenAudioDeviceStreamHandle_Logger);

            System.Console.WriteLine("[HARMONY] All Harmony patches applied successfully...");
        }


        // InjectTranspiler(typeof(SIPSorceryMedia.SDL3.SDL3AudioEndPoint), "PlaybackWorker_DoWork", PlaybackWorker_DoWorkTranspiler);
        // const sbyte MS = 1;
        // static System.Collections.Generic.IEnumerable<HarmonyLib.CodeInstruction> PlaybackWorker_DoWorkTranspiler(
        //     System.Collections.Generic.IEnumerable<HarmonyLib.CodeInstruction> instructions) {
        //     object patched = null;
        //     foreach (var inst in instructions) {
        //         if (patched == null) {
        //             // Check for both Ldc_I4 and Ldc_I4_S opcodes with value 50
        //             if (inst.opcode == System.Reflection.Emit.OpCodes.Ldc_I4 && inst.operand is int operand1 && operand1 == 50) {
        //                 inst.operand = MS; // Change for stereo
        //                 patched = inst.opcode;
        //             }
        //             else if (inst.opcode == System.Reflection.Emit.OpCodes.Ldc_I4_S && inst.operand is sbyte operand2 && operand2 == 50) {
        //                 inst.operand = (sbyte)MS; // Change for stereo
        //                 patched = inst.opcode;
        //             }
        //             if (patched != null) System.Console.WriteLine($"[HARMONY] PlaybackWorker_DoWork: Changed Wait(50) to Wait({MS}) via {patched}");
        //         }
        //         yield return inst;
        //     }

        //     if (patched == null) {
        //         System.Console.WriteLine("[HARMONY] WARNING: PlaybackWorker_DoWork transpiler did not find Wait(50) to patch");
        //         foreach (var inst in instructions) {
        //             System.Console.WriteLine($"[HARMONY] PlaybackWorker_DoWork.inst {inst.opcode} {inst.operand}");
        //         }
        //         throw new System.Exception($"FAILED TO PATCH PlaybackWorker_DoWork");
        //     }
        // }


        class SipsorceryLoggerFactory : Microsoft.Extensions.Logging.ILoggerFactory {
            class SipsorceryLogger : Microsoft.Extensions.Logging.ILogger {
                private readonly log4net.ILog m_log;
                public SipsorceryLogger(string categoryName) { m_log = log4net.LogManager.GetLogger(categoryName); }
                public IDisposable BeginScope<TState>(TState state) => null;
                public bool IsEnabled(Microsoft.Extensions.Logging.LogLevel logLevel) => true;
                public void Log<TState>(Microsoft.Extensions.Logging.LogLevel logLevel, Microsoft.Extensions.Logging.EventId eventId, TState state, System.Exception exception, System.Func<TState, Exception, string> formatter) {
                    m_log.InfoFormat("[SIPSORCERY_ENGINE] {0}: {1}", logLevel, formatter(state, exception));
                    if (exception != null) m_log.ErrorFormat("[SIPSORCERY_ENGINE_EX] {0}", exception.ToString().Replace("\r\n", "\\r\\n"));
                }
            }
            public void AddProvider(Microsoft.Extensions.Logging.ILoggerProvider provider) { }
            public Microsoft.Extensions.Logging.ILogger CreateLogger(string categoryName) => new SipsorceryLogger(categoryName);
            public void Dispose() { }
        }

        static void Main(string[] args)
        {
            System.Runtime.InteropServices.NativeLibrary.Load(System.AppDomain.CurrentDomain.BaseDirectory + "runtimes/win-x64/native/SDL3.dll");
            SIPSorcery_SDL3_monkeypatch(args.Contains("--stereo"));
            System.Console.WriteLine($"[HARMONY] ....args[0]={args.Contains("--verbose")}");

            if (args.Contains("--verbose")) {
                log4net.Config.BasicConfigurator.Configure(new log4net.Appender.ConsoleAppender() {
                    Layout = new log4net.Layout.PatternLayout("%date %-5level %logger - %message%newline"),
                });
                void slevel(string a, log4net.Core.Level b) {
                    ((log4net.Repository.Hierarchy.Logger)log4net.LogManager.GetRepository().GetLogger(a)).Level = b;
                }
                slevel("sipsorcery", log4net.Core.Level.Warn);
                slevel("SIPSorcery.Net", log4net.Core.Level.Warn);
                slevel("SIPSorceryMedia.SDL3", log4net.Core.Level.Debug);
                // ((log4net.Repository.Hierarchy.Logger)log4net.LogManager.GetRepository().GetLogger("SIPSorceryMedia.SDL3.SDL3AudioEndPoint")).Level = log4net.Core.Level.Debug;
                // ((log4net.Repository.Hierarchy.Logger)log4net.LogManager.GetRepository().GetLogger("SIPSorceryMedia.SDL3.SDL3AudioSource")).Level = log4net.Core.Level.Debug;
                SIPSorcery.LogFactory.Set(new SipsorceryLoggerFactory());
            }

            new DeepSeaClientWithVoice().RunClient(args, "DeepSeaClient", "2.5.7 " + Settings.USER_AGENT);
        }
    }
}
