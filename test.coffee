debug = require('debug')
debug.enable("*")
Clic = require './index'

self = Clic.command()
  .description "Cli-Command Example Propgram "
  # .array '--mod str ... str', 'mods'
  .string '--str, -s <str>', 'string'
  .string '--str2 <str>', 'string'
  .number '--count, -c <count>', "set count."
  .number '--count2 <count>', "set count."
  # .number '--long, -l <count>', """long description of flag. this is show examples.
  #   but not auto breakline. devoloper should be care length
  #   """
  # .boolean "--version, -v", "print version"
  # .usage '-f'
  .boolean "-t", "T"
  # .string "-m <modifires>", "use hardware"
  .boolean "--hw", "use hardware"
  .boolean "--pass", "use pass"
  .boolean "--violate", "test vaiolate"
  .subAction 'hw', ()->
    console.log 'hw=', Clic.opts.hw
  # .subAction 'violate', ()->
  #   console.log 'try access undefined input vale'
  #   a = Clic.opts.not_exist
  #
  # .subCommand 'violate', 'test vioate', Clic.command().action ()->
  #   console.log 'try access undefined input vale'
  #   a = Clic.opts.not_exist
  # .subCommand 'version', "print version", (new Clic()).action ()-> console.log 'version: 1.0.0'
  .help default: true, command: false
  .version '1.0.0', command: true

# console.log 'opts=', self.extractOpts()

self.execute()
console.log 'Clic.opts =', Clic.opts
