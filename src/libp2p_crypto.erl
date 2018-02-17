-module(libp2p_crypto).

-include_lib("public_key/include/public_key.hrl").

-type private_key() :: #'ECPrivateKey'{}.
-type public_key() :: {#'ECPoint'{}, binary()}.
-type address() :: <<_:160>>.

-export_type([private_key/0, public_key/0, address/0]).

-export([generate_keypair/0, pubkey_to_address/1, pubkey_to_b58/1,
         address_to_b58/1, b58_to_address/1]).

generate_keypair() ->
    PrivKey = #'ECPrivateKey'{parameters=Params, publicKey=PubKeyPoint} =
        public_key:pem_entry_decode(lists:nth(2, public_key:pem_decode(list_to_binary(os:cmd("openssl ecparam -name prime256v1 -genkey -outform PEM"))))),
    PubKey = {#'ECPoint'{point=PubKeyPoint}, Params},
    {PubKey, PrivKey}.

-spec pubkey_to_address(public_key()) -> address().
pubkey_to_address(PubKey) ->
    {ECPoint, _} = PubKey,
    Bin = ECPoint#'ECPoint'.point,
    multihash:hash(Bin, {blake2b, 20}).

pubkey_to_b58(PubKey) ->
    address_to_b58(pubkey_to_address(PubKey)).

-spec address_to_b58(address()) -> string().
address_to_b58(Addr) ->
    base58:binary_to_base58(Addr).

-spec b58_to_address(string()) -> binary().
b58_to_address(B58) ->
    base58:base58_to_binary(B58).
