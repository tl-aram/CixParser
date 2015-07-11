# Parser for Cix, a subset of the C language (http://github.com/Celarix/Cix)
# This parser is a reworked version of what I did for my previous unnamed language, which is an implementation (rip-off)
# of the TDOP parsing algorithm (http://javascript.crockford.com/tdop/tdop.html)

class Token
	attr_accessor :type, :value
	def initialize
		@type = nil
		@value = nil
	end
end

class Lexer
	@@reserved_words = "break case char const continue do double else float for goto if int long return short sizeof struct void while".split(' ')
	attr_accessor :lineno, :source, :tok_start, :cur
	def initialize
		@lineno = 0
		@source = [ ]
		@tok_start = 0
		@cur = 0
	end
	
# The parser usually ignores whitespace, but since, say method(vars) is valid function call syntax while method  (vars ) isn't,
# the parser sometimes needs to check. 
 def get_token(skip_whitespace=1)
		t = Token.new
		while (skip_whitespace && (@source[@lineno][@cur]) =~ /\s/) #should match newlines too
			@cur+=1
		end
		if @source[@lineno][@cur].nil? #probably change to empty?
			t::type = 'end'
			return t
		end
		@tok_start = @cur
		if (@source[@lineno][@cur]) =~ /[A-Za-z_]/
			@@reserved_words.each do |word|
				if (@source[@lineno][@cur..@cur+word.length-1] == word && @source[@lineno][@cur+word.length-1] > 'z') #to check that it's the end of the name
					@cur+=word.length
					t::type = 'keyword'
					t::value = @source[@lineno][@tok_start..@cur+word.length-1]
					return t
				end
			end
			while @source[@lineno][@cur] =~ /A-Za-z_/
				@cur+=1
			end
			t::type = 'name'
			t::value = @source[@lineno][@tok_start..@cur-1]
			return t #since @cur is already incremented to point to the next char, we return early
				@cur+=1
			while @source[@lineno][@cur] =~ /\d/
				@cur+=1
			end
			t::type = 'number'
			t::value = @source[@lineno][@tok_start..@cur-1]
			return t
		end
		# A method for tokenizing the comparison operators <=, == >= !=, as well as compound assignment operators
		def compsym(sym)
			if @source[@lineno][@cur.next] == '='
				@cur+=1
				sym + '='
			else
				sym
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
	def initialize
		@tokenizer = Lexer.new
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
			sym::nud = Proc.new do |node|
				node::left = $i::parser.expression bp
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
			sym::led = Proc.new do |node, left|
				node::left = left
				node::right = $i::parser.expression bp
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
			sym::led = Proc.new do |node, left|
				node::left = left
				node::right = $i::parser.expression bp-1
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
			sym::led = Proc.new do |node, left|
				# fill in
			end
		end
		sym	
	end
	
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
	infix('(', 80) do |node, left| #for function calls
		raise 'Function called with bad name' if left::id != 'name'
		node::left = left
		node::right = $i::parser::expression 0
		$i::parser.expect ')'
		node
	end
	symbol(')')
	infix(',', 5)
	infixr('=', 10) do |node, left|
		raise 'Left side of \'=\' not an lvalue' if left::id != 'name'
		node::left = left
		node::right = $i::parser.expression 9
		node
	end
	infixr('&', 30)
	infixr('|', 30)
	infix('>', 40)
	infix('<', 40)
	infix('<=', 40)
	infix('==', 40)
	infix('!=', 40)
	infix('>=', 40)
	infix('+', 50)
	infix('-', 50)
	infix('*', 60)
	infix('/', 60)
	infix('%', 60)
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
				when 'operator'
					nextnode = @@symtab[@token::value].clone #probably not the best way to do, maybe use metaprogramming
				when 'number'
					nextnode = @@symtab['literal'].clone
					nextnode::left = @token::value.to_i
				when 'string'
					nextnode = @@symtab['literal'].clone
					nextnode::left = @token::value
				when 'name'
					nextnode = @@symtab['name'].clone
					nextnode::left = @token::value
				when 'func'
					nextnode = @@symtab['func'].clone
					nextnode::left = @token::value
				when 'while'
					nextnode = @@symtab['while'].clone
					nextnode::left = @token::value
				when 'end'
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
		left = @sav::nud.call(@sav)
		while rbp < @node.lbp
			@sav = @node
 			expect
			left = @sav::led.call(@sav, left)
		end
		left
	end
		expect
		tree = expression 0
		expect ';'
		tree
	end
end
