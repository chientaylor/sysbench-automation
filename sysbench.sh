#!/bin/bash

# DEFINITIONS
# LOCALIPERF - String for the local iPerf server's address or DNS name.
#	If LOCALIPERF is set to 'none', the local iPerf test will not be run.
# OSINT - Interger for OS ( 1 for Debian/Ubuntu, 2 for CentOS, 3 for FreeBSD [NOT WORKING])
# PLATINT - Interger for Source Platform ( 0; Baremetal, 1; Proxmox, 2; Xen/XenServer, 3; Hyper-V Server, 4; VMware (ESXi and vSphere), 5; oVirt )
# OS - String for the OS
# PLATFORM - String for the platform
# SYSTEM - String for the combination of the OS and Platform in the order "OS-PLATFORM"

LOCALIPERF = none

while [ "$OSINT" != '1' ] && [ "$OSINT" != '2' ] && [ "$OSINT" != '3' ]; do
	echo "What Operating system?"
	echo "1: Debian/Ubuntu"
	echo "2: CentOS"
	echo "3: FreeBSD (Testing)"
	read OSINT
done


while [ "$PLATINT" != '0' ] && [ "$PLATINT" != '1' ] && [ "$PLATINT" != '2' ] && [ "$PLATINT" != '3' ] && [ "$PLATINT" != '4' ] && [ "$PLATINT" != '5' ]; do
	echo "What Platform?"
	echo "0: Baremetal"
	echo "1: ProxMox"
	echo "2: XenServer"
	echo "3: Hyper-V"
	echo "4: VMware"
	echo "5: oVirt"
	read PLATINT
done


if [ "$OSINT" == '1' ]; then
        OS='Debian'
        apt update
        apt install sysbench iperf -y
elif [ "$OSINT" = '2' ]; then
        OS='CentOS'
        yum update -y
        yum install epel-release -y
        yum install sysbench iperf -y
elif [ "$OSINT" = '3' ]; then
	OS='FreeBSD'
	pkg update
	pkg install sysbench iperf -y
else
	echo "Something has gone wrong with OS detection! Exiting!"
	exit 1
fi


if [ "$PLATINT" == '0' ]; then
	PLATFORM='Baremetal' 
elif [ "$PLATINT" == '1' ]; then
	PLATFORM='ProxMox'
elif [ "$PLATINT" == '2' ]; then
	PLATFORM='XenServer'
elif [ "$PLATINT" == '3' ]; then
	PLATFORM='Hyper-V'
elif [ "$PLATINT" == '4' ]; then
	PLATFORM='VMware'
elif [ "$PLATINT" == '5' ]; then
	PLATFORM='oVirt'
else
	echo "Something has gone wrong with Platform detection! Exiting!"
	exit 1
fi


export SYSTEM="$OS-$PLATFORM"


echo "Press Enter to begin benchmarks!"
read NULL


for COUNTER in 1 2 3 4 5; do
	if [ "$LOCALIPERF" == 'none' ]; then
		echo "Local iPerf server not set, so test not run."
	else
		#iPerf Local Test
		echo "Performing local iPerf benchmark for test $COUNTER"
		iperf -c $LOCALIPERF | tee iperf-local-$SYSTEM-Run-$COUNTER.txt
	fi
	#iPerf Internet Test using HurricanElectric's servers
	echo "Performing remote iPerf benchmark for test $COUNTER"
	iperf -c iperf.he.net -r | tee iperf-remote-$SYSTEM-Run-$COUNTER.txt
	# CPU Test
	echo "Performing CPU benchmark for test $COUNTER"
	sysbench --test=cpu --cpu-max-prime=20000 run | tee sysbench-CPU-$SYSTEM-Run-$COUNTER.txt
	# Disk Test Preparation
	echo "Preparing disk benchmark for test $COUNTER"
	sysbench --test=fileio --file-total-size=5G prepare
	# Disk Test Run
	echo "Performing Disk benchmark for test $COUNTER"
	sysbench --test=fileio --file-total-size=5G --file-test-mode=rndrw --init-rng=on --max-time=300 --max-requests=0 run | tee sysbench-Disk-$SYSTEM-Run-$COUNTER.txt
	# Disk Test Cleanup
	echo "Performing Disk cleanup for test $COUNTER"
	sysbench --test=fileio --file-total-size=5G cleanup
	# Memory Test Large
	echo "Performing 1GB Memory benchmark for test $COUNTER"
	sysbench --test=memory --memory-block-size=1G --memory-total-size=10G run | tee sysbench-RAM-1G-$SYSTEM-Run-$COUNTER.txt
	# Memory Test Medium
	echo "Performing 1MB Memory benchmark for test $COUNTER"
	sysbench --test=memory --memory-block-size=1M --memory-total-size=10G run | tee sysbench-RAM-1M-$SYSTEM-Run-$COUNTER.txt
	# Memory Test Small
	echo "Performing 1KB Memory benchmark for test $COUNTER"
	sysbench --test=memory --memory-block-size=1K --memory-total-size=10G run | tee sysbench-RAM-1K-$SYSTEM-Run-$COUNTER.txt
	# OpenSSL Speed Test
	echo "Performing OpenSSL benchmark for test $COUNTER"
	openssl speed | tee openssl-$SYSTEM-Run-$COUNTER.txt
	# Allow System to recover before next run
	echo "Sleeping for 60 seconds"
	sleep 60
