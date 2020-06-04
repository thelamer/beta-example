# buildtime stage
FROM lsiobase/alpine:3.12 as builder

ARG NANO_RELEASE
ARG THREADS=8

SHELL ["/bin/bash", "-c"]
RUN \
 echo "**** install build packages ****" && \
 apk add \
	cmake \
	curl \
	g++ \
	gcc \
	git \
	grep \
	jq \
	linux-headers \
	make \
	openssl \
	patch \
	wget
RUN \
 echo "**** grabbing source ****" && \
 if [ -z ${NANO_RELEASE+x} ]; then \
	NANO_RELEASE=$(curl -sL 'https://hub.docker.com/v2/repositories/nanocurrency/nano-beta/tags' \
	|jq -r '.results[].name' \
	|grep -Po "V\d+\d+.*" | head -n1); \
 fi && \
 git clone https://github.com/nanocurrency/nano-node.git /tmp/src && \
 cd /tmp/src && \
 git checkout ${NANO_RELEASE} && \
 git submodule update --init --recursive
RUN \
 echo "**** building boost ****" && \
 cd /tmp/src && \
 /bin/bash util/build_prep/bootstrap_boost.sh -m -B 1.70 && \
 mkdir /tmp/build
RUN \
 echo "**** compiling node software ****" && \
 cd /tmp/build && \
 cmake /tmp/src \
	-DCI_BUILD=OFF \
	-DBOOST_ROOT=/usr/local/boost \
	-DACTIVE_NETWORK=nano_beta_network \
	-DNANO_POW_SERVER=OFF && \
 make nano_node -j ${THREADS}
RUN \
 echo "**** organizing software ****" && \
 mkdir -p \
	/buildout/usr/bin \
	/buildout/etc && \
 mv \
	/tmp/build/nano_node \
	/buildout/usr/bin/ && \
 mv /tmp/src/api /buildout/usr/bin/api || : && \
 echo beta > /buildout/etc/nano-network

# runtime
FROM lsiobase/alpine:3.12

RUN \
 echo "**** install packages ****" && \
 apk add --no-cache \
	curl \
	p7zip && \
 echo "**** clean up ****" && \
 rm -rf \
	/tmp/*

# copy in files
COPY --from=builder /buildout /
COPY /root /

# ports and volumes
EXPOSE 54000/udp 54000 55000 57000
VOLUME /config
