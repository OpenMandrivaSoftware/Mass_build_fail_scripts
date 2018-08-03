#!/bin/sh
# Automatically fix some common errors detected during mass build
# (C) 2018 Bernhard "Bero" Rosenkraenzer <bero@lindev.ch>
# Released under the GPLv3

OURDIR="$(realpath $(dirname $0))"

. ${OURDIR}/abftools.sh

archId znver1
platformId cooker
buildlog 193516
latestSuccessfulBuild cooker boost znver1
