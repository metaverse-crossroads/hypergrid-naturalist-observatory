// experimental mock gateway service
// see: os-webrtc-janus
// [JanusWebRtcVoice] JanusGatewayURI = ${Const|BaseURL}:${Const|PublicPort}/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-janus

[assembly: Mono.Addins.Addin("MiniJanus", "0.0")]
[assembly: Mono.Addins.AddinDependency("OpenSim.Region.Framework", "0.0")]

/*
$ . species/opensim-core/plugins/oscsc.bash
$ oscsc species/opensim-core/plugins/MiniJanus.cs vivarium/opensim-core-master/bin/MiniJanus.dll
*/

namespace humbletim {
    using JSON = OpenMetaverse.StructuredData.OSDMap;
    using Scene = OpenSim.Region.Framework.Scenes.Scene;
    using Requests = System.Collections.Generic.Dictionary<OpenMetaverse.UUID, System.Threading.Tasks.Task<System.Collections.Hashtable>>;

    [Mono.Addins.Extension(Path = "/OpenSim/RegionModules", NodeName = "RegionModule", Id = "MiniJanus", InsertBefore="WebRtcVoiceServiceModule")]
    public class MiniJanus : OpenSim.Region.Framework.Interfaces.ISharedRegionModule
    {
        public string Name { get { return "MiniJanus"; } }
        public System.Type ReplaceableInterface { get { return null; } }
        public bool IsSharedModule { get { return true; } }
        public void Initialise(Nini.Config.IConfigSource source) {
            System.Console.WriteLine("[MiniJanus]: Initialise called!");
            m_log.Info("[MiniJanus]: Initialise(OpenSimBase) called - starting initialization");
            assertUsBeforeWebRtc();
            addPollingHandler(
                "/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-janus",
                OpenSim.Framework.Servers.MainServer.GetHttpServer(0)
            );
        }
        public void PostInitialise() { }
        public void Close() { }
        public void AddRegion(Scene scene) { } // scene.RegisterModuleInterface<HumbletimUsersPlugin>(this);
        public void RemoveRegion(Scene scene) { } // scene.UnregisterModuleInterface<HumbletimUsersPlugin>(this);
        public void RegionLoaded(Scene scene) { }

        // ===================================================================

        public void addPollingHandler(string uripath, OpenSim.Framework.Servers.HttpServer.IHttpServer httpServer){
            Requests requestTasks = new();
            httpServer.AddPollServiceHTTPHandlerVarPath(new OpenSim.Framework.Servers.HttpServer.PollServiceEventArgs(
                /* || OnRequest || */ delegate(OpenMetaverse.UUID requestID, OpenSim.Framework.Servers.HttpServer.OSHttpRequest request) {
                    var req = new JSON{
                        ["id"] = requestID,
                        ["method"] = request.HttpMethod,
                        ["uri"] = request.UriPath,
                        ["body"] = new System.IO.StreamReader(request.InputStream, System.Text.Encoding.UTF8).ReadToEnd(),
                    };
                    m_log.Info($"[MiniJanus]: MyAsyncHandler: {req}");
                    async System.Threading.Tasks.Task<System.Collections.Hashtable> DoAsyncWork() {
                        try {
                            JSON res = await ProcessRequestJSON(req);
                            m_log.Info($"[MiniJanus]: //MyAsyncHandler: {res}");
                            return new System.Collections.Hashtable {
                                ["str_response_string"] = res["body"].AsString(),
                                ["content_type"] = res["content-type"].AsString(),
                            };
                        } catch (System.Exception ex) {
                            m_log.Error($"[MiniJanus]: Task failed: {ex}");
                            return new System.Collections.Hashtable {
                                ["str_response_string"] = $"Internal error {ex}",
                                ["content_type"] = "text/plain",
                                ["int_response_code"] = 500
                            };
                        }
                    }
                    lock(requestTasks) requestTasks[requestID] = DoAsyncWork();
                    return null; // Defer to poll service manager
                },

                uripath,

                /* || HasEvents || */ delegate (OpenMetaverse.UUID requestID, OpenMetaverse.UUID pId) {
                    lock(requestTasks) return requestTasks.TryGetValue(requestID, out var task) && task.IsCompleted;
                },

                /* || GetEvents || */ delegate(OpenMetaverse.UUID requestID, OpenMetaverse.UUID pId) {
                    lock(requestTasks) {
                        if (requestTasks.TryGetValue(requestID, out var task) && task.IsCompleted) {
                            // Remove and return the result directly
                            requestTasks.Remove(requestID);
                            return task.Result;
                        }
                    }
                    throw new System.Exception($"This shouldn't happen if HasEvents returned true; requestID={requestID} pId={pId}");
                },

                /* || NoEvents || */ delegate(OpenMetaverse.UUID requestID, OpenMetaverse.UUID pId) {
                    lock(requestTasks) requestTasks.Remove(requestID); // Clean up on timeout
                    return new System.Collections.Hashtable {
                        ["str_response_string"] = "timeout",
                        ["content_type"] = "text/plain"
                    };
                },

                /* || Drop || */ delegate(OpenMetaverse.UUID requestID, OpenMetaverse.UUID pId) {
                    lock(requestTasks) requestTasks.Remove(requestID);
                },
                OpenMetaverse.UUID.Random(),
                30000
            ));
        }
        public static void assertUsBeforeWebRtc() {
            var nodes = Mono.Addins.AddinManager.GetExtensionNodes("/OpenSim/RegionModules");
            foreach (Mono.Addins.ExtensionNode node in nodes) {
                if (node.Id == "MiniJanus") break;
                if (node.Id.StartsWith("WebRtc", System.StringComparison.OrdinalIgnoreCase))
                    throw new System.Exception($"CRITICAL: {node.Id} loaded before MiniJanus. Ambient ordering failed.");
            }
        }
        private static readonly log4net.ILog m_log = log4net.LogManager.GetLogger(System.Reflection.MethodBase.GetCurrentMethod().DeclaringType);

