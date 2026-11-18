# Cloud provider CLIs: AWS (aws), Google Cloud (gcloud, gsutil, bq) and
# Kubernetes (kubectl, k9s) for their clusters.
{
  homeManager.cloud =
    { pkgs, ... }:
    {
      # Only the package: with settings/credentials left empty the module
      # writes nothing, so ~/.aws/config stays a normal file that
      # `aws configure sso` can edit (declared settings would make it a
      # read-only store symlink). SSO tokens are short-lived and cached by
      # `aws sso login` in ~/.aws/sso/cache; nothing secret is declared here.
      programs.awscli.enable = true;

      # No home-manager module; gcloud already uses ~/.config/gcloud. Log in
      # with `gcloud auth login` (and `gcloud auth application-default login`
      # for SDKs). gke-gcloud-auth-plugin is kubectl's credential plugin for
      # GKE clusters (`gcloud container clusters get-credentials` wires it up);
      # EKS's (`aws eks update-kubeconfig`) is the aws CLI itself.
      home.packages = [
        (pkgs.google-cloud-sdk.withExtraComponents [
          pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin
        ])
        pkgs.kubectl
      ];

      programs.k9s.enable = true;

      # home.shellAliases reaches every enabled shell (zsh and bash, from
      # shell.nix) and merges with their own aliases.
      home.shellAliases.awslogin = "aws sso login --sso-session Anaya";

      # `awsp <profile>` switches AWS_PROFILE in the current shell, completing
      # the profiles in ~/.aws/config. zsh only; merges with shell.nix's
      # initContent, after compinit.
      programs.zsh.initContent = ''
        awsp() { export AWS_PROFILE="$1"; }
        _awsp() { compadd $(aws configure list-profiles); }
        compdef _awsp awsp
      '';
    };
}
