#!/bin/bash
##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift Cluster Membership open source project
##
## Copyright (c) 2018-2019 Apple Inc. and the Swift Cluster Membership project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.md for the list of Swift Cluster Membership project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

set -e

my_path="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
root_path="$my_path/../.."

short_version=$(git describe --abbrev=0 --tags 2> /dev/null || echo "0.0.0")
long_version=$(git describe             --tags 2> /dev/null || echo "0.0.0")
if [[ "$short_version" == "$long_version" ]]; then
  version="${short_version}"
  doc_link_version="${version}"
else
  version="${short_version}-dev"
  doc_link_version="master" # since dev is latest development we point to master
fi
echo "Project version: ${version}"

# all our public modules which we want to document
modules=(
  SWIM
  SWIMNIOExample
)

declare -r build_path_linux='.build/x86_64-unknown-linux-gnu'

if [[ "$(uname -s)" == "Linux" ]]; then
  # build code if required
    swift build
  # setup source-kitten if required
  mkdir -p "$root_path/.build/sourcekitten"
  source_kitten_source_path="$root_path/.build/sourcekitten/source"
  source_kitten_path="$source_kitten_source_path/$build_path_linux/release"
  if [[ ! -f "$source_kitten_path/sourcekitten" ]]; then
    git clone https://github.com/jpsim/SourceKitten.git "$source_kitten_source_path"
  fi
    rm -rf "$source_kitten_source_path/.swift-version"
    cd "$source_kitten_source_path" && swift build -c release && cd "$root_path"
  # generate
  for module in "${modules[@]}"; do
#    if [[ ! -f "$root_path/.build/sourcekitten/$module.json" ]]; then
      # always generate, otherwise we miss things when we're iterating on adding docs.
      echo "Generating $root_path/.build/sourcekitten/$module.json ..."
      "$source_kitten_path/sourcekitten" doc --spm-module "$module" > "$root_path/.build/sourcekitten/$module.json"
#    fi
  done
fi

# prep index
tmp=`mktemp -d`
module_switcher="${tmp}/README.md"
touch $module_switcher
jazzy_args=(--clean
            --swift-build-tool spm
            --readme "$module_switcher"
            --config "$my_path/.jazzy.json"
            --documentation=${root_path}/Docs/*.md
            --github-file-prefix https://github.com/apple/swift-cluster-membership/blob/$doc_link_version
            --theme fullwidth
           )

# run jazzy
if ! command -v jazzy > /dev/null; then
  gem install jazzy --no-ri --no-rdoc
fi

mkdir -p "$root_path/.build/docs/jazzy/api/$version"
mkdir -p "$root_path/.build/docs/jazzy/docset/$version"
for module in "${modules[@]}"; do
  args=("${jazzy_args[@]}" --output "$root_path/.build/docs/jazzy/api/$version/$module" --docset-path "$root_path/.build/docs/jazzy/docset/$version/$module" --module "$module")
  if [[ "$(uname -s)" == "Linux" ]]; then
    args+=(--sourcekitten-sourcefile "$root_path/.build/sourcekitten/$module.json")
  fi

  cat "$my_path/includes/${module}_README.md" > "$module_switcher"
  for module in "${modules[@]}"; do
    echo " - [$module](../$module/index.html)" >> "$module_switcher"
  done

  jazzy "${args[@]}"
done

echo "Done."