        public static int N = 1;

        public static string stringify(JSON ob) { return OpenMetaverse.StructuredData.OSDParser.SerializeJsonString(ob); }
        public static JSON parse(string json) { return (JSON)OpenMetaverse.StructuredData.OSDParser.DeserializeJson(json); }
        public static async System.Threading.Tasks.Task sleep(double seconds) { await System.Threading.Tasks.Task.Delay((int)(seconds * 1000.0)); }

        public async System.Threading.Tasks.Task<JSON> ProcessRequestJSON(JSON httpRequest) {
            m_log.Info($"[Humbletim/MiniJanus]: ProcessRequestJSON: {httpRequest}");
            if (httpRequest["method"] == "GET") {
                if (httpRequest["uri"].AsString().EndsWith("/info")) {
                    return new JSON {
                        ["code"] = 200,
                        ["content-type"] = "application/json",
                        ["body"] = stringify(new JSON{ ["foo"] = "bar" }),
                    };
                }
                // TODO long polling mocks etc.
                await sleep(10);
                string responseBody = stringify(new JSON {
                    ["janus"] = "error",
                    ["transaction"] = "GET",
                    ["error"] = new JSON {
                        ["code"] = N++,
                        ["reason"] = $"TODO {httpRequest["uri"]}",
                    }
                });
                return new JSON {
                    ["code"] = 200,
                    ["content-type"] = "application/json",
                    ["body"] = responseBody,
                };
            } else if (httpRequest["method"] == "POST") {
                JSON parsed = parse(httpRequest["body"].AsString());
                m_log.Info($"[Humbletim/MiniJanus]: POST: {parsed}");

                JSON jsonObj;
                if (parsed["janus"] == "create") {
                    jsonObj = new JSON {
                        ["janus"] = "success",
                        ["transaction"] = parsed["transaction"],
                        ["data"] = new JSON {
                            ["id"] = N++,
                        }
                    };
                } else if (parsed["janus"] == "attach") {
                    jsonObj = new JSON {
                        ["janus"] = "success",
                        ["transaction"] = parsed["transaction"],
                        ["data"] = new JSON {
                            ["id"] = N++,
                        }
                    };
                } else {
                    jsonObj = new JSON {
                        ["janus"] = "error",
                        ["transaction"] = parsed["transaction"],
                        ["error"] = new JSON {
                            ["code"] = N++,
                            ["reason"] = $"TODO {parsed["janus"]}",
                        }
                    };

                }

                return new JSON{
                    ["code"] = 200,
                    ["content-type"] = "application/json",
                    ["body"] = stringify(jsonObj),
                };
            } else
            return new JSON{
                ["code"] = 405, // Not Allowed
                ["content-type"] = "text/plain",
                ["body"] = $"MethodNotAllowed {httpRequest}",
            };
        }
    } // MiniJanus
} // humbletim
