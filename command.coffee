path = require 'path'
debug = require('debug') 'clic'
R = require 'ramda'
RA = require 'ramda-adjunct'
changeCase = require 'change-case'
child_process = require 'child_process'
fs = require 'fs'
# indent = require 'indent-string'

CLI_OPTS = {}
setCliOpts = (opts)-> CLI_OPTS = opts
getCliOpts = -> CLI_OPTS

RAW_CMDS = []
RAW_OPTS = []
getCliRaw = ->
  cmds: RAW_CMDS
  opts: RAW_OPTS

withDash = (str)->
  if 1 is R.length str
    return "-" + str
  else
    return "--" + str
class OptInfo
  constructor: (opts)->
    @data = {}
    for tok in opts
      if R.startsWith '--no-', tok
        @setKey tok[5...]
        @pushValue false
      if R.startsWith '--', tok
        @setKey tok[2...]
      else if R.startsWith '-', tok
        for ch in tok[1...]
          @setKey ch
      else
        @pushValue tok
    @end()

  setKey: (key)->
    @endOpt()
    @last_key = key
    @last_val = []
  pushValue: (val)->
    @last_val.push val
  end: ()->
    @endOpt()
  endOpt: ()->
    # if R.isEmpty @last_val
    #   @last_val.push true
    @data[@last_key] = @last_val

  getValues: (aliases)->
    exists = R.map R.has(R.__, @data), aliases
    in_count = R.length R.filter R.equals(true), exists
    if in_count > 1
      throw new Error 'dont mix aliases'
    for alias in aliases
      continue unless @data[alias]?
      return [alias, @data[alias]]
    return [null, null]


GENESIS_CONTEXT = null
# NOTE opts값은 변하지 않으니 genesis를 여러번 불러서 처리해도 된다.
genesisContext = ()->
  return GENESIS_CONTEXT if GENESIS_CONTEXT?

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
  RAW_CMDS = commands
  RAW_OPTS = opts

  # [opts, commands] = R.partition R.startsWith('-'), opts

  cmd1 = path.basename fn#, path.extname fn
  GENESIS_CONTEXT = {
    host : [cmd1]
    # opt_info: parser
    commands
    opts
  }

  debug 'genesisContext', GENESIS_CONTEXT
  return GENESIS_CONTEXT


getFlagInfo = (flag_fmt, opt)->
  aliases = flag_fmt.match /\-\-?[\w\-]+/g
  debug 'aliases', aliases
  # aliases = R.split /[^\w\-]+/, flag_names
  removeDash = R.replace /^\-+/, ''
  aliases = R.map removeDash, aliases
  name = opt?.name or R.head aliases
  isShort = R.o R.equals(2), R.length
  [shorts, longs] = R.partition isShort, aliases
  name = changeCase.constantCase name
  return { name, aliases, shorts, longs }

maxOfProp = (prop_name, data)->
  fmtLength = R.o R.length, R.prop prop_name
  lens = R.map fmtLength, data
  max_len = R.reduce R.max, 0, lens

