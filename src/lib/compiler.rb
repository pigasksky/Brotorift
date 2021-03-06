require_relative 'parser'
require_relative 'compiler_error'
require_relative 'runtime'


class String
	def char_case
		if self == self.upcase
			return :upper
		else
			return :lower
		end
	end
end


class Compiler
	attr_reader :errors, :runtime

	def initialize
		@errors = []
		@message_base_id = 0
		@message_id = 0
	end

	def compile filename
		@runtime = self.compile_file filename
	end

	def compile_file filename
		content = File.read filename, encoding: 'utf-8'
		tokens = Lexer::lex content, filename
		begin
			ast = Parser::parse tokens
		rescue RLTK::NotInLanguage => e
			add_error UnexpectedTokenError.new e.current
			return
		end
		runtime = Runtime.new filename
		self.compile_ast runtime, ast
		runtime
	end

	def compile_ast runtime, ast
		@runtime = runtime
		ast.each do |decl|
			begin
				case decl
				when IncludeDecl
					compile_include decl
				when EnumDecl
					compile_enum decl
				when NodeDecl
					compile_node decl
				when StructDecl
					compile_struct decl
				when DirectionDecl
					compile_direction decl
				when SequenceDecl
					compile_sequence decl
				end
			rescue CompilerError => e
				@errors.push e
			end
		end
	end

	def compile_include include_ast
		filename = include_ast.filename + '.b'
		if not File.exists? filename
			add_error IncludeFileNotFoundError.new filename, include_ast.position
			return
		end
		include_runtime = self.compile_file filename
		@runtime.add_include include_runtime
	end

	def compile_enum enum_ast
		self.check_case 'enum', :upper, enum_ast
		self.check_type_unique enum_ast
		enum_def = EnumTypeDef.new enum_ast
		enum_ast.elements.each do |element_ast|
			self.check_case 'enum element', :upper, element_ast
			self.check_unique 'enum element', enum_def.elements[element_ast.name], element_ast
			element_def = EnumElementDef.new element_ast
			enum_def.add_element element_def
		end
		@runtime.add_enum enum_def
	end

	def compile_node node_ast
		self.check_case 'node', :upper, node_ast
		self.check_case 'node_nick', :upper, node_ast
		self.check_unique 'node', @runtime.nodes[node_ast.name], node_ast
		self.check_unique 'node', @runtime.nodes[node_ast.nickname], node_ast
		node_def = NodeDef.new node_ast
		@runtime.add_node node_def
	end

	def compile_struct struct_ast
		self.check_case 'struct', :upper, struct_ast
		self.check_type_unique struct_ast
		struct_def = StructTypeDef.new struct_ast
		struct_ast.members.each do |member_ast|
			self.check_case 'struct member', :lower, member_ast
			self.check_unique 'struct member', struct_def.get_member(member_ast.name), member_ast
			member_type_def = self.get_member_type @runtime.nodes.values, member_ast.type
			member_def = MemberDef.new member_ast, member_type_def
			struct_def.add_member member_def
		end
		@runtime.add_struct struct_def
	end

	def compile_direction direction_ast
		client = @runtime.nodes[direction_ast.client]
		if client == nil
			add_error NodeNotFoundError.new direction_ast, direction_ast.client
			return
		end

		server = @runtime.nodes[direction_ast.server]
		if server == nil
			add_error NodeNotFoundError.new direction_ast, direction_ast.server
			return
		end

		if client == server
			add_error ClientServerSameError.new direction_ast
			return
		end

		@message_base_id += 1000
		@message_id = 0

		old_direction = @runtime.get_direction client, direction_ast.direction, server
		self.check_unique 'direction', old_direction, direction_ast

		direction_def = DirectionDef.new direction_ast, client, server
		direction_ast.messages.each do |message_ast|
			self.check_case 'message', :upper, message_ast
			self.check_unique 'message', direction_def.messages[message_ast.name], message_ast
			direction_def.add_message self.compile_message direction_def, message_ast
		end
		@runtime.add_direction direction_def
	end

	def compile_message direction_def, message_ast
		@message_id += 1
		message_def = MessageDef.new message_ast, @message_base_id + @message_id
		message_ast.members.each do |member_ast|
			self.check_case 'message member', :lower, member_ast
			self.check_unique 'message member', message_def.get_member(member_ast.name), member_ast

			nodes_to_check = [direction_def.client, direction_def.server]
			member_type_def = self.get_member_type nodes_to_check, member_ast.type
			member_def = MemberDef.new member_ast, member_type_def
			message_def.add_member member_def
		end
		message_def
	end

	def compile_sequence sequence_ast
		self.check_case 'sequence', :upper, sequence_ast
		self.check_unique 'sequence', @runtime.get_sequence(sequence_ast.name), sequence_ast
		sequence_def = SequenceDef.new sequence_ast
		sequence_ast.steps.each do |step_ast|
			sequence_def.add_step self.compile_step step_ast
		end
		@runtime.add_sequence sequence_def
	end

	def compile_step step_ast
		client = @runtime.nodes[step_ast.client]
		if client == nil
			add_error NodeNotFoundError.new step_ast, step_ast.client
			return nil
		end

		server = @runtime.nodes[step_ast.server]
		if server == nil
			add_error NodeNotFoundError.new step_ast, step_ast.server
			return nil
		end

		if client == server
			add_error ClientServerSameError.new step_ast
			return nil
		end

		direction_def = @runtime.get_direction client, step_ast.direction, server
		if direction_def == nil
			add_error DirectionNotFoundError.new step_ast, client, step_ast.direction, server
			return nil
		end

		message_def = direction_def.messages[step_ast.message]
		if message_def == nil
			add_error MessageNotFoundError.new step_ast, direction_def
			return nil
		end

		StepDef.new step_ast, direction_def, message_def
	end

	def get_member_type nodes_to_check, member_type_ast
		type_def, runtime = self.get_type member_type_ast, true
		return nil if type_def == nil

		params = []
		case type_def.name
		when 'List'
			self.check_type_param_count member_type_ast, 1
			params.push self.get_member_type nodes_to_check, member_type_ast.params[0]
		when 'Set'
			self.check_type_param_count member_type_ast, 1
			params.push self.get_member_type nodes_to_check, member_type_ast.params[0]
		when 'Map'
			self.check_type_param_count member_type_ast, 2
			params.push self.get_member_type nodes_to_check, member_type_ast.params[0]
			params.push self.get_member_type nodes_to_check, member_type_ast.params[1]
		else
			self.check_type_param_count member_type_ast, 0
		end

		member_type_def = TypeInstanceDef.new member_type_ast, type_def, params, runtime
		self.check_type_nodes member_type_ast, member_type_def
		member_type_def
	end

	def check_type_nodes member_type_ast, member_type_def
		return if @runtime == member_type_def.runtime

		@runtime.nodes.each do |n|
			external_node = member_type_def.runtime.nodes.find { |node| n.name == node.name }
			if external_node == nil
				add_error CorrespondingNodeNotFoundError.new member_type_def, n.name
				return
			end

			if external_node.language != n.language
				add_error NodeLanguageMismatchError.new member_type_def, n, external_node
				return
			end
		end
	end

	def get_type ast, raise_error
		return nil if ast == nil
		
		type_def, runtime = @runtime.get_type ast.name
		return type_def, runtime if type_def != nil

		add_error TypeNotFoundError.new ast, ast.name if raise_error
		return type_def, runtime
	end

	def check_case type, initial_case, ast
		if type == 'node_nick' and initial_case != ast.nickname[0].char_case
			add_error InitialCaseError.new type, initial_case, ast
		elsif initial_case != ast.name[0].char_case
			add_error InitialCaseError.new type, initial_case, ast
		end
	end

	def check_type_unique ast
		type_def, _ = self.get_type ast, false
		return if type_def == nil

		if type_def.is_a? BuiltinTypeDef
			add_error BuiltinNameConflictError.new ast
		else
			self.check_unique 'type', type_def, ast
		end
	end

	def check_unique type, old_def, new_ast
		return if old_def == nil
		add_error DuplicateDefError.new type, old_def.name, old_def.ast, new_ast
	end

	def check_type_param_count ast, expected_count
		add_error TypeParamCountMismatchError.new ast, expected_count if ast.params.length != expected_count
	end

	def add_error error
		@errors.push error
	end
end