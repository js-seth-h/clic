
console.log 'test2'
debug = require('debug')
# debug.enable("*")
Clic = require './index'
Clic.restoreFromEnv()

console.log 'clic', Clic.opts
