%% -*- coding: utf-8 -*-
%% Automatically generated, do not edit
%% Generated by gpb_compile version 4.1.3
-module(libp2p_identify_pb).

-export([encode_msg/1, encode_msg/2]).
-export([decode_msg/2, decode_msg/3]).
-export([merge_msgs/2, merge_msgs/3]).
-export([verify_msg/1, verify_msg/2]).
-export([get_msg_defs/0]).
-export([get_msg_names/0]).
-export([get_group_names/0]).
-export([get_msg_or_group_names/0]).
-export([get_enum_names/0]).
-export([find_msg_def/1, fetch_msg_def/1]).
-export([find_enum_def/1, fetch_enum_def/1]).
-export([enum_symbol_by_value/2, enum_value_by_symbol/2]).
-export([get_service_names/0]).
-export([get_service_def/1]).
-export([get_rpc_names/1]).
-export([find_rpc_def/2, fetch_rpc_def/2]).
-export([get_package_name/0]).
-export([gpb_version_as_string/0, gpb_version_as_list/0]).

-include("libp2p_identify_pb.hrl").
-include("gpb.hrl").

%% enumerated types

-export_type([]).

%% message types
-type libp2p_identify_pb() :: #libp2p_identify_pb{}.
-export_type(['libp2p_identify_pb'/0]).

