using System;
using System.IO;
using System.Linq;
using System.Threading;
using System.Collections.Generic;
using OpenMetaverse;
using OpenMetaverse.Packets;
using LibreMetaverse.Voice.WebRTC;
using OmvTestHarness;

namespace OmvTestHarness
{
    public class DeepSeaClientWithVoice : DeepSeaClient
    {
        private VoiceManager voice;
        private AutoResetEvent eventQueueRunningEvent = new AutoResetEvent(false);

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
                            EncounterLogger.Log("Visitant", "VOICE", "AUDIO_UPDATE", $"Peer: {id}, Power: {state.Power}, VAD: {state.VoiceActive}");
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
                else if (cmd == "VOICE_PLAY")
                {
                    if (voice == null || !voice.connected)
                    {
                        Console.WriteLine("Voice not connected.");
                        return true;
                    }

                    string wavPath = arg.Trim();
                    if (string.IsNullOrEmpty(wavPath))
                    {
                        // Default search logic
                        var candidates = new[] {
                            Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "scarlet-fire.wav"),
                            Path.Combine(Directory.GetCurrentDirectory(), "scarlet-fire.wav"),
                            Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "..\\..\\..\\", "scarlet-fire.wav")
                        };
                        wavPath = candidates.FirstOrDefault(p => !string.IsNullOrEmpty(p) && File.Exists(p));
                    }

                    if (!string.IsNullOrEmpty(wavPath) && File.Exists(wavPath))
                    {
                        EncounterLogger.Log("Visitant", "VOICE", "PLAY_WAV", $"Playing {wavPath}");
                        voice.PlayWavAsMic(wavPath, loop: true);
                    }
                    else
                    {
                        EncounterLogger.Log("Visitant", "VOICE", "PLAY_FAILURE", $"WAV file not found: {wavPath}");
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

    class Program
    {
        static void Main(string[] args)
        {
            new DeepSeaClientWithVoice().RunClient(args, "DeepSeaClient", "2.5.7");
        }
    }
}
