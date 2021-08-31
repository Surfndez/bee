ARG BASH_VERSION=5.1
FROM bash:${BASH_VERSION} AS base
WORKDIR /usr/local/opt/bee
COPY DEPENDENCIES.md .
RUN apk add --no-cache $(cat DEPENDENCIES.md)
RUN git config --global user.email "bee" && git config --global user.name "bee"

FROM base AS bee
WORKDIR /usr/local/opt/bee
COPY etc etc
COPY src src
COPY version.txt .
RUN echo "source /usr/local/opt/bee/etc/bash_completion.d/bee-completion.bash" > /root/.bashrc
RUN ln -s /usr/local/opt/bee/src/bee /usr/local/bin/bee
VOLUME /root/project
WORKDIR /root/project
CMD ["bee"]

FROM bee AS test
WORKDIR /usr/local/opt/bee
COPY test test
RUN test/bats/bin/bats --tap test
