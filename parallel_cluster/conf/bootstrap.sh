#!/bin/bash
USER="ec2-user"

function bootstrap_master {
    echo "Create the sinteractive convenience script"
    # NOTE: PATH is overwritten by some other process,
    # so we put it somewhere that's generally accessible
    tee /usr/bin/sinteractive <<'EOF'
#!/bin/bash
if [ "${SHELL}" != "/bin/tcsh" ]
then
  exec srun $* --pty -u ${SHELL} -i -l
else
  exec srun $* --pty -u ${SHELL} -i
fi
EOF
    chmod 755 /usr/bin/sinteractive
}

function bootstrap_fleet {
    echo "Installing packages ${@} ..."
    yum -y install "${@}"
}

################################################################################
##### bootstrapping cluster instances
echo "Bootstrapping instance!"

# log arguments
echo "bootstrap script has $# arguments"
for arg in "$@"; do
    echo "arg: ${arg}"
done

# run separate bootstrap for master or fleet nodes
. "/etc/parallelcluster/cfnconfig"
case "${cfn_node_type}" in
    MasterServer)
        echo "Master node: running master bootstrap"
        bootstrap_master
    ;;
    ComputeFleet)
        echo "Compute node: running compute bootstrap"
        bootstrap_fleet "${@:2}"
    ;;
    *)
        echo "Unexpected node type. Ignoring."
    ;;
esac

echo "Post Install script done."
