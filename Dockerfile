# To refresh, copy the Digest from
# `docker buildx imagetools inspect cgr.dev/chainguard/wolfi-base:latest`
ARG WOLFI_BASE=cgr.dev/chainguard/wolfi-base@sha256:3258be472764337fd13095bcbb3182da170243b5819fd67ad4c0754590588b31

FROM ${WOLFI_BASE} AS builder

ARG GAWK_VERSION=5.3.2
ARG GAWK_SHA256=f8c3486509de705192138b00ef2c00bbbdd0e84c30d5c07d23fc73a9dc4cc9cc

ARG BATS_VERSION=1.13.0
ARG BATS_SHA256=a85e12b8828271a152b338ca8109aa23493b57950987c8e6dff97ba492772ff3

# build-base: gcc + make + glibc-dev
# gmp-dev + mpfr-dev: arbitrary-precision math support (gawk -M flag).
# Wolfi's prebuilt gawk lacks MPFR, which silently breaks exercises that
# rely on big-integer arithmetic (e.g., armstrong-numbers).
RUN apk add --no-cache bash build-base gmp-dev mpfr-dev wget xz

RUN wget -q -O /tmp/gawk.tar.xz \
        https://ftp.gnu.org/gnu/gawk/gawk-${GAWK_VERSION}.tar.xz \
    && [ "$(sha256sum /tmp/gawk.tar.xz | cut -d' ' -f1)" = "${GAWK_SHA256}" ] \
    && tar -C /tmp -xJf /tmp/gawk.tar.xz \
    && cd /tmp/gawk-${GAWK_VERSION} \
    && ./configure --prefix=/usr/local --with-mpfr \
    && make -j"$(nproc)" \
    && make install

RUN wget -q -O /tmp/bats.tar.gz \
        https://github.com/bats-core/bats-core/archive/refs/tags/v${BATS_VERSION}.tar.gz \
    && [ "$(sha256sum /tmp/bats.tar.gz | cut -d' ' -f1)" = "${BATS_SHA256}" ] \
    && tar -C /tmp -xzf /tmp/bats.tar.gz \
    && /tmp/bats-core-${BATS_VERSION}/install.sh /usr/local


FROM ${WOLFI_BASE}

# bash for bin/run.sh (uses arrays, [[, etc.)
# coreutils for realpath
# jq for JSON output
# gmp + mpfr: runtime libs for the gawk we built above
RUN apk add --no-cache bash coreutils gmp jq mpfr

COPY --from=builder /usr/local /usr/local

WORKDIR /opt/test-runner
COPY . .
ENV BATS_RUN_SKIPPED=true
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8
ENTRYPOINT ["/opt/test-runner/bin/run.sh"]
