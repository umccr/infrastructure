#!/bin/bash
USER="ec2-user"

function bootstrap_all {
    echo "Common setup"
    yum install -y curl
    echo "Common setup done."
}

function bootstrap_master {
    echo "Create the sinteractive convenience script"
    tee /usr/local/bin/sinteractive <<'EOF'
#!/bin/bash
if [ "${SHELL}" != "/bin/tcsh" ]
then
  exec srun $* --pty -u ${SHELL} -i -l
else
  exec srun $* --pty -u ${SHELL} -i
fi
EOF
    chmod 755 /usr/local/bin/sinteractive
}

function bootstrap_fleet {
    echo "Installing packages ${@} ..."
    yum -y install "${@}"
    echo "Packages installed"
}

################################################################################
##### bootstrapping cluster instances

# log arguments
echo "bootstrap script has $# arguments"
for arg in "$@"; do
    echo "arg: ${arg}"
done

# run common bootstrap tasks
bootstrap_all

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