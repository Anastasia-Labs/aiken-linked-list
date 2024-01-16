use aiken/bytearray
use aiken/interval
use aiken/list
use aiken/transaction.{Output}
use aiken/transaction/value.{lovelace_of}
use linkedlist/constants
use linkedlist/types.{Common, Config, POSIXTime, PubKeyHash, SetNode}
use linkedlist/utils

pub fn init(common: Common) -> Bool {
  let must_spend_nodes = list.length(common.node_inputs) > 0
  let must_exactly_one_node_output = list.length(common.node_outputs) == 1
  let must_mint_correctly =
    utils.validate_mint(
      common.mint,
      common.own_cs,
      constants.origin_node_token_name,
      1,
    )
  must_spend_nodes? && must_exactly_one_node_output? && must_mint_correctly?
}

pub fn deinit(common: Common) -> Bool {
  let must_spend_exactly_one_node_input = list.length(common.node_inputs) == 1
  let must_not_produce_node_output = list.length(common.node_outputs) == 0
  let must_burn_correctly =
    utils.validate_mint(
      common.mint,
      common.own_cs,
      constants.origin_node_token_name,
      -1,
    )
  must_spend_exactly_one_node_input? && must_not_produce_node_output? && must_burn_correctly?
}

pub fn insert(common: Common, insert_key: PubKeyHash, node: SetNode) -> Bool {
  let must_cover_inserting_key = utils.cover_key(node, insert_key)
  expect [covering_node] = common.node_inputs
  let prev_node_datum = utils.as_predecessor_of(node, insert_key)
  let node_datum = utils.as_successor_of(insert_key, node)
  let must_has_datum_in_output =
    list.any(
      common.node_outputs,
      fn(node_pair) { node_datum == node_pair.node },
    )
  let must_correct_node_output =
    list.any(
      common.node_outputs,
      fn(node_pair) {
        covering_node.val == node_pair.val && prev_node_datum == node_pair.node
      },
    )

  let must_mint_correct =
    utils.validate_mint(
      common.mint,
      common.own_cs,
      bytearray.concat(constants.origin_node_token_name, insert_key),
      1,
    )
  must_cover_inserting_key? && must_has_datum_in_output? && must_correct_node_output? && must_mint_correct?
}

pub fn remove(
  common: Common,
  range: POSIXTime,
  disc_config: Config,
  outs: List<Output>,
  sigs: List<PubKeyHash>,
  remove_key: PubKeyHash,
  node: SetNode,
) -> Bool {
  let must_cover_remove_key = utils.cover_key(node, remove_key)
  let prev_node_datum = utils.as_predecessor_of(node, remove_key)
  let node_datum = utils.as_successor_of(remove_key, node)
  let must_spend_two_nodes = list.length(common.node_inputs) == 2
  expect Some(stay_node) =
    list.find(common.node_inputs, fn(input) { prev_node_datum == input.node })
  expect Some(remove_node) =
    list.find(common.node_inputs, fn(input) { node_datum == input.node })
  let remove_token_name =
    bytearray.concat(constants.origin_node_token_name, remove_key)
  let must_correct_node_output =
    list.any(
      common.node_outputs,
      fn(node_pair) { stay_node.val == node_pair.val && node == node_pair.node },
    )
  let must_mint_correct =
    utils.validate_mint(common.mint, common.own_cs, remove_token_name, -1)
  let must_sign_by_user = list.has(sigs, remove_key)
  let own_input_lovelace = lovelace_of(remove_node.val)
  let own_input_fee = utils.div_ceil(own_input_lovelace, 4)
  let disc_deadline = disc_config.deadline
  let must_satisfy_removal_broke_phase_rules =
    if
    interval.is_entirely_after(interval.after(disc_deadline - 8_640_000), range){
    
      True
    } else {
      list.any(
        outs,
        fn(out) {
          out.address == disc_config.penalty_address && own_input_fee < lovelace_of(
            out.value,
          )
        },
      )
    }
  must_cover_remove_key? && must_spend_two_nodes? && must_correct_node_output? && must_mint_correct? && must_sign_by_user? && must_satisfy_removal_broke_phase_rules?
}
