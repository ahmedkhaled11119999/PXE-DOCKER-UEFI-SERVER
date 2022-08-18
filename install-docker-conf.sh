#!/bin/bash

OPTIONS_LIST=("docker_reg" "image_name" "packages_path" "images_path")
for ARGUMENT in "$@"; do
	OPTION=$(echo $ARGUMENT | cut -f 1 -d "=")
	echo ${OPTIONS_LIST[@]} | grep -w -q $OPTION
	if [[ $? == 0 ]]; then
		OPTION_LENGTH=${#OPTION}
		VALUE="${ARGUMENT:$OPTION_LENGTH+1}"
		export "$OPTION"="$VALUE"
	else
		echo "Invalid Option '$OPTION'"
		exit 1
	fi
done
for item in "${OPTIONS_LIST[@]}"; do
	if [[ -z "${!item}" ]]; then
		echo "Option $item is not given, please provide it and try again"
		exit 1
	fi
done

function directory_checker {
	if ! [[ -d $1 ]]; then
		echo -e "No directory found in $1\nplease recheck the path & try again." && exit 1
	fi
}

function configure_registry {
	cat > /etc/docker/daemon.json <<EOF
{
"insecure-registries":["$docker_reg"]
}
EOF
	([ $? -eq 0 ] && echo "Added registry configurations to /etc/docker/daemon.json")
	echo "Restarting docker service..."
	systemctl restart docker
	sleep 10
	([ $? -eq 0 ] && echo "Restarted docker service.")
}

directory_checker $images_path
directory_checker $packages_path

echo "Testing internet connection..."
wget -q --spider http://google.com
if [[ $? -eq 0 ]]; then
	echo -e "\033[36mAttempting to download docker & docker-compose..."
	apt-get update && apt-get install -y docker.io docker-compose
	if [[ $? == 0 ]]; then
		echo -e "\033[32mDocker & docker-compose installation was successfull."
	else
		echo -e "Something went wrong while installing docker & docker-compose, apt exit code: $?"
	fi
else
	echo "Failed to connect, Please check your connection and try again."
	echo "Do you want to complete the process assuming docker & docker-compose are installed? (Y/N)"
	read force_init
	if [[ "$force_init" == "n" || "$force_init" == "N" || "$force_init" == "no" || "$force_init" == "NO" ]]; then
		echo "Exiting.."
		exit 1
	fi
fi
configure_registry
pxe_image_path="$docker_reg/$image_name"

sudo ./init-compose-and-run.sh $packages_path $images_path $pxe_image_path
