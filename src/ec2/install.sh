#!/usr/bin/env bash

internal_cidr=$1
internal_gw=$2
internal_ip=$3
access_key_id=$4
secret_access_key=$5
subnet_id=$6
private_key_file=$7

stemcell_url=https://bosh.io/d/stemcells/bosh-aws-xen-hvm-ubuntu-trusty-go_agent?v=3363.9

echo " --Update system-- "
sudo apt -y update
sudo apt -y upgrade

# Install prerequisites
sudo apt -y install git gcc make ruby zlibc zlib1g-dev ruby-bundler ruby-dev build-essential patch libssl-dev bison openssl libreadline6 libreadline6-dev curl git-core libssl-dev libyaml-dev libxml2-dev autoconf libc6-dev ncurses-dev automake libtool

# Install uaac
sudo gem install cf-uaac

echo " --Preparing deployments-- "
git clone https://github.com/cloudfoundry/bosh-deployment ~/workspace/bosh-deployment

echo " --Download and Install bosh-cli-- "
curl -O https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-2.0.1-linux-amd64
chmod +x bosh-cli-2.0.1-linux-amd64
sudo mv bosh-cli-2.0.1-linux-amd64 /usr/local/bin/bosh

echo " --Create a directory for the director-- "
mkdir -p ~/deployments/bosh-master

cd ~/deployments/bosh-master

echo "-- Trigger bosh deployment with UAA for AWS --"
bosh create-env ~/workspace/bosh-deployment/bosh.yml \
  --state ./state.json \
  -o ~/workspace/bosh-deployment/aws/cpi.yml \
  -o ~/workspace/bosh-deployment/uaa.yml \
  --vars-store ./creds.yml \
  -v director_name=bosh-master-director \
  -v internal_cidr=${internal_cidr} \
  -v internal_gw=${internal_gw} \
  -v internal_ip=${internal_ip} \
  -v access_key_id=${access_key_id} \
  -v secret_access_key=${secret_access_key} \
  -v az=eu-central-1a \
  -v region=eu-central-1 \
  -v default_key_name=bosh \
  -v default_security_groups=[bosh] \
  -v subnet_id=${subnet_id} \
  --var-file private_key=${private_key_file}

# Log in to the Director
export BOSH_CLIENT=admin
export BOSH_CLIENT_SECRET=`bosh int ./creds.yml --path /admin_password`

# Alias the deployed Director
bosh -e ${internal_ip} --ca-cert <(bosh int ./creds.yml --path /director_ssl/ca) alias-env bosh-1

echo "-- Update a cloud config with a single az "
bosh -n -e bosh-1 update-cloud-config ~/workspace/bosh-deployment/aws/cloud-config.yml \
  -v az=eu-central-1a \
  -v subnet_id=${subnet_id} \
  -v internal_cidr=${internal_cidr} \
  -v internal_gw=${internal_gw}

echo "-- Upload an initial stemcell --"
bosh -e bosh-1 upload-stemcell ${stemcell_url}

echo "-- Upload Release --"
bosh -e bosh-1 upload-release https://github.com/pivotal-cf-experimental/dummy-boshrelease/releases/download/v2/dummy-2.tgz