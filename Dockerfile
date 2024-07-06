# This is the last tested version of emscripten.
# Feel free to try with a newer version
FROM emscripten/emsdk:3.1.62

RUN DEBIAN_FRONTEND=noninteractive apt --no-install-recommends -qy update && \
    DEBIAN_FRONTEND=noninteractive apt --no-install-recommends -qy install \
    pkg-config \
    ninja-build \
    jq \
    brotli \
    autoconf \
    autoconf-archive \
    automake \
    zlib1g-dev

# Add to PATH the clang version that ships with emsdk
ENV PATH="${EMSDK}/upstream/bin:${PATH}"