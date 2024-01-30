use aiken/bytearray
use aiken/dict.{has_key}
use aiken/interval.{Interval}
use aiken/list
use aiken/transaction.{
  InlineDatum, Input, Mint, Output, ScriptContext, Transaction,
}
use aiken/transaction/value.{
  AssetName, PolicyId, Value, flatten, from_minted_value, to_dict, tokens,
}
use linkedlist/constants.{set_node_prefix}
use linkedlist/types.{
  Common, Empty, Key, NodePair, POSIXTime, PubKeyHash, SetNode,
}

pub fn validate_mint(
  mints: Value,
  expected_minting_policy: ByteArray,
  expected_minting_name: ByteArray,
  expected_minting_amt: Int,
) -> Bool {
  let mints_policy = dict.to_list(value.tokens(mints, expected_minting_policy))
  mints_policy == [(expected_minting_name, expected_minting_amt)]
}

pub fn cover_key(node: SetNode, insert_key: PubKeyHash) -> Bool {
  let less_than_key =
    when node.key is {
      Empty -> True
      Key(key) -> bytearray.compare(key, insert_key) == Less
    }
  let more_than_key =
    when node.next is {
      Empty -> True
      Key(key) -> bytearray.compare(key, insert_key) == Greater
    }
  less_than_key? && more_than_key?
}

pub fn as_predecessor_of(node: SetNode, next_key: PubKeyHash) -> SetNode {
  SetNode { key: node.key, next: Key(next_key) }
}

pub fn as_successor_of(prev_key: PubKeyHash, node: SetNode) -> SetNode {
  SetNode { key: Key(prev_key), next: node.next }
}

pub fn div_ceil(a, b: Int) -> Int {
  let div = a / b
  let rem = a % b
  when rem is {
    0 -> div
    _ -> div + 1
  }
}

pub fn make_common(
  ctx: ScriptContext,
) -> (Common, List<Input>, List<Output>, List<PubKeyHash>, Interval<POSIXTime>) {
  expect ScriptContext {
    transaction: Transaction {
      inputs,
      outputs,
      mint,
      validity_range,
      extra_signatories,
      ..
    },
    purpose: Mint(own_cs),
  } = ctx
  let in_outputs = get_outputs(inputs)
  let from_node_val = only_at_node_val(in_outputs, own_cs)
  let to_node_val = only_at_node_val(outputs, own_cs)
  expect Some(head) = list.head(list.concat(from_node_val, to_node_val))
  let Output { address: node_address, .. } = head
  expect
    from_node_val
      |> list.concat(to_node_val)
      |> list.reduce(
           True,
           fn(acc, cur_node) {
             let Output { address: cur_address, .. } = cur_node
             and {
               cur_address == node_address,
               acc,
             }
           },
         )
  let node_inputs = list.map(from_node_val, node_input_utxo_datum_unsafe)
  let node_outputs =
    list.map(to_node_val, fn(node) { parse_node_output_utxo(own_cs, node) })
  let common =
    Common { own_cs, mint: from_minted_value(mint), node_inputs, node_outputs }
  (common, inputs, outputs, extra_signatories, validity_range)
}

// Checks if a Currency Symbol is held within a Value
pub fn has_data_cs(cs: PolicyId, value: Value) -> Bool {
  value
    |> to_dict()
    |> has_key(cs)
}

pub fn get_outputs(inputs: List<Input>) -> List<Output> {
  list.map(
    inputs,
    fn(input) {
      let Input { output, .. } = input
      output
    },
  )
}

pub fn only_at_node_val(outputs: List<Output>, cs: PolicyId) -> List<Output> {
  outputs
    |> list.filter(
         fn(output) {
           let Output { value, .. } = output
           has_data_cs(cs, value)
         },
       )
}

pub fn node_input_utxo_datum_unsafe(output: Output) -> NodePair {
  expect Output { value, datum: InlineDatum(raw_node), .. } = output
  expect node: SetNode = raw_node
  NodePair { val: value, node }
}

pub fn parse_node_output_utxo(cs: PolicyId, output: Output) -> NodePair {
  expect Output { value, datum: InlineDatum(raw_node), .. } = output
  expect node: SetNode = raw_node
  expect [(tn, amount)] =
    value
      |> tokens(cs)
      |> dict.to_list()
  expect amount == 1
  let node_key = parse_node_key(tn)
  let datum_key =
    when node.key is {
      Empty -> None
      Key(key) -> Some(key)
    }
  expect node_key == datum_key
  expect list.length(flatten(value)) == 2
  expect valid_node(node)
  expect find_cs_by_token_prefix(value, set_node_prefix) == [cs]
  NodePair { val: value, node }
}

pub fn parse_node_key(tn: AssetName) -> Option<ByteArray> {
  let prefix_length = bytearray.length(set_node_prefix)
  let tn_length = bytearray.length(tn)
  let key = bytearray.drop(tn, prefix_length)
  expect set_node_prefix == bytearray.take(tn, prefix_length)
  when prefix_length < tn_length is {
    True -> Some(key)
    False -> None
  }
}

pub fn valid_node(node: SetNode) -> Bool {
  when node.key is {
    Empty -> True
    Key(node_key) ->
      when node.next is {
        Empty -> True
        Key(next_key) -> bytearray.compare(node_key, next_key) == Less
      }
  }
}

pub fn find_cs_by_token_prefix(
  value: Value,
  prefix: ByteArray,
) -> List<PolicyId> {
  value
    |> flatten
    |> list.filter_map(
         fn(input: (PolicyId, ByteArray, Int)) -> Option<PolicyId> {
           let (cs, tn, _amt) = input
           if is_prefix_of(prefix, tn) {
             Some(cs)
           } else {
             None
           }
         },
       )
}

pub fn is_prefix_of(prefix: ByteArray, src: ByteArray) -> Bool {
  let prefix_length = bytearray.length(prefix)
  let src_length = bytearray.length(src)
  when prefix_length <= src_length is {
    True -> bytearray.take(src, prefix_length) == prefix
    False -> False
  }
}
