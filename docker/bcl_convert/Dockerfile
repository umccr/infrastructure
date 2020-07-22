FROM centos:7

RUN yum update -y && \
    yum install -y wget unzip

RUN cd /tmp && \
    wget http://webdata.illumina.com.s3-website-us-east-1.amazonaws.com/downloads/software/bcl-convert/bcl-convert-3.6.3-1.el7.x86_64.zip && \
    unzip bcl-convert-3.6.3-1.el7.x86_64.zip && \
    yum install -y bcl-convert-3.6.3-1.el7.x86_64.rpm && \
    rm -rf /tmp/bcl-convert*

ENTRYPOINT ["bcl-convert"]
CMD ["--version"]