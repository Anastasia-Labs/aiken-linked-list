use aiken/interval.{Interval, after, is_entirely_before}
use aiken/list
use aiken/transaction.{Input, Mint, Output, ScriptContext, Transaction}
use linkedlist/linked_list.{deinit, init, insert, remove}
use linkedlist/types.{
  Config, Deinit, Init, Insert, NodeAction, POSIXTime, PubKeyHash, Remove,
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
