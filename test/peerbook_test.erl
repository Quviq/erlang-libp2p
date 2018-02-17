-module(peerbook_test).

-include_lib("eunit/include/eunit.hrl").

basic_test() ->
    Swarms = [S1] = test_util:setup_swarms(1),

    PeerBook = libp2p_swarm:peerbook(S1),

    ?assert(libp2p_peerbook:put(PeerBook,
                                "QmcgpsyWgH8Y8ajJz1Cu72KnS5uo2Aa2LpzU7kinSupNKC",
                                ["/ip4/1.2.3.4/tcp/4000"])),
    ?assert(libp2p_peerbook:put(PeerBook,
                                "/ip4/1.2.3.4/tcp/4000/p2p/QmcgpsyWgH8Y8ajJz1Cu72KnS5uo2Aa2LpzU7kinSupNKC")),
    ?assert(libp2p_peerbook:is_key(PeerBook, "QmcgpsyWgH8Y8ajJz1Cu72KnS5uo2Aa2LpzU7kinSupNKC")),
    ?assertNot(libp2p_peerbook:is_key(PeerBook, "foo")),

    ?assertEqual(1, length(libp2p_peerbook:keys(PeerBook))),
    ?assertEqual(["/ip4/1.2.3.4/tcp/4000"],
                 libp2p_peerbook:get(PeerBook, "QmcgpsyWgH8Y8ajJz1Cu72KnS5uo2Aa2LpzU7kinSupNKC")),
    ?assertEqual([], libp2p_peerbook:get(PeerBook, "foo")),

    ?assertError(bad_arg, libp2p_peerbook:put(PeerBook, "/ip4/1.2.3.4/tcp/4000")),


    test_util:teardown_swarms(Swarms).
