export DOTNET_CLI_TELEMETRY_OPTOUT=1
export DOTNET_ROOT="$(bash -x ./instruments/substrate/ensure_dotnet.sh)"
wget -P /tmp -q https://github.com/Aermoss/PySDL3-Build/releases/download/v3.4.2/Linux-AMD64-v3.4.2.zip
unzip -d vivarium/substrate/dotnet-8.0/shared/Microsoft.NETCore.App/8.0.25 /tmp/Linux-AMD64-v3.4.2.zip libSDL3.so


uname -a
cat /etc/issue

export git_user=/dev/null

# /bin/echo -e 'canary() { $* ;  }\ndeclare -xf canary' | tee bin/canary 
#mkdir vivarium -pv
# objdump -T /usr/local/lib/libSDL3.so | grep -o 'GLIBC_[0-9.]*' | sort -V | uniq
# ldd /usr/local/lib/libSDL3.so
# ls -l ./instruments/substrate/ensure_dotnet.sh

# ls -l vivarium/substrate/dotnet-8.0
wget -P /tmp -q https://github.com/Aermoss/PySDL3-Build/releases/download/v3.4.2/Linux-AMD64-v3.4.2.zip
unzip -d vivarium/substrate/dotnet-8.0/shared/Microsoft.NETCore.App/8.0.25 /tmp/Linux-AMD64-v3.4.2.zip libSDL3.so

test -d "$DOTNET_ROOT" || exit 224
export PATH=$DOTNET_ROOT:$PATH
dotnet --version
which dotnet

# 1. Create a quick disposable project folder
mkdir sdl-test && cd sdl-test

# 2. Generate a standard .NET 8 console project (.csproj)
dotnet new console

# 3. Overwrite the default Program.cs with our smoke test
cat << 'EOF' > Program.cs
using System;
using System.Runtime.InteropServices;

class Program {
    [DllImport("SDL3", CallingConvention = CallingConvention.Cdecl)]
    public static extern int SDL_GetVersion();

    static void Main() {
        try {
            int version = SDL_GetVersion();
            Console.WriteLine($"SUCCESS: Loaded SDL3 Version {version}");
        } catch (Exception e) {
            Console.WriteLine($"FAIL: {e.Message}");
        }
    }
}
EOF

# 4. Run it (pointing to your newly scavenged library)
xLD_LIBRARY_PATH=/usr/local/lib dotnet run

exit 55