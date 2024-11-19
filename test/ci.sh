#!/usr/bin/env bash

set -e

export LANG="C.UTF-8"

# Used for CI. Runs the given version and each tool individually, so we can
# see how long each tool takes to load. Note that some ghc+tool combinations
# are skipped due to e.g. poor caching or lack of support.
#
# See NOTE: [GHC 9.8.3 Tools]
declare -A tool_map
tool_map[default,bare]="bare"
tool_map[default,ormolu]="true"
tool_map[ghc981,ormolu]="false" # poor caching
tool_map[ghc983,ormolu]="false" # poor caching
tool_map[default,fourmolu]="true"
tool_map[ghc981,fourmolu]="false" # poor caching
tool_map[ghc983,fourmolu]="false" # poor caching
tool_map[default,apply-refact]="true"
tool_map[ghc981,apply-refact]="false" # unsupported
tool_map[ghc983,apply-refact]="false" # poor caching
tool_map[ghc9101,apply-refact]="false" # unsupported
tool_map[default,hlint]="true"
tool_map[ghc981,hlint]="false" # poor caching
tool_map[ghc983,hlint]="false" # poor caching
tool_map[ghc9101,hlint]="false" # unsupported

ghc_version=""
tool_list="bare ormolu fourmolu hlint apply-refact"

while [ $# -gt 0 ]; do
  case "$1" in
    "-h" | "--help")
      echo -e "ci: Script used for CI testing.\n"
      echo "Usage: ci.sh (-g|--ghc GHC)"
      echo "             [-h|--help]"
      echo ""
      echo "Available options:"
      echo -e "  -g,--ghc\tGHC version to test."
      exit 0
      ;;
    "-g" | "--ghc")
      ghc_version=$2
      shift
      ;;
    *)
      echo "Unexpected arg: '$1'. Try --help."
      exit 1
    esac
    shift
  done

set +e

succeeded_str="Succeeded:"
failed_str="Failed:"
any_failed=0

if [[ -z $ghc_version ]]; then
  echo "Option --ghc is required."
  exit 1
fi

for tool in $tool_list; do
  map=${tool_map[$ghc_version,$tool]}

  # Didn't find an entry for ghc_version, try the default.
  if [[ -z $map ]]; then
    map=${tool_map[default,$tool]}
  fi

  if [[ -z $map ]]; then
    echo "*** ci.sh: Error finding map for tool ${$tool}, ghc ${ghc_version} ***"
    exit 1
  fi

  switch=${map[$ghc_version]}

  exit_code=0
  if [[ $switch == "bare" ]]; then
    echo "*** ci.sh: Testing ($ghc_version, $tool) ***"

    ./test/load_shell.sh \
      --ghc $ghc_version \
      --no-tools \
      --verbose

    exit_code=$?

  elif [[ $switch == "true" ]]; then
    echo "*** ci.sh: Testing tool ($ghc_version, $tool) ***"

    ./test/load_shell.sh \
      --ghc $ghc_version \
      --no-tools \
      --$tool true \
      --verbose

    exit_code=$?

  elif [[ $switch == "false" ]]; then
    echo "*** ci.sh: Skipping $tool ***"
    exit_code=0
  else
    echo "*** ci.sh: Error, unexpected switch value: $switch ***"
    exit 1
  fi

  if [[ $exit_code -ne 0 ]]; then
    echo "*** ci.sh: ($ghc_version, $tool) Failed ***"
    failed_str+=" ($ghc_version, $tool)"
    any_failed=1
  else
    echo "*** ci.sh: ($ghc_version, $tool) Succeeded ***"
    succeeded_str+=" ($ghc_version, $tool)"
  fi
done

echo $succeeded_str
echo $failed_str
exit $any_failed