class CliCommand
  constructor: ()->
    @alt_actions = {}
    @commands = {}
    @sub_commands = {}
    @extractors = []
    # @opts = []
    @desc = null
    @usage_prop = ''
    @help_data =
      options: []
      commands: []
      examples: []

  printHelp: ()->
    if @help_data.hook_pre?
      await @help_data.hook_pre.apply this, []
      # await @help_data.hook()
    debug 'print help'

    if @desc?
      console.log @desc
      console.log ''

    # console.log 'cli command:', @cli_cmd
    # console.log ''

    console.log 'Usage: '
    if R.is Function, @usage_prop
      @usage_prop()
    else
      console.log '  ' + @cli_cmd + ' ' + @usage_prop
    console.log ''

      # console.log "Desc:"
      # console.log "  " + @desc
    if not R.isEmpty @help_data.options
      console.log "Options:"
      pad_size = R.max 20, 2 + maxOfProp 'flag_fmt', @help_data.options
      for item in @help_data.options
        console.log "  " + item.flag_fmt.padEnd(pad_size) + item.desc
      console.log ''
    if not R.isEmpty @help_data.commands
      console.log "Commands:"
      pad_size = R.max 15, 2 + maxOfProp 'command', @help_data.commands
      for item in @help_data.commands
        console.log "  - " + item.command.padEnd(pad_size) + item.desc
      console.log ''
    if not R.isEmpty @help_data.examples
      console.log "Examples:"
      pad_size = R.max 15, 2 + maxOfProp 'str', @help_data.examples
      for item in @help_data.examples
        console.log "  - " + item.str.padEnd(pad_size) + item.desc
      console.log ''

    if @help_data.hook_post?
      await @help_data.hook_post.apply this, []

  description: (@desc)->
    return this
  helpHook: (fn)->
    @help_data.hook_pre = fn
    return this
  onPreHelp: (fn)->
    @help_data.hook_pre = fn
    return this
  onPostHelp: (fn)->
    @help_data.hook_post = fn
    return this
  usage: (@usage_prop)->
    return this
  example: (str, desc)->
    @help_data.examples.push {str, desc}
    return this
  setHelpCommand: (command, desc)->
    @help_data.commands.push {command, desc}
    return this
  setHelpFlag: (flag_fmt, desc)->
    @help_data.options.push {flag_fmt, desc}
    return this
  getFileOpts: ()->
    return [] unless @opt_filepath
    try
      opts_contents = fs.readFileSync @opt_filepath, 'utf8'
      opts_lines = R.reject RA.isNilOrEmpty, R.split /\r?\n/, opts_contents
      asFlag = (line)->
        # re = /(\"([^\"]+)\"|([^\s\"]+)\s+)\s*/
        # console.log 'exec', re.exec(line)
        toks = line.match(/\"([^\"]+)\"|([^\s\"]+)/g)
        removeQuotes = (word)->
          return word[1...-1] if word[0] is '"'
          return word
        R.map removeQuotes, toks
        # line.match(/(\"[^\"]+\"|[^\\s\"]+)/)
      file_opts = R.flatten R.map asFlag, opts_lines
    catch error
      return []


  extractOpts: (context)->
    unless context?
      context = genesisContext()

    file_opts = @getFileOpts()
    # console.log file_opts
    # opts_contents = R.split /(\"[^\"]+\"|[^\\s\"]+)/g, opts_contents
    # console.log opts_contents
    # process.exit()
    acc = {}
    for extract_fn in @extractors
      extract_fn acc, new OptInfo file_opts
    for extract_fn in @extractors
      extract_fn acc, new OptInfo context.opts


    # context.input = {}
    # for extract_fn in @extractors
    #   extract_fn context
      # debug 'context in progress', context
    # cli_opts = @parseContext context
    # context._ = context.commands
    setCliOpts R.mergeRight acc,
      _: context.commands
  execute: (context, @parent = null)->
    unless context?
      context = genesisContext()
    # else
    #   @parent = context.parent
      # console.log 'process.argv', process.argv
    # @runHooks(context)
    debug 'context =', context
    @cli_cmd = R.join ' ', context.host
    task_promise = @runSubCommand context
    return task_promise if task_promise?

    cli_opts = @extractOpts context
    debug 'cli_opts =', cli_opts
    for own flag, act of @alt_actions
      continue unless cli_opts[flag]?
      debug 'cli_opts[flag]', cli_opts[flag]
      return act.fn.apply this, [] #  act.execute(context)

    # for own flag, act of @commands
    cmd_name = R.head context.commands
    if cmd_name? and @commands[cmd_name]?
      cli_opts._.shift()
      return @commands[cmd_name].fn.apply this, []

    if @action_fn?
      debug 'run default', @action_fn
      return @action_fn.apply this, []

    console.log 'try --help, -h or command help '
  # executeDefault: ()->
  runSubCommand: (context)->
    return null if context.commands.length is 0
    cmd_name = R.head context.commands
    return null unless @sub_commands[cmd_name]?
    debug 'runSubCommand', cmd_name
    ctx = R.mergeRight context,
      host: R.concat context.host, [cmd_name]
      commands: R.tail context.commands
      # parent: this
    return do ()=>
      await @sub_commands[cmd_name].execute ctx, this # TODO 자식을 위해서 고쳐야함.

  action: (fn)->
    @action_fn = fn
    return this
  actionAlt: (flag, fn)->
    flag = changeCase.constantCase flag
    @alt_actions[flag] = {fn}
    return this
  command: (args... )->
    desc = ''
    [str, fn_or_sub] = args if args.length is 2
    [str, desc, fn_or_sub] = args if args.length is 3

    if R.is Function, fn_or_sub
      @commands[str] = {fn: fn_or_sub}
    else
      @sub_commands[str] = fn_or_sub
    @setHelpCommand str, desc
    return this
  # subCommand: (str, desc, sub_cmd )->
  #   @sub_commands[str] = sub_cmd
  #   # @help_data.commands.push {command: str, desc}
  #   @setHelpCommand str, desc
  #   return this
  optsFile: (@opt_filepath)-> return this
  array: (flag_fmt, desc = '', opt = {})->
    {name, aliases, shorts, longs} = getFlagInfo flag_fmt, opt
    debug 'string', name, shorts, longs
    # @help_data.options.push {flag_fmt, desc}
    @setHelpFlag flag_fmt, desc
    @extractors.push (acc, opt_info)->
      [alias, vals] = opt_info.getValues aliases
      unless alias?
        acc[name] = opt.default or [] if R.isNil acc[name]
        return
      else
        acc[name] = vals
    return this
  string: (flag_fmt, desc = '', opt = {})->
    {name, aliases, shorts, longs} = getFlagInfo flag_fmt, opt
    debug 'string', name, shorts, longs
    # @help_data.options.push {flag_fmt, desc}
    @setHelpFlag flag_fmt, desc
    @extractors.push (acc, opt_info)->
      [alias, vals] = opt_info.getValues aliases
      unless alias?
        acc[name] = opt.default if R.isNil acc[name]
        return
      if vals.length isnt 1
        throw new Error 'require only single string; ' + withDash alias
      acc[name] = vals[0]
    return this
  number: (flag_fmt, desc = '', opt = {})->
    {name, aliases, shorts, longs} = getFlagInfo flag_fmt, opt
    debug 'number', name, shorts, longs
    # @help_data.options.push {flag_fmt, desc}
    @setHelpFlag flag_fmt, desc
    @extractors.push (acc, opt_info)->
      [alias, vals] = opt_info.getValues aliases
      # return ctx unless alias?
      unless alias?
        acc[name] = opt.default if R.isNil acc[name]
        return
      if vals.length isnt 1
        throw new Error 'require only single number; ' + withDash alias
      num =  Number vals[0]
      if Number.isNaN num
        throw new Error 'can not parse number; ' + vals[0]
      acc[name] = num
    return this
  custom: (flag_fmt, desc = '', opt = {})->
    {name, aliases, shorts, longs} = getFlagInfo flag_fmt, opt
    debug 'string', name, shorts, longs
    # @help_data.options.push {flag_fmt, desc}
    @setHelpFlag flag_fmt, desc
    @extractors.push (acc, opt_info)->
      [alias, vals] = opt_info.getValues aliases
      # return ctx unless alias?
      unless alias?
        acc[name] = opt.default if R.isNil acc[name]
        return
      acc[name] = opt.convert vals, alias
    return this

  boolean: (flag_fmt, desc = '', opt = {})->
    {name, aliases, shorts, longs} = getFlagInfo flag_fmt, opt
    debug 'boolean', name, shorts, longs
    # @help_data.options.push {flag_fmt, desc}
    @setHelpFlag flag_fmt, desc
    @extractors.push (acc, opt_info)->
      [alias, vals] = opt_info.getValues aliases
      unless alias?
        acc[name] = opt.default if R.isNil acc[name]
        return
      if vals.length is 0
        acc[name] = true
        return
      if vals[0] is false
        acc[name] = false
        return
      debug 'boolean', alias, vals
      throw new Error 'require only on/off; ' + withDash alias
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
      @actionAlt 'version', -> printVer()
    if opt.command
      @command 'version', "show version", -> printVer()
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
      @actionAlt 'help', ()-> @printHelp()
    if opt.command
      @command 'help', "show help", -> @printHelp()
    if opt.default
      @action -> @printHelp()
    return this


Object.defineProperties exports,
  opts:
    get: ()-> getCliOpts()
  raw:
    get: ()-> getCliRaw()

Object.assign exports,
  command: ()-> new CliCommand()
  # restoreFromEnv: ->
  #   if process.env.clic_opt_str?
  #     setCliOpts JSON.parse process.env.clic_opt_str
  #     return true
  #   return false
  spawnShell: (cmd)->
    # console.log 'run', cmd
    options =
      stdio: 'inherit'
      shell: true
    # if opt.pass_opt is 'env'
    #   options.env = Object.assign process.env,
    #     clic_opt_str: JSON.stringify getCliOpts()
    gctx = genesisContext()
    toks = [cmd, getCliOpts()._..., gctx.opts... ]
    cmd = R.join ' ', toks
    # opt_str = R.join ' ', R.concat getCliOpts()._, gctx.opts
    # cmd = cmd + " " + opt_str
    # if process.platform is "win32"
    #   command = "cmd.exe"
    #   args = ["/s", "/c", cmd]
    #   options.windowsVerbatimArguments = true
    # else
    #   command = "/bin/sh"
    #   args = [ "-c", cmd ]
    # console.log 'child_process.spawn', command, args, options
    proc = child_process.spawn cmd, [], options