-spec encode_msg(#libp2p_identify_pb{}) -> binary().
encode_msg(Msg) -> encode_msg(Msg, []).


-spec encode_msg(#libp2p_identify_pb{}, list()) -> binary().
encode_msg(Msg, Opts) ->
    case proplists:get_bool(verify, Opts) of
      true -> verify_msg(Msg, Opts);
      false -> ok
    end,
    TrUserData = proplists:get_value(user_data, Opts),
    case Msg of
      #libp2p_identify_pb{} ->
	  e_msg_libp2p_identify_pb(Msg, TrUserData)
    end.



e_msg_libp2p_identify_pb(Msg, TrUserData) ->
    e_msg_libp2p_identify_pb(Msg, <<>>, TrUserData).


e_msg_libp2p_identify_pb(#libp2p_identify_pb{protocol_version
						 = F1,
					     publicKey = F2, listen_addrs = F3,
					     observed_addr = F4, protocols = F5,
					     agent_version = F6},
			 Bin, TrUserData) ->
    B1 = if F1 == undefined -> Bin;
	    true ->
		begin
		  TrF1 = id(F1, TrUserData),
		  case is_empty_string(TrF1) of
		    true -> Bin;
		    false -> e_type_string(TrF1, <<Bin/binary, 10>>)
		  end
		end
	 end,
    B2 = if F2 == undefined -> B1;
	    true ->
		begin
		  TrF2 = id(F2, TrUserData),
		  case iolist_size(TrF2) of
		    0 -> B1;
		    _ -> e_type_bytes(TrF2, <<B1/binary, 18>>)
		  end
		end
	 end,
    B3 = begin
	   TrF3 = id(F3, TrUserData),
	   if TrF3 == [] -> B2;
	      true ->
		  e_field_libp2p_identify_pb_listen_addrs(TrF3, B2,
							  TrUserData)
	   end
	 end,
    B4 = if F4 == undefined -> B3;
	    true ->
		begin
		  TrF4 = id(F4, TrUserData),
		  case iolist_size(TrF4) of
		    0 -> B3;
		    _ -> e_type_bytes(TrF4, <<B3/binary, 34>>)
		  end
		end
	 end,
    B5 = begin
	   TrF5 = id(F5, TrUserData),
	   if TrF5 == [] -> B4;
	      true ->
		  e_field_libp2p_identify_pb_protocols(TrF5, B4,
						       TrUserData)
	   end
	 end,
    if F6 == undefined -> B5;
       true ->
	   begin
	     TrF6 = id(F6, TrUserData),
	     case is_empty_string(TrF6) of
	       true -> B5;
	       false -> e_type_string(TrF6, <<B5/binary, 50>>)
	     end
	   end
    end.

e_field_libp2p_identify_pb_listen_addrs([Elem | Rest],
					Bin, TrUserData) ->
    Bin2 = <<Bin/binary, 26>>,
    Bin3 = e_type_bytes(id(Elem, TrUserData), Bin2),
    e_field_libp2p_identify_pb_listen_addrs(Rest, Bin3,
					    TrUserData);
e_field_libp2p_identify_pb_listen_addrs([], Bin,
					_TrUserData) ->
    Bin.

e_field_libp2p_identify_pb_protocols([Elem | Rest], Bin,
				     TrUserData) ->
    Bin2 = <<Bin/binary, 42>>,
    Bin3 = e_type_string(id(Elem, TrUserData), Bin2),
    e_field_libp2p_identify_pb_protocols(Rest, Bin3,
					 TrUserData);
e_field_libp2p_identify_pb_protocols([], Bin,
				     _TrUserData) ->
    Bin.

e_type_string(S, Bin) ->
    Utf8 = unicode:characters_to_binary(S),
    Bin2 = e_varint(byte_size(Utf8), Bin),
    <<Bin2/binary, Utf8/binary>>.

e_type_bytes(Bytes, Bin) when is_binary(Bytes) ->
    Bin2 = e_varint(byte_size(Bytes), Bin),
    <<Bin2/binary, Bytes/binary>>;
e_type_bytes(Bytes, Bin) when is_list(Bytes) ->
    BytesBin = iolist_to_binary(Bytes),
    Bin2 = e_varint(byte_size(BytesBin), Bin),
    <<Bin2/binary, BytesBin/binary>>.

e_varint(N, Bin) when N =< 127 -> <<Bin/binary, N>>;
e_varint(N, Bin) ->
    Bin2 = <<Bin/binary, (N band 127 bor 128)>>,
    e_varint(N bsr 7, Bin2).

is_empty_string("") -> true;
is_empty_string(<<>>) -> true;
is_empty_string(L) when is_list(L) ->
    not string_has_chars(L);
is_empty_string(B) when is_binary(B) -> false.

string_has_chars([C | _]) when is_integer(C) -> true;
string_has_chars([H | T]) ->
    case string_has_chars(H) of
      true -> true;
      false -> string_has_chars(T)
    end;
string_has_chars(B)
    when is_binary(B), byte_size(B) =/= 0 ->
    true;
string_has_chars(C) when is_integer(C) -> true;
string_has_chars(<<>>) -> false;
string_has_chars([]) -> false.


decode_msg(Bin, MsgName) when is_binary(Bin) ->
    decode_msg(Bin, MsgName, []).

decode_msg(Bin, MsgName, Opts) when is_binary(Bin) ->
    TrUserData = proplists:get_value(user_data, Opts),
    case MsgName of
      libp2p_identify_pb ->
	  try d_msg_libp2p_identify_pb(Bin, TrUserData) catch
	    Class:Reason ->
		StackTrace = erlang:get_stacktrace(),
		error({gpb_error,
		       {decoding_failure,
			{Bin, libp2p_identify_pb,
			 {Class, Reason, StackTrace}}}})
	  end
    end.



d_msg_libp2p_identify_pb(Bin, TrUserData) ->
    dfp_read_field_def_libp2p_identify_pb(Bin, 0, 0,
					  id([], TrUserData),
					  id(<<>>, TrUserData),
					  id([], TrUserData),
					  id(<<>>, TrUserData),
					  id([], TrUserData),
					  id([], TrUserData), TrUserData).

dfp_read_field_def_libp2p_identify_pb(<<10,
					Rest/binary>>,
				      Z1, Z2, F@_1, F@_2, F@_3, F@_4, F@_5,
				      F@_6, TrUserData) ->
    d_field_libp2p_identify_pb_protocol_version(Rest, Z1,
						Z2, F@_1, F@_2, F@_3, F@_4,
						F@_5, F@_6, TrUserData);
dfp_read_field_def_libp2p_identify_pb(<<18,
					Rest/binary>>,
				      Z1, Z2, F@_1, F@_2, F@_3, F@_4, F@_5,
				      F@_6, TrUserData) ->
    d_field_libp2p_identify_pb_publicKey(Rest, Z1, Z2, F@_1,
					 F@_2, F@_3, F@_4, F@_5, F@_6,
					 TrUserData);
dfp_read_field_def_libp2p_identify_pb(<<26,
					Rest/binary>>,
				      Z1, Z2, F@_1, F@_2, F@_3, F@_4, F@_5,
				      F@_6, TrUserData) ->
    d_field_libp2p_identify_pb_listen_addrs(Rest, Z1, Z2,
					    F@_1, F@_2, F@_3, F@_4, F@_5, F@_6,
					    TrUserData);
dfp_read_field_def_libp2p_identify_pb(<<34,
					Rest/binary>>,
				      Z1, Z2, F@_1, F@_2, F@_3, F@_4, F@_5,
				      F@_6, TrUserData) ->
    d_field_libp2p_identify_pb_observed_addr(Rest, Z1, Z2,
					     F@_1, F@_2, F@_3, F@_4, F@_5, F@_6,
					     TrUserData);
dfp_read_field_def_libp2p_identify_pb(<<42,
					Rest/binary>>,
				      Z1, Z2, F@_1, F@_2, F@_3, F@_4, F@_5,
				      F@_6, TrUserData) ->
    d_field_libp2p_identify_pb_protocols(Rest, Z1, Z2, F@_1,
					 F@_2, F@_3, F@_4, F@_5, F@_6,
					 TrUserData);
dfp_read_field_def_libp2p_identify_pb(<<50,
					Rest/binary>>,
				      Z1, Z2, F@_1, F@_2, F@_3, F@_4, F@_5,
				      F@_6, TrUserData) ->
    d_field_libp2p_identify_pb_agent_version(Rest, Z1, Z2,
					     F@_1, F@_2, F@_3, F@_4, F@_5, F@_6,
					     TrUserData);
dfp_read_field_def_libp2p_identify_pb(<<>>, 0, 0, F@_1,
				      F@_2, R1, F@_4, R2, F@_6, TrUserData) ->
    #libp2p_identify_pb{protocol_version = F@_1,
			publicKey = F@_2,
			listen_addrs = lists_reverse(R1, TrUserData),
			observed_addr = F@_4,
			protocols = lists_reverse(R2, TrUserData),
			agent_version = F@_6};
