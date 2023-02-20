FROM public.ecr.aws/lambda/python:3.9

ARG CONDA_LOCK_VERSION=0.2.0
ARG CONDA_LOCK_URL=https://raw.githubusercontent.com/umccr/dracarys/v${CONDA_LOCK_VERSION}/conda/env/lock/conda-lock.yml
ARG MINI_VERSION=22.11.1-4
ARG MINI_URL=https://github.com/conda-forge/miniforge/releases/download/${MINI_VERSION}/Mambaforge-${MINI_VERSION}-Linux-x86_64.sh
ARG MAMBA_PREFIX="/opt/mambaforge"

RUN yum update -y && \
    yum install -y wget curl git python3 python3-dev python3-pip gcc which
RUN   curl  -k --silent -L "${MINI_URL}" -o "/tmp/mambaforge.sh"
RUN   curl  -k --silent  -L "${CONDA_LOCK_URL}" -o "/tmp/conda-lock.yml"
RUN /bin/bash /tmp/mambaforge.sh -b -p "${MAMBA_PREFIX}" && rm /tmp/mambaforge.sh  

ENV PATH="${MAMBA_PREFIX}/bin:$PATH"
ARG ENV_DIR=/tmp/dracarys_conda_env
ARG ENV_NAME="dracarys_env"

RUN mkdir ${ENV_DIR}
RUN cp /tmp/conda-lock.yml ${ENV_DIR}/

RUN conda config --set always_yes yes && \
    mamba install -c conda-forge conda-lock==1.0.5
RUN conda-lock install --name ${ENV_NAME} ${ENV_DIR}/conda-lock.yml && mamba clean --all --force-pkgs-dirs

ENV PATH="${MAMBA_PREFIX}/envs/${ENV_NAME}/bin:${PATH}"
ENV CONDA_PREFIX="${MAMBA_PREFIX}/envs/${ENV_NAME}" 

SHELL ["conda", "run", "-n", "dracarys_env", "/bin/bash", "-c"]   

COPY requirements.txt ./
RUN pip install -r requirements.txt
COPY lambda.py ./
CMD ["lambda.handler"]
