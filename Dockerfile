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
RUN git clone --branch BigFastTreeModel https://beast-dev@github.com/beast-dev/beast-mcmc.git 
# RUN git clone --depth=1 --branch GMRFskyrideIntervalRefactor https://beast-dev@github.com/beast-dev/beast-mcmc.git 
WORKDIR ${ROOT_HOME}/beast-mcmc
RUN git checkout e5c6d1e
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


# iqtree 
WORKDIR ${ROOT_HOME}
RUN curl -fsSL https://github.com/iqtree/iqtree2/releases/download/v2.1.2/iqtree-2.1.2-Linux.tar.gz \
  | tar xzvpf - --strip-components=1
RUN mv bin/iqtree2 ${ROOT_HOME}/exicutables

## TODO does it use GPU if docker-nividiea2 is set up?

###########################################################################
# gotree just downloaded from releases - TODO grab from dockerhub image
FROM golang:1.13 as go
WORKDIR /go/src/app
RUN git clone --depth=1 --branch v0.4.2 https://github.com/evolbioinfo/gotree 
RUN go get -d -v ./gotree
RUN go install -v ./gotree

RUN git clone --depth=1 https://github.com/cov-ert/gofasta
RUN go get -d -v ./gofasta
RUN go install -v ./gofasta

# RUN git clone --depth=1 --branch v0.3.2 https://github.com/evolbioinfo/goalign 
# RUN go get -d -v ./goalign
# RUN go install -v ./goalign

# rust and fertree / TODO remove rust at the end
FROM rust:1.51 as rust
WORKDIR /root
RUN git clone https://github.com/jtmccr1/fertree.git
WORKDIR /root/fertree
RUN git checkout 5c7947d
RUN cargo install --path .

WORKDIR /root
RUN git clone  https://github.com/jtmccr1/sampler.git
WORKDIR /root/sampler
RUN git checkout bf0a646
RUN cargo install --path .

RUN cargo install ripgrep

# WORKDIR ${ROOT_HOME}
# RUN git clone --depth=1  https://github.com/neherlab/treetime.git
# WORKDIR ${ROOT_HOME}/treetime
# RUN pip3 install .
# RUN mv bin/treetime ${ROOT_HOME}/exicutables

# FROM quay.io/biocontainers/minimap2:2.20--h5bf99c6_0 as minimap2

#fresh image 
FROM python:3.7
# RUN apt-get update && apt-get install -y extra-runtime-dependencies && rm -rf /var/lib/apt/lists/* 
RUN git clone --depth=1  --branch v0.8.1 https://github.com/neherlab/treetime.git \
	 && cd treetime \
	 && pip3 install . 
COPY --from=beast /root/exicutables/* /usr/local/bin/
COPY --from=beast /root/beast_builds/* /usr/local/
COPY --from=beast /root/libs/lib/* /usr/local/lib/
COPY --from=beast /root/libs/include/* /usr/local/include/
COPY --from=beast /usr/local/openjdk-8 /usr/local/openjdk-8
COPY --from=rust  /usr/local/cargo/bin/fertree /usr/local/bin/fertree
COPY --from=rust  /usr/local/cargo/bin/sampler /usr/local/bin/sampler
COPY --from=rust  /usr/local/cargo/bin/rg /usr/local/bin/rg
COPY --from=go /go/bin/gotree /usr/local/bin/gotree
COPY --from=go /go/bin/gofasta /usr/local/bin/gofasta
# COPY --from=go /go/bin/goalign /usr/local/bin/goalign
COPY ./bin/* /usr/local/bin 

# COPY --from=minimap2 /usr/local/bin/minimap2 /usr/local/bin/minimap2


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



