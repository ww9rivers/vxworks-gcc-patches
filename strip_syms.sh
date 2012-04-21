#!/bin/sh

OBJCOPY_EXE=$1
NM_EXE=$2
INOBJ=$3
OUTOBJ=$4

shift 4

$NM_EXE $* | cut -d ' ' -f 3 | sed '/^$/d' > /tmp/$$.syms
$OBJCOPY_EXE --localize-symbols=/tmp/$$.syms $INOBJ $OUTOBJ


