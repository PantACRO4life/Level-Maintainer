local cfg = {}

-- EXAMPLE --
-- NEW SIMPLIFIED FORMAT:
-- ["item_name"] = {threshold, batch_size}
-- ["item_name"] = {nil, batch_size}  -- without threshold (better performance!)

-- OLD FORMAT (for backward compatibility):
-- ["item_name"] = {{item_id, item_meta},threshold, batchsize} -- keep in mind that no threshold has a better performance!
-- ["fluid_name"] = {{fluid_tag item},threshold, batchsize}}  -- keep in mind that no threshold has a better performance!
-- ["Osmium Dust"] = {{ item_id = "gregtech:gt.metaitem.01", item_meta = "2083"}, nil, 64}, -- without threshold, batch_size=64
-- ["drop of Molten SpaceTime"] = {{ fluid_tag = "molten.spacetime"}, 1000, 64} -- with threshold, batch_size=64

cfg["items"] = {

}

cfg["sleep"] = 10

-- Timezone offset in hours
-- Examples: -3 (Argentina), 0 (UTC), 1 (Europe), -5 (USA East)
cfg["timezone"] = 0

return cfg
