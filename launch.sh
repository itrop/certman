#!/bin/bash

IMAGE_TAG=certman:latest
CONTAINER=certman

pause(){
    local k
    echo "$@"
    read -p "Press [Enter] key to continue..." k
}

echo
echo "Building the image: $IMAGE_TAG  - please wait."  
docker build -q --tag $IMAGE_TAG  .

echo
echo "Here it is:"
docker images $IMAGE_TAG

echo
pause "Launching the image in default mode (to get certs exp info from predefined servers). "
docker run --rm --name $CONTAINER $IMAGE_TAG

echo
pause "Launching the image in menu mode (to check the full functionality). "
docker run -it --rm -v $(pwd):/test --name $CONTAINER $IMAGE_TAG -m

echo "Done."
