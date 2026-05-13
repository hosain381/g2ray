{
  "name": "G2Ray",
  "build": {
    "dockerfile": "Dockerfile"
  },
  "features": {
    "ghcr.io/devcontainers/features/sshd:1": {
      "version": "latest"
    }
  },
  "forwardPorts": [443],
  "portsAttributes": {
    "443": {
      "label": "Xray VLESS",
      "onAutoForward": "silent",
      "visibility": "public"
    }
  },
  "postCreateCommand": "bash /workspaces/g2ray/.devcontainer/startup.sh",
  "remoteUser": "root"
}