dfp_read_field_def_libp2p_identify_pb(Other, Z1, Z2,
				      F@_1, F@_2, F@_3, F@_4, F@_5, F@_6,
				      TrUserData) ->
    dg_read_field_def_libp2p_identify_pb(Other, Z1, Z2,
					 F@_1, F@_2, F@_3, F@_4, F@_5, F@_6,
					 TrUserData).

dg_read_field_def_libp2p_identify_pb(<<1:1, X:7,
				       Rest/binary>>,
				     N, Acc, F@_1, F@_2, F@_3, F@_4, F@_5, F@_6,
				     TrUserData)
    when N < 32 - 7 ->
    dg_read_field_def_libp2p_identify_pb(Rest, N + 7,
					 X bsl N + Acc, F@_1, F@_2, F@_3, F@_4,
					 F@_5, F@_6, TrUserData);
dg_read_field_def_libp2p_identify_pb(<<0:1, X:7,
				       Rest/binary>>,
				     N, Acc, F@_1, F@_2, F@_3, F@_4, F@_5, F@_6,
				     TrUserData) ->
    Key = X bsl N + Acc,
    case Key of
      10 ->
	  d_field_libp2p_identify_pb_protocol_version(Rest, 0, 0,
						      F@_1, F@_2, F@_3, F@_4,
						      F@_5, F@_6, TrUserData);
      18 ->
	  d_field_libp2p_identify_pb_publicKey(Rest, 0, 0, F@_1,
					       F@_2, F@_3, F@_4, F@_5, F@_6,
					       TrUserData);
      26 ->
	  d_field_libp2p_identify_pb_listen_addrs(Rest, 0, 0,
						  F@_1, F@_2, F@_3, F@_4, F@_5,
						  F@_6, TrUserData);
      34 ->
	  d_field_libp2p_identify_pb_observed_addr(Rest, 0, 0,
						   F@_1, F@_2, F@_3, F@_4, F@_5,
						   F@_6, TrUserData);
      42 ->
	  d_field_libp2p_identify_pb_protocols(Rest, 0, 0, F@_1,
					       F@_2, F@_3, F@_4, F@_5, F@_6,
					       TrUserData);
      50 ->
	  d_field_libp2p_identify_pb_agent_version(Rest, 0, 0,
						   F@_1, F@_2, F@_3, F@_4, F@_5,
						   F@_6, TrUserData);
      _ ->
	  case Key band 7 of
	    0 ->
		skip_varint_libp2p_identify_pb(Rest, 0, 0, F@_1, F@_2,
					       F@_3, F@_4, F@_5, F@_6,
					       TrUserData);
	    1 ->
		skip_64_libp2p_identify_pb(Rest, 0, 0, F@_1, F@_2, F@_3,
					   F@_4, F@_5, F@_6, TrUserData);
	    2 ->
		skip_length_delimited_libp2p_identify_pb(Rest, 0, 0,
							 F@_1, F@_2, F@_3, F@_4,
							 F@_5, F@_6,
							 TrUserData);
	    3 ->
		skip_group_libp2p_identify_pb(Rest, Key bsr 3, 0, F@_1,
					      F@_2, F@_3, F@_4, F@_5, F@_6,
					      TrUserData);
	    5 ->
		skip_32_libp2p_identify_pb(Rest, 0, 0, F@_1, F@_2, F@_3,
					   F@_4, F@_5, F@_6, TrUserData)
	  end
    end;
