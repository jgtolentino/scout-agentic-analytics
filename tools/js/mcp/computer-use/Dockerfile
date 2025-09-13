FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
ENV PYTHONUNBUFFERED=1

# Install system dependencies
RUN apt-get update && apt-get install -y \
    # X11 and display
    xvfb \
    x11vnc \
    xterm \
    fluxbox \
    novnc \
    websockify \
    # Desktop environment
    mutter \
    tint2 \
    gnome-terminal \
    nautilus \
    # Applications
    firefox \
    libreoffice \
    gedit \
    evince \
    # Development tools
    curl \
    wget \
    git \
    python3 \
    python3-pip \
    nodejs \
    npm \
    # System utilities
    sudo \
    net-tools \
    iputils-ping \
    dbus-x11 \
    # Screenshots and automation
    scrot \
    xdotool \
    xclip \
    # Fonts
    fonts-liberation \
    fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/*

# Create non-root user
RUN useradd -m -s /bin/bash user && \
    echo 'user:pulser' | chpasswd && \
    usermod -aG sudo user && \
    echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers

# Set up VNC
RUN mkdir -p /home/user/.vnc && \
    x11vnc -storepasswd pulser123 /home/user/.vnc/passwd && \
    chown -R user:user /home/user/.vnc

# Install Python packages for automation
RUN pip3 install --no-cache-dir \
    pyautogui \
    pillow \
    opencv-python-headless \
    numpy \
    requests

# Install Node.js packages
WORKDIR /app
COPY package*.json ./
RUN npm install

# Copy application files
COPY . .
RUN chown -R user:user /app

# Set up workspace directory
RUN mkdir -p /home/user/workspace && \
    chown -R user:user /home/user/workspace

# Create startup script
RUN echo '#!/bin/bash\n\
# Start X virtual framebuffer\n\
Xvfb :1 -screen 0 ${DISPLAY_WIDTH}x${DISPLAY_HEIGHT}x24 &\n\
sleep 2\n\
\n\
# Start window manager\n\
DISPLAY=:1 mutter &\n\
sleep 1\n\
\n\
# Start panel\n\
DISPLAY=:1 tint2 &\n\
\n\
# Start VNC server\n\
x11vnc -display :1 -forever -usepw -shared -rfbport 5900 -bg -o /var/log/x11vnc.log\n\
\n\
# Start noVNC\n\
websockify --web=/usr/share/novnc/ 6080 localhost:5900 &\n\
\n\
# Start the MCP server\n\
cd /app && npm start\n\
' > /start.sh && chmod +x /start.sh

# Switch to non-root user
USER user
WORKDIR /home/user

# Expose ports
EXPOSE 5900 6080 8080

# Start services
CMD ["/start.sh"]