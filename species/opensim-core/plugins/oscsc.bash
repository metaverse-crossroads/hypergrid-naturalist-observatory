#!/bin/bash

function dotnet() {
    test -v DOTNET_ROOT || { echo "!DOTNET_ROOT" >&2 ; return 4 ; }
    test -d $DOTNET_ROOT || { echo "!$DOTNET_ROOT" >&2 ; return 5; } 
    $DOTNET_ROOT/dotnet "$@"
}

declare -xf dotnet

function mspath() {
    if which cygpath 2>&1 >/dev/null ; then
        cygpath -ms "$1"
    else
        echo "$1"
    fi
}

dotnet_root_rel() {
    realpath --relative-base=$PWD "$(cd "$DOTNET_ROOT" && pwd)"
}

function corers-lib() {
    local lib=$(dotnet_root_rel)/shared/Microsoft.NETCore.App/$(dotnet --list-runtimes | grep "Microsoft.NETCore.App" | tail -n1 | cut -d' ' -f2)
    mspath "$lib"
}

function corers_rel() {(
    cd $(corers-lib)
    fgrep BSJB -l {System.*,Microsoft.*,mscorlib,netstandard}.dll | fgrep -v .Native. | sed 's/^/-r:/'
)}


function corers_abs() {(
    fgrep BSJB -l $(corers-lib)/{System.*,Microsoft.*,mscorlib,netstandard}.dll | fgrep -v .Native. | sed 's/^/-r:/'
)}

function localrs_rel() {(
    local lib=$1 output=$2
    cd $lib
    fgrep BSJB -l *.dll | fgrep -v $(basename $output) | sed 's/^/-r:/'
)}

# function localrs_abs() {(
#     local lib=$1 output=$2
#     fgrep BSJB -l $lib/*.dll | fgrep -v $(basename $output) | sed 's/^/-r:/'
# )}

function confess() { echo "$*" >&2 ; "$@"; }

