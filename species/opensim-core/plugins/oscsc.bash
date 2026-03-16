#!/bin/bash

# observatory opensim-core plugin helper
# (compiles singleton .cs directly into a Mono.Addin .dll)
function oscsc() {(
    set -euo pipefail
    local cls=$(basename -s .cs $1)
    local id=$(basename -s .dll $2)
    local dll=$(dirname $2)/$id.dll
    local SIMULANT_FQN=$(basename $(dirname $(dirname $dll)))
    . ${REPO_ROOT:-$PWD}/instruments/substrate/observatory_env.bash ;
    #$(dirname $(readlink -f $(which dotnet)))
    dotnet $DOTNET_ROOT/sdk/$(dotnet --version)/Roslyn/bincore/csc.dll \
        -target:library \
        -out:$dll $1 \
$(find $DOTNET_ROOT/shared/Microsoft.NETCore.App/$(dotnet --list-runtimes | grep "Microsoft.NETCore.App" | tail -n1 | cut -d' ' -f2) \
    -maxdepth 1 \
    \( -name "System.*.dll" -o -name "Microsoft.*.dll" -o -name "mscorlib.dll" -o -name "netstandard.dll" \) \
    -not -name "*.Native.*" \
    -printf "-r:%p ")\
        -lib:$(dirname $dll) \
        -r:{Nini,Mono.Addins,OpenSim.Framework,OpenSim.Framework.Servers.HttpServer,OpenSim.Region.Framework,OpenSim.Region.CoreModules,OpenSim.Services.UserAccountService,log4net,OpenSim,OpenMetaverse,OpenSim.Services.Interfaces,XMLRPC,OpenSim.Framework.Console,OpenMetaverseTypes,OpenSim.Framework,OpenSim.Framework.Servers.HttpServer,OpenSim.Framework.Servers,OpenSim.Server.Handlers,OpenMetaverse.StructuredData}.dll -nologo
    ls -l $dll
)}

# this is not needed but left for reference
# (having an .addin to go with .dll bypasses certain Mono [Extension(...)] limitations)
function _oscsc_mkaddin() {(
    set -euo pipefail
    local cls=$(basename -s .cs $1)
    local id=$(basename -s .dll $2)
    local dll=$(dirname $2)/$id.dll
    local addin=${dll/.dll/.addin}
    . ${REPO_ROOT:-$PWD}/instruments/substrate/observatory_env.bash ;
cat << EOF > $addin
<Addin id="$id" version="1.0" isroot="false">
  <Dependencies><Addin id="OpenSim.Region.Framework" version="0.0" /></Dependencies>
  <Runtime><Import assembly="$id.dll"/></Runtime>
  <Extension path="/OpenSim/RegionModules">
      <RegionModule id="$id" class="humbletim.$cls" insertbefore="${3:-*}" />
  </Extension>
</Addin>
EOF
    ls -l $addin
)}
