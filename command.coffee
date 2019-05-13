path = require 'path'
debug = require('debug') 'command'
R = require 'ramda'

getFlagInfo = (flag_fmt, opt)->
  alias = flag_fmt.match /\-\-?[\w\-]+/g
  debug 'alias', alias
  # alias = R.split /[^\w\-]+/, flag_names
  name = opt?.name or R.replace /^\-+/, '', R.head alias
  isShort = R.o R.equals(2), R.length
  [shorts, longs] = R.partition isShort, alias
  return { name, alias, shorts, longs }

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

  # usage: ()->
  #   return this
  description: (@desc)-> return this
  example: (str, desc)->
    @help_data.examples.push {str, desc}
    return this


  execute: (context)->
    unless context?
      debug 'process.argv', process.argv
      # debug 'requre.main', require.main
      fn = require.main.filename
      # debug 'fn =', fn, process.argv.findIndex
      inx = process.argv.indexOf fn
      debug 'inx ', inx
      args = process.argv[(inx + 1) ...]
      inx = R.findIndex R.startsWith('-'), args
      commands = R.slice 0, inx, args
      opts = R.slice inx, args.length, args
      # [opts, commands] = R.partition R.startsWith('-'), opts

      cmd1 = path.basename fn #, path.extname fn
      debug 'cmd1=', cmd1, opts
      context = {
        host : [cmd1]
        opts
        commands
      }
      # console.log 'process.argv', process.argv
    # @runHooks(context)
    debug 'context =', context
    @cli_cmd = R.join ' ', context.host
    if context.commands.length > 0
      cmd_name = R.head context.commands
      if @sub_commands[cmd_name]?
        ctx = R.mergeRight R.clone(context),
          host: R.concat context.host, [cmd_name]
          commands: R.tail context.commands
          parent: this
        return @sub_commands[cmd_name].execute ctx # TODO 자식을 위해서 고쳐야함.

    ctx = @parseContext context
    debug 'parsed context =', ctx
    for act in @sub_actions
      if ctx[act.flag]?
        debug 'ctx[act.flag]', ctx[act.flag]
        return act.fn.apply this, [ctx] #  act.execute(context)
    # return @executeDefault context
    if @action_fn?
      @action_fn.apply this, [ctx]
    else
      console.log 'try --help, -h or command help '
  # executeDefault: ()->

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

  # date: ()->
  #   return this
  anything: ()->
    return this
  string: ()->
    {name, alias, shorts, longs} = getFlagInfo flag_fmt, opt
    debug 'string', name, shorts, longs
    @help_data.options.push {flag_fmt, desc}
    @parser.push (ctx)->
      given = R.intersection alias, ctx.opts
      return ctx if R.isEmpty given
      if given.length > 1
        throw new Error 'Duplicated arguments. ' + JSON.stringify given
      opt_str = R.head given
      inx = R.findIndex R.equals(opt_str), ctx.opts
      val_str = R.nth inx + 1, ctx.opts
      debug ' as String', inx, val_str
      changes =
        "#{name}": val_str
        opts: R.remove inx, 2, ctx.opts
      debug 'changes = ', changes
      R.mergeRight ctx, changes
    return this
  number: (flag_fmt, desc, opt = {})->
    {name, alias, shorts, longs} = getFlagInfo flag_fmt, opt
    debug 'number', name, shorts, longs
    @help_data.options.push {flag_fmt, desc}
    @parser.push (ctx)->
      given = R.intersection alias, ctx.opts
      return ctx if R.isEmpty given
      if given.length > 1
        throw new Error 'Duplicated arguments. ' + JSON.stringify given
      opt_str = R.head given
      inx = R.findIndex R.equals(opt_str), ctx.opts
      val_str = R.nth inx + 1, ctx.opts
      debug ' as Number', inx, val_str

      changes =
        "#{name}": Number val_str
        opts: R.remove inx, 2, ctx.opts
      debug 'changes = ', changes
      R.mergeRight ctx, changes
    return this

  boolean: (flag_fmt, desc, opt = {})->
    {name, alias, shorts, longs} = getFlagInfo flag_fmt, opt
    #
    # alias = flag_fmt.match /\-\-?[\w\-]+/g
    # debug 'alias', alias
    # # alias = R.split /[^\w\-]+/, flag_names
    # name = opt.name or R.head alias
    # isShort = R.o R.equals(1), R.length
    # [shorts, longs] = R.partition isShort, alias
    debug 'boolean', name, shorts, longs
    @help_data.options.push {flag_fmt, desc}
    @parser.push (ctx)->
      changes =
        "#{name}": opt.default or undefined

      if not R.isEmpty R.intersection alias, ctx.opts
        changes =
          "#{name}": true
          opts: R.without alias, ctx.opts
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
      default: true
    alias = []
    alias.push '--version' if opt.long
    alias.push '-v' if opt.short
    printVer = ()-> console.log 'Version: ', version_str
    if alias.length > 0
      @boolean R.join(', ', alias), "show version", name: 'version'
      @subAction 'version', printVer
    if opt.command
      @subCommand 'version', "show version", (new CliCommand()).action printVer
    if opt.default
      @action -> printVer
    return this
  help: (opt)->
    opt = R.mergeLeft opt,
      short: true
      long: true
      command: true
      default: true
    alias = []
    alias.push '--help' if opt.long
    alias.push '-h' if opt.short
    if alias.length > 0
      @boolean R.join(', ', alias), "show help", name: 'help'
      @subAction 'help', (ctx)-> @printHelp()
    if opt.command
      @subCommand 'help', "show help", (new CliCommand()).action (ctx)-> ctx.parent.printHelp()
    if opt.default
      @action -> @printHelp()
    return this

module.exports = CliCommand
