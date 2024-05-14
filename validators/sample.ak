use aiken/bytearray
use aiken/dict
use aiken/interval.{Finite, Interval, IntervalBound, is_entirely_before}
use aiken/list
use aiken/transaction.{
  InlineDatum, Input, Mint, NoDatum, Output, OutputReference, ScriptContext,
  Transaction, TransactionId,
}
use aiken/transaction/credential.{Address}
use aiken/transaction/value
use linkedlist/constants.{origin_node_token_name}
use linkedlist/linked_list.{deinit, init, insert, remove}
use linkedlist/types.{
  Config, Deinit, Empty, Init, Insert, Key, NodeAction, Remove, SetNode,
}
use linkedlist/utils

validator {
  fn mint_validator(cfg: Config, redeemer: NodeAction, ctx: ScriptContext) {
    let (common, inputs, outputs, sigs, vrange) = utils.make_common(ctx)
    when redeemer is {
      Init -> {
        expect
          list.any(
            inputs,
            fn(input) { cfg.init_utxo == input.output_reference },
          )
        init(common)
      }
      Deinit -> deinit(common)
      Insert { key_to_insert, covering_node } -> {
        expect is_entirely_before(vrange, cfg.deadline)
        expect list.any(sigs, fn(sig) { sig == key_to_insert })
        insert(common, key_to_insert, covering_node)
      }
      Remove { key_to_remove, covering_node } -> {
        expect is_entirely_before(vrange, cfg.deadline)
        remove(common, vrange, cfg, outputs, sigs, key_to_remove, covering_node)
      }
    }
  }
}

test mint_validator_init() {
  let own_cs = #"746fa3ba2daded6ab9ccc1e39d3835aa1dfcb9b5a54acc2ebe6b79a4"
  let init_output_ref =
    OutputReference {
      transaction_id: TransactionId {
        hash: #"2c6dbc95c1e96349c4131a9d19b029362542b31ffd2340ea85dd8f28e271ff6d",
      },
      output_index: 1,
    }
  let config =
    Config {
      init_utxo: init_output_ref,
      deadline: 86_400_000,
      penalty_address: Address(credential.ScriptCredential("P"), None),
    }
  let redeemer = Init
  let minted_value = value.add(value.zero(), own_cs, origin_node_token_name, 1)
  let head_output =
    Output {
      address: Address(credential.ScriptCredential("B"), None),
      value: value.add(
        minted_value,
        value.ada_policy_id,
        value.ada_asset_name,
        4_000_000,
      ),
      datum: InlineDatum(SetNode { key: Empty, next: Empty }),
      reference_script: None,
    }
  let context =
    ScriptContext {
      purpose: Mint(own_cs),
      transaction: Transaction {
        inputs: [
          Input {
            output_reference: init_output_ref,
            output: Output {
              address: Address(credential.ScriptCredential("C"), None),
              value: value.from_lovelace(4_000_000),
              datum: NoDatum,
              reference_script: None,
            },
          },
        ],
        reference_inputs: [],
        outputs: [head_output],
        fee: value.zero(),
        mint: value.to_minted_value(minted_value),
        certificates: [],
        withdrawals: dict.new(),
        validity_range: interval.everything(),
        extra_signatories: [],
        redeemers: dict.new(),
        datums: dict.new(),
        id: TransactionId {
          hash: #"2c6dbc95c1e96349c4131a9d19b029362542b31ffd2340ea85dd8f28e271ff6d",
        },
      },
    }

  mint_validator(config, redeemer, context)
}

