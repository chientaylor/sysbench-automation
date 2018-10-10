#!/bin/bash
while [ "$OSBOOL" != '1' ] && [ "$OSBOOL" != '2' ]; do
	echo "What Operating system?"
	echo "1: Debian"
	echo "2: CentOS"
	read OSBOOL
done
while [ "$PLATBOOL" != '0' ] && [ "$PLATBOOL" != '1' ] && [ "$PLATBOOL" != '2' ] && [ "$PLATBOOL" != '3' ] && [ "$PLATBOOL" != '4' ] && [ "$PLATBOOL" != '5' ]; do
	echo "What Platform?"
	echo "0: Baremetal"
	echo "1: ProxMox"
	echo "2: XenServer"
	echo "3: Hyper-V"
	echo "4: VMware"
	echo "5: oVirt"
read PLATBOOL
done
if [ "$OSBOOL" == '1' ]; then
        OS='Debian'
        apt update
        apt install sysbench iperf -y
elif [ "$OSBOOL" = '2' ]; then
        OS='CentOS'
        yum check-update -y
        yum install epel-release -y
        yum update -y
        yum install sysbench iperf -y
fi
if [ "$PLATBOOL" == '0' ]; then
	PLATFORM='Baremetal' 
elif [ "$PLATBOOL" == '1' ]; then
	PLATFORM='ProxMox'
elif [ "$PLATBOOL" == '2' ]; then
	PLATFORM='XenServer'
elif [ "$PLATBOOL" == '3' ]; then
	PLATFORM='Hyper-V'
elif [ "$PLATBOOL" == '4' ]; then
	PLATFORM='VMware'
elif [ "$PLATBOOL" == '5' ]; then
	PLATFORM='oVirt'
fi
export SYSTEM="$OS-$PLATFORM"

echo "Press Enter to begin benchmarks!"
read NULL

for COUNTER in 1 2 3; do
	#iPerf Local Test (-r Argument failed on CentOS)
	iperf -c 172.30.0.12 | tee iperf-local-$SYSTEM-Run-$COUNTER.txt
	#iPerf Internet Test (Not run, blocked by campus firewall)
	#iperf -c iperf.he.net -r | tee iperf-remote-$OS-Run-$COUNTER.txt
	# CPU Test
	sysbench --test=cpu --cpu-max-prime=20000 run | tee sysbench-CPU-$SYSTEM-Run-$COUNTER.txt
	# Disk Test Preparation
	sysbench --test=fileio --file-total-size=5G prepare
	# Disk Test Run
	sysbench --test=fileio --file-total-size=5G --file-test-mode=rndrw --init-rng=on --max-time=300 --max-requests=0 run | tee sysbench-Disk-$SYSTEM-Run-$COUNTER.txt
	# Disk Test Cleanup
	sysbench --test=fileio --file-total-size=5G cleanup
	# Memory Test Large
	sysbench --test=memory --memory-block-size=1G --memory-total-size=10G run | tee sysbench-RAM-1G-$SYSTEM-Run-$COUNTER.txt
	# Memory Test Medium
	sysbench --test=memory --memory-block-size=1M --memory-total-size=10G run | tee sysbench-RAM-1M-$SYSTEM-Run-$COUNTER.txt
	# Memory Test Small
	sysbench --test=memory --memory-block-size=1K --memory-total-size=10G run | tee sysbench-RAM-1K-$SYSTEM-Run-$COUNTER.txt
	# OpenSSL Speed Test
	openssl speed | tee openssl-$SYSTEM-Run-$COUNTER.txt
	# Allow System to recover before next run
	sleep 60
done

touch $SYSTEM-final.txt
echo "Final Results" >> $SYSTEM-final.txt
echo "OpenSSL" >> $SYSTEM-final.txt
grep "md5 " openssl-$SYSTEM-Run-*.txt >> $SYSTEM-final.txt
grep "sha1" openssl-$SYSTEM-Run-*.txt >> $SYSTEM-final.txt
grep "aes-256 cbc" openssl-$SYSTEM-Run-*.txt >> $SYSTEM-final.txt
grep "sha512" openssl-$SYSTEM-Run-*.txt >> $SYSTEM-final.txt
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
echo "iPerf" >> $SYSTEM-final.txt
cat iperf-local-$SYSTEM-Run-*.txt >> $SYSTEM-final.txt

echo "Benchmarking Completed! File $SYSTEM-final.txt contains the results!"

exit 0