dg_read_field_def_libp2p_identify_pb(<<>>, 0, 0, F@_1,
				     F@_2, R1, F@_4, R2, F@_6, TrUserData) ->
    #libp2p_identify_pb{protocol_version = F@_1,
			publicKey = F@_2,
			listen_addrs = lists_reverse(R1, TrUserData),
			observed_addr = F@_4,
			protocols = lists_reverse(R2, TrUserData),
			agent_version = F@_6}.

d_field_libp2p_identify_pb_protocol_version(<<1:1, X:7,
					      Rest/binary>>,
					    N, Acc, F@_1, F@_2, F@_3, F@_4,
					    F@_5, F@_6, TrUserData)
    when N < 57 ->
    d_field_libp2p_identify_pb_protocol_version(Rest, N + 7,
						X bsl N + Acc, F@_1, F@_2, F@_3,
						F@_4, F@_5, F@_6, TrUserData);
d_field_libp2p_identify_pb_protocol_version(<<0:1, X:7,
					      Rest/binary>>,
					    N, Acc, _, F@_2, F@_3, F@_4, F@_5,
					    F@_6, TrUserData) ->
    {NewFValue, RestF} = begin
			   Len = X bsl N + Acc,
			   <<Utf8:Len/binary, Rest2/binary>> = Rest,
			   {unicode:characters_to_list(Utf8, unicode), Rest2}
			 end,
    dfp_read_field_def_libp2p_identify_pb(RestF, 0, 0,
					  NewFValue, F@_2, F@_3, F@_4, F@_5,
					  F@_6, TrUserData).

d_field_libp2p_identify_pb_publicKey(<<1:1, X:7,
				       Rest/binary>>,
				     N, Acc, F@_1, F@_2, F@_3, F@_4, F@_5, F@_6,
				     TrUserData)
    when N < 57 ->
    d_field_libp2p_identify_pb_publicKey(Rest, N + 7,
					 X bsl N + Acc, F@_1, F@_2, F@_3, F@_4,
					 F@_5, F@_6, TrUserData);
d_field_libp2p_identify_pb_publicKey(<<0:1, X:7,
				       Rest/binary>>,
				     N, Acc, F@_1, _, F@_3, F@_4, F@_5, F@_6,
				     TrUserData) ->
    {NewFValue, RestF} = begin
			   Len = X bsl N + Acc,
			   <<Bytes:Len/binary, Rest2/binary>> = Rest,
			   {binary:copy(Bytes), Rest2}
			 end,
    dfp_read_field_def_libp2p_identify_pb(RestF, 0, 0, F@_1,
					  NewFValue, F@_3, F@_4, F@_5, F@_6,
					  TrUserData).

d_field_libp2p_identify_pb_listen_addrs(<<1:1, X:7,
					  Rest/binary>>,
					N, Acc, F@_1, F@_2, F@_3, F@_4, F@_5,
					F@_6, TrUserData)
    when N < 57 ->
    d_field_libp2p_identify_pb_listen_addrs(Rest, N + 7,
					    X bsl N + Acc, F@_1, F@_2, F@_3,
					    F@_4, F@_5, F@_6, TrUserData);
d_field_libp2p_identify_pb_listen_addrs(<<0:1, X:7,
					  Rest/binary>>,
					N, Acc, F@_1, F@_2, Prev, F@_4, F@_5,
					F@_6, TrUserData) ->
    {NewFValue, RestF} = begin
			   Len = X bsl N + Acc,
			   <<Bytes:Len/binary, Rest2/binary>> = Rest,
			   {binary:copy(Bytes), Rest2}
			 end,
    dfp_read_field_def_libp2p_identify_pb(RestF, 0, 0, F@_1,
					  F@_2,
					  cons(NewFValue, Prev, TrUserData),
					  F@_4, F@_5, F@_6, TrUserData).

d_field_libp2p_identify_pb_observed_addr(<<1:1, X:7,
					   Rest/binary>>,
					 N, Acc, F@_1, F@_2, F@_3, F@_4, F@_5,
					 F@_6, TrUserData)
    when N < 57 ->
    d_field_libp2p_identify_pb_observed_addr(Rest, N + 7,
					     X bsl N + Acc, F@_1, F@_2, F@_3,
					     F@_4, F@_5, F@_6, TrUserData);