test mint_validator_deinit() {
  let own_cs = #"746fa3ba2daded6ab9ccc1e39d3835aa1dfcb9b5a54acc2ebe6b79a4"
  let init_output_ref =
    OutputReference {
      transaction_id: TransactionId {
        hash: #"2c6dbc95c1e96349c4131a9d19b029362542b31ffd2340ea85dd8f28e271ff6d",
      },
      output_index: 1,
    }
  let config =
    Config {
      init_utxo: init_output_ref,
      deadline: 86_400_000,
      penalty_address: Address(credential.ScriptCredential("P"), None),
    }
  let redeemer = Deinit
  let own_cs_value = value.add(value.zero(), own_cs, origin_node_token_name, -1)
  let burn_value = value.add(value.zero(), own_cs, origin_node_token_name, -1)
  let in_output =
    Output {
      address: Address(credential.ScriptCredential("B"), None),
      value: value.add(
        own_cs_value,
        value.ada_policy_id,
        value.ada_asset_name,
        4_000_000,
      ),
      datum: InlineDatum(SetNode { key: Empty, next: Empty }),
      reference_script: None,
    }
  let context =
    ScriptContext {
      purpose: Mint(own_cs),
      transaction: Transaction {
        inputs: [Input { output_reference: init_output_ref, output: in_output }],
        reference_inputs: [],
        outputs: [],
        fee: value.zero(),
        mint: value.to_minted_value(burn_value),
        certificates: [],
        withdrawals: dict.new(),
        validity_range: interval.everything(),
        extra_signatories: [],
        redeemers: dict.new(),
        datums: dict.new(),
        id: TransactionId {
          hash: #"2c6dbc95c1e96349c4131a9d19b029362542b31ffd2340ea85dd8f28e271ff6d",
        },
      },
    }

  mint_validator(config, redeemer, context)
}

