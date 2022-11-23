#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'English'

# Implementation of the command line program
class Rawk
  Options = Struct.new('Options', :sep, :linesep, :verbose, :args, :startup, :finally)

  def self.parse_opts(argv)
    opts = Options.new(nil, "\n", false, [], nil, nil)

    optparser = OptionParser.new do |parser|
      parser.banner = 'Usage: rawk [OPTIONS] (FILENAME | -) [CODE...]'

      parser.on('-FSEP', '--separator=SEP', 'Field separator') { |sep|
        opts.sep = sep
      }

      parser.on('-LSEP', '--line-separator=SEP', 'Line separator') { |sep|
        opts.linesep = sep
      }

      parser.on('-B', '--begin CODE', 'Code to run on start-up') { |code|
        opts.startup = code
      }

      parser.on('-E', '--end CODE', 'Code to run after processing all lines') { |code|
        opts.finally = code
      }

      parser.on('-v', '--verbose', 'Print extra information for debugging') { |v|
        opts.verbose = v
      }

      parser.on('-h', '--help', 'Prints this help') {
        puts parser
        exit
      }
    end

    optparser.parse!(argv)

    # First argument (if present) is the filename for ARGF
    opts.args = argv.pop(argv.size - 1) if argv.size > 1

    opts
  end

  def self.main(opts)
    warn "Opts: #{opts.to_h}" if opts.verbose

    $INPUT_RECORD_SEPARATOR = opts.linesep
    $NR = 0 # Special variable that auto-increments on each line

    ctx = EvalCtx.__get_binding
    eval(opts.startup, ctx, "startup") unless opts.startup.nil?
    ARGF.each_line do |line|
      EvalCtx.__set_line_context(line.chomp, opts)

      opts.args.zip(1..) do |arg, idx|
        eval(arg, ctx, "arg#{idx}")
      end
    end
    eval(opts.finally, ctx, "end")  unless opts.finally.nil?
  end
end

# This class acts as a context for calling eval, adding extra
# functionality on top of Ruby, for example variables and some
# convenience functions. Rawk scripts are able to call methods
# defined inside this class. Methods starting with double
# underscore are required by the implementation and not meant
# to be called from scripts.
class EvalCtx
  # Allow users to type sin(x) instead of Math::sin(x) etc
  extend Math
  @globals = { NF: 0, NR: 0, A0: '' }
  @fields = []
  # Some constants that may be useful
  PI = Math::PI
  TAU = 2 * PI
  PHI = 1.61803398874989
  E = Math::E

  def self.__set_line_context(line, opts)
    @fields = line.split(opts.sep)
    @globals[:A0] = line
    @globals[:NF] = @fields.size
    @globals[:NR] = $NR

    warn "Line #{$NR} : #{@globals}" if opts.verbose
  end

  def self.__get_binding
    # Variables defined in this method get exposed to the
    # binding, and are usable in scripts without initialization
    num = 0
    sum = 0
    count = 0
    total = 0
    result = 0
    dict = {}
    results = []
    # all single letter variables pre-initialized to 0
    a=b=c=d=e=f=g=h=i=j=k=l=m=n=o=p=q=r=s=t=u=v=w=x=y=z=0
    binding
  end

  # Convenient method for printing separated by spaces
  def self.P(*args)
    puts args.join(' ')
  end

  # Meta-programming magicks to make special variables (such
  # as NF) work – ruby does not allow dynamic constants
  def self.const_missing(name)
    case name
    when :A
      @fields
    when :N
      @fields.map(&:to_i)
    when :D
      @fields.map(&:to_f)
    when /^([AND])([1-9]\d*)$/
      field_number = $2.to_i
      return nil if field_number > @fields.length

      field_value = @fields[field_number - 1]
      case $1
      in 'A' then return field_value
      in 'N' then return field_value.to_i
      in 'D' then return field_value.to_f
      end
    else
      @globals[name]
    end
  end
end

if __FILE__ == $PROGRAM_NAME
  opts = Rawk.parse_opts(ARGV)

  Signal.trap('INT') do
    warn "Interrupted by SIGINT while processing line #{$NR}"
    exit
  end

  Rawk.main(opts)
end