d_field_libp2p_identify_pb_observed_addr(<<0:1, X:7,
					   Rest/binary>>,
					 N, Acc, F@_1, F@_2, F@_3, _, F@_5,
					 F@_6, TrUserData) ->
    {NewFValue, RestF} = begin
			   Len = X bsl N + Acc,
			   <<Bytes:Len/binary, Rest2/binary>> = Rest,
			   {binary:copy(Bytes), Rest2}
			 end,
    dfp_read_field_def_libp2p_identify_pb(RestF, 0, 0, F@_1,
					  F@_2, F@_3, NewFValue, F@_5, F@_6,
					  TrUserData).

d_field_libp2p_identify_pb_protocols(<<1:1, X:7,
				       Rest/binary>>,
				     N, Acc, F@_1, F@_2, F@_3, F@_4, F@_5, F@_6,
				     TrUserData)
    when N < 57 ->
    d_field_libp2p_identify_pb_protocols(Rest, N + 7,
					 X bsl N + Acc, F@_1, F@_2, F@_3, F@_4,
					 F@_5, F@_6, TrUserData);
d_field_libp2p_identify_pb_protocols(<<0:1, X:7,
				       Rest/binary>>,
				     N, Acc, F@_1, F@_2, F@_3, F@_4, Prev, F@_6,
				     TrUserData) ->
    {NewFValue, RestF} = begin
			   Len = X bsl N + Acc,
			   <<Utf8:Len/binary, Rest2/binary>> = Rest,
			   {unicode:characters_to_list(Utf8, unicode), Rest2}
			 end,
    dfp_read_field_def_libp2p_identify_pb(RestF, 0, 0, F@_1,
					  F@_2, F@_3, F@_4,
					  cons(NewFValue, Prev, TrUserData),
					  F@_6, TrUserData).

d_field_libp2p_identify_pb_agent_version(<<1:1, X:7,
					   Rest/binary>>,
					 N, Acc, F@_1, F@_2, F@_3, F@_4, F@_5,
					 F@_6, TrUserData)
    when N < 57 ->
    d_field_libp2p_identify_pb_agent_version(Rest, N + 7,
					     X bsl N + Acc, F@_1, F@_2, F@_3,
					     F@_4, F@_5, F@_6, TrUserData);
d_field_libp2p_identify_pb_agent_version(<<0:1, X:7,
					   Rest/binary>>,
					 N, Acc, F@_1, F@_2, F@_3, F@_4, F@_5,
					 _, TrUserData) ->
    {NewFValue, RestF} = begin
			   Len = X bsl N + Acc,
			   <<Utf8:Len/binary, Rest2/binary>> = Rest,
			   {unicode:characters_to_list(Utf8, unicode), Rest2}
			 end,
    dfp_read_field_def_libp2p_identify_pb(RestF, 0, 0, F@_1,
					  F@_2, F@_3, F@_4, F@_5, NewFValue,
					  TrUserData).

skip_varint_libp2p_identify_pb(<<1:1, _:7,
				 Rest/binary>>,
			       Z1, Z2, F@_1, F@_2, F@_3, F@_4, F@_5, F@_6,
			       TrUserData) ->
    skip_varint_libp2p_identify_pb(Rest, Z1, Z2, F@_1, F@_2,
				   F@_3, F@_4, F@_5, F@_6, TrUserData);
skip_varint_libp2p_identify_pb(<<0:1, _:7,
				 Rest/binary>>,
			       Z1, Z2, F@_1, F@_2, F@_3, F@_4, F@_5, F@_6,
			       TrUserData) ->
    dfp_read_field_def_libp2p_identify_pb(Rest, Z1, Z2,
					  F@_1, F@_2, F@_3, F@_4, F@_5, F@_6,
					  TrUserData).

skip_length_delimited_libp2p_identify_pb(<<1:1, X:7,
					   Rest/binary>>,
					 N, Acc, F@_1, F@_2, F@_3, F@_4, F@_5,
					 F@_6, TrUserData)
    when N < 57 ->
    skip_length_delimited_libp2p_identify_pb(Rest, N + 7,
					     X bsl N + Acc, F@_1, F@_2, F@_3,
					     F@_4, F@_5, F@_6, TrUserData);
skip_length_delimited_libp2p_identify_pb(<<0:1, X:7,
					   Rest/binary>>,
					 N, Acc, F@_1, F@_2, F@_3, F@_4, F@_5,
					 F@_6, TrUserData) ->
    Length = X bsl N + Acc,
    <<_:Length/binary, Rest2/binary>> = Rest,
    dfp_read_field_def_libp2p_identify_pb(Rest2, 0, 0, F@_1,
					  F@_2, F@_3, F@_4, F@_5, F@_6,
					  TrUserData).

