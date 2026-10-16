# notmuch: the index, the tag rules and the post-new hook (homeManager.email).
{
  homeManager.email =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      # Folder names come from the account (accounts.email.accounts.personal
      # .folders, default.nix); home-manager has no option for the junk folder.
      personal = config.accounts.email.accounts.personal;
      junkFolder = "Junk";
      # A notmuch query for one of the personal account's maildir folders.
      folder = name: "folder:${personal.maildir.path}/${name}";

      # Structural: by folder, always applied to all mail.
      folderRules = [
        "+sent -inbox -- ${folder personal.folders.sent}"
        "+draft -inbox -- ${folder personal.folders.drafts}"
        "+trash -inbox -- ${folder personal.folders.trash}"
        "+spam -inbox -- ${folder junkFolder}"
      ];

      # Category tags. Applied to new mail by the post-new hook, and to all mail
      # by `notmuch-retag`, so both always use the same rules.
      categoryRules = {
        finance = "to:fin.outlying285@simplelogin.com or from:revolut or from:paypal or from:coinbase or from:stripe or from:bbva or from:n26";
        shopping = "to:vinted.bust057@simplelogin.com or from:silbon or from:aliexpress or from:amazon or from:boots or from:uber";
        social = "to:socbos+twitter@simplelogin.com or from:instagram or from:twitter or from:facebookmail";
        jobs = "from:pagepersonnel or from:infojobs or from:relocate or from:appfigures";
        travel = "from:iberia or from:balearia or from:booking or from:airbnb or from:renfe or from:parador";
        newsletter = "to:simplelogin-newsletter.makeover699@simplelogin.com or from:voxespana or from:elespanol or from:myglo or from:lateral or from:riela or from:steam";
        # U-tad (Office 365) mail: the tenant blocks third-party IMAP/SMTP
        # clients, so it is forwarded from Outlook to a SimpleLogin alias.
        utad = "to:juan.vallejo@live.u-tad.com or to:utadfwd.culminate455@aleeas.com";
      };

      # A `notmuch tag --batch` file (see notmuch-tag(1), TAG FILE FORMAT).
      # `scope` is prepended to every category query.
      mkTagBatch =
        name: scope:
        pkgs.writeText "notmuch-${name}.batch" (
          lib.concatLines (
            folderRules ++ lib.mapAttrsToList (tag: query: "+${tag} -- ${scope}(${query})") categoryRules
          )
        );

      newMailBatch = mkTagBatch "new" "tag:new and ";
      allMailBatch = mkTagBatch "all" "";
    in
    {
      home.packages = [
        # Re-apply every tag rule to all mail, e.g. after adding or changing one.
        # Only adds tags; it never removes a tag a changed rule no longer matches.
        (pkgs.writeShellScriptBin "notmuch-retag" ''
          exec ${pkgs.notmuch}/bin/notmuch tag --batch --input=${allMailBatch}
        '')
      ];

      programs.notmuch = {
        enable = true;
        # `new` marks mail for the new-mail tag rules (newMailBatch); the
        # post-new hook removes it once they (and notify.nix) have run.
        settings.new.tags = [
          "new"
          "unread"
          "inbox"
        ];
        # No pre-new hook: syncing is sync.nix's mail-sync, which then runs
        # `notmuch new`. Post-new: tag rules first (so spam/trash are known),
        # then notify.nix's notification step, then clear `new`.
        hooks.postNew = lib.mkMerge [
          (lib.mkBefore "notmuch tag --batch --input=${newMailBatch}")
          (lib.mkAfter "notmuch tag -new -- tag:new")
        ];
      };
    };
}
