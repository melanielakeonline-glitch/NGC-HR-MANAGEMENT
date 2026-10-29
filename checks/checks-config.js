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

  cleaning: [
    {
      id: 'opening', label: 'At opening', tasks: [
        { id: 'handwash', name: 'Hand-wash sink stocked (soap, paper towels)' },
        { id: 'surfaces-am', name: 'Work surfaces sanitised before prep' },
        { id: 'dates', name: 'Dates and labels checked in the fridges (first in, first out)' }
      ]
    },
    {
      id: 'closing', label: 'At closing', tasks: [
        { id: 'surfaces', name: 'Work surfaces and cutting boards cleaned and sanitised' },
        { id: 'pasta-cooker', name: 'Pasta cooker emptied and cleaned' },
        { id: 'hob', name: 'Stove and hob cleaned' },
        { id: 'hood', name: 'Extractor hood wiped' },
        { id: 'fridges', name: 'Fridges wiped (handles, seals, spills)' },
        { id: 'sinks', name: 'Sinks and taps cleaned' },
        { id: 'dishwasher', name: 'Dishwasher emptied, filters cleaned' },
        { id: 'bins', name: 'Bins emptied, bags replaced, bins cleaned' },
        { id: 'kitchen-floor', name: 'Kitchen floor swept and mopped' },
        { id: 'tables', name: 'Dining tables and chairs cleaned' },
        { id: 'dining-floor', name: 'Dining floor swept and mopped' },
        { id: 'counter', name: 'Cashier counter, card machine and screens wiped' },
        { id: 'touchpoints', name: 'Door handles and light switches wiped' }
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