skip_group_libp2p_identify_pb(Bin, FNum, Z2, F@_1, F@_2,
			      F@_3, F@_4, F@_5, F@_6, TrUserData) ->
    {_, Rest} = read_group(Bin, FNum),
    dfp_read_field_def_libp2p_identify_pb(Rest, 0, Z2, F@_1,
					  F@_2, F@_3, F@_4, F@_5, F@_6,
					  TrUserData).

skip_32_libp2p_identify_pb(<<_:32, Rest/binary>>, Z1,
			   Z2, F@_1, F@_2, F@_3, F@_4, F@_5, F@_6,
			   TrUserData) ->
    dfp_read_field_def_libp2p_identify_pb(Rest, Z1, Z2,
					  F@_1, F@_2, F@_3, F@_4, F@_5, F@_6,
					  TrUserData).

skip_64_libp2p_identify_pb(<<_:64, Rest/binary>>, Z1,
			   Z2, F@_1, F@_2, F@_3, F@_4, F@_5, F@_6,
			   TrUserData) ->
    dfp_read_field_def_libp2p_identify_pb(Rest, Z1, Z2,
					  F@_1, F@_2, F@_3, F@_4, F@_5, F@_6,
					  TrUserData).

read_group(Bin, FieldNum) ->
    {NumBytes, EndTagLen} = read_gr_b(Bin, 0, 0, 0, 0, FieldNum),
    <<Group:NumBytes/binary, _:EndTagLen/binary, Rest/binary>> = Bin,
    {Group, Rest}.

%% Like skipping over fields, but record the total length,
%% Each field is <(FieldNum bsl 3) bor FieldType> ++ <FieldValue>
%% Record the length because varints may be non-optimally encoded.
%%
%% Groups can be nested, but assume the same FieldNum cannot be nested
%% because group field numbers are shared with the rest of the fields
%% numbers. Thus we can search just for an group-end with the same
%% field number.
%%
%% (The only time the same group field number could occur would
%% be in a nested sub message, but then it would be inside a
%% length-delimited entry, which we skip-read by length.)
read_gr_b(<<1:1, X:7, Tl/binary>>, N, Acc, NumBytes, TagLen, FieldNum)
  when N < (32-7) ->
    read_gr_b(Tl, N+7, X bsl N + Acc, NumBytes, TagLen+1, FieldNum);
read_gr_b(<<0:1, X:7, Tl/binary>>, N, Acc, NumBytes, TagLen,
          FieldNum) ->
    Key = X bsl N + Acc,
    TagLen1 = TagLen + 1,
    case {Key bsr 3, Key band 7} of
        {FieldNum, 4} -> % 4 = group_end
            {NumBytes, TagLen1};
        {_, 0} -> % 0 = varint
            read_gr_vi(Tl, 0, NumBytes + TagLen1, FieldNum);
        {_, 1} -> % 1 = bits64
            <<_:64, Tl2/binary>> = Tl,
            read_gr_b(Tl2, 0, 0, NumBytes + TagLen1 + 8, 0, FieldNum);
        {_, 2} -> % 2 = length_delimited
            read_gr_ld(Tl, 0, 0, NumBytes + TagLen1, FieldNum);
        {_, 3} -> % 3 = group_start
            read_gr_b(Tl, 0, 0, NumBytes + TagLen1, 0, FieldNum);
        {_, 4} -> % 4 = group_end
            read_gr_b(Tl, 0, 0, NumBytes + TagLen1, 0, FieldNum);
        {_, 5} -> % 5 = bits32
            <<_:32, Tl2/binary>> = Tl,
            read_gr_b(Tl2, 0, 0, NumBytes + TagLen1 + 4, 0, FieldNum)
    end.

read_gr_vi(<<1:1, _:7, Tl/binary>>, N, NumBytes, FieldNum)
  when N < (64-7) ->
    read_gr_vi(Tl, N+7, NumBytes+1, FieldNum);
read_gr_vi(<<0:1, _:7, Tl/binary>>, _, NumBytes, FieldNum) ->
    read_gr_b(Tl, 0, 0, NumBytes+1, 0, FieldNum).

read_gr_ld(<<1:1, X:7, Tl/binary>>, N, Acc, NumBytes, FieldNum)
  when N < (64-7) ->
    read_gr_ld(Tl, N+7, X bsl N + Acc, NumBytes+1, FieldNum);
