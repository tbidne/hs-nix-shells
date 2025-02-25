# Provides common utilities

let
  ghcMap = import ./ghc_map.nix;
  showKeys =
    attrs:
    let
      attrKeys = builtins.attrNames attrs;
    in
    builtins.concatStringsSep ", " attrKeys;
  member = y: xs: builtins.foldl' (acc: x: if x == y then true else acc) false xs;

  lookupOrDie =
    mp: key: keyName:
    if mp ? ${key} then
      mp.${key}
    else
      throw "Invalid ${keyName}: '${key}'; valid keys are ${showKeys mp}.";

  # Returns a list of dev tools, depending on the arguments.
  mkDev =
    devTools: ghcSet:
    let
      dontCheck = ghcSet.pkgs.haskell.lib.dontCheck;
      compiler = ghcSet.compiler;
      addTool =
        acc: tool:
        let
          flagName = tool.flagName;
        in
        if devTools."${flagName}" then
          if member flagName ghcSet.unsupported then
            throw "${flagName} is unsupported for ${ghcSet.versName}."
          else
            acc ++ [ (dontCheck tool.pkg) ]
        else
          acc;
      allTools = [
        {
          flagName = "apply-refact";
          pkg = compiler.apply-refact;
        }
        {
          flagName = "fourmolu";
          pkg = compiler.fourmolu;
        }
        {
          flagName = "hls";
          pkg = compiler.haskell-language-server;
        }
        {
          flagName = "hlint";
          pkg = compiler.hlint;
        }
        {
          flagName = "ormolu";
          pkg = compiler.ormolu;
        }
      ];
    in
    builtins.foldl' addTool [ ] allTools;
in
{
  inherit mkDev;

  getGhcSet = ghc-vers: lookupOrDie ghcMap ghc-vers "ghc-vers";

  emptyDevTools = {
    apply-refact = false;
    fourmolu = false;
    hlint = false;
    hls = false;
    ormolu = false;
  };
}
