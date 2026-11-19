# The fork's Batocera build image plus a make wrapper for Rosetta
# (see make-wrapper). build-on-mac.sh builds and uses this image.
ARG BASE
FROM ${BASE}
COPY make-wrapper /usr/bin/make.wrapper
RUN mv /usr/bin/make /usr/bin/make.real \
 && mv /usr/bin/make.wrapper /usr/bin/make \
 && make --version | head -1 && gmake --version | head -1
