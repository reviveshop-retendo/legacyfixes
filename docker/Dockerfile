# Build environment for LegacyFixes.
#
# Theos needs a cross toolchain to build armv7 dylibs on x86_64 Linux.
# The official installer sets all of that up for us.
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        bash ca-certificates curl git make perl rsync zip xz-utils \
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

WORKDIR /work
CMD ["bash"]
