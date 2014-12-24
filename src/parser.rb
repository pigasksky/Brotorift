require 'rltk'
require './ast'


class Parser < RLTK::Parser
	@@enum_value = 0

	list(:decl_list, :decl)

	production(:decl) do
		clause('include_decl')									{ |d| d }
		clause('namespace_decl')								{ |d| d }
		clause('node_decl')										{ |d| d }
		clause('struct_decl')									{ |d| d }
		clause('enum_decl')										{ |d| d }
		clause('direction_decl')								{ |d| d }
		clause('sequence_decl')									{ |d| d }
	end

	production(:include_decl) do
		clause('INCLUDE STRING')								{ |_, filename| IncludeDecl.new filename }
	end

	production(:namespace_decl) do
		clause('NAMESPACE IDENT namespace')						{ |_, language, namespace| NamespaceDecl.new language, namespace }
	end

	production(:namespace) do
		clause('IDENT')											{ |name| name }
		clause('IDENT DOT namespace')							{ |name, _, rest| name + '.' + rest }
	end

	production(:node_decl) do
		clause('NODE IDENT doc')								{ |_, name, doc| NodeDecl.new name, name, doc }
		clause('NODE IDENT AS IDENT doc')						{ |_, name, _, nickname, doc| NodeDecl.new name, nickname, doc }
	end

	production(:doc) do
		clause('')												{ || '' }
		clause('DOCUMENT')										{ |doc| doc }
	end

	production(:struct_decl) do
		clause('STRUCT IDENT doc member_list END')				{ |_, name, doc, members, _| StructDecl.new name, doc, members }
	end

	list(:member_list, :member)

	production(:member) do
		clause('type IDENT doc')								{ |type, name, doc| MemberDef.new type, name, doc }
	end

	production(:type) do
		clause('IDENT')											{ |name| TypeDef.new name, [] }
		clause('IDENT LANGLE type_param_list RANGLE')			{ |name, _, params, _| TypeDef.new name, params }
	end

	nonempty_list(:type_param_list, :IDENT, :COMMA)

	production(:enum_decl) do
		clause('ENUM IDENT doc element_list END')				{ |_, name, doc, elements, _| @@enum_value = 0; EnumDecl.new name, doc, elements }
	end

	list(:element_list, :element)

	production(:element) do
		clause('IDENT doc')										{ |name, doc| @@enum_value += 1; EnumElementDef.new name, @@enum_value - 1, doc }
		clause('IDENT ASSIGN NUMBER doc')						{ |name, _, value, doc| @@enum_value = value + 1; EnumElementDef.new name, @@enum_value - 1, doc }
	end

	production(:direction_decl) do
		clause('DIRECTION IDENT ARROW IDENT doc message_list END')	{ |_, from, _, to, doc, messages, _| DirectionDecl.new from, to, doc, messages }
	end

	list(:message_list, :message)

	production(:message) do
		clause('MESSAGE IDENT doc member_list END')				{ |_, name, doc, members, _| MessageDef.new name, doc, members }
	end

	production(:sequence_decl) do
		clause('SEQUENCE IDENT doc step_list END')				{ |_, name, doc, steps, _| SequenceDecl.new name, doc, steps }
	end

	list(:step_list, :step)

	production(:step) do
		clause('IDENT ARROW IDENT COLON IDENT doc')				{ |from, _, to, _, message, doc| StepDef.new from, to, message, doc }
	end

	finalize
end


content = File.read 'test2.b'
tokens = Lexer::lex content
puts tokens

puts '-----------------------------------------------------------'

ast = Parser::parse tokens
puts ast