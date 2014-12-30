node unity ChatClient namespace Fitbos.Chat
node scala ChatServer namespace org.fitbos.chat

direction ChatClient -> ChatServer
	message SetName					# Set your chat nickname
		String name					# The nickname
		Map<Int, Set<String>> aaa
	end
end

direction ChatClient <- ChatServer
	message SetNameResult			# The result of SetName
		Bool succeeded				# Is succeeded or not
		Set<Set<String>> test
	end
end