#!/bin/bash

# $1 'first argument' => packages_path
# $2 'second argument' => images_path
# $3 'third argument' => reg_pxe_image

test_ip_result=$(ip a | grep -E -B2 "(192\.168\.20\.([0-9]|[1-9][0-9]|1[0-9]{2}|2[0-4][0-9]|25[0-5]))\/(3[0-2]|[1-2][0-9]|[0-9])")
if [[ $? == 0 ]]; then
  found_interface=$(echo $test_ip_result | head -n 1 | cut -d ":" -f 2 | xargs)
  interface_name=$(ls /sys/class/net/ | grep ^e.* | head -n 1)
  if [[ "$found_interface" != "$interface_name" ]]; then
    echo -e "This script will set static ip for your network interface with '192.168.20.2/24',"
    echo -e "We found an existing interface which has an IP on the same subnet."
    echo -e "Please change this to avoid any problems."
    echo -e "The Interface name: $found_interface"
  fi
else
  interface_name=$(ls /sys/class/net/ | grep ^e.* | head -n 1)
  echo -e "\033[36mSetting static ip for $interface_name to '192.168.20.2/24' ..."
  netplan_file_name=$(ls /etc/netplan | head -n 1)
  cat >/etc/netplan/$netplan_file_name <<EOF
    network:
      version: 2
      renderer: networkd
      ethernets:
          $interface_name:
              addresses:
                  - 192.168.20.2/24
              routes:
                  - to: default
                    via: 192.168.20.1
EOF
  netplan apply
  if [[ $? == 0 ]]; then
    echo -e "\033[32mStatic IP was set successfully for $interface_name"
    packages_path=$1
    images_path=$2
    reg_pxe_image=$3
    echo "Pulling docker image from registry..."
    docker pull $reg_pxe_image
    ([ $? -eq 0 ] && echo "Pulled the PXE server image successfully.") || (echo "Failed to pull the PXE server image, exit code: $?" && exit 1)
    cat > docker-compose.yaml <<EOF
    version: "3.3"
    services:
      pxe-server:
        image: $reg_pxe_image
        container_name: pxe-uefi-container
        tty: true
        restart: always
        environment:
          - PXE_IP=192.168.20.3
          - PXE_SUBNET=192.168.20.0
          - PXE_GATEWAY=192.168.20.1
          - PXE_BROADCAST=192.168.20.255
          - PXE_NETMASK=255.255.255.0
          - PXE_RANGE_LOW=192.168.20.10
          - PXE_RANGE_HIGH=192.168.20.100
        networks:
          macnet:
            ipv4_address: 192.168.20.3
        volumes:
          - $packages_path:/packages
          - $images_path:/images
    networks:
      macnet:
        driver: macvlan
        driver_opts:
          parent: $interface_name
        ipam:
          config:
            - subnet: "192.168.20.0/24"
EOF
    docker-compose up -d
    if [[ $? == 0 ]]; then
      echo -e "pxe-uefi-container is running..."
    else
      echo -e "There was a problem initializing the container, docker-compose exit code: $?"
    fi
  else
    echo -e "There was an issue setting static IP for $interface_name , netplan exit code: $?"
  fi
fi
