-module(bad_eocd).
-export([exception/1]).

exception([]) -> erlang:error("Failed to decompress Zip File").