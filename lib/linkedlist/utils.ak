use aiken/bytearray
use aiken/dict
use aiken/transaction/value.{Value}
use linkedlist/types.{Empty, Key, PubKeyHash, SetNode}

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
