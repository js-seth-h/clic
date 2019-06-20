
console.log 'test2'
debug = require('debug')
# debug.enable("*")
Clic = require './index'
# Clic.restoreFromEnv()
cmds = require './test'
cmds.self.extractOpts()
console.log 'test2 reparse clic', Clic.opts
