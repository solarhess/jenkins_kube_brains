#!/bin/bash
set -x

function time() {
	STARTMS=$(date +%s%3N)
    $@
	ENDMS=$(date +%s%3N)
    let ELAPSED=ENDMS-STARTMS
	echo "Time: $ELAPSED ms"
}

echo 
echo 
echo "Write throughput for workspace volume"
echo 
echo "  writes one large 1 GB file to the jenkins job workspace"
echo 
time dd if=/dev/zero of=$WORKSPACE/testfile bs=1G count=1 oflag=direct
time rm -rf $WORKSPACE/testfile

echo 
echo 
echo "Write latency for workspace"
echo 
echo "  writes 1000 chunks of 0.5 kb to the jenkins job workspace"
echo 
time dd if=/dev/zero of=$WORKSPACE/testfile bs=512 count=1000 oflag=direct
time rm -rf $WORKSPACE/testfile

echo 
echo 
echo "Write Directory Tree"
echo 
echo "  creates 100 directories with 200 files in each directory"
echo 
set +x
STARTMS=$(date +%s%3N)
mkdir $WORKSPACE/sampledir
COUNTER=0
while [  $COUNTER -lt 100 ]; do
  mkdir -p $WORKSPACE/sampledir/$COUNTER
  COUNTER2=0
  while [  $COUNTER2 -lt 100 ]; do
  	touch $WORKSPACE/sampledir/$COUNTER/$COUNTER2
	touch $WORKSPACE/sampledir/$COUNTER/$COUNTER2
	let COUNTER2=COUNTER2+1 
  done
  let COUNTER=COUNTER+1 
done 
ENDMS=$(date +%s%3N)

let ELAPSED=ENDMS-STARTMS
echo "Time: $ELAPSED ms"

rm -rf $WORKSPACE/sampledir