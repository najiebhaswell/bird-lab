FROM debian:12

# Install basic networking tools and dependencies
RUN apt-get update && apt-get install -y \
    apt-transport-https \
    ca-certificates \
    wget \
    iproute2 \
    iputils-ping \
    tcpdump \
    isc-dhcp-client \
    tshark \
    nano \
    mtr-tiny \
    traceroute \
    openssh-server \
    && rm -rf /var/lib/apt/lists/*

# Set root password to "root" for SSH access and allow root login
RUN echo "root:root" | chpasswd && \
    sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config

# Add CZ.NIC Labs Packaging GPG key and repo
RUN wget -O /usr/share/keyrings/cznic-labs-pkg.gpg https://pkg.labs.nic.cz/gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cznic-labs-pkg.gpg] https://pkg.labs.nic.cz/bird3 bookworm main" | tee /etc/apt/sources.list.d/cznic-labs-bird3.list

# Install bird3 from the repository
RUN apt-get update && apt-get install -y bird3 && rm -rf /var/lib/apt/lists/*

# The bird3 package instals bird to /usr/sbin/bird wait, the binary is probably `bird` or `bird3`. It's usually `bird`.
# We'll see. The config also might be at /etc/bird/bird.conf instead of /usr/local/etc/bird.conf
COPY bird.conf /etc/bird/bird.conf

COPY start.sh /start.sh
RUN chmod +x /start.sh

ENTRYPOINT ["/start.sh"]
