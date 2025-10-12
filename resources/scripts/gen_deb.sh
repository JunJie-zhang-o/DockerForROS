#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKGS_NAME=$(basename "$(cd "$SCRIPT_DIR/.." && pwd)") 

source "$SCRIPT_DIR/deb_utils.sh"

check_sudo

DEVEL_DIR="$(cd "$SCRIPT_DIR/../../../devel" && pwd)"
echo "Script directory: $DEVEL_DIR"




create_rosdep_source "$PKGS_NAME" "$SCRIPT_DIR"


echo "Sourcing the development setup script..."
source "$DEVEL_DIR/setup.bash"



build_ros_deb "$(cd "$SCRIPT_DIR/../upperlimb/" && pwd)" "zj-humanoid" "true"
build_ros_deb "$(cd "$SCRIPT_DIR/../uplimb_interface/" && pwd)" "zj-humanoid" "false"


DIST_PATH="$(cd "$SCRIPT_DIR/../dist" && pwd)"
uninstall_ros_debs "$DIST_PATH"
echo "Script execution completed."