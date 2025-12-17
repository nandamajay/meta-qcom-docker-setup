FROM ubuntu:22.04

# Install Yocto build dependencies + kas + UI tools
RUN apt-get update && apt-get install -y \
    git python3-pip locales build-essential \
    chrpath cpio diffstat file gawk wget zstd \
    whiptail pv sudo ca-certificates xz-utils tar rsync \
    && update-ca-certificates \
    && locale-gen en_US.UTF-8

# Cache meta-qcom inside the image for fast seeding
RUN mkdir -p /opt/src && \
    git clone --depth 1 -b master https://github.com/qualcomm-linux/meta-qcom.git /opt/src/meta-qcom

# Create non-root user (do this while still root)
RUN useradd -m builder && echo "builder ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Critical defaults for tools relying on $HOME and for kas's work dir
ENV HOME=/workspace
ENV KAS_WORK_DIR=/workspace/.kas

# Pre-create runtime directories as root, then give them to 'builder'
RUN mkdir -p /workspace/.kas && chown -R builder:builder /workspace

# Switch to non-root user and set working dir
USER builder
WORKDIR /workspace

# Install kas
RUN sudo pip3 install kas

# Copy interactive build script
COPY build-meta-qcom-ui.sh /usr/local/bin/build-meta-qcom-ui.sh
RUN sudo chmod +x /usr/local/bin/build-meta-qcom-ui.sh

# Use JSON-form (exec) ENTRYPOINT
ENTRYPOINT ["/usr/local/bin/build-meta-qcom-ui.sh"]
