--!strict
-- Logic/Economy (owned by `shop`; contracts §7): the pure rules behind the cash economy, the shops and housing.
-- No services, no clocks, no Instances: EconomyService, ShopService, HousingService and the Shop/Housing screens all
-- run the same code, and tests/shop covers it under Lune.
--
--   Economy.Wallet     cash maths: multipliers per income kind, credit / spend (all or nothing) / living charges
--   Economy.Purchase   prices, discounts, which shop sells what, purchase validation, dress-code hints
--   Economy.Housing    decor placement rules: slot-kind compatibility, contexts, budgets, themes
--   Economy.Assign     dorm / apartment / desk / office assignment pools (capacity exhaustion, office fallback)
--   Economy.Plaques    deal plaque layout on desks and bookshelves (v3 §13)

local Economy = {}

Economy.Wallet = require(script.Wallet)
Economy.Purchase = require(script.Purchase)
Economy.Housing = require(script.Housing)
Economy.Assign = require(script.Assign)
Economy.Plaques = require(script.Plaques)

return Economy
