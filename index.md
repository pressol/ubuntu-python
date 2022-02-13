# Ubuntu-Python

This project aims to give a ultra small Ubuntu LTS based docker image containing the latest three python versions 

## Build process

- Jenkins 
- Github Actions

### The current process
The current process uses Github Actions but I will likely move the build process to Jenkins at a later date, as i have some free compute and a tiny bit of time.

1. Using the Ubuntu docker container
2. Runs some security stuff and installs some security package
3. Installs Python version and builds it from source
4. Removes the packages needed for building python


