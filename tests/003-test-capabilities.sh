#!/bin/bash

source $SRCDIR/utils.sh

# readonly_rootfs, cap_add and cap_drop flags are tested as part of this test.
test_capabilities_nomad_job() {
    pushd ~/go/src/github.com/Roblox/nomad-driver-containerd/example

    echo "INFO: Starting nomad capabilities job using nomad-driver-containerd."
    nomad job run -detach capabilities.nomad

    echo "INFO: Checking status of capabilities job."
    cap_status=$(nomad job status -short capabilities|grep Status|awk '{split($0,a,"="); print a[2]}'|tr -d ' ')
    if [ $cap_status != "running" ];then
        echo "ERROR: Error in getting capabilities job status."
        exit 1
    fi

    # Even though $(nomad job status) reports capabilities job status as "running"
    # The actual container process might not be running yet.
    # We need to wait for actual container to start running before trying exec.
    echo "INFO: Wait for capabilities container to get into RUNNING state, before trying exec."
    is_container_active capabilities true

    echo "INFO: Inspecting capabilities job."
    cap_status=$(nomad job inspect capabilities|jq -r '.Job .Status')
    if [ $cap_status != "running" ]; then
        echo "ERROR: Error in inspecting capabilities job."
        exit 1
    fi

    # Check if CAP_SYS_ADMIN was added.
    echo "INFO: Checking if CAP_SYS_ADMIN is added."
    nomad alloc exec -job capabilities capsh --print|grep cap_sys_admin >/dev/null 2>&1
    rc=$?
    if [ $rc -ne 0 ]; then
        echo "ERROR: CAP_SYS_ADMIN was not added to the capabilities set."
        exit 1
    fi

    # Check if CAP_CHOWN was dropped.
    echo "INFO: Checking if CAP_CHOWN is dropped."
    nomad alloc exec -job capabilities capsh --print|grep cap_chown >/dev/null 2>&1
    rc=$?
    if [ $rc -eq 0 ]; then
        echo "ERROR: CAP_CHOWN was not dropped from the capabilities set."
        exit 1
    fi

    # Check if readonly_rootfs is set to true.
    echo "INFO: Checking if readonly_rootfs is set to true."
    local outfile=$(mktemp /tmp/capabilities.XXXXXX)
    nomad alloc exec -job capabilities touch /tmp/file.txt >> $outfile 2>&1
    if ! grep -q "Read-only file system" $outfile; then
        echo "ERROR: readonly_rootfs is not set to true."
        cleanup "$outfile"
        exit 1
    fi
    cleanup "$outfile"

    echo "INFO: Stopping nomad capabilities job."
    nomad job stop -detach capabilities
    cap_status=$(nomad job status -short capabilities|grep Status|awk '{split($0,a,"="); print a[2]}'|tr -d ' ')
    if [ $cap_status != "dead(stopped)" ];then
        echo "ERROR: Error in stopping capabilities job."
        exit 1
    fi

    echo "INFO: purge nomad capabilities job."
    nomad job stop -detach -purge capabilities
    popd
}

cleanup() {
  local tmpfile=$1
  rm $tmpfile > /dev/null 2>&1
}

test_capabilities_nomad_job