read_gr_ld(<<0:1, X:7, Tl/binary>>, N, Acc, NumBytes, FieldNum) ->
    Len = X bsl N + Acc,
    NumBytes1 = NumBytes + 1,
    <<_:Len/binary, Tl2/binary>> = Tl,
    read_gr_b(Tl2, 0, 0, NumBytes1 + Len, 0, FieldNum).

merge_msgs(Prev, New) -> merge_msgs(Prev, New, []).

merge_msgs(Prev, New, Opts)
    when element(1, Prev) =:= element(1, New) ->
    TrUserData = proplists:get_value(user_data, Opts),
    case Prev of
      #libp2p_identify_pb{} ->
	  merge_msg_libp2p_identify_pb(Prev, New, TrUserData)
    end.

merge_msg_libp2p_identify_pb(#libp2p_identify_pb{protocol_version
						     = PFprotocol_version,
						 publicKey = PFpublicKey,
						 listen_addrs = PFlisten_addrs,
						 observed_addr =
						     PFobserved_addr,
						 protocols = PFprotocols,
						 agent_version =
						     PFagent_version},
			     #libp2p_identify_pb{protocol_version =
						     NFprotocol_version,
						 publicKey = NFpublicKey,
						 listen_addrs = NFlisten_addrs,
						 observed_addr =
						     NFobserved_addr,
						 protocols = NFprotocols,
						 agent_version =
						     NFagent_version},
			     TrUserData) ->
    #libp2p_identify_pb{protocol_version =
			    if NFprotocol_version =:= undefined ->
				   PFprotocol_version;
			       true -> NFprotocol_version
			    end,
			publicKey =
			    if NFpublicKey =:= undefined -> PFpublicKey;
			       true -> NFpublicKey
			    end,
			listen_addrs =
			    if PFlisten_addrs /= undefined,
			       NFlisten_addrs /= undefined ->
				   'erlang_++'(PFlisten_addrs, NFlisten_addrs,
					       TrUserData);
			       PFlisten_addrs == undefined -> NFlisten_addrs;
			       NFlisten_addrs == undefined -> PFlisten_addrs
			    end,
			observed_addr =
			    if NFobserved_addr =:= undefined -> PFobserved_addr;
			       true -> NFobserved_addr
			    end,
			protocols =
			    if PFprotocols /= undefined,
			       NFprotocols /= undefined ->
				   'erlang_++'(PFprotocols, NFprotocols,
					       TrUserData);
			       PFprotocols == undefined -> NFprotocols;
			       NFprotocols == undefined -> PFprotocols
			    end,
			agent_version =
			    if NFagent_version =:= undefined -> PFagent_version;
			       true -> NFagent_version
			    end}.


verify_msg(Msg) -> verify_msg(Msg, []).

verify_msg(Msg, Opts) ->
    TrUserData = proplists:get_value(user_data, Opts),
    case Msg of
      #libp2p_identify_pb{} ->
	  v_msg_libp2p_identify_pb(Msg, [libp2p_identify_pb],
				   TrUserData);
      _ -> mk_type_error(not_a_known_message, Msg, [])
    end.


-dialyzer({nowarn_function,v_msg_libp2p_identify_pb/3}).
v_msg_libp2p_identify_pb(#libp2p_identify_pb{protocol_version
						 = F1,
					     publicKey = F2, listen_addrs = F3,
					     observed_addr = F4, protocols = F5,
					     agent_version = F6},
			 Path, _) ->
    if F1 == undefined -> ok;
       true -> v_type_string(F1, [protocol_version | Path])
    end,
    if F2 == undefined -> ok;
       true -> v_type_bytes(F2, [publicKey | Path])
    end,
    if is_list(F3) ->
	   _ = [v_type_bytes(Elem, [listen_addrs | Path])
		|| Elem <- F3],
	   ok;
       true ->
	   mk_type_error({invalid_list_of, bytes}, F3,
			 [listen_addrs | Path])
    end,
    if F4 == undefined -> ok;
       true -> v_type_bytes(F4, [observed_addr | Path])
    end,
    if is_list(F5) ->
	   _ = [v_type_string(Elem, [protocols | Path])
		|| Elem <- F5],
	   ok;
       true ->
	   mk_type_error({invalid_list_of, string}, F5,
			 [protocols | Path])
    end,
    if F6 == undefined -> ok;
       true -> v_type_string(F6, [agent_version | Path])
    end,
    ok.

