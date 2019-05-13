debug = require('debug')
debug.enable("*")
Clic = require './index'

self = new Clic
self
  .description "test "
  .number '--count, -c <count>', "set count"
  # .boolean "--version, -v", "print version"
  # .usage '-f'
  # .boolean "--hw", "use hardware"
  # .string "-m <modifires>", "use hardware"
  .boolean "--hw", "use hardware"
  .boolean "--violate", "test vaiolate"
  .subAction 'violate', (ctx)->
    console.log 'try access undefined input vale'
    a = ctx.not_exist

  .subCommand 'violate', 'test vioate', (new Clic()).action (ctx)->
    console.log 'try access undefined input vale'
    a = ctx.not_exist
  # .subCommand 'version', "print version", (new Clic()).action ()-> console.log 'version: 1.0.0'
  .help default: false, command: false
  .version '1.0.0', command: false
self.execute()
