'use strict';
try {
  const wt = require('node:worker_threads');
  if (wt && typeof wt.markAsUncloneable !== 'function') {
    wt.markAsUncloneable = function(obj) { return obj; };
  }
} catch (e) {}