done

touch $SYSTEM-final.txt
echo "Final Results" >> $SYSTEM-final.txt
echo "OpenSSL" >> $SYSTEM-final.txt
grep "md5        " openssl-$SYSTEM-Run-*.txt >> $SYSTEM-final.txt
grep "sha1       " openssl-$SYSTEM-Run-*.txt >> $SYSTEM-final.txt
grep "aes-256 cbc" openssl-$SYSTEM-Run-*.txt >> $SYSTEM-final.txt
grep "sha512     " openssl-$SYSTEM-Run-*.txt >> $SYSTEM-final.txt
echo "                  sign    verify    sign/s verify/s" >> $SYSTEM-final.txt
grep "rsa 4096" openssl-$SYSTEM-Run-*.txt >> $SYSTEM-final.txt
echo "CPU" >> $SYSTEM-final.txt
grep "total time:" sysbench-CPU-$SYSTEM-Run-*.txt >> $SYSTEM-final.txt
grep "avg:" sysbench-CPU-$SYSTEM-Run-*.txt >> $SYSTEM-final.txt
echo "Disk" >> $SYSTEM-final.txt
grep "total time:" sysbench-Disk-$SYSTEM-Run-*.txt >> $SYSTEM-final.txt
grep "avg:" sysbench-Disk-$SYSTEM-Run-*.txt >> $SYSTEM-final.txt
echo "RAM 1K" >> $SYSTEM-final.txt
grep "total time:" sysbench-RAM-1K-$SYSTEM-Run-*.txt >> $SYSTEM-final.txt
grep "avg:" sysbench-RAM-1K-$SYSTEM-Run-*.txt >> $SYSTEM-final.txt
echo "RAM 1M" >> $SYSTEM-final.txt
grep "total time:" sysbench-RAM-1M-$SYSTEM-Run-*.txt >> $SYSTEM-final.txt
grep "avg:" sysbench-RAM-1M-$SYSTEM-Run-*.txt >> $SYSTEM-final.txt
echo "RAM 1G" >> $SYSTEM-final.txt
grep "total time:" sysbench-RAM-1G-$SYSTEM-Run-*.txt >> $SYSTEM-final.txt
grep "avg:" sysbench-RAM-1G-$SYSTEM-Run-*.txt >> $SYSTEM-final.txt
if [ "$LOCALIPERF" == 'none' ]; then
	echo "Local iPerf test was not run, no results to report" >> $SYSTEM-final.txt
else
	echo "iPerf Local" >> $SYSTEM-final.txt
	cat iperf-local-$SYSTEM-Run-*.txt >> $SYSTEM-final.txt
fi
echo "iPerf Remote" >> $SYSTEM-final.txt
cat iperf-remote-$SYSTEM-Run-*.txt >> $SYSTEM-final.txt

echo "Benchmarking Completed! File $SYSTEM-final.txt contains the results!"

exit 0
