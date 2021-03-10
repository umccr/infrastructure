# scripts  <!-- omit in toc -->

- [assume-role-vault](#assume-role-vault)
- [safe-terraform](#safe-terraform)
- [bash-utils.sh](#bash-utilssh)
- [Installing Samplesheet check on a windows machine](#installing-samplesheet-check-on-a-windows-machine)

## assume-role-vault
Wrapper script around `assume-role` to setup Vault access in addition to the AWS credentials setup.

Setup:
- install `assume-role` as per [docs](https://github.com/coinbase/assume-role) including the addition to your `rc` file
- place `assume-role-vault` wrapper script somewhere
- add a bash alias: `alias assume-role-vault='. /path/to/assume-role-vault'` (Note: include the full path to the script to avoid recursion)

Usage:
- set GitHub token: `export GITHUB_TOKEN=<your personal GitHub access token>`
- call `assume-role-vault` the same as you would `assume-role` itself: `assume-role-vault prod ops-admin`

The `assume-role` script will populate the env with AWS access credentials and the `assume-role-vault` wrapper will add Vault access credentials. You should then be able to query Vault and use tools like Terraform that require access to AWS and Vault.

## safe-terraform
Wrapper to call `terraform` commands that checks the current environment. It compares the `git` branch, the `terraform.workspace` and the `AWS` account name to avoid accidental cross account deployments.

Usage:
- put the script on your `$PATH`
- use `safe-terraform` instead of `terraform`

## bash-utils.sh
XXX

## Installing Samplesheet check on a windows machine
**WARNING** *requires basic understanding of Windows operating systems and non-conforming terminal syntax:*

1. Download and install [anaconda3](https://www.anaconda.com/distribution/)
    * Select all presets.  
    * Anaconda should be installed into `%HOMEPATH%\Anaconda3`
   
2. Run the anaconda command prompt executable from the Start Menu:
    * You should see `(base)` at start of your command prompt line.  

3. Update the base conda environment: `conda update --name base conda --yes`
   
4. Create & activate an environment
    * `conda create --name samplesheet_check --yes`
    * `conda activate samplesheet_check`
   
5. Install git 
    * `conda install --channel conda-forge git --yes`
    * `git --version`  (must be greater than 2.25)
   
6. Head to the conda prefix directory and create the following subdirectories in the conda directory:
   > On WINDOWS you can use the `%CONDA_PREFIX%` env var.
    * `etc\conda\activate.d`
    * `secrets`
    * `git\infrastructure`
   
7. Ask [Florian](mailto:florian.reisigner@umccr.org) or [Alexis](mailto:alexis.lucattini@umccr.org) for the `google_secret.json` secret key.
   > This can be found in the ssm parameter `/data_portal/dev/google/lims_service_account_json`
   
   The following command will generate the `google_secret.json` file

   ```shell
   aws ssm get-parameter \
     --name "${ssm_key}" \
     --with-decryption | \
   jq --raw-output \
     '.Parameter.Value | fromjson' > google_secret.json 
   ```
   * Place this file in the folder `%CONDA_PREFIX%\secrets` with the name `google_secret.json`
7. Set env vars in `activate.d`:  
   > This will make sure the environment variable GSPREAD_PANDAS_CONFIG_DIR is set when the conda env is activated  
   
   * `echo set GSPREAD_PANDAS_CONFIG_DIR=^%CONDA_PREFIX^%\secrets >> %CONDA_PREFIX%\etc\conda\activate.d\env_vars.bat`
   
   > Confirm the file exists with:
   
   * `type "%CONDA_PREFIX%\etc\conda\activate.d\env_vars.bat"`
   
8. Install the infrastructure repo:
   > Installed under %CONDA_PREFIX%\git\infrastructure.  
   > We install only the folders that are necessary 
   
   ```shell
   # Change to git directory
   cd git\infrastructure
   
   # Initialise directory and activate spare checkout
   git init
   
   # Initialise and set sparse checkout
   git sparse-checkout init --cone
   git sparse-checkout set scripts\umccr_pipeline
   
   # Confirm entry with
   type .git\info\sparse-checkout
   
   # Add infrastructure remote to folder
   git remote add -f origin https://github.com/umccr/infrastructure.git
   
   # Pull
   git pull origin master  # samplesheet-check-update-script branch for now
   ```
     
9. Now create two one-liner `.bat` files on the user's desktop using the scripts below
   > You will need to first run the update-git repo before launching the samplesheet launcher.
   > This update-git repo will install all pre-requisites into the repository.  
   > This may take some time.  

   a. Samplesheet launcher
   > samplesheet_check.bat
   
   ```commandline
   %windir%\system32\cmd.exe /k ""%HOMEPATH%\Anaconda3\Scripts\activate.bat" "%HOMEPATH%\Anaconda3\envs\samplesheet_check" && python "%HOMEPATH%\Anaconda3\envs\samplesheet_check\git\infrastructure\scripts\umccr_pipeline\samplesheet-check-gui-wrapper.py" && exit"
   ```

   b. Update git repo and installations
   > update_samplesheet_check_script.bat   

   ```commandline
   %windir%\system32\cmd.exe /k ""%HOMEPATH%\Anaconda3\Scripts\activate.bat" "%HOMEPATH%\Anaconda3\envs\samplesheet_check" && cd "%HOMEPATH%\Anaconda3\envs\samplesheet_check\git\infrastructure" && git pull && conda env update --name samplesheet_check --file "%HOMEPATH%\Anaconda3\envs\samplesheet_check\git\infrastructure\scripts\umccr_pipeline\env\samplesheet-check.yml" && exit"
   ```