function cspp() {
    local tmp_dir=$(mktemp -d)
    test -d "$tmp_dir" || { echo "!tmp_dir $tmp_dir" ; return 34; }
    trap "test ! -d '$tmp_dir' || rm -irv '$tmp_dir'; trap - RETURN" RETURN

    local sources=()
    local output=""
    local flags=()

    # Simple ArgParse: Sort incoming args into buckets
    for arg in "$@"; do
        if [[ "$arg" == /dev/fd/* ]]; then
            ls -l $arg
            cat $arg > $tmp_dir/${arg//\//_}.cs
            sources+=("$tmp_dir/${arg//\//_}.cs")
        elif [[ "$arg" == *.cs ]]; then
            sources+=("$arg")
        elif [[ "$arg" == -* ]]; then
            flags+=("$arg")
        else
            # The first non-.cs, non-hyphenated arg is our output
            [[ -z "$output" ]] && output="$arg" || flags+=("$arg")
        fi
    done

    local out=${output%.*}.dll
    local lib=$(mspath "$(dirname $output)")
    local csc=$(dotnet_root_rel)/sdk/$(dotnet --version)/Roslyn/bincore/csc.dll
    [[ "$output" == *.exe ]] && local target=exe || local target=library

    local tmp_out="$tmp_dir/$(basename "$output")"

    # core managed dlls
    cat << EOF > $tmp_dir/managed-dlls.rsp
-lib:$(corers-lib)
$(corers_rel)
-lib:$lib
$(localrs_rel $lib $out)
EOF

# local additionalProbingPaths=$(true || (
#     ( echo "${flags[@]}" ; cat $tmp_dir/managed-dlls.rsp ) | grep -oE -- '-lib:[^ ]+' | sed 's/-lib://'
#     ( echo "${flags[@]}" ; cat $tmp_dir/managed-dlls.rsp ) | grep -oE -- '-r:[^ ]+' | sed 's/-r://' | xargs -r -n1 dirname 
# ) | xargs -r -n1 realpath | xargs -r -n1 cygpath -ma | sort -u | sed 's/.*/"&"/' | paste -sd, -)

    echo ""
    confess dotnet "$csc" -debug+ -langversion:12 -nologo -target:$target -out:"$out" @$tmp_dir/managed-dlls.rsp "${sources[@]}"  "${flags[@]}" || {
        echo ""
        local err=$?
        mv $tmp_dir/managed-dlls.rsp -v /tmp/
        rmdir $tmp_dir
        return $err
    }
    echo ""
    mv $tmp_dir/managed-dlls.rsp -v /tmp/
    # mv -v $tmp_out $out
    rmdir $tmp_dir
    set +x


# local all_probing=$(printf "%s\n%s" "$r_dirs" "$lib_dirs" | grep . | sort -u | sed 's/.*/"&"/' | paste -sd, -)


local net_version=$(dotnet --version | cut -d. -f1-2)
( cat << EOF | tee "${output%.*}.runtimeconfig.json"
{
  "runtimeOptions": {
    "tfm": "net${net_version}",
    "framework": {
      "name": "Microsoft.NETCore.App",
      "version": "${net_version}.0"
    }
  }
}
EOF
)
#    "additionalProbingPaths": [ $additionalProbingPaths ]

# ( cat << EOF | tee "${output%.*}.exe.config"
# <?xml version="1.0" encoding="utf-8"?>  
# <configuration>  
#   <runtime>  
#     <assemblyBinding xmlns="urn:schemas-microsoft-com:asm.v1">  
#       <probing privatePath="${r_dirs}" />  
#     </assemblyBinding>  
#   </runtime>  
# </configuration>
# EOF
# )
    ls -l ${output%.*}.*
}

# observatory opensim-core plugin helper
# (compiles singleton .cs directly into a Mono.Addin .dll)
oscsc_SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )/../.." && pwd )"
function oscsc() {(
    test -v DOTNET_ROOT || { echo "!DOTNET_ROOT" >&2 ; return 40 ; }
    local SCRIPT_DIR="${oscsc_SCRIPT_DIR}"
    local REPO_ROOT="$(dirname "$SCRIPT_DIR")"
    set -euo pipefail
    local cs=$1
    local out=$2
    shift 2
    local RDEPS=(-r:{Nini,Mono.Addins,OpenSim.Framework,OpenSim.Framework.Servers.HttpServer,OpenSim.Region.Framework,OpenSim.Region.CoreModules,OpenSim.Services.UserAccountService,log4net,OpenSim,OpenMetaverse,OpenSim.Services.Interfaces,XMLRPC,OpenSim.Framework.Console,OpenMetaverseTypes,OpenSim.Framework,OpenSim.Framework.Servers.HttpServer,OpenSim.Framework.Servers,OpenSim.Server.Handlers,OpenMetaverse.StructuredData,OpenSim.Capabilities}.dll)
    local cls=$(basename -s .cs $cs)
    local ext="${out##*.}"
    local target=library
    [[ "$ext" == exe ]] && target=exe
    local id=$(basename -s .$ext $out)
    local dll=$(dirname $out)/$id.$ext
    local SIMULANT_FQN=$(basename $(dirname $(dirname $dll)))
    . $REPO_ROOT/instruments/substrate/observatory_env.bash ;
    #$(dirname $(readlink -f $(which dotnet)))
    export PATH="$(cd $DOTNET_ROOT && pwd):$PATH"
    $DOTNET_ROOT/dotnet $DOTNET_ROOT/sdk/$(dotnet --version)/Roslyn/bincore/csc.dll \
        -target:$target \
        -out:$dll $cs \
        $(corers_abs) \
        -lib:$(dirname $dll) \
        "${RDEPS[@]}" -nologo "$@"
    ls -l $dll
)}

# # this is not needed but left for reference
# # (having an .addin to go with .dll bypasses certain Mono [Extension(...)] limitations)
# function _oscsc_mkaddin() {(
#     set -euo pipefail
#     local cls=$(basename -s .cs $1)
#     local id=$(basename -s .dll $2)
#     local dll=$(dirname $2)/$id.dll
#     local addin=${dll/.dll/.addin}
#     . ${REPO_ROOT:-$PWD}/instruments/substrate/observatory_env.bash ;
# cat << EOF > $addin
# <Addin id="$id" version="1.0" isroot="false">
#   <Dependencies><Addin id="OpenSim.Region.Framework" version="0.0" /></Dependencies>
#   <Runtime><Import assembly="$id.dll"/></Runtime>
#   <Extension path="/OpenSim/RegionModules">
#       <RegionModule id="$id" class="humbletim.$cls" insertbefore="${3:-*}" />
#   </Extension>
# </Addin>
# EOF
#     ls -l $addin
# )}

