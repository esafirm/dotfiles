## Create file with certain size
createfile(){
	dd if=/dev/zero of=output.dat  bs=1m  count=$1
}
