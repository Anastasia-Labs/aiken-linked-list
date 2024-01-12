use aiken/hash.{Blake2b_224, Hash}
use aiken/transaction.{OutputReference}
use aiken/transaction/credential.{Address, VerificationKey}
use aiken/transaction/value.{AssetName, PolicyId, Value}

/// A number of milliseconds since 00:00:00 UTC on 1 January 1970.
pub type POSIXTime =
  Int

pub type AssetClass {
  policy_id: PolicyId,
  asset_name: AssetName,
}

pub type PubKeyHash =
  Hash<Blake2b_224, VerificationKey>

pub type Config {
  init_utxo: OutputReference,
  deadline: POSIXTime,
  penalty_address: Address,
}

pub type NodeKey {
  Key { key: PubKeyHash }
  Empty
}

pub type SetNode {
  key: NodeKey,
  next: NodeKey,
}

pub type NodePair {
  val: Value,
  node: SetNode,
}

pub type Common {
  own_cs: PolicyId,
  mint: Value,
  node_inputs: List<NodePair>,
  node_outputs: List<NodePair>,
}

pub type NodeAction {
  Init
  Deinit
  Insert
  Remove
}
