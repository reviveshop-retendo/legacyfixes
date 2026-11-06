# Build environment for LegacyFixes.
#
# Theos needs a cross toolchain to build armv7 dylibs on x86_64 Linux.
# The official installer sets all of that up for us.
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        bash ca-certificates curl git make perl rsync zip unzip xz-utils xxd \
        build-essential fakeroot libxml2 libtinfo6 sudo python3 dpkg-dev \
    && rm -rf /var/lib/apt/lists/*

RUN useradd -m -s /bin/bash builder \
    && echo 'builder ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

USER builder
ENV HOME=/home/builder \
    THEOS=/home/builder/theos \
    CI=1 \
    PATH=/home/builder/theos/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Installs Theos, the Linux iOS toolchain, and the latest SDK.
RUN bash -c "$(curl -fsSL https://raw.githubusercontent.com/theos/theos/master/bin/install-theos)"

# iOS 6/7/8/9 are 32-bit only, so build against the last 32-bit SDK.
RUN "$THEOS/bin/install-sdk" iPhoneOS9.3

# The theos iOS 9.3 SDK omits liblaunch.dylib, but its libSystem.tbd still
# re-exports it. Apple's ld64 tolerates that; the Linux ld64 in the toolchain
# treats it as a fatal missing input. Nothing we link uses liblaunch symbols,
# so drop the dangling re-export.
RUN sed -i 's| /usr/lib/system/liblaunch\.dylib,||' \
    "$THEOS/sdks/iPhoneOS9.3.sdk/usr/lib/libSystem.tbd"

# TubeReplacer's bundled Objective-C protobuf runtime is version 40311.
# protoc must emit matching generated code; protoc 3.12 (Ubuntu 22.04's
# package) is too old and fails the runtime version check. Pin 35.1.
USER root
RUN curl -fsSL -o /tmp/protoc.zip \
        "https://github.com/protocolbuffers/protobuf/releases/download/v35.1/protoc-35.1-linux-x86_64.zip" \
    && echo "6930ebf62bd4ea607b98fff052596c6ee564b9835b4ce172c75a3f53ae9d91b7  /tmp/protoc.zip" \
        | sha256sum -c - \
    && mkdir -p /opt/protoc \
    && unzip -q /tmp/protoc.zip -d /opt/protoc \
    && ln -s /opt/protoc/bin/protoc /usr/local/bin/protoc \
    && rm -f /tmp/protoc.zip

# CI runs the container as the runner's arbitrary UID. Theos lives in
# /home/builder, which useradd creates as 0750; without traversal permission
# make cannot read the Theos makefiles and fails with "No rule to make target
# '/tweak.mk'". Keep this as its own layer so it does not invalidate the
# expensive Theos/SDK install above.
RUN chmod 0755 /home/builder
USER builder

WORKDIR /work
CMD ["bash"]
