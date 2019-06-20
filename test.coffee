
debug = require('debug')
# debug.enable("*")
Clic = require './index'

sub = Clic.command()
  .help command: false
  .array '--mod <str> ... <str>', 'mods'
  .version '9.9.9', default: true
  .boolean '-z'
  .actionAlt 'z', ()->
    console.log 'sub -z print=', Clic.opts

self = Clic.command()
  # .usage "groups... -g greps..."
  .optsFile 'clic.opts'
  .usage ->
    console.log "  #{@cli_cmd} groups... -g greps.."
  .description "Cli-Command Example Propgram "
  # .array '--mod str ... str', 'mods'
  .string '--str, -s <str>', 'string'
  .string '--str2 <str>', 'string', default: 'test'
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
  .actionAlt 'hw', ()->
    console.log 'hw=', Clic.opts.HW
  .command 'print', 'print Clic.opts', ()->
    console.log 'print=', Clic.opts
  .command 'sub', 'sub', sub
  .onPostHelp ->
    console.log 'Groups:'
    console.log '   asdfasdf'
    console.log ''

  # .subAction 'violate', ()->
  #   console.log 'try access undefined input vale'
  #   a = Clic.opts.not_exist
  #
  # .subCommand 'violate', 'test vioate', Clic.command().action ()->
  #   console.log 'try access undefined input vale'
  #   a = Clic.opts.not_exist
  # .subCommand 'version', "print version", (new Clic()).action ()-> console.log 'version: 1.0.0'
  .command 'shell', ->
    Clic.runSh "coffee test2.coffee", pass_opt: 'env'
  .help default: true, command: false
  .version '1.0.0', command: true

# console.log 'opts=', self.extractOpts()

if require.main is module
  self.execute()

module.exports = {
  self
}
# console.log 'Clic.opts =', Clic.opts
# console.log 'Clic.raw =', Clic.raw
