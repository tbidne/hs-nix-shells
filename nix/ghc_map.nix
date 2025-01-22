let
  getPkgs =
    hash:
    import (fetchTarball { url = "https://github.com/NixOS/nixpkgs/archive/${hash}.tar.gz"; }) { };

  mkSet =
    {
      hash,
      versName,
      overrides ? _: _: { },
      poorGhcCache ? false,
      poorToolCache ? [ ],
      unstableHash ? false,
      unsupported ? [ ],
      warnings ? [ ],
    }:
    let
      hlib = pkgs.haskell.lib;
      pkgs = getPkgs hash;

      # Combines fixed warnings with general custom warning into a bulleted
      # list of warnings.
      allWarnings =
        let
          poorGhcCacheMsg = if poorGhcCache then "This GHC has poor caching." else null;

          poorToolCacheWarnMsg =
            if poorToolCache == [ ] then
              null
            else
              "Tool(s) have poor caching: " + builtins.concatStringsSep ", " poorToolCache;

          unstableHashWarnMsg =
            if unstableHash then "The hash is unstable i.e. this may change in the future." else null;

          unsupportedWarnings =
            if unsupported == [ ] then
              null
            else
              "Unsupported tool(s): " + builtins.concatStringsSep ", " unsupported;

          composeWarnings =
            msgs:
            let
              go = acc: m: if m != null then acc + "\n - " + m else acc;
            in
            builtins.foldl' go "" msgs;
        in
        composeWarnings (
          [
            poorGhcCacheMsg
            poorToolCacheWarnMsg
            unstableHashWarnMsg
            unsupportedWarnings
          ]
          ++ warnings
        );
      wrapper = if allWarnings == "" then x: x else x: pkgs.lib.warn allWarnings x;
    in
    {
      inherit pkgs unsupported versName;
      compiler = wrapper (
        pkgs.haskell.packages."${versName}".override {
          # compose inherited overrides w/ custom set below
          overrides =
            final: prev:
            (overrides final prev)
            // {
              # Conundrum: This package had failing tests on CI for GHC 9.4.4.
              # On the one hand, GHC 9.4.4 is not a priority as its caching is
              # poor and there are better, more recent versions.
              #
              # On the other hand, this could happen to a version we care about,
              # so we should probably do something about it.
              #
              # We could override hls to disable floskell as it is not a package
              # I personally care about. But that feels like a sticky situation,
              # providing hls w/ some plugins randomly disabled.
              #
              # Probably the best compromise is to simply disable tests suites as
              # needed.
              hls-floskell-plugin = hlib.dontCheck prev.hls-floskell-plugin;
            };
        }
      );
    };
