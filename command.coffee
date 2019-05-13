path = require 'path'
debug = require('debug') 'command'
R = require 'ramda'

CLI_OPTS = {}
setCliOpts = (opts)-> CLI_OPTS = opts
getCliOpts = (opts)-> CLI_OPTS

genesisContext = ()->
  debug 'process.argv', process.argv
  # debug 'requre.main', require.main
  fn = require.main.filename
  # debug 'fn =', fn, process.argv.findIndex
  inx = process.argv.indexOf fn
  debug 'inx ', inx
  args = process.argv[(inx + 1) ...]
  inx = R.findIndex R.startsWith('-'), args
  inx = args.length if inx is -1
  commands = R.slice 0, inx, args
  opts = R.slice inx, args.length, args
  # [opts, commands] = R.partition R.startsWith('-'), opts

  cmd1 = path.basename fn #, path.extname fn
  context = {
    host : [cmd1]
    opts
    commands
  }
  debug 'genesisContext', context
  return context


getFlagInfo = (flag_fmt, opt)->
  aliases = flag_fmt.match /\-\-?[\w\-]+/g
  debug 'aliases', aliases
  # aliases = R.split /[^\w\-]+/, flag_names
  name = opt?.name or R.replace /^\-+/, '', R.head aliases
  isShort = R.o R.equals(2), R.length
  [shorts, longs] = R.partition isShort, aliases
  return { name, aliases, shorts, longs }

getValInOpts = (opts, aliases )->
  given = R.intersection aliases, opts
  return [undefined, opts] if R.isEmpty given
  if given.length > 1
    throw new Error 'Duplicated options. ' + JSON.stringify given
  opt_str = R.head given
  inx = R.findIndex R.equals(opt_str), opts
  val_str = R.nth inx + 1, opts
  opts = R.remove inx, 2, opts
  # {opts, opt_val: val_str}
  [val_str, opts]

