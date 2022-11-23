#!/usr/bin/env ruby

require 'optparse'

class Rawk
  Options = Struct.new('Options', :sep, :linesep, :verbose, :args)

  def self.parse_opts(argv)
    opts = Options.new(nil, "\n", false, [])

    parser = OptionParser.new do |parser|
      parser.banner = 'Usage: rawk [OPTIONS] (FILENAME | -) [CODE...]'

      parser.on('-FSEP', '--separator=SEP', 'Field separator') { |sep|
        opts.sep = sep
      }

      parser.on('-LSEP', '--line-separator=SEP', 'Line separator') { |sep|
        opts.linesep = sep
      }

      parser.on('-v', '--verbose', 'Print extra information for debugging') { |v|
        opts.verbose = v
      }

      parser.on('-h', '--help', 'Prints this help') {
        puts parser
        exit
      }
    end

    parser.parse!(argv)

    # First argument (if present) is the filename for ARGF
    if argv.size > 1
      opts.args = argv.pop(argv.size - 1)
    end

    opts
  end
end

class EvalCtx
  @@globals = {:NF => 0, :NR => 0, :A0 => "", :A => []}
  @@fields = []

  def self.__set_line_context(line, opts)
    @@fields = line.split(opts.sep)
    @@globals[:A0] = line
    @@globals[:NF] = @@fields.size
    @@globals[:NR] = $.

    if opts.verbose
      STDERR.puts "Line #{$.} : #{@@globals}"
    end
  end

  def self.__get_binding
    binding
  end

  # Convenient method for printing separated by spaces
  def self.P(*args)
    puts args.join(' ')
  end

  # Meta-programming magicks to make special variables (such
  # as NF) work – ruby does not allow dynamic constants
  def self.const_missing(name)
    if name =~ /^([AND])([1-9]\d*)$/
      field_number = $2.to_i
      return nil if field_number > @@fields.length
      field_value = @@fields[field_number]
      case $1
      in 'A' then return field_value
      in 'N' then return field_value.to_i
      in 'D' then return field_value.to_f
      end
    elsif name == :A
      @@fields
    elsif name == :N
      @@fields.map(&:to_i)
    elsif name == :D
      @@fields.map(&:to_f)
    else
      @@globals[name]
    end
  end
end

if __FILE__ == $0
  opts = Rawk.parse_opts(ARGV)
  if opts.verbose
    puts "Opts: #{opts.to_h}"
  end

  $/ = opts.linesep  # Special variable used by ARGF.each_line
  $. = 0  # Special variable that auto-increments on each line

  Signal.trap("INT") {
    STDERR.puts "Interrupted by SIGINT while processing line #{$.}"
    STDERR.puts " r = #{r}" unless r.nil?
    exit
  }

  ctx = EvalCtx.__get_binding
  ARGF.each_line do |line|
    EvalCtx.__set_line_context(line.chomp, opts)

    opts.args.zip(1..) do |arg, idx|
      eval(arg, ctx, "arg#{idx}")
    end
  end
end
