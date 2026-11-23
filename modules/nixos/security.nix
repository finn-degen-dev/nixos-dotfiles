{ lib, ... }:

{
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 53317 8080 9090 ];
    allowedUDPPorts = [ 53317 ];
    logRefusedPackets = true;
    logRefusedConnections = true;
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
    extraConfig = ''
      Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
      MACs hmac-sha2-256-etm@openssh.com,hmac-sha2-512-etm@openssh.com,umac-128-etm@openssh.com
      KexAlgorithms curve25519-sha256,curve25519-sha256@libssh.org,diffie-hellman-group16-sha512,diffie-hellman-group18-sha512
      AuthenticationMethods publickey
      MaxAuthTries 3
      LoginGraceTime 30
      ClientAliveInterval 300
      ClientAliveCountMax 2
      X11Forwarding no
      AllowAgentForwarding no
      AllowStreamLocalForwarding no
      AllowTcpForwarding no
      PermitEmptyPasswords no
      PermitUserEnvironment no
      PrintMotd no
    '';
  };

  nix.settings = {
    allowed-users = [ "@wheel" ];
    require-sigs = true;

    http-connections = 50;
    max-substitution-jobs = 32;
    download-buffer-size = 67108864;

    trusted-substituters = [
      "https://cache.nixos.org"
      "https://nixos.cachix.org"
      "https://cuda-maintainers.cachix.org"
      "https://vicinae.cachix.org"
      "https://boredvoidater-dotfiles.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nixos.cachix.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5U="
      "vicinae.cachix.org-1:b67slZMcPnvEtL5mB5g7pSmD898Wmsr0pIgb78a/Xlg="
      "boredvoidater-dotfiles.cachix.org-1:Lw1knkMWYS0Zdc/xpPT+98s0nNio12ziYASKjps5790="
    ];
  };

  boot.kernel.sysctl = {
    "net.ipv4.tcp_syncookies" = 1;
    "net.ipv4.conf.all.rp_filter" = 1;
    "net.ipv4.conf.default.rp_filter" = 1;
    "net.ipv4.conf.all.accept_redirects" = 0;
    "net.ipv4.conf.default.accept_redirects" = 0;
    "net.ipv4.conf.all.send_redirects" = 0;
    "net.ipv4.conf.all.accept_source_route" = 0;
    "net.ipv4.conf.default.accept_source_route" = 0;
    "net.ipv4.icmp_echo_ignore_broadcasts" = 1;
    "net.ipv4.icmp_ignore_bogus_error_responses" = 1;
    "net.ipv6.conf.all.accept_redirects" = 0;
    "net.ipv6.conf.default.accept_redirects" = 0;
    "kernel.dmesg_restrict" = 1;
    "kernel.kptr_restrict" = 2;
    "kernel.yama.ptrace_scope" = 1;
    "kernel.unprivileged_bpf_disabled" = 1;
    "kernel.perf_event_paranoid" = 3;
    "fs.protected_hardlinks" = 1;
    "fs.protected_symlinks" = 1;
    "fs.protected_fifos" = 2;
    "fs.protected_regular" = 2;
    "vm.mmap_rnd_bits" = 32;
    "vm.mmap_rnd_compat_bits" = 16;
  };

  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
  };

  environment.defaultPackages = lib.mkForce [ ];

  security.audit = {
    enable = true;
    rules = [
      "-w /etc/passwd -p wa -k passwd_changes"
      "-w /etc/shadow -p wa -k shadow_changes"
      "-w /etc/sudoers -p wa -k sudoers_changes"
      "-w /etc/ssh/sshd_config -p wa -k sshd_config_changes"
      "-a exit,always -F arch=b64 -S mount -S umount2 -k mount"
      "-a exit,always -F arch=b64 -S setuid -S setgid -S setreuid -S setregid -k priv_esc"
      "-w /run/current-system/sw/bin/insmod -p x -k modules"
      "-w /run/current-system/sw/bin/rmmod -p x -k modules"
      "-w /run/current-system/sw/bin/modprobe -p x -k modules"
    ];
  };

  systemd.coredump.enable = true;
  systemd.coredump.settings.Coredump = {
    Storage = "external";
    Compress = "zstd";
    ProcessSizeMax = "2G";
    ExternalSizeMax = "10G";
    MaxUse = "5G";
    KeepSize = "1G";
  };
  systemd.tmpfiles.rules = [
    "d /var/lib/systemd/coredump 0700 root root -"
  ];

  boot.blacklistedKernelModules = [
    "cramfs"
    "freevxfs"
    "jffs2"
    "hfs"
    "hfsplus"
    "squashfs"
    "udf"
    "affs"
    "ecryptfs"
    "befs"
    "sysv"
    "ufs"
  ];
}
