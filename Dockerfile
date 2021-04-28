FROM openjdk:8 as beast
# Beast and BEAGLE borrowed from https://github.com/beast-dev/BeastDocker/blob/master/Dockerfile
WORKDIR /tmp
RUN apt-get update && apt-get install -y \
#	libx11-6 libxext-dev libxrender-dev libxtst-dev \
	ant \
	build-essential \
	autoconf \
	automake \
	libtool \
	subversion 

# Clean-up
RUN apt-get -y autoremove
RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* 

ENV JAVA_TOOL_OPTIONS -Dfile.encoding=UTF8
ENV ROOT_HOME /root

# to make copying over easier in the end
RUN mkdir ${ROOT_HOME}/exicutables
RUN mkdir ${ROOT_HOME}/beast_builds/
RUN mkdir -p ${ROOT_HOME}/libs

# Clone and install Beast from sources
WORKDIR ${ROOT_HOME}
RUN git clone --depth=1 --branch v1.10.5pre_thorney_v0.1.1 https://beast-dev@github.com/beast-dev/beast-mcmc.git 
WORKDIR ${ROOT_HOME}/beast-mcmc
RUN ant linux
RUN mkdir -p /usr/local
RUN mv ${ROOT_HOME}/beast-mcmc/release/Linux/BEASTv1* ${ROOT_HOME}/beast_builds/
RUN ant -f build_beastgen.xml package
RUN mv ${ROOT_HOME}/beast-mcmc/release_beastgen/BEASTGen*/  ${ROOT_HOME}/beast_builds/

# beagle - hmc?
WORKDIR ${ROOT_HOME}
RUN git clone --depth=1 https://github.com/beagle-dev/beagle-lib.git
WORKDIR ${ROOT_HOME}/beagle-lib
RUN ./autogen.sh
RUN ./configure --disable-sse --disable-march-native --prefix=${ROOT_HOME}/libs
RUN make install 


## TODO does it use GPU if docker-nividiea2 is set up?

###########################################################################
# gotree just downloaded from releases - TODO grab from dockerhub image
WORKDIR ${ROOT_HOME}
RUN wget  --content-disposition  https://github.com/evolbioinfo/gotree/releases/download/v0.4.1/gotree_amd64_linux
RUN mv gotree_amd64_linux gotree 
RUN chmod +x gotree 
RUN mv gotree ${ROOT_HOME}/exicutables

# rust and fertree / TODO remove rust at the end
FROM rust:1.51 as rust
RUN git clone --depth=1 https://github.com/jtmccr1/fertree.git
WORKDIR ${ROOT_HOME}/fertree
RUN cargo install --path .

# WORKDIR ${ROOT_HOME}
# RUN git clone --depth=1  https://github.com/neherlab/treetime.git
# WORKDIR ${ROOT_HOME}/treetime
# RUN pip3 install .
# RUN mv bin/treetime ${ROOT_HOME}/exicutables

#fresh image 
FROM python:3.7
# RUN apt-get update && apt-get install -y extra-runtime-dependencies && rm -rf /var/lib/apt/lists/* 
RUN git clone --depth=1  https://github.com/neherlab/treetime.git \
	 && cd treetime \
	 && pip3 install . 
COPY --from=beast /root/exicutables/* /usr/local/bin/
COPY --from=beast /root/beast_builds/* /usr/local/
COPY --from=beast /root/libs/lib/* /usr/local/lib/
COPY --from=beast /root/libs/include/* /usr/local/include/
COPY --from=beast /usr/local/openjdk-8 /usr/local/openjdk-8
COPY --from=rust  /usr/local/cargo/bin/fertree /usr/local/bin/fertree
#Remove python remove once we don't need treetime anymore

ENV PATH /usr/local/bin:/usr/local/beast/bin:/usr/local/beastgen/bin:/usr/local/openjdk-8/bin:$PATH
ENV LD_LIBRARY_PATH /usr/local/lib:$LD_LIBRARY_PATH
ENV PKG_CONFIG_PATH $HOME/lib/pkgconfig:$PKG_CONFIG_PATH
ENV JAVA_TOOL_OPTIONS -Dfile.encoding=UTF8
ENV JAVA_HOME=/usr/local/openjdk-8




# FROM rocker/tidyverse:latest

# # Install R packages
# RUN install2.r --error \
#     lubridate \
#     tidyverse 
# set path



