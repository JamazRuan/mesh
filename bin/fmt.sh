#!/bin/bash

# Copyright 2018 Istio Authors
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Applies requisite code formatters to the source tree
# fmt.sh -c check only.

set -e

SCRIPTPATH=$( cd "$(dirname "$0")" ; pwd -P )

# Go format tool to use
# While 'goimports' is preferred we temporarily use 'gofmt' until https://github.com/golang/go/issues/28200 is resolved
GO_FMT_TOOL=goimportsdocker

check=false

case $1 in
    -c|--check)
    check=true
esac

ROOTDIR=$SCRIPTPATH/..
cd "$ROOTDIR"

GOPATH=$(cd "$ROOTDIR/../../.."; pwd)
export GOPATH
export PATH=$GOPATH/bin:$PATH

PKGS=${PKGS:-"."}
if [[ -z ${GO_FILES} ]];then
  GO_FILES=$(find "${PKGS}" -type f -name '*.go' ! -name '*.gen.go' ! -name '*.pb.go' ! -name '*mock*.go' | grep -v ./vendor)
fi

# need to pin goimports to align with golangci-lint. SHA is from x/tools repo
GO_IMPORTS_DOCKER="gcr.io/istio-testing/goimports:92cdcd90bf52"
if [ $GO_FMT_TOOL = "goimportsdocker" ]; then
  tool="docker run -i --rm \
    -v $(pwd):/go/src/istio.io/istio \
    -w /go/src/istio.io/istio ${GO_IMPORTS_DOCKER} /goimports"
  check_args="-d -local istio.io"
  fmt_args="-w -local istio.io"
fi

if [ $GO_FMT_TOOL = "goimports" ]; then
  go get -u golang.org/x/tools/cmd/goimports
  tool=${GOPATH}/bin/goimports
  check_args="-l -local istio.io"
  fmt_args="-w -local istio.io"

  if [[ -d "${tool}" ]];then
      echo "download golang.org/x/tools/cmd/goimports failed"
      exit 1
  fi
fi

if [ $GO_FMT_TOOL = "gofmt" ]; then
  tool=gofmt
  check_args="-l"
  fmt_args="-w"
fi

if [ $check = false ]; then
  echo "formatting the source files"
  # shellcheck disable=SC2086
  $tool $fmt_args ${GO_FILES}
# Passing a long list of files to the tool has the benefit for a docker-based tool, since docker takes
# a long time to start-up. However, this does not work well on circle CI due to hitting limits on argv.
# Therefore, preserving the old style in comments, in case we want to switch to using circle again for this.
#
#  for fl in ${GO_FILES}; do
#    if head -20 "$fl" | grep "Code generated by counterfeiter" > /dev/null; then
#       continue
#    fi
#    if head -20 "$fl" | grep "Code generated by go-bindata" > /dev/null; then
#       continue
#    fi
#    $tool $fmt_args "$fl"
#  done
  exit $?
fi

ERR=0

# shellcheck disable=SC2086
file_needs_formatting=$($tool $check_args ${GO_FILES})
if [[ -n "$file_needs_formatting" ]]; then
  echo "please run bin/fmt.sh against: $file_needs_formatting"
  ERR=1
fi

# for fl in ${GO_FILES}; do
#  $tool $check_args $fl
#  if head -20 "$fl" | grep "Code generated by counterfeiter" > /dev/null; then
#    continue
#  fi
#  if head -20 "$fl" | grep "Code generated by go-bindata" > /dev/null; then
#    continue
#  fi
#  file_needs_formatting=$($tool $check_args "$fl")
#  if [[ -n "$file_needs_formatting" ]]; then
#    echo "please run bin/fmt.sh against: $file_needs_formatting"
#    ERR=1
#  fi
#done

if ((ERR != 0)); then
  exit 1
fi

