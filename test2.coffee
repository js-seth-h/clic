
console.log 'test2'
debug = require('debug')
# debug.enable("*")
Clic = require './index'
Clic.restoreFormEnv()

console.log 'clic', Clic.opts
