FROM ubuntu:14.04

RUN apt-get update && apt-get -y upgrade

# this includes g++ & gcc
RUN apt-get install -y build-essential

# python 2.7 and 3 installed by default, but i prefer anaconda (also it includes pip)
RUN apt-get install -y wget
RUN wget https://3230d63b5fc54e62148e-c95ac804525aac4b6dba79b00b39d1d3.ssl.cf1.rackcdn.com/Anaconda-2.2.0-Linux-x86_64.sh
RUN chmod +x Anaconda-2.2.0-Linux-x86_64.sh
RUN /bin/bash /Anaconda-2.2.0-Linux-x86_64.sh -b -p /opt/conda
RUN rm Anaconda-2.2.0-Linux-x86_64.sh
ENV PATH /opt/conda/bin:$PATH

RUN conda update -y conda
RUN conda update -y anaconda

CMD ["/bin/bash"]
