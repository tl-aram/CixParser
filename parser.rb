# Parser for Cix, a subset of the C language (http://github.com/Celarix/Cix)
# This parser is a reworked version of what I did for my previous unnamed language, which is an implementation (rip-off)
# of the TDOP parsing algorithm (http://javascript.crockford.com/tdop/tdop.html)

# Token types
Name_T = 0
Numeric_T = 1
String_T = 2
Operator_T = 3

class Token
	attr_accessor :type, :value
	def initialize
		@type = nil
		@value = nil
	end
end


class Lexer	
	# _srcfile: An open IO object, which is either a file or stdin.
	def initialize(_srcfile)
		@srcfile = _srcfile
		if $live
			@src = [ @srcfile.readline.chomp ]
		else
			@src = _srcfile.read.split("\n")
		end
		@lineno = 0
		@linepos = 0
		@tok_start = 0
	end
	
	def skip_whitespace
		
	end
	
	def parse_number
		numeric_t = Token.new
		numeric_t::type = Numeric_T
		number_string = ""
		while ('0'..'9') === @src[@lineno][@linepos]
			number_string += @src[@lineno][@linepos]
			@linepos+=1
		end
		numeric_t::value = number_string.to_i
		case @src[@lineno][@linepos]
		when 'u' then
			if @src[@lineno][@linepos] == 'l'
				@linepos+=2
			else
				@linepos+=1
			end
			puts "Warning: numeric type suffixes not yet supported"
		when 'f' then
			@linepos+=1
			puts "Warning: numeric type suffixes not yet supported"
		when 'd' then
			@linepos+=1
			puts "Warning: numeric type suffixes not yet supported"
		end
		return numeric_t
	end
	
	def parse_name
	
	end
	
	def parse_operator
	
	end
	
	def parse_string
		string_t = Token.new
		string_t::type = String_T
		string_t::value = ""
		special_char_map = "\a\b\f\n\r\t\v".codepoints #for definite values!
		@linepos+=1
		while (@src[@lineno][@linepos] && @src[@lineno][@linepos] != '"')
			if @src[@lineno][@linepos] == '\\'
				@linepos+=1
				if (@src[@lineno][@linepos] == '\\') || (@src[@lineno][@linepos] == '"')
					string_t::value += @src[@lineno][@linepos] 
				elsif (@src[@lineno][@linepos] == 'a')
					string_t::value += special_char_map[0].chr
				elsif (@src[@lineno][@linepos] == 'b')
					string_t::value += special_char_map[1].chr
			  elsif (@src[@lineno][@linepos] == 'f')
					string_t::value += special_char_map[2].chr
				elsif (@src[@lineno][@linepos] == 'n')
					string_t::value += special_char_map[3].chr
				elsif (@src[@lineno][@linepos] == 'r')
					string_t::value += special_char_map[4].chr
				elsif (@src[@lineno][@linepos] == 't')
					string_t::value += special_char_map[5].chr
				elsif (@src[@lineno][@linepos] == 'v')
					string_t::value += special_char_map[6].chr
				elsif ((@src[@lineno][@linepos]) == 'U' ||
				       (@src[@lineno][@linepos]) == 'u')
					puts "Warning: Unicode strings not yet supported, at line #{@lineno + 1}"
					@linepos+=4
				end
			elsif (@src[@lineno][@linepos] >= "\x20" &&
			       @src[@lineno][@linepos] <= "\x7F")
				string_t::value += @src[@lineno][@linepos]
			else
				puts "Warning: non-ASCII and special characters will be ignored, at line #{@lineno + 1}"
			end
			@linepos+=1
		end
		@linepos+=1 #to get past end quote
		return string_t
	end
	
	# Builds the next token from the input stream.
	def get_token
		t = Token.new
		case @src[@lineno][@linepos]
			when ' ' then
				skip_whitespace
			when '\f' then #less likely to see this
				skip_whitespace
			when '\t' then
				skip_whitespace
			when '\v' then
				skip_whitespace
			when '0'..'9' then
				t = parse_number
			when 'A-Z' then
				t = parse_name
			when 'a-z' then
				parse_name
			when '_' then
				t = parse_name
			when /[~!$%\^&*()-+=|{}\[\]\:;\/?<>,.]/ then #very much check
				t = parse_operator
			when '"' then
				t = parse_string
		end
	end
end

class Node #I actually forgot there was an existing Symbol class, and tried to call it that, not knowing why I was getting errors
	attr_accessor :id, :lbp, :nud, :led, :left, :right
	def initialize(id, bp) #I know, the symbol creation in the original is all in one place
		@id = id
		@lbp = bp
		@nud = Proc.new { raise "Undefined." } #null denotation
		@led = Proc.new { raise "Undefined." } #left denotation.	Should be something less clunky; no actual first order first-order functions here
	end
	
	def to_s(indent=0)
		raise "Node has no children" if @left.nil?
		if @right
			return ("(%s\n" +
							("   " * (indent+1)) +
							"%s\n" +
							("   " * (indent+1)) +
							"%s)") % [@id,
												(if (@left.class == Node)
														 @left.to_s(indent+1)
												 else @left.to_s end
												),
												(if (@right.class == Node)
														 @right.to_s(indent+1)
												 else @right.to_s end
												)
												]
		else
			return ("(%s" +
							" "	  +
							"%s)") % [@id,
												(if (@left.class == Node)
														@left.to_s(indent+1)
												 else @left.to_s end
												)
											 ]
		end
	end
end

