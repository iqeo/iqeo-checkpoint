#! /usr/bin/env ruby

def parse_name! line
  parsed_name = true
  case                                       # name...
  when line.sub!( /^:([-\w.]+)/, '"\1":'  )  # unquoted: :abc   => "abc":
  when line.sub!( /^:"(.+)"/,    '"\1":'  )  # quoted:   :"abc" => "abc":
  when line.sub!( /^: /,           '"": ' )  # empty:    :      =>    "":
  else
    parsed_name = false
  end
  $debug_str[0] = "n" if parsed_name
  parsed_name
end

def parse_value! line
  parsed_value = true
  case                                           # value...
  when line.sub!( /\(\)$/,            'null,' )  # null:          ()      => null,
  when line.sub!( /\(true\)$/,        'true,' )  # true:          (true)  => true,
  when line.sub!( /\(false\)$/,      'false,' )  # false:         (false) => false,
  when line.sub!( /\("(.*)"\)$/,      '"\1",' )  # quoted string: ("abc") => "abc",
  when line.sub!( /\((-?)(0*)(\d+)\)$/, '\3,' )  # numeric:       (00nn)  => nn,    - removes leading zeroes
  when line.sub!( /\((.*)\)$/,        '"\1",' )  # in parens:     (abc)   => "abc",
  when line.sub!( /: ([-\w.]+)/,    ': "\1",' )  # no parens:     abc     => "abc",
  else
    parsed_value = false
  end
  $debug_str[1] = "v" if parsed_value
  parsed_value
end

def parse_open! line
  parsed_open = true
  case                                                        # open set...
  when line.sub!( /^\($/,                  '{'  )             # anonymous:    (      =>    {
  when line.sub!( /": \($/,             '": {'  )             # unnamed:   ": (      => ": { 
  when line.sub!( /": \("(.*)"$/,       '": { "_id": "\1",' ) # quoted:    ": ("abc" => ": { "_id": "abc" 
  when line.sub!( /": \(([-\w.]+)$/,    '": { "_id": "\1",' ) # unquoted:  ": (abc   => ": { "_id": "abc" 
  else
    parsed_open = false
  end
  if parsed_open
    $debug_str[2] = "o"
    $sets.push :hash  # assume hash until we check next line for array
  end
  parsed_open
end

def parse_close! line
  parsed_close = true
  case                                                            # close set...
  when line.sub!( /^\)$/, "#{$sets.last == :hash ? '}' : ']'}," ) # anonymous:  ) => },
  else
    parsed_close = false
  end
  if parsed_close
    $debug_str[2] = "c" 
    $sets.pop
  end
  parsed_close
end

if __FILE__ == $0

  $debug = false
  $sets = []
  previous = {}
  indent_level = 0
  previous_output = nil
  this_output = nil

  File.open(ARGV[0]).each_line do |line|
    line.encode! invalid: :replace
    line.strip!
    $debug_str = "   "
   
    parsed_name  = parse_name!  line
    parsed_value = parse_value! line
    parsed_open  = parse_open!  line
    parsed_close = parse_close! line

    indent_level -= 1 if parsed_close
    indent_str = "  " * indent_level
    indent_level += 1 if parsed_open

    if previous[:output]
      # remove previous trailing comma if line closes set
      previous[:output].sub!( /,$/, '' ) if parsed_close
      # change hash to array if first item does not have a key
      if previous[:parsed_open] && line =~ /^"": /             # empty name makes this an array
        $sets[previous[:set_index]] = :array                   # change hash to array
        previous[:output] = previous[:output].sub ': {', ': [' # fix previous output
      end
      # change hash items to array items if this set is an array
      line.sub!( /^"": /, '') if $sets[previous[:set_index]] == :array
      puts previous[:output]
    end


    this_output = "#{$debug ? $debug_str : ''}#{indent_str}#{line}"

    previous[:output] = this_output
    previous[:parsed_name]  = parsed_name
    previous[:parsed_value] = parsed_value
    previous[:parsed_open]  = parsed_open
    previous[:parsed_close] = parsed_close
    previous[:set_index]    = $sets.size - 1
  end
  this_output.sub!( /,$/, '' ) # last line is a set close with comma, remove the comma
  puts this_output

end

# fix: broken "next-number" on line 61899 (hash key in array breaks parsing)
