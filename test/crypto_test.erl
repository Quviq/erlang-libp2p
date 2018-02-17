-module(crypto_test).

-include_lib("eunit/include/eunit.hrl").

key_test() ->
    {Pub, Priv} = libp2p_crypto:generate_keypair(),

    ?assertNotEqual(Pub, Priv),

    PubAddress = libp2p_crypto:pubkey_to_address(Pub),
    B58Address = libp2p_crypto:address_to_b58(PubAddress),

    ?assertEqual(PubAddress, libp2p_crypto:b58_to_address(B58Address)),
    ?assertEqual(B58Address, libp2p_crypto:pubkey_to_b58(Pub)),

    ok.
