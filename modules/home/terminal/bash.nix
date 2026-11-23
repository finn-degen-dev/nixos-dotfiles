{ meta, ... }:

{
  programs.bash = {
    enable = true;
    shellAliases = {
      nrs = "sudo nixos-rebuild switch --flake ~/nixos-dotfiles#${meta.hostname}";
      n = "nvim";
      python = "python3";
      unity = "nvidia-offload unityhub";
      sops-edit = "nix shell nixpkgs#sops -c sops ~/nixos-dotfiles/secrets/secrets.yaml";

      update = "bash ~/nixos-dotfiles/config/vicinae/scripts/system-update.sh";
      update-local = "cd ~/nixos-dotfiles && nix flake update && sudo nixos-rebuild switch --flake ~/nixos-dotfiles#${meta.hostname} && sudo nix-collect-garbage --delete-older-than 7d && sudo nix-store --optimise";

      pack = "cd ~/nixos-dotfiles && repomix";
      pack-full = "cd ~/nixos-dotfiles && repomix --no-dot-ignore --ignore 'secrets/**,config/nvim/lazy-lock.json,config/icons/**'";
      pack-tokens = "cd ~/nixos-dotfiles && repomix --token-count-tree 200 --no-files --stdout";
    };
  };
}
