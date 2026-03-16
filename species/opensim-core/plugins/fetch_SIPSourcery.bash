# ---------------------------------------------------------
    # NEW: The 100% Glassbox Dependency Fetcher (Corrected Versions)
    # ---------------------------------------------------------
    echo "Fetching SIPSorcery via raw HTTP (Zero MSBuild magic)..."
    
    mkdir -p .deps_sandbox
    pushd .deps_sandbox > /dev/null

    # 1. Download raw .nupkg zip files directly from NuGet API
    dl() {
        echo "... $3" >&2
        curl -sS -C - -L "$@"
    }
    dl -o sipsorcery.zip "https://www.nuget.org/api/v2/package/SIPSorcery/8.0.12"
    dl -o sipsorcery_media.zip "https://www.nuget.org/api/v2/package/SIPSorceryMedia.Abstractions/8.0.12"
    dl -o bouncycastle.zip "https://www.nuget.org/api/v2/package/Portable.BouncyCastle/1.9.0"
    dl -o logging.zip "https://www.nuget.org/api/v2/package/Microsoft.Extensions.Logging.Abstractions/9.0.0"
    dl -o concentus.zip "https://www.nuget.org/api/v2/package/Concentus/2.2.2"
    dl -o dnsclient.zip "https://www.nuget.org/api/v2/package/DnsClient/1.8.0"
    dl -o websocketsharp.zip "https://www.nuget.org/api/v2/package/SIPSorcery.WebSocketSharp/0.0.1"

    # 2. Unzip ONLY the required netstandard2.0 DLLs directly into OpenSim's bin/ folder 
    unzip -jo sipsorcery.zip "lib/netstandard2.0/SIPSorcery.dll" -d ../bin/
    unzip -jo sipsorcery_media.zip "lib/netstandard2.0/SIPSorceryMedia.Abstractions.dll" -d ../bin/
    unzip -jo bouncycastle.zip "lib/netstandard2.0/BouncyCastle.Crypto.dll" -d ../bin/
    unzip -jo logging.zip "lib/netstandard2.0/Microsoft.Extensions.Logging.Abstractions.dll" -d ../bin/
    unzip -jo concentus.zip "lib/netstandard2.0/Concentus.dll" -d ../bin/
    unzip -jo dnsclient.zip "lib/netstandard2.0/DnsClient.dll" -d ../bin/
    unzip -jo websocketsharp.zip "lib/netstandard2.0/websocket-sharp.dll" -d ../bin/

    popd > /dev/null
    
    # We deliberately DO NOT rm -rf .deps_sandbox so you can audit the zip files.
    # ---------------------------------------------------------