in
# NOTE: We do not always need to override tools even though the default is
# not what we want.
#
# For example, the current ghc 9.4 nixpkgs hash we use has the default
# hlint-3.4 (ghc 9.2) whereas we want hlint-3.5. We could explicitly
# override this, but in fact this is already done in nixpkgs in
# configuration-ghc-9.4.x.nix.
{
  # In general, the hash for ghc vers N should be a commit C where N has
  # good caching for every tool. The best candidates are commits where N is
  # the default ghc.
  #
  # However, some versions will not have any such C as they were never a
  # default e.g. ghc928 was released after 9.4.X was already the default.
  # For those, just take the earliest hash when they were added.
  #
  # When we have a choice, in theory it makes sense to take the latest commit
  # possible, since it is more likely that later hashes will be compatible
  # with more packages (because maintainers will have had more time to make
  # their packages compatible).
  #
  # In practice, simply taking the first hash that gives us good caching and
  # tool compatibility is good enough and means we don't have to keep updating
  # hashes just in case a later one is "better". Thus we generally only
  # update an existing hash when the newer hash offers better caching / fixes
  # some tool.
  #
  # These hashes should come from nixos-unstable for caching purposes.

  ghc8107 = mkSet {
    hash = "6d28139e80dd2976650c6356269db942202e7c90";
    versName = "ghc8107";
  };

  ghc902 = mkSet {
    hash = "a7855f2235a1876f97473a76151fec2afa02b287";
    versName = "ghc902";
  };

  ghc925 = mkSet {
    hash = "d0d55259081f0b97c828f38559cad899d351cad1";
    versName = "ghc925";
  };

  ghc926 = mkSet {
    hash = "d0d55259081f0b97c828f38559cad899d351cad1";
    versName = "ghc926";
  };

  ghc927 = mkSet {
    hash = "3c5319ad3aa51551182ac82ea17ab1c6b0f0df89";
    versName = "ghc927";
  };

  ghc928 = mkSet {
    hash = "75a5ebf473cd60148ba9aec0d219f72e5cf52519";
    versName = "ghc928";
  };

  ghc944 = mkSet {
    hash = "5e4c2ada4fcd54b99d56d7bd62f384511a7e2593";
    versName = "ghc944";
    poorGhcCache = true;
  };

  ghc945 = mkSet {
    hash = "5e4c2ada4fcd54b99d56d7bd62f384511a7e2593";
    versName = "ghc945";
  };

  ghc946 = mkSet {
    hash = "5e4c2ada4fcd54b99d56d7bd62f384511a7e2593";
    versName = "ghc946";
  };

  ghc947 = mkSet {
    hash = "85f1ba3e51676fa8cc604a3d863d729026a6b8eb";
    versName = "ghc947";
  };

  ghc948 = mkSet {
    hash = "5a09cb4b393d58f9ed0d9ca1555016a8543c2ac8";
    versName = "ghc948";
  };

  ghc961 = mkSet {
    # Older hash as newer hash does not contain ghc961. Sadly this means we
    # cannot use hlint as this nixpkgs does not have hlint_3_6. We need to
    # overrride it manually e.g. with callHackage.
    hash = "1c9db9710cb23d60570ad4d7ab829c2d34403de3";
    versName = "ghc961";
    overrides = final: prev: {
      apply-refact = prev.apply-refact_0_13_0_0;
      fourmolu = prev.fourmolu_0_12_0_0;
      ormolu = prev.ormolu_0_7_1_0;

      hlint = (
        final.callHackageDirect {
          pkg = "hlint";
          ver = "3.6.1";
          sha256 = "sha256-fH4RYnWeuBqJI5d3Ba+Xs0BxYr0IYFH1OWO3k2iHGlU=";
        } { }
      );
    };
    poorGhcCache = true;
  };

  ghc962 = mkSet {
    hash = "5e4c2ada4fcd54b99d56d7bd62f384511a7e2593";
    versName = "ghc962";
    overrides = _: prev: {
      fourmolu = prev.fourmolu_0_13_1_0;
      hlint = prev.hlint_3_6_1;
      ormolu = prev.ormolu_0_7_2_0;
    };
  };

  ghc963 = mkSet {
    hash = "5e4c2ada4fcd54b99d56d7bd62f384511a7e2593";
    versName = "ghc963";
    overrides = _: prev: {
      fourmolu = prev.fourmolu_0_13_1_0;
      hlint = prev.hlint_3_6_1;
      ormolu = prev.ormolu_0_7_2_0;
    };
  };

  ghc964 = mkSet {
    hash = "2726f127c15a4cc9810843b96cad73c7eb39e443";
    versName = "ghc964";
  };

  ghc965 = mkSet {
    hash = "25865a40d14b3f9cf19f19b924e2ab4069b09588";
    versName = "ghc965";
  };

  ghc966 = mkSet {
    hash = "d04953086551086b44b6f3c6b7eeb26294f207da";
    versName = "ghc966";
  };

  # NOTE: We could upgrade this hash to 25865a40d14b3f9cf19f19b924e2ab4069b09588
  # -- what ghc982 currently uses -- and then we'd get apply-refact.
  # However ghc981's caching is terrible with that hash, so we judge that the
  # better caching is worth giving up apply-refact.
  ghc981 = mkSet {
    hash = "2726f127c15a4cc9810843b96cad73c7eb39e443";
    versName = "ghc981";
    overrides = _: prev: {
      fourmolu = prev.fourmolu_0_14_1_0;
      hlint = prev.hlint_3_8;
      ormolu = prev.ormolu_0_7_3_0;
    };

    unsupported = [ "apply-refact" ];

    poorToolCache = [
      "fourmolu"
      "hlint"
      "hls"
      "ormolu"
    ];
  };

  ghc982 = mkSet {
    hash = "25865a40d14b3f9cf19f19b924e2ab4069b09588";
    versName = "ghc982";
    overrides = _: prev: {
      apply-refact = prev.apply-refact_0_14_0_0;
      fourmolu = prev.fourmolu_0_15_0_0;
      hlint = prev.hlint_3_8;
      ormolu = prev.ormolu_0_7_4_0;
    };
  };

  ghc983 = mkSet {
    hash = "9e4d5190a9482a1fb9d18adf0bdb83c6e506eaab";
    versName = "ghc983";
    overrides = _: prev: {
      #apply-refact = prev.apply-refact_0_14_0_0;
      #fourmolu = prev.fourmolu_0_15_0_0;
      #hlint = prev.hlint_3_8;
      #ormolu = prev.ormolu_0_7_4_0;
    };

    poorToolCache = [
      "apply-refact"
      "fourmolu"
      "hlint"
      "ormolu"
    ];

    unstableHash = true;
  };

  ghc984 = mkSet {
    hash = "9e4d5190a9482a1fb9d18adf0bdb83c6e506eaab";
    versName = "ghc984";

    unsupported = [
      #"apply-refact"
      #"hlint"
    ];

    unstableHash = true;
  };

  ghc9101 = mkSet {
    hash = "5633bcff0c6162b9e4b5f1264264611e950c8ec7";
    versName = "ghc9101";

    unsupported = [
      "apply-refact"
      "hlint"
    ];
    unstableHash = true;
  };

  ghc9121 = mkSet {
    hash = "ed4a395ea001367c1f13d34b1e01aa10290f67d6";
    versName = "ghc9121";

    unsupported = [
      "apply-refact"
      "fourmolu"
      "hlint"
      "hls"
      "ormolu"
    ];
    unstableHash = true;
  };
}
