{ config, pkgs, meta, ... }:

{
  programs.git = {
    enable = true;
    settings = {
      user.name = meta.gitName;
      user.email = meta.gitEmail;
      commit.template = "${config.xdg.configHome}/git/commit-template";
      credential.helper = "${pkgs.gh}/bin/gh auth git-credential";
      filter.lfs = {
        clean = "${pkgs.git-lfs}/bin/git-lfs clean -- %f";
        process = "${pkgs.git-lfs}/bin/git-lfs filter-process";
        required = true;
        smudge = "${pkgs.git-lfs}/bin/git-lfs smudge -- %f";
      };
    };
  };

  xdg.configFile."git/commit-template".text = ''

    # <type>[optional (scope)][optional !]: <description>
    #
    # Core types:
    #   feat     - New feature or capability
    #   fix      - Bug fix
    #   chore    - Maintenance, lockfiles, cleanup
    #   refactor - Code/config restructure (no behavior change)
    #   docs     - Documentation or comments only
    #
    # Other types:
    #   build    - Dependencies, flake inputs, build scripts
    #   perf     - Performance improvement
    #   style    - Formatting / whitespace only
    #   ci       - CI/CD workflows
    #   test     - Adding or fixing tests
    #   revert   - Reverting a commit
  '';

  home.packages = with pkgs; [
    git-lfs
    gh
  ];
}