test mint_validator_deinit_fails_on_non_empty() fail {
  let own_cs = #"746fa3ba2daded6ab9ccc1e39d3835aa1dfcb9b5a54acc2ebe6b79a4"
  let init_output_ref =
    OutputReference {
      transaction_id: TransactionId {
        hash: #"2c6dbc95c1e96349c4131a9d19b029362542b31ffd2340ea85dd8f28e271ff6d",
      },
      output_index: 1,
    }
  let config =
    Config {
      init_utxo: init_output_ref,
      deadline: 86_400_000,
      penalty_address: Address(credential.ScriptCredential("P"), None),
    }
  let user2_pkh =
    bytearray.from_string(
      @"e18d73505be6420225ed2a42c8e975e4c6f9148ab38e951ea2572e54",
    )
  let user2_tn = "FSNe18d73505be6420225ed2a42c8e975e4c6f9148ab38e951ea2572e54"
  let remove_output_ref =
    OutputReference {
      transaction_id: TransactionId { hash: #"" },
      output_index: 1,
    }
  let remove_node =
    SetNode { key: Key { key: user2_pkh }, next: Key { key: user2_pkh } }
  let user2_value = value.add(value.zero(), own_cs, user2_tn, 1)
  let remove_node_output =
    Output {
      address: Address(credential.ScriptCredential("I"), None),
      value: value.add(
        user2_value,
        value.ada_policy_id,
        value.ada_asset_name,
        9_000_000,
      ),
      datum: InlineDatum(remove_node),
      reference_script: None,
    }
  let burn_value = value.add(value.zero(), own_cs, origin_node_token_name, -1)
  let redeemer = Deinit
  let context =
    ScriptContext {
      purpose: Mint(own_cs),
      transaction: Transaction {
        inputs: [
          Input {
            output_reference: remove_output_ref,
            output: remove_node_output,
          },
        ],
        reference_inputs: [],
        outputs: [],
        fee: value.zero(),
        mint: value.to_minted_value(burn_value),
        certificates: [],
        withdrawals: dict.new(),
        validity_range: interval.everything(),
        extra_signatories: [],
        redeemers: dict.new(),
        datums: dict.new(),
        id: TransactionId {
          hash: #"2c6dbc95c1e96349c4131a9d19b029362542b31ffd2340ea85dd8f28e271ff6d",
        },
      },
    }
  mint_validator(config, redeemer, context)
}

test mint_validator_insert() {
  let own_cs = #"746fa3ba2daded6ab9ccc1e39d3835aa1dfcb9b5a54acc2ebe6b79a4"
  let init_output_ref =
    OutputReference {
      transaction_id: TransactionId {
        hash: #"2c6dbc95c1e96349c4131a9d19b029362542b31ffd2340ea85dd8f28e271ff6d",
      },
      output_index: 1,
    }
  let config =
    Config {
      init_utxo: init_output_ref,
      deadline: 86_400_000,
      penalty_address: Address(credential.ScriptCredential("P"), None),
    }
  let user1_pkh =
    bytearray.from_string(
      @"a65ca58a4e9c755fa830173d2a5caed458ac0c73f97db7faae2e7e3b",
    )
  let covering_tn =
    "FSNa65ca58a4e9c755fa830173d2a5caed458ac0c73f97db7faae2e7e3b"
  let user2_pkh =
    bytearray.from_string(
      @"e18d73505be6420225ed2a42c8e975e4c6f9148ab38e951ea2572e54",
    )
  let insert_tn = "FSNe18d73505be6420225ed2a42c8e975e4c6f9148ab38e951ea2572e54"
  let covering_minted_value = value.add(value.zero(), own_cs, covering_tn, 1)
  let covering_node_value =
    value.add(
      covering_minted_value,
      value.ada_policy_id,
      value.ada_asset_name,
      9_000_000,
    )
  let covering_node = SetNode { key: Key { key: user1_pkh }, next: Empty }
  let covering_output =
    Output {
      address: Address(credential.ScriptCredential("I"), None),
      value: covering_node_value,
      datum: InlineDatum(covering_node),
      reference_script: None,
    }
  let covering_output_ref =
    OutputReference {
      transaction_id: TransactionId { hash: #"" },
      output_index: 1,
    }
  let out_prev_node =
    SetNode { key: covering_node.key, next: Key { key: user2_pkh } }

  let out_prev_node_output =
    Output {
      address: Address(credential.ScriptCredential("I"), None),
      value: covering_node_value,
      datum: InlineDatum(out_prev_node),
      reference_script: None,
    }
  let out_node =
    SetNode { key: Key { key: user2_pkh }, next: covering_node.next }
  let insert_minted_value = value.add(value.zero(), own_cs, insert_tn, 1)
  let out_node_output =
    Output {
      address: Address(credential.ScriptCredential("I"), None),
      value: value.add(
        insert_minted_value,
        value.ada_policy_id,
        value.ada_asset_name,
        9_000_000,
      ),
      datum: InlineDatum(out_node),
      reference_script: None,
    }
  let redeemer = Insert { key_to_insert: user2_pkh, covering_node }
  let insert_timerange =
    Interval {
      lower_bound: IntervalBound {
        bound_type: Finite(1000),
        is_inclusive: False,
      },
      upper_bound: IntervalBound {
        bound_type: Finite(2000),
        is_inclusive: False,
      },
    }
  let context =
    ScriptContext {
      purpose: Mint(own_cs),
      transaction: Transaction {
        inputs: [
          Input {
            output_reference: covering_output_ref,
            output: covering_output,
          },
        ],
        reference_inputs: [],
        outputs: [out_prev_node_output, out_node_output],
        fee: value.zero(),
        mint: value.to_minted_value(insert_minted_value),
        certificates: [],
        withdrawals: dict.new(),
        validity_range: insert_timerange,
        extra_signatories: [user2_pkh],
        redeemers: dict.new(),
        datums: dict.new(),
        id: TransactionId {
          hash: #"2c6dbc95c1e96349c4131a9d19b029362542b31ffd2340ea85dd8f28e271ff6d",
        },
      },
    }
  mint_validator(config, redeemer, context)
}

test mint_validator_remove() {
  let own_cs = #"746fa3ba2daded6ab9ccc1e39d3835aa1dfcb9b5a54acc2ebe6b79a4"
  let init_output_ref =
    OutputReference {
      transaction_id: TransactionId {
        hash: #"2c6dbc95c1e96349c4131a9d19b029362542b31ffd2340ea85dd8f28e271ff6d",
      },
      output_index: 1,
    }
  let config =
    Config {
      init_utxo: init_output_ref,
      deadline: 86_400_000,
      penalty_address: Address(credential.ScriptCredential("P"), None),
    }
  let user1_pkh =
    bytearray.from_string(
      @"a65ca58a4e9c755fa830173d2a5caed458ac0c73f97db7faae2e7e3b",
    )
  let covering_tn =
    "FSNa65ca58a4e9c755fa830173d2a5caed458ac0c73f97db7faae2e7e3b"
  let user2_pkh =
    bytearray.from_string(
      @"e18d73505be6420225ed2a42c8e975e4c6f9148ab38e951ea2572e54",
    )
  let user2_tn = "FSNe18d73505be6420225ed2a42c8e975e4c6f9148ab38e951ea2572e54"
  let covering_minted_value = value.add(value.zero(), own_cs, covering_tn, 1)
  let covering_node_value =
    value.add(
      covering_minted_value,
      value.ada_policy_id,
      value.ada_asset_name,
      9_000_000,
    )
  let covering_node =
    SetNode { key: Key { key: user1_pkh }, next: Key { key: user2_pkh } }
  let covering_output =
    Output {
      address: Address(credential.ScriptCredential("I"), None),
      value: covering_node_value,
      datum: InlineDatum(covering_node),
      reference_script: None,
    }
  let covering_output_ref =
    OutputReference {
      transaction_id: TransactionId { hash: #"" },
      output_index: 1,
    }
  let remove_output_ref =
    OutputReference {
      transaction_id: TransactionId { hash: #"" },
      output_index: 1,
    }
  let remove_node = SetNode { key: Key { key: user2_pkh }, next: Empty }
  let user2_value = value.add(value.zero(), own_cs, user2_tn, 1)
  let remove_node_output =
    Output {
      address: Address(credential.ScriptCredential("I"), None),
      value: value.add(
        user2_value,
        value.ada_policy_id,
        value.ada_asset_name,
        9_000_000,
      ),
      datum: InlineDatum(remove_node),
      reference_script: None,
    }
  let output_node = SetNode { key: covering_node.key, next: remove_node.next }
  let out_node_output =
    Output {
      address: Address(credential.ScriptCredential("I"), None),
      value: covering_node_value,
      datum: InlineDatum(output_node),
      reference_script: None,
    }
  let remove_burn_value = value.add(value.zero(), own_cs, user2_tn, -1)
  let cover_node = SetNode { key: Key { key: user1_pkh }, next: Empty }
  let redeemer = Remove { key_to_remove: user2_pkh, covering_node: cover_node }
  let remove_timerange =
    Interval {
      lower_bound: IntervalBound {
        bound_type: Finite(1000),
        is_inclusive: False,
      },
      upper_bound: IntervalBound {
        bound_type: Finite(2000),
        is_inclusive: False,
      },
    }
  let context =
    ScriptContext {
      purpose: Mint(own_cs),
      transaction: Transaction {
        inputs: [
          Input {
            output_reference: remove_output_ref,
            output: remove_node_output,
          },
          Input {
            output_reference: covering_output_ref,
            output: covering_output,
          },
        ],
        reference_inputs: [],
        outputs: [out_node_output],
        fee: value.zero(),
        mint: value.to_minted_value(remove_burn_value),
        certificates: [],
        withdrawals: dict.new(),
        validity_range: remove_timerange,
        extra_signatories: [user2_pkh],
        redeemers: dict.new(),
        datums: dict.new(),
        id: TransactionId {
          hash: #"2c6dbc95c1e96349c4131a9d19b029362542b31ffd2340ea85dd8f28e271ff6d",
        },
      },
    }
  mint_validator(config, redeemer, context)
}
