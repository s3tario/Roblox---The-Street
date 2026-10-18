--!strict
-- Wallet defaults (owned by `shop`; contracts §3 and §7). Saved in data.wallet and replicated to the owner.
--   cash     spendable Cash (whole dollars, never below 0)
--   earned   lifetime cash credited (after multipliers)
--   spent    lifetime cash spent in shops and on purchases
--   living   lifetime weekly living costs charged
--   recent   ring of the latest credits and debits { at, delta, source } (newest last, Shop.economy.recent kept)

return {
	wallet = {
		cash = 0,
		earned = 0,
		spent = 0,
		living = 0,
		recent = {},
	},
}
