// Settings for the Daily checks page (/checks).
// Change fridges, limits, cleaning tasks and toilet checks here; the page follows.
// Every item has an "id": keep an id the same when you only rename something,
// so its history stays linked. Give new items a new id.
// "stores" on an item limits it to those stores; leave it out to use it everywhere.
window.CHECKS_CONFIG = {
  stores: [
    { id: 'santo-antonio', name: 'Santo António', active: true },
    { id: 'store-2', name: 'Store 2', active: false }
  ],

  // Days the restaurant is closed (0 = Sunday … 6 = Saturday). Closed days don't count as missing.
  closedDays: [],

  temperatures: {
    times: [
      { id: 'open', label: 'Opening', hint: 'When you arrive' },
      { id: 'close', label: 'Closing', hint: 'Before you leave' }
    ],
    // min / max in °C. A reading outside them asks what was done about it.
    units: [
      { id: 'fridge-1', name: 'Kitchen fridge 1', min: 0, max: 5 },
      { id: 'fridge-2', name: 'Kitchen fridge 2', min: 0, max: 5 },
      { id: 'toppings', name: 'Toppings fridge', min: 0, max: 5 },
      { id: 'drinks', name: 'Drinks fridge', min: 0, max: 8 },
      { id: 'freezer-1', name: 'Freezer', min: -25, max: -18 }
    ],
    actions: [
      'Kept the door closed, rechecking in 30 min',
      'Adjusted the thermostat',
      'Moved the food to another fridge',
      'Threw the food away',
      'Told the manager'
    ]
  },

  // Cleaning, based on the chef, cashier and production booklets plus HACCP basics.
  // every: 'day' (at closing), 'week' (once Monday–Sunday) or 'month' (once per calendar month).
  // days (optional, daily groups only): weekdays it applies, 0 = Sunday … 6 = Saturday.
  // who: the role that normally does it (shown as a label).
  cleaning: [
    {
      id: 'kitchen', label: 'Kitchen', who: 'Chef', every: 'day', tasks: [
        { id: 'k-covered', name: 'All sauces and toppings closed, covered and in the fridge. Nothing left out' },
        { id: 'k-labels', name: 'Everything kept for tomorrow is labelled (panzerotti, parmesan, basil oil…). Expiry = 3 days, today included' },
        { id: 'k-dates', name: 'Dates checked: expired products thrown away, oldest in front (FIFO)' },
        { id: 'k-fridge-order', name: 'Fridges organised: raw products (eggs) on the bottom shelf, away from ready-to-eat food' },
        { id: 'k-boiler', name: 'Pasta boiler switched off, drained, basket and inserts washed, cleaned inside and out' },
        { id: 'k-stoves', name: 'Electric stoves (5) unplugged, cooled, cleaned and stacked in place' },
        { id: 'k-toaster', name: 'Toaster unplugged, crumbs removed, toaster and area cleaned' },
        { id: 'k-counters', name: 'Counters washed with soap and disinfected' },
        { id: 'k-walls', name: 'Walls and splash areas cleaned' },
        { id: 'k-fridge-doors', name: 'Fridge doors and handles cleaned' },
        { id: 'k-knives', name: 'Knives washed, dried and stored safely' },
        { id: 'k-containers', name: 'Used pasta containers washed, dried and stored. Never fresh food in a dirty container' },
        { id: 'k-sink', name: 'Kitchen sink cleaned and organised; hand soap and paper towels refilled' },
        { id: 'k-cloths', name: 'Cloths and sponges washed or replaced' },
        { id: 'k-extraction', name: 'Extraction switched off after cooking and cleaning' }
      ]
    },
    {
      id: 'front', label: 'Cashier and dining room', who: 'Cashier', every: 'day', tasks: [
        { id: 'f-dishwasher', name: 'Dishwasher: both filters cleaned, drained, inside wiped, filters back' },
        { id: 'f-dishes', name: 'All dishes washed and put away; pans clean, dry and hanging' },
        { id: 'f-sinks', name: 'Upstairs and downstairs sinks cleaned and dried' },
        { id: 'f-counters', name: 'Cashier and kitchen counters, trays and plates cleaned; drawers organised' },
        { id: 'f-fridges', name: 'Drink fridges (upstairs and downstairs) restocked and doors fully closed' },
        { id: 'f-ice', name: 'Ice from the bucket back in the ice bag in the freezer' },
        { id: 'f-outside', name: 'Outside tables cleaned and brought inside; chairs up' },
        { id: 'f-floors', name: 'Kitchen and restaurant floors swept and mopped; dirty water emptied, mop stored' },
        { id: 'f-bins', name: 'Both downstairs bins emptied; glass and organic separated' }
      ]
    },
    {
      id: 'production', label: 'Production', who: 'Production', every: 'day', days: [0, 2, 3, 4, 5, 6], tasks: [
        { id: 'p-machine', name: 'Pasta machine cleaned inside, no hardened pasta left' },
        { id: 'p-dies', name: 'Dies cleaned and back in water' },
        { id: 'p-labels', name: 'Old labels removed; new production label on every container. Expiry = 3 days, today included' },
        { id: 'p-cooling', name: 'Hot sauces cooled on the counter (about 2 hours, not longer), then covered and in the fridge' },
        { id: 'p-pasta', name: 'Pasta containers closed (2 layers of paper) and stored correctly' },
        { id: 'p-station', name: 'Production counter, scale, blender and sink cleaned and put back' }
      ]
    },
    {
      id: 'weekly', label: 'Weekly', who: 'Any day this week', every: 'week', tasks: [
        { id: 'w-fridges', name: 'Fridges emptied and cleaned inside: shelves, walls and door seals' },
        { id: 'w-freezer', name: 'Freezer organised: everything labelled and dated, no ice build-up' },
        { id: 'w-storage', name: 'Downstairs storage organised: nothing on the floor, closed containers, oldest in front, nothing expired' },
        { id: 'w-bins', name: 'Bins washed and disinfected inside and out' },
        { id: 'w-under', name: 'Under and behind counters, stoves and fridges swept and mopped' },
        { id: 'w-shelves', name: 'Shelves, racks and drawers wiped' },
        { id: 'w-chemicals', name: 'Cleaning products stored away from food, every bottle labelled' },
        { id: 'w-pests', name: 'Pest check: no droppings, insects or gnawing; tell the manager straight away if you see any' }
      ]
    },
    {
      id: 'monthly', label: 'Monthly', who: 'Any day this month', every: 'month', tasks: [
        { id: 'm-extractor', name: 'Extractor hood and filters deep cleaned and degreased' },
        { id: 'm-behind', name: 'Fridges and freezer pulled out; cleaned behind and underneath' },
        { id: 'm-freezer', name: 'Freezer emptied and deep cleaned (defrosted if there is ice)' },
        { id: 'm-walls', name: 'Walls, vents and light covers cleaned (kitchen and dining room)' },
        { id: 'm-drains', name: 'Floor drains cleaned' },
        { id: 'm-thermometer', name: 'Thermometer tested in iced water: should read 0 °C (±1). Tell the manager if not' }
      ]
    }
  ],

  toilet: {
    checks: [
      { id: 'check-1', label: '1st check', hint: 'Lunch / first half of the day' },
      { id: 'check-2', label: '2nd check', hint: 'Dinner / second half of the day' }
    ],
    items: [
      { id: 'bowl', name: 'Toilet bowl and seat cleaned' },
      { id: 'sink', name: 'Sink and tap cleaned' },
      { id: 'mirror', name: 'Mirror cleaned' },
      { id: 'floor', name: 'Floor cleaned' },
      { id: 'soap', name: 'Soap refilled' },
      { id: 'paper', name: 'Toilet paper refilled' },
      { id: 'towels', name: 'Paper towels refilled' },
      { id: 'bin', name: 'Bin emptied' }
    ]
  }
};
