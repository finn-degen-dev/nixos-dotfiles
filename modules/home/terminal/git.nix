{ pkgs, meta, ... }:

{
  programs.git = {
    enable = true;
    settings = {
      user.name = meta.gitName;
      user.email = meta.gitEmail;
      credential.helper = "${pkgs.gh}/bin/gh auth git-credential";
      filter.lfs = {
        clean = "${pkgs.git-lfs}/bin/git-lfs clean -- %f";
        process = "${pkgs.git-lfs}/bin/git-lfs filter-process";
        required = true;
        smudge = "${pkgs.git-lfs}/bin/git-lfs smudge -- %f";
      };
    };
  };

  home.packages = with pkgs; [
    git-lfs
    gh
  ];
}