-dialyzer({nowarn_function,v_type_string/2}).
v_type_string(S, Path) when is_list(S); is_binary(S) ->
    try unicode:characters_to_binary(S) of
      B when is_binary(B) -> ok;
      {error, _, _} ->
	  mk_type_error(bad_unicode_string, S, Path)
    catch
      error:badarg ->
	  mk_type_error(bad_unicode_string, S, Path)
    end;
v_type_string(X, Path) ->
    mk_type_error(bad_unicode_string, X, Path).

-dialyzer({nowarn_function,v_type_bytes/2}).
v_type_bytes(B, _Path) when is_binary(B) -> ok;
v_type_bytes(B, _Path) when is_list(B) -> ok;
v_type_bytes(X, Path) ->
    mk_type_error(bad_binary_value, X, Path).

-spec mk_type_error(_, _, list()) -> no_return().
mk_type_error(Error, ValueSeen, Path) ->
    Path2 = prettify_path(Path),
    erlang:error({gpb_type_error,
		  {Error, [{value, ValueSeen}, {path, Path2}]}}).


-dialyzer({nowarn_function,prettify_path/1}).
prettify_path([]) -> top_level;
prettify_path(PathR) ->
    list_to_atom(lists:append(lists:join(".",
					 lists:map(fun atom_to_list/1,
						   lists:reverse(PathR))))).


-compile({inline,id/2}).
id(X, _TrUserData) -> X.

-compile({inline,cons/3}).
cons(Elem, Acc, _TrUserData) -> [Elem | Acc].

-compile({inline,lists_reverse/2}).
'lists_reverse'(L, _TrUserData) -> lists:reverse(L).
-compile({inline,'erlang_++'/3}).
'erlang_++'(A, B, _TrUserData) -> A ++ B.

get_msg_defs() ->
    [{{msg, libp2p_identify_pb},
      [#field{name = protocol_version, fnum = 1, rnum = 2,
	      type = string, occurrence = optional, opts = []},
       #field{name = publicKey, fnum = 2, rnum = 3,
	      type = bytes, occurrence = optional, opts = []},
       #field{name = listen_addrs, fnum = 3, rnum = 4,
	      type = bytes, occurrence = repeated, opts = []},
       #field{name = observed_addr, fnum = 4, rnum = 5,
	      type = bytes, occurrence = optional, opts = []},
       #field{name = protocols, fnum = 5, rnum = 6,
	      type = string, occurrence = repeated, opts = []},
       #field{name = agent_version, fnum = 6, rnum = 7,
	      type = string, occurrence = optional, opts = []}]}].


get_msg_names() -> [libp2p_identify_pb].


get_group_names() -> [].


get_msg_or_group_names() -> [libp2p_identify_pb].


get_enum_names() -> [].


fetch_msg_def(MsgName) ->
    case find_msg_def(MsgName) of
      Fs when is_list(Fs) -> Fs;
      error -> erlang:error({no_such_msg, MsgName})
    end.


-spec fetch_enum_def(_) -> no_return().
fetch_enum_def(EnumName) ->
    erlang:error({no_such_enum, EnumName}).


find_msg_def(libp2p_identify_pb) ->
    [#field{name = protocol_version, fnum = 1, rnum = 2,
	    type = string, occurrence = optional, opts = []},
     #field{name = publicKey, fnum = 2, rnum = 3,
	    type = bytes, occurrence = optional, opts = []},
     #field{name = listen_addrs, fnum = 3, rnum = 4,
	    type = bytes, occurrence = repeated, opts = []},
     #field{name = observed_addr, fnum = 4, rnum = 5,
	    type = bytes, occurrence = optional, opts = []},
     #field{name = protocols, fnum = 5, rnum = 6,
	    type = string, occurrence = repeated, opts = []},
     #field{name = agent_version, fnum = 6, rnum = 7,
	    type = string, occurrence = optional, opts = []}];
find_msg_def(_) -> error.


find_enum_def(_) -> error.


-spec enum_symbol_by_value(_, _) -> no_return().
enum_symbol_by_value(E, V) ->
    erlang:error({no_enum_defs, E, V}).


-spec enum_value_by_symbol(_, _) -> no_return().
enum_value_by_symbol(E, V) ->
    erlang:error({no_enum_defs, E, V}).



get_service_names() -> [].


get_service_def(_) -> error.


get_rpc_names(_) -> error.


find_rpc_def(_, _) -> error.



-spec fetch_rpc_def(_, _) -> no_return().
fetch_rpc_def(ServiceName, RpcName) ->
    erlang:error({no_such_rpc, ServiceName, RpcName}).


get_package_name() -> undefined.



gpb_version_as_string() ->
    "4.1.3".

gpb_version_as_list() ->
    [4,1,3].
