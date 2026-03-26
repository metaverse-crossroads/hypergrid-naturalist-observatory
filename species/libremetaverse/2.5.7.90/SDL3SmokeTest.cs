// smoke-test.cs
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

/*

uname -a
cat /etc/issue
pushd vivarium/
set -x
wget -q https://github.com/Aermoss/PySDL3-Build/releases/download/v3.4.2/Linux-AMD64-v3.4.2.zip
sudo unzip -d /usr/local/lib Linux-AMD64-v3.4.2.zip libSDL3.so
objdump -T /usr/local/lib/libSDL3.so | grep -o 'GLIBC_[0-9.]*' | sort -V | uniq
ldd /usr/local/lib/libSDL3.so
popd
export DOTNET_ROOT=`./observatory/substrate/ensure_dotnet.sh`
export PATH=$DOTNET_ROOT:$PATH
dotnet --version
which dotnet
echo <<EOF>Blah.cs
// smoke-test.cs
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
dotnet run Blah.cs

exit 55
*/