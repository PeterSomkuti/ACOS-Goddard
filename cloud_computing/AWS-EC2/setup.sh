#!/bin/bash

# Set-up script to download, build and install all required dependencies to run retrievals
# with ACOS-Goddard. This script, for now, works ONLY with the Amazon Linux 2023 AMI.

# This script really only works if this is executed in the "cloud_computing/AWS-EC2"
# folder - so we check here if that is the case. If not, exit.


ACOS_DIR="`pwd`/../../../"
if [ -d "${ACOS_DIR}/ACOS-Goddard/cloud_computing/AWS-EC2" ]; then
    echo "Passed basic directory check. Moving on."
else
    echo "Problem! This script must be executed in ACOS-Goddard/cloud_computing/AWS-EC2"
    exit
fi

# Step 1, install all required packages via yum

echo "### Installing required software via yum"

sudo yum -y install git gfortran g++ openblas-devel patch parallel

# Step 2, download Julia via juliaup (unless it exists)

echo "### Installing Julia via juliaup"

juliaup -V
if [ $? -ne 0 ]; then
    echo "JuliaUp not found - installing"
    curl -fsSL https://install.julialang.org | sh
else
    echo "JuliaUp found - moving on."
fi


# Step 3, clone and build XRTM
echo "### Building XRTM"
XRTM_DIR=${ACOS_DIR}/xrtm

if [ -d "${XRTM_DIR}" ]; then
    echo "Directory xrtm already exists. If you want a re-install, delete please."
else
    echo "Cloining and building XRTM"
    git clone https://github.com/PeterSomkuti/xrtm ${XRTM_DIR}
    # copy patch
    cp xrtm_make.patch ${XRTM_DIR}
    # move into XRTM directory and copy makefile
    cd ${XRTM_DIR}
    cp make.inc.example make.inc
    # patch!
    patch make.inc xrtm_make.patch
    # build!
    make
fi

# Step 4, instantiate all needed Julia packages
cd ${ACOS_DIR}/ACOS-Goddard

# If it exists, remove the Manifest file (it might confuse the current installation..)
if [ -f "Manifest.toml" ]; then
    rm Manifest.toml
fi
# Install packages
julia --project="." -e 'using Pkg; Pkg.add(path="https://github.com/US-GHG-Center/RetrievalToolbox.jl"); Pkg.instantiate();'

# Step 5, download the needed ACOS files from github
cd ${ACOS_DIR}/ACOS-Goddard/example_data
wget -nc https://github.com/nasa/RtRetrievalFramework/raw/refs/heads/master/input/common/input/l2_solar_model.h5
wget -nc https://github.com/nasa/RtRetrievalFramework/raw/refs/heads/master/input/common/input/l2_aerosol_combined.h5
wget -nc https://github.com/nasa/RtRetrievalFramework/raw/refs/heads/master/input/oco/input/l2_oco_static_input.h5