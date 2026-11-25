{ pkgs, config, ... }:

let
  nvidia-offload = pkgs.writeShellScriptBin "nvidia-offload" ''
    unset __EGL_VENDOR_LIBRARY_FILENAMES
    export __NV_PRIME_RENDER_OFFLOAD=1
    export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
    export __GLX_VENDOR_LIBRARY_NAME=nvidia
    export __VK_LAYER_NV_optimus=NVIDIA_only
    exec "$@"
  '';
in
{

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      ocl-icd
      intel-compute-runtime # Fixes DaVinci Resolve aborting on the iGPU
    ];
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = true;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;

    prime = {
      offload = {
        enable = true;
        enableOffloadCmd = false; # Replaced below to unset __EGL_VENDOR_LIBRARY_FILENAMES for offloaded EGL apps
      };
      
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  boot.extraModprobeConfig = ''
    options nvidia NVreg_EnableGpuFirmware=0
    options nvidia_drm fbdev=0
  '';

  services.udev.extraRules = ''
    ACTION=="add|change", SUBSYSTEM=="drm", KERNEL=="card[0-9]*", DEVPATH=="*/0000:00:02.0/drm/card*", SYMLINK+="dri/intel-igpu"
    ACTION=="add|bind|change", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", TEST=="power/control", ATTR{power/control}="auto"
  '';

  environment.sessionVariables = {
    # Comment out AQ_DRM_DEVICES if using an external display port wired directly to the dGPU
    AQ_DRM_DEVICES = "/dev/dri/intel-igpu";
    __EGL_VENDOR_LIBRARY_FILENAMES = "/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json";
  };

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
  };

  programs.gamemode.enable = true;

  services.sunshine = {
    enable = true;
    autoStart = false;
    capSysAdmin = true;    # Essential for Wayland/Hyprland display capture
    openFirewall = true;   # Opens ports 47984-48010 for Moonlight
  };

  environment.systemPackages = with pkgs; [
    nvidia-offload
    steam-run
    cudatoolkit
  ];
}