# A subdivision of code, associated with a function, struct definition, control structure, or the whole source file
# Has a parse tree for each statement, and a table of variables to give local scope
# Blocks are nested within each other as in the code itself, with all blocks contained within a single parent associated with
# the whole source.  The parent block contains a function table, as well as the global scope.
class Block
	attr_accessor :children, :vartab, :functab, :parent
	# If a block isn't the parent block, you can't declare functions -- as in C, no nested functions
	def initialize(parent_block)
		@children = { }
		@vartab = { }
		@functab = { }
		@parent = parent_block
	end
	
	# Searches for a variable in the current scope.  If it can't be found, searches parent blocks
	def find_name(name)
		if @vartab[name]
			return @vartab[name]
		else
			return @parent.find_name(name) if @parent
		end
		raise "Variable '%s' not defined..." % name
	end
end

class Parser
	@@symtab = {} # Contains all the valid language tokens.  I'm not entirely sure about declaring it a class var
	def self.symtab
			@@symtab
	end

	attr_accessor :node, :sav, :tokenizer #done to get parentheses working.  Fix later
	def initialize(_src)
		@tokenizer = Lexer.new(_src)
		@token = nil
		@blocklevel = 0
		@node = nil
		@sav = nil
	end

	def self.symbol(id, bp=0) #Returns symbol, takes value and binding power
		if @@symtab[id]
			if bp > @@symtab[id]::lbp
				@@symtab[id]::lbp = bp
			end
		else
			@@symtab[id] = Node.new(id, bp)
		end
		@@symtab[id]
	end

	def self.prefix(id, bp=0, &nud)
		sym = symbol(id, bp)
		if nud
			sym::nud = nud
		else
			sym::nud = Proc.new do |node, parser|
				node::left = parser.expression bp
				node
			end
		end
		sym
	end
	
	def self.infix_left(id, bp=0, &led)
		sym = symbol(id, bp)
		if led
			sym::led = led
		else
			sym::led = Proc.new do |node, left, parser|
				node::left = left
				node::right = parser.expression bp
				node
			end
			sym
		end
	end
	
	def self.infix_right(id, bp=0, &led)
		sym = symbol(id, bp)
		if led
			sym::led = led
		else
			sym::led = Proc.new do |node, left, parser|
				node::left = left
				node::right = parser.expression bp-1
				node
			end
		end
		sym
	end
	
	def self.postfix(id, bp=0, &led)
		sym = symbol(id, bp)
		if led
			sym::led = led
		else
			sym::led = Proc.new do |node, left, parser|
				# fill in
			end
		end
		sym	
	end
	
	#@tokenizer::reserved_words.each do |keyword| # add all keywords
	#	symbol(keyword)
	#end ...later
	symbol('{')
	symbol('}')
	symbol(';')
	prefix('+', 10)
	prefix('-', 10)
	prefix('!', 70)
	prefix('(', 80) do |node|
		node = $i::parser.expression 0
#		$i::parser::sav = $i::parser::node
		$i::parser.expect ')'
		node
	end
	infix_left('(', 80) do |node, left| #for function calls
		raise 'Function called with bad name' if left::id != 'name'
		node::left = left
		node::right = $i::parser::expression 0
		$i::parser.expect ')'
		node
	end
	symbol(')')
	infix_left(',', 5)
	infix_right('=', 10) do |node, left|
		raise 'Left side of \'=\' not an lvalue' if left::id != 'name'
		node::left = left
		node::right = $i::parser.expression 9
		node
	end
	infix_right('&', 30)
	infix_right('|', 30)
	infix_left('>', 40)
	infix_left('<', 40)
	infix_left('<=', 40)
	infix_left('==', 40)
	infix_left('!=', 40)
	infix_left('>=', 40)
	infix_left('+', 50)
	infix_left('-', 50)
	infix_left('*', 60)
	infix_left('/', 60)
	infix_left('%', 60)
	symbol('literal')::nud = Proc.new do |node|
		node
	end
#	symbol('string')::nud = Proc.new do |node|
#		node
#	end
	symbol('name')::nud = Proc.new do |node|
		node
	end
	symbol('end')::nud = Proc.new do |node|
		node
	end
	
	def expect(expected=nil)
		if expected
			if @node::id != expected #doesn't actually get new token properly.  Fix later
				expect
				return @node
				raise SyntaxError, "%s expected, but %s received instead" % [expected, (@node ? ("symbol " + @node.id) : "nothing")] if @node::id != expected
			end
		else
			@token = @tokenizer.get_token
			case @token::type
				when :Operator
					nextnode = @@symtab[@token::value].clone #probably not the best way to do, maybe use metaprogramming
				when :Number
					nextnode = @@symtab['literal'].clone
					nextnode::left = @token::value.to_i
				when :String
					nextnode = @@symtab['literal'].clone
					nextnode::left = @token::value
				when :Name
					nextnode = @@symtab['name'].clone
					nextnode::left = @token::value
				when :Keyword
					nextnode = @@symtab[@token::value].clone
				when :End
					nextnode = @@symtab['end'].clone
			end
#			if @sav == @node #When we need to get a new token/node, which is most of the time
				@node = nextnode
#			end
#			if expected	#caused trouble with the ';'
#				if nextnode::id != expected
#					raise SyntaxError, "%s expected, but %s received instead" % [expected, (nextnode ? ("symbol " + nextnode.id) : "nothing")]
#				end
#			end
			@node #Either we have a new node, or will just use the existing one
		end
	end
	
	def expression(rbp)
		@sav = @node
		expect
		left = @sav::nud.call(@sav, self)
		while rbp < @node.lbp
			@sav = @node
 			expect
			left = @sav::led.call(@sav, left, self)
		end
		left
	end
	
	def statement
		@sav = expect
		expression(0)
	end
end

$live = true
l = Lexer.new($stdin)
l.get_token
#puts "q to exit\n"
#p = Parser.new($stdin)
#while (c = gets) and (c != "q")
#	$stdin.ungetc(c)
#	puts p.statement
#end