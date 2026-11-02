{ names, expected }:
let
	valid = actual: actual != []
		&& builtins.length actual == builtins.length (builtins.attrNames (builtins.listToAttrs (map (name: { inherit name; value = true; }) actual)))
		&& builtins.sort builtins.lessThan actual == builtins.sort builtins.lessThan expected;
	missing = map (omitted: builtins.filter (name: name != omitted) names) names;
in
valid names
&& builtins.all (candidate: !(valid candidate)) (missing ++ [ [] (names ++ [ (builtins.head names) ]) (names ++ [ "unlisted-runtime-case" ]) ])
