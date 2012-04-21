#!/bin/bash
TCL_SCRIPT="`dirname "$0"`/wind_base/host/resource/hutils/tcl/munch.tcl"
NM_EXE=$1
OUTPUT_FILE=$2
shift 2
"$NM_EXE" $* | tclsh "$TCL_SCRIPT" -c ppc | sed 's/extern void\(.*\);/extern void \1 __attribute__((externally_visible));/' > "$OUTPUT_FILE"
