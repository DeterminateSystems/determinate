# This method of generating Nix configuration borrows heavily from the nix-darwin project:
# https://github.com/nix-darwin/nix-darwin/blob/e04a388232d9a6ba56967ce5b53a8a6f713cdfcf/modules/nix/default.nix
# We have included the LICENSE file for the nix-darwin project in this directory from the e04a388232d9a6ba56967ce5b53a8a6f713cdfcf revision of the project:
# https://github.com/nix-darwin/nix-darwin/tree/e04a388232d9a6ba56967ce5b53a8a6f713cdfcf

{ lib }:

let
  inherit (lib) types;

  mkValueString =
    v:
    if v == null then
      ""
    else if builtins.isBool v then
      lib.boolToString v
    else if builtins.isInt v then
      builtins.toString v
    else if builtins.isFloat v then
      lib.strings.floatToString v
    else if builtins.isList v then
      builtins.toJSON v
    else if lib.isDerivation v then
      builtins.toString v
    else if builtins.isPath v then
      builtins.toString v
    else if builtins.isAttrs v then
      builtins.toJSON v
    else if builtins.isString v then
      v
    else if lib.strings.isCoercibleToString v then
      builtins.toString v
    else
      abort "The Nix configuration value ${lib.generators.toPretty { } v} can't be encoded";

  mkKeyValue = k: v: "${lib.escape [ "=" ] k} = ${mkValueString v}";
in
{
  mkConfig = attrs: lib.mapAttrsToList mkKeyValue attrs;
}
