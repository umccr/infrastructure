# Packer docker file

To build the docker image (within this directory):  
`docker build --tag local/packer:1.2.0 .`

Once build, an alias can be set to mimic the packer command:  
`alias packer='docker run --rm -v "$(pwd):/tmp/packer" -e AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY -e AWS_SESSION_TOKEN local/packer:1.2.0'`

Then proceed as if packer was installed:  
`packer build <your_packer.json>`
