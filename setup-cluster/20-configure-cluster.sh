
#!/bin/bash
set -eio pipefail

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
cd $DIR

source ./files/common
source $DIR/out/common # Use the AWS testbed, override cluster spec in files/common with out/common 

uploadFiles $MASTER_NODE_HOSTNAME

ssh $SSH_OPTS admin@$MASTER_NODE_HOSTNAME bash -x files/configure-cluster.sh
