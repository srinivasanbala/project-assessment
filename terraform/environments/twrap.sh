#!/bin/bash
set -e

data=""
git_root=`git rev-parse --show-toplevel`
planfile=""
planopt=""
tfopt=""
tfvars="variables.tfvars"
version=`grep "required_version" setup.tf | awk '{gsub(/[^0-9\.]+/,"")}1'`

unset AWS_ACCESS_KEY_ID
unset AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN
unset AWS_SECURITY_TOKEN

usage()
{
    prog=$(basename $0)
    cat <<EOT
usage: ${prog} <command> [extra terraform args...]

Wrapper around terraform tool to select AWS profile and re-use session before running command.
Automatically loads tfvars file because the offical paramter is too long to type and we need this 99% of the time.

WARNING: The order of parameters has changed from the previous wrapper to simplify workflow.

ex: ${prog} plan
    ${prog} apply
    ${prog} console

EOT
}


get_modules()
{
    terraform get
}


# map role ARM to AWS profile
get_role()
{
    profile=$1
    case ${profile} in
        "srini_dev")
            role="arn:aws:iam::******:role/governance/full_admin_role"
            ;;
        "srini_prod")
            role="arn:aws:iam::*******:role/governance/full_admin_role"
            ;;
        *)
            echo "!!! Unknown profile-to-role mapping. Check you profile name." >&2
            exit 1
            ;;
    esac
    echo "${role}"
}


get_profile()
{
    account=$1
    case "${account}" in
        "dev")
            profile="srini_dev"
            ;;
        "prod")
            profile="srini_prod"
            ;;
        *)
            echo "!!! Unknown account-to-profile mapping. Check your account name." >&2
            exit 1
            ;;
    esac
    echo ${profile}
}


# generate a plan file for the current plan
generate_planfile()
{
    planname=$1
    plandir="${PWD}/plans"
    planfile="${plandir}/${planname}_$(date -u +%Y%m%d-%H%M%S)"
    [ -d ${plandir} ] || mkdir -p ${plandir}
    echo ${planfile}
}


# find the latest plan file and use that
get_planfile()
{
    plandir="$(dirname $1)/plans"
    find ${plandir} -maxdepth 1 -type f | sort -rn | head -1
}


# commit applied plans so we could rollback a configuration to a known state
commit_plan()
{
    planfile=$1
    echo "You should always commit successful plans fto git to allow fast configuration rollback"
    echo "Did the apply command succeed? (Y/N)"
    read resp
    case ${resp} in
        "Y")
            git add ${planfile}
            git commit -m 'Saving applied plan'
            git push
            ;;
        *)
            echo "Plan not saved to git."
            ;;
    esac
}


if [ $# -eq 0 ]; then
    usage
    exit 1
fi

rundir=$(dirname $0)

if [ ! "${rundir}" == "." ]; then
    echo "Please run this command from inside the cluster directory as ./${prog}"
    exit 1
fi

cmd="$*"

# Detect some implicit paramters
terraform_dir=$(echo $PWD | sed -e "s,^${git_root}/*,,")
proj_dir=$(echo ${terraform_dir} | sed -e "s,^clusters/,,")
IFS='/'
set ${proj_dir}
project=$1
account=$2
cluster=$3
region=$4

unset IFS
profile=$(get_profile ${account})
role=$(get_role ${profile})
echo "Using the following account and profile: " ${account} ${profile}

if [ ! -f ${tfvars} ]; then
    echo "TFVARS file not found: " ${tfvars}
    exit 1
fi

if [ ! -z "${profile}" -a ! -z "${role}" ]; then
    # Get AWS credentials
    seed=$(date +%s)
    data=$(aws --profile ${profile} sts assume-role --role-arn ${role} --role-session-name srini${seed})
    if [ -z "${data}" ]; then
        echo "!!! Error getting a valid session. Please fix it."
        exit 1
    fi
    export AWS_ACCESS_KEY_ID=$(echo ${data} | sed 's/.*AccessKeyId": "\([A-Za-z0-9\/+=]*\).*/\1/')
    export AWS_SECRET_ACCESS_KEY=$(echo ${data} | sed 's/.*SecretAccessKey": "\([A-Za-z0-9\/+=]*\).*/\1/')
    export AWS_SESSION_TOKEN=$(echo ${data} | sed 's/.*SessionToken": "\([A-Za-z0-9\/+=]*\).*/\1/')
    export AWS_SECURITY_TOKEN=$(echo ${data} | sed 's/.*SessionToken": "\([A-Za-z0-9\/+=]*\).*/\1/')

    echo "AWS session set"
else
    echo "!!! No session set. Older export variables were removed for safety."
fi
echo


# Generate or read a plan file base on command
runcmd=$(echo "${cmd}" | sed -e 's/ .*//')
case ${runcmd} in
    "plan")
        get_modules
        planfile=$(generate_planfile ${region})
        planopt="-out ${planfile}"
        tfopt="-var-file=${tfvars}"
        ;;
    "apply")
        get_modules
        planfile=$(get_planfile ${tfvars})
        planopt="${planfile}"
        if [ -z "${planopt}" ]; then
            echo "No planfile found. I refuse to apply a configuration before you plan it."
            echo "Please run 'plan' first."
            exit
        fi
        echo "Using planfile: " ${planfile}
        ;;
esac

# run terraform
terraform-$version ${cmd} ${tfopt} ${planopt}


if [ ${runcmd} == "apply" ]; then
    commit_plan ${planfile}
fi