# protectFromAccessViolate = (data)->
#   new Proxy data,
#     get: (target, name)->
#       unless R.has "name", target
#         throw new Error "Access vioate on Clic context."
#       return target[name]
class CliCommand
  constructor: ()->
    @sub_actions = []
    @sub_commands = {}
    @parser = []
    # @opts = []
    @desc = null
    @help_data =
      options: []
      commands: []
      examples: []
  printHelp: ()->
    debug 'print help'
    if @desc?
      console.log "Desc:"
      console.log "  " + @desc
    if not R.isEmpty @help_data.options
      console.log "Options:"
      for item in @help_data.options
        console.log "  " + item.flag_fmt.padEnd(20) + item.desc
    if not R.isEmpty @help_data.commands
      console.log "Commands:"
      for item in @help_data.commands
        console.log "  " + item.command.padEnd(20) + item.desc
    if not R.isEmpty @help_data.examples
      console.log "Examples:"
      for item in @help_data.examples
        console.log "  " + item.str.padEnd(20) + item.desc

  description: (@desc)-> return this
  example: (str, desc)->
    @help_data.examples.push {str, desc}
    return this

  extractOpts: (context)->
    unless context?
      context = genesisContext()
    cli_opts = @parseContext context
    cli_opts._ = cli_opts.commands
    setCliOpts cli_opts

  execute: (context)->
    unless context?
      context = genesisContext()
    else
      @parent = context.parent
      # console.log 'process.argv', process.argv
    # @runHooks(context)
    debug 'context =', context
    @cli_cmd = R.join ' ', context.host
    if @runSubCommand context
      return

    cli_opts = @extractOpts context
    debug 'cli_opts =', cli_opts
    for act in @sub_actions
      if cli_opts[act.flag]?
        debug 'cli_opts[act.flag]', cli_opts[act.flag]
        return act.fn.apply this, [] #  act.execute(context)
    # return @executeDefault context
    if @action_fn?
      debug 'run default', @action_fn
      @action_fn.apply this, []
    else
      console.log 'try --help, -h or command help '
  # executeDefault: ()->
  runSubCommand: (context)->
    return false if context.commands.length is 0
    cmd_name = R.head context.commands
    return false unless @sub_commands[cmd_name]?
    debug 'runSubCommand', cmd_name
    ctx = R.mergeRight R.clone(context),
      host: R.concat context.host, [cmd_name]
      commands: R.tail context.commands
      parent: this
    @sub_commands[cmd_name].execute ctx # TODO 자식을 위해서 고쳐야함.
    return true

  action: (fn)->
    @action_fn = fn
    return this
  subAction: (flag, fn)->
    @sub_actions.push {flag, fn}
    return this
  subCommand: (str, desc, sub_cmd )->
    @sub_commands[str] = sub_cmd
    @help_data.commands.push {command: str, desc}
    return this

  parseContext: (context)->
    for parse in @parser
      context = parse context
      debug 'context in progress', context
    return context

  string: (flag_fmt, desc, opt = {})->
    {name, aliases, shorts, longs} = getFlagInfo flag_fmt, opt
    debug 'string', name, shorts, longs
    @help_data.options.push {flag_fmt, desc}
    @parser.push (ctx)->
      [val, opts]= getValInOpts ctx.opts, aliases
      return ctx unless val
      debug ' as string', val
      changes =
        "#{name}": val
        opts: opts
      debug 'changes = ', changes
      R.mergeRight ctx, changes
    return this
  number: (flag_fmt, desc, opt = {})->
    {name, aliases, shorts, longs} = getFlagInfo flag_fmt, opt
    debug 'number', name, shorts, longs
    @help_data.options.push {flag_fmt, desc}
    @parser.push (ctx)->
      [val, opts]= getValInOpts ctx.opts, aliases
      return ctx unless val
      debug ' as Number', val
      changes =
        "#{name}": Number val
        opts: opts
      debug 'changes = ', changes
      R.mergeRight ctx, changes
    return this
  anything: (flag_fmt, desc, opt = {})->
    {name, aliases, shorts, longs} = getFlagInfo flag_fmt, opt
    debug 'string', name, shorts, longs
    @help_data.options.push {flag_fmt, desc}
    @parser.push (ctx)->
      [val, opts]= getValInOpts ctx.opts, aliases
      return ctx unless val
      debug ' as string', val
      changes =
        "#{name}": opt.convert val
        opts: opts
      debug 'changes = ', changes
      R.mergeRight ctx, changes
    return this

  boolean: (flag_fmt, desc, opt = {})->
    {name, aliases, shorts, longs} = getFlagInfo flag_fmt, opt
    debug 'boolean', name, shorts, longs
    @help_data.options.push {flag_fmt, desc}
    @parser.push (ctx)->
      changes =
        "#{name}": opt.default or undefined

      if not R.isEmpty R.intersection aliases, ctx.opts
        changes =
          "#{name}": true
          opts: R.without aliases, ctx.opts
      else
        no_flags = R.map R.concat('--no'), longs
        if not R.isEmpty R.intersection no_flags, ctx.opts
          changes =
            "#{name}": false
            opts: R.without no_flags, ctx.opts
      debug 'changes = ', changes
      R.mergeRight ctx, changes

    return this

  version: (version_str, opt)->
    opt = R.mergeLeft opt,
      short: true
      long: true
      command: true
      default: false
    aliases = []
    aliases.push '--version' if opt.long
    aliases.push '-v' if opt.short
    printVer = ()-> console.log 'Version: ', version_str
    if aliases.length > 0
      @boolean R.join(', ', aliases), "show version", name: 'version'
      @subAction 'version', -> printVer()
    if opt.command
      @subCommand 'version', "show version", (new CliCommand()).action -> printVer()
    if opt.default
      @action -> printVer()
    return this
  help: (opt)->
    opt = R.mergeLeft opt,
      short: true
      long: true
      command: true
      default: true
    aliases = []
    aliases.push '--help' if opt.long
    aliases.push '-h' if opt.short
    if aliases.length > 0
      @boolean R.join(', ', aliases), "show help", name: 'help'
      @subAction 'help', ()-> @printHelp()
    if opt.command
      @subCommand 'help', "show help", (new CliCommand()).action -> @parent.printHelp()
    if opt.default
      @action -> @printHelp()
    return this


Object.defineProperties exports,
  command:
    value: ()-> new CliCommand()
  opts:
    get: ()-> getCliOpts()
