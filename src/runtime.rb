
class Def
	attr_reader :ast

	def initialize ast
		@ast = ast
	end
end


class TypeDef < Def
	attr_reader :name

	def initialize ast, name
		super ast
		@name = name
	end
end


class BuiltinTypeDef < TypeDef
	def initialize name
		super nil, name
	end
end


class EnumElementDef < Def
	attr_reader :name, :value, :doc

	def initialize ast
		super ast
		@name = ast.name
		@value = ast.value
		@doc = ast.doc
	end
end


class EnumTypeDef < TypeDef
	attr_reader :elements, :doc

	def initialize ast
		super ast, ast.name
		@doc = ast.doc
		@elements = {}
	end

	def add_element element_def
		@elements[element_def.name] = element_def
	end
end


class NodeDef < Def
	attr_reader :name, :language, :nickname, :namespace, :doc

	def initialize ast
		super ast
		@name = ast.name
		@language = ast.language
		@nickname = ast.nickname
		@namespace = ast.namespace
		@doc = ast.doc
	end
end


class StructTypeDef < TypeDef
	attr_reader :members, :doc

	def initialize ast
		super ast, ast.name
		@members = []
		@doc = ast.doc
	end

	def add_member member_def
		@members.push member_def
	end

	def get_member name
		@members.find { |m| m.name == name }
	end
end


class MemberTypeDef < Def
	attr_reader :type, :params

	def initialize ast, type, params
		super ast
		@type = type
		@params = params
	end
end


class MemberDef < Def
	attr_reader :name, :type, :doc

	def initialize ast, type
		super ast
		@name = ast.name
		@type = type
		@doc = ast.doc
	end
end


class DirectionDef < Def
	attr_reader :client, :direction, :server, :messages, :doc

	def initialize ast, client, server
		super ast
		@client = client
		@direction = ast.direction
		@server = server
		@messages = {}
		@doc = ast.doc
	end

	def name
		case @direction
		when :left
			return "#{@client.name} <- #{@server.name}"
		when :right
			return "#{@client.name} -> #{@server.name}"
		end
	end

	def add_message message_def
		@messages[message_def.name] = message_def
	end
end


class MessageDef < Def
	attr_reader :name, :members, :doc

	def initialize ast
		super ast
		@name = ast.name
		@members = []
		@doc = ast.doc
	end

	def add_member member_def
		@members.push member_def
	end

	def get_member name
		@members.find { |m| m.name == name }
	end
end


class SequenceDef < Def
	attr_reader :name, :steps, :doc

	def initialize ast
		super ast
		@name = ast.name
		@steps = []
		@doc = ast.doc
	end

	def add_step step_def
		@steps.push step_def
	end
end


class StepDef < Def
	attr_reader :direction, :message, :doc

	def initialize ast, direction, message
		super ast
		@direction = direction
		@message = message
		@doc = ast.doc
	end
end


class Runtime
	attr_reader :builtins
	attr_reader :nodes
	attr_reader :enums
	attr_reader :structs
	attr_reader :directions
	attr_reader :sequences

	def initialize
		@builtins = {}
		@enums = {}
		@nodes = {}
		@structs = {}
		@directions = []
		@sequences = {}

		self.init_builtins
	end

	def init_builtins
		type_names = [
			'Bool',
			'Byte',
			'Short',
			'Int',
			'Long',
			'Float',
			'Double',
			'String',
			'ByteBuffer',
			'List',
			'Set',
			'Map',
			'Vector2',
			'Vector3',
			'Matrix4',
		]
		type_names.each { |t| @builtins[t] = BuiltinTypeDef.new t }
	end

	def add_enum enum_def
		@enums[enum_def.name] = enum_def
	end

	def add_node node_def
		@nodes[node_def.name] = node_def
		@nodes[node_def.nickname] = node_def if node_def.name != node_def.nickname
	end

	def add_struct struct_def
		@structs[struct_def.name] = struct_def
	end

	def add_direction direction_def
		@directions.push direction_def
	end

	def get_direction client, direction, server
		@directions.find { |d| d.client == client and d.server == server and d.direction == direction }
	end

	def add_sequence sequence_def
		@sequences[sequence_def.name] = sequence_def
	end
end