FROM ubuntu:resolute AS builder

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && \
    apt-get -y install --no-install-recommends \
    acl attr autoconf bind9utils binutils bison build-essential \
    ca-certificates ccache curl debhelper dnsutils docbook-xml \
    docbook-xsl flex gcc git glusterfs-common gzip heimdal-multidev \
    hostname krb5-config krb5-kdc krb5-user language-pack-en \
    libacl1-dev libarchive-dev libattr1-dev libavahi-common-dev \
    libblkid-dev libbsd-dev libcap-dev libcephfs-dev libcups2-dev \
    libdbus-1-dev libglib2.0-dev libgnutls28-dev libgpgme11-dev \
    libicu-dev libjansson-dev libjson-perl libkrb5-dev libldap2-dev \
    liblmdb-dev libncurses5-dev libpam0g-dev libparse-yapp-perl \
    libpcap-dev libpopt-dev libreadline-dev libsystemd-dev \
    libtasn1-dev libtracker-sparql-3.0-dev libunwind-dev lmdb-utils \
    locales lsb-release make mawk patch perl perl-modules pkg-config \
    procps psmisc python3 python3-cryptography python3-dbg python3-dev \
    python3-dnspython python3-gpg python3-iso8601 python3-markdown \
    python3-matplotlib python3-pexpect python3-pyasn1 python3-setproctitle \
    rng-tools rsync sed sudo tar tree uuid-dev wget xfslibs-dev \
    xsltproc zlib1g-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/* /var/cache/apt/*

WORKDIR /build

RUN wget https://download.samba.org/pub/samba/stable/samba-4.24.7.tar.gz && \
    tar xzvf samba-4.24.7.tar.gz && \
    cd samba-4.24.7 && \
    ./configure \
        --prefix=/usr/local/samba \
        --enable-selftest \
        --sysconfdir=/etc/samba \
        --with-ldap \
        --with-shared-modules='!vfs_snapper' \
        --with-ads \
        --with-winbind && \
    make -j"$(nproc)" && \
    make install && \
    find /usr/local/samba -type f -executable -exec strip --strip-unneeded {} \; 2>/dev/null || true && \
    find /usr/local/samba -name "*.so*" -exec strip --strip-unneeded {} \; 2>/dev/null || true && \
    rm -rf /usr/local/samba/share/doc /usr/local/samba/share/man /usr/local/samba/include /usr/local/samba/lib/*.la && \
    cd / && rm -rf /build/samba-4.24.7*

FROM ubuntu:resolute AS runtime

ENV DEBIAN_FRONTEND=noninteractive \
    PATH=/usr/local/samba/bin:/usr/local/samba/sbin:$PATH

RUN apt-get update && \
    apt-get -y install --no-install-recommends \
    acl attr bind9utils ca-certificates dnsutils \
    krb5-config krb5-kdc krb5-user \
    libacl1 libarchive13 libattr1 libavahi-common3 libblkid1 \
    libbsd0 libcap2 libcephfs2 libcups2 libdbus-1-3 libglib2.0-0 \
    libgpgme45 libjansson4 libldap2 libncurses6 libpopt0 \
    libpython3.14 libncursesw6 libpam0g libsystemd0 \
    procps python3 python3-cryptography python3-dnspython \
    python3-gpg python3-iso8601 python3-markdown python3-pexpect \
    python3-pyasn1 python3-setproctitle sed tar && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* /var/cache/apt/* /tmp/* /var/tmp/*

COPY --from=builder /usr/local/samba /usr/local/samba
COPY --from=builder /etc/samba /etc/samba

VOLUME ["/etc/samba", "/usr/local/samba"]

ADD docker-entrypoint.sh /docker-entrypoint.sh
RUN chmod +x /docker-entrypoint.sh

ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["samba"]
