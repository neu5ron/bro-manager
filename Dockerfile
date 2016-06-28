FROM phusion/baseimage
MAINTAINER Slawomir Rozbicki <docker@rozbicki.eu>

# Specify program
ENV PROG bro
ENV PF_PROG PF_RING
# Specify source extension
ENV EXT tar.gz
# Specify Bro version to download and install (e.g. bro-2.3.1, bro-2.4)
ENV BRO_VERS 2.4.1
# Install directory
ENV PREFIX /opt/bro
ENV PF_PREFIX /opt/PF_RING
ENV CAF_PREFIX /opt/caf
# Path should include prefix
ENV PATH /usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PREFIX/bin
# Storage prefix
ENV STOR_PATH /data/bro
# Build faster (make -jX)
ENV PROC_NUM 4

# Bro deps
RUN apt-get update -y && apt-get install --no-install-recommends -y \
google-perftools libtcmalloc-minimal4 libgoogle-perftools4 geoip-bin \
geoip-database rsync ssmtp

# Devels (only for bro build - might be removed later)
RUN apt-get install --no-install-recommends -y libgoogle-perftools-dev \
libgeoip-dev cmake gcc g++ bison flex python-dev swig make libssl-dev git

# Build PF_RING
WORKDIR /usr/src
RUN git clone https://github.com/ntop/PF_RING.git
WORKDIR /usr/src/$PF_PROG/userland/lib
RUN ./configure && make -j$PROC_NUM
WORKDIR /usr/src/$PF_PROG/userland/libpcap
RUN ./configure --prefix=$PF_PREFIX && make -j$PROC_NUM && make install 

# Build CAF
WORKDIR /usr/src
RUN git clone https://github.com/actor-framework/actor-framework.git
WORKDIR /usr/src/actor-framework
RUN ./configure --prefix=$CAF_PREFIX && make -j$PROC_NUM && make install

# Build Bro
WORKDIR /usr/src
RUN curl --insecure -O https://www.bro.org/downloads/release/$PROG-$BRO_VERS.$EXT && tar -xzf $PROG-$BRO_VERS.$EXT
WORKDIR /usr/src/$PROG-$BRO_VERS
RUN ./configure --prefix=$PREFIX --with-pcap=$PF_PREFIX --with-libcaf=$CAF_PREFIX \
&& make -j$PROC_NUM && make install && make install-aux

# Get the GeoIP data, prepare the storage & misc tunning.
RUN mkdir -p ${STOR_PATH}/logs ${STOR_PATH}/spool \
&& sed -i 's/^LogDir = \/opt\/bro/LogDir = \/data\/bro/g' ${PREFIX}/etc/broctl.cfg\
&& sed -i 's/^SpoolDir = \/opt\/bro/SpoolDir = \/data\/bro/g' ${PREFIX}/etc/broctl.cfg

# Clean up.
RUN apt-get remove -y libgoogle-perftools-dev libgeoip-dev cmake gcc g++ \
bison flex python-dev swig make libssl-dev git && apt-get autoremove -y \
&& apt-get autoclean -y

CMD ["/usr/bin/python", "/opt/bro/bin/broctl"]
