// lets SIPSorcery live out-of-tree use of as-is upstream libremetaverse "WebRtcTest"
/*
$ . instruments/substrate/observatory_env.bash
$ . species/opensim-core/plugins/oscsc.bash
$ cspp species/libremetaverse/2.5.7.90/WebRtcTest.Bootstrapper.cs -main:WebRtcTest.Bootstrapper \
    vivarium/libremetaverse-2.5.7.90/Programs/WebRtcTest/*.cs \
    vivarium/libremetaverse-2.5.7.90/bin/net8.0/WebRtcTest.exe 
*/

namespace WebRtcTest {
     internal class Bootstrapper {
        [System.STAThread]
        private static void Main(string[] args) {
            string wtf = System.AppDomain.CurrentDomain.BaseDirectory + @"\..\..\DeepSeaClient_Project\bin\Release\net8.0\";
            // System.Reflection.Assembly.LoadFrom(wtf + "SIPSorceryMedia.Abstractions.dll");
            // System.Reflection.Assembly.LoadFrom(wtf + "SIPSorcery.dll");
            // System.Reflection.Assembly.LoadFrom(wtf + "SIPSorceryMedia.SDL3.dll");
            System.Console.WriteLine("Bootstrapper");
            System.Environment.SetEnvironmentVariable("PATH", System.Environment.GetEnvironmentVariable("PATH") + ";" + wtf + @"runtimes\win-x64\native");
            // System.AppDomain.CurrentDomain.AssemblyResolve += (sender, args) => {  
            //     System.Console.WriteLine($"...AssemblyResolve {args.Name}");
            //     string dll = new System.Reflection.AssemblyName(args.Name).Name;
            //     if (dll.StartsWith("SIPSorcery")) {  
            //         string ass = wtf + dll + ".dll";
            //         System.Console.WriteLine($"...... {ass}");
            //         return System.Reflection.Assembly.LoadFrom(ass);  
            //     }  
            //     return null;
            // };
            var targetType = System.Type.GetType("WebRtcTest.WebRtcTest, WebRtcTest");
            if (targetType != null) {
                var mainMethod = targetType.GetMethod("Main", System.Reflection.BindingFlags.Static | System.Reflection.BindingFlags.NonPublic);
                if (mainMethod != null) {
                    // Invoke the private static Main(string[] args)
try {
    var task = (System.Threading.Tasks.Task)mainMethod.Invoke(null, new object[] { args });
   task.GetAwaiter().GetResult();
}
catch (System.Reflection.TargetInvocationException ex) {
    // This catches errors inside the Main method
    System.Console.WriteLine("INNER EXCEPTION: " + ex.InnerException?.Message);
    System.Console.WriteLine("STACK: " + ex.InnerException?.StackTrace);
}
catch (System.Exception ex) {
    System.Console.WriteLine("GENERAL EXCEPTION: " + ex.Message);
}

                }
            }            
        }
     }
}
