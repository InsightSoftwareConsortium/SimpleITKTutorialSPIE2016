#!/bin/sh

container=2016-spie-itk
image=insighttoolkit/simpleitk-notebooks:2016-spie
image_archive=2016-SPIE-MI-ITK-Course-Notebooks.tar
port=8888
extra_run_args=""
develop=""
quiet=""

show_help() {
cat << EOF
Usage: ${0##*/} [-h] [-q] [-c CONTAINER] [-i IMAGE] [-p PORT] [-r DOCKER_RUN_FLAGS]

This script is a convenience script to run Docker images. It:

- Makes sure docker is available
- On Windows and Mac OSX, creates a docker machine if required
- Informs the user of the URL to access the container with a web browser
- Stops and removes containers from previous runs to avoid conflicts
- Mounts the present working directory to /home/jovyan/work on Linux and Mac OSX
- Loads an image from an archive file in the pwd if present

Options:

  -h             Display this help and exit.
  -c             Container name to use (default ${container}).
  -i             Image name (default ${image}).
  -p             Port to expose the notebook server (default ${port}). If an empty
                 string, the port is not exposed.
  -r             Extra arguments to pass to 'docker run'.
  -d             Mount the local repository directory for Notebook development. Requires Linux or Mac OSX.
  -q             Do not output informational messages.
EOF
}

while [ $# -gt 0 ]; do
	case "$1" in
		-h)
			show_help
			exit 0
			;;
		-c)
			container=$2
			shift
			;;
		-i)
			image=$2
			shift
			;;
		-p)
			port=$2
			shift
			;;
		-r)
			extra_run_args="$extra_run_args $2"
			shift
			;;
		-d)
			develop=1
			;;
		-q)
			quiet=1
			;;
		*)
			show_help >&2
			exit 1
			;;
	esac
	shift
done


which docker 2>&1 >/dev/null
if [ $? -ne 0 ]; then
	echo "Error: the 'docker' command was not found.  Please install docker."
	exit 1
fi

pwd_dir="$(pwd)"
if [ -z "$(docker images -q ${image})" ]; then
	archive="${pwd_dir}/${image_archive}"
	if [ -e "${archive}" ]; then
		if [ -z "$quiet" ]; then
			echo "Loading image archive ${archive}..."
		fi
		docker load -i "${archive}"
	fi
fi

os=$(uname)
if [ "${os}" != "Linux" ]; then
	vm=$(docker-machine active 2> /dev/null || echo "default")
	if ! docker-machine inspect "${vm}" &> /dev/null; then
		if [ -z "$quiet" ]; then
			echo "Creating machine ${vm}..."
		fi
		docker-machine -D create -d virtualbox --virtualbox-memory 2048 ${vm}
	fi
	docker-machine start ${vm} > /dev/null
    eval $(docker-machine env $vm --shell=sh)
fi

ip=$(docker-machine ip ${vm} 2> /dev/null || echo "localhost")
url="http://${ip}:$port"

cleanup() {
	docker stop $container >/dev/null
	docker rm $container >/dev/null
}

running=$(docker ps -a -q --filter "name=${container}")
if [ -n "$running" ]; then
	if [ -z "$quiet" ]; then
		echo "Stopping and removing the previous session..."
		echo ""
	fi
	cleanup
fi

if [ -z "$quiet" ]; then
	echo ""
	echo "Setting up the notebook container..."
	echo ""
	if [ -n "$port" ]; then
		echo "Point your web browser to ${url}"
		echo ""
	fi
fi

pwd_dir="$(pwd)"
mount_local=""
if [ "${os}" = "Linux" ] || [ "${os}" = "Darwin" ]; then
	if [ -n "$develop" ]; then
		mount_local=" -v ${pwd_dir}:/home/jovyan/notebooks "
	else
		mount_local=" -v ${pwd_dir}:/home/jovyan/work "
	fi
fi
port_arg=""
if [ -n "$port" ]; then
	port_arg="-p $port:8888"
fi

docker run \
  -d \
  --name $container \
  ${mount_local} \
  $port_arg \
  $extra_run_args \
  $image >/dev/null

trap "docker stop $container >/dev/null" SIGINT SIGTERM

docker wait $container >/dev/null

# vim: noexpandtab shiftwidth=4 tabstop=4 softtabstop=0
