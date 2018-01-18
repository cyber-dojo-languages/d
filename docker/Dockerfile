FROM  cyberdojofoundation/ubuntu-build-essential:18.04
LABEL maintainer=jon@jaggersoft.com

RUN apt-get update
RUN apt-get install --yes gdc

RUN gdc --version | grep -q 7.2.0
