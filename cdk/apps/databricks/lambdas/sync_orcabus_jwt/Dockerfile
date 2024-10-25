FROM amazon/aws-lambda-python:3.11.2024.01.05.15

LABEL maintainer="Alexis Lucattini"

# Install latest databricks cli
RUN yum update -y -q && \
    yum install -y -q \
      curl \
      unzip && \
    curl --fail --silent --show-error --location \
     --url "https://raw.githubusercontent.com/databricks/setup-cli/main/install.sh" | \
    sh


# Copy requirements.txt
# https://docs.aws.amazon.com/lambda/latest/dg/python-image.html
COPY requirements.txt ${LAMBDA_TASK_ROOT}
COPY lambda_code.py ${LAMBDA_TASK_ROOT}

# Install requirements
RUN pip install -r requirements.txt

CMD ["lambda_code.handler"]