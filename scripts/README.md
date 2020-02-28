# scripts

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

1. Download [conda](https://www.anaconda.com/distribution/)
2. Update the base conda environment: `conda update -n base conda`
3. Create an environment with python 3.6 installed, name it something like *samplesheet_launcher_py3.6*
4. Activate the env and install the following programs through pip:
    * gspread
    * sample-sheet
    * gooey
    * git (can be installed through conda)
5. Head to the conda prefix directory and create the following subdirectories:
    * `etc/conda/activate.d`
    * `secrets`
    * `git`
6. Ask Florian or Alexis for the `google_secrets.json` secret key.
    * Place this in the folder `%CONDA_PREFIX%\secrets`
7. Head to the conda prefix directory and create the subdirectories `etc\conda\activate.d`.
    * In here we will create file called `env_vars.bat` with the following line:
      *  `set GSPREAD_PANDAS_CONFIG_DIR=%CONDA_PREFIX%\secrets`
8. Download the [infrastructure repo](https://github.com/umccr/infrastructure) into the directory `%CONDA_PREFIX%\git`.
9. Now create two one-liner `.bat` files on the Desktop using the scripts below

9a: Samplesheet launcher
```commandline
%windir%\system32\cmd.exe /k ""%CSIDL_PROFILE%\AppData\Local\Continuum\anaconda3\Scripts\activate.bat" "%CSIDL_PROFILE%\AppData\Local\Continuum\anaconda3\envs\samplesheet_launcher_py3.6" && python "%CSIDL_PROFILE%\AppData\Local\Continuum\anaconda3\envs\samplesheet_launcher_py3.6\git\infrastructure\scripts\umccr_pipeline\samplesheet-check-gui-wrapper.py" && exit"
```

9b: Update git repo
```commandline
%windir%\system32\cmd.exe /k ""%CSIDL_PROFILE%\AppData\Local\Continuum\anaconda3\Scripts\activate.bat" "%CSIDL_PROFILE%\AppData\Local\Continuum\anaconda3\envs\samplesheet_launcher_py3.6" && cd "%CSIDL_PROFILE%\AppData\Local\Continuum\anaconda3\envs\samplesheet_launcher_py3.6\git\infrastructure" && git pull && exit"
```
