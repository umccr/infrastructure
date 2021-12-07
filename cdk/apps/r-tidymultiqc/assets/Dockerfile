FROM public.ecr.aws/lambda/provided:al2

RUN yum -y install wget tar libxml2-devel && amazon-linux-extras install R4 -y

ENV PATH="${PATH}:/opt/R/${R_VERSION}/bin/"

RUN Rscript -e "install.packages(c('httr', 'jsonlite', 'logger', 'logging', 'TidyMultiqc', 'arrow', 'paws'), repos = 'https://cloud.r-project.org/')"

COPY runtime.R functions.R bootstrap.R ${LAMBDA_TASK_ROOT}/
RUN chmod 755 -R ${LAMBDA_TASK_ROOT}/

RUN printf '#!/bin/sh\ncd $LAMBDA_TASK_ROOT\nRscript bootstrap.R' > /var/runtime/bootstrap \
  && chmod +x /var/runtime/bootstrap

CMD [ "functions.myRcode" ]